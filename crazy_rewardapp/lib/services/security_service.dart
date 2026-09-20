import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'device_integrity_service.dart';

class SecurityService {
  // Byte-masked XOR obfuscation to prevent plain text exposure in decompiled APK
  static const List<int> _kSecMask = [67, 114, 97, 122, 121, 82, 101, 119, 97, 114, 100, 83, 101, 99];
  static const List<int> _kSecBytes = [
    32, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 12, 22, 6, 32, 45, 80, 66, 75, 103,
    0, 67, 86, 23, 86, 106, 0, 80, 114, 67, 84, 76, 79, 51, 6, 18, 83, 23,
    87, 101, 85, 90, 39, 20, 7, 66, 65, 48
  ];

  static String _resolveMasterApiKey() {
    final chars = List<int>.generate(
      _kSecBytes.length,
      (i) => _kSecBytes[i] ^ _kSecMask[i % _kSecMask.length],
    );
    return String.fromCharCodes(chars);
  }

  // Master API Key (Seed for deriving per-user / per-device session keys)
  static final String _masterApiKey = _resolveMasterApiKey();
  static String get masterApiKey => _masterApiKey;

  static String _dynamicSecretKey = '';
  static String get secretKey => _dynamicSecretKey.isNotEmpty ? _dynamicSecretKey : _masterApiKey;

  static void updateSecretKey(String newKey) {
    if (newKey.trim().isNotEmpty) {
      _dynamicSecretKey = newKey.trim();
    }
  }

  // ----------------------------------------------------
  // Dynamic Keys Local Storage Helper (Secure Sandbox)
  // ----------------------------------------------------
  static Future<String> _getSecureKeyPath(String filename) async {
    final directory = await getApplicationSupportDirectory();
    return '${directory.path}/$filename.enc';
  }

  static Future<void> saveSecureKeys(String clientPrivateKeyPem, String serverPublicKeyPem) async {
    try {
      // Encrypt PEM strings using our dynamic AES-256 before writing to disk
      final encPrivateKey = encryptPayload(clientPrivateKeyPem);
      final encPublicKey = encryptPayload(serverPublicKeyPem);

      final privateFile = File(await _getSecureKeyPath('client_private'));
      final publicFile = File(await _getSecureKeyPath('server_public'));

      await privateFile.writeAsString(encPrivateKey);
      await publicFile.writeAsString(encPublicKey);
    } catch (e) {}
  }

  static Future<String?> getSecurePrivateKey() async {
    try {
      final file = File(await _getSecureKeyPath('client_private'));
      if (await file.exists()) {
        final encryptedContent = await file.readAsString();
        final rawKey = decryptPayload(encryptedContent);
        if (rawKey.isNotEmpty) return rawKey;
      }
    } catch (e) {}
    return null;
  }

  static Future<String?> getSecureServerPublicKey() async {
    try {
      final file = File(await _getSecureKeyPath('server_public'));
      if (await file.exists()) {
        final encryptedContent = await file.readAsString();
        final rawKey = decryptPayload(encryptedContent);
        if (rawKey.isNotEmpty) return rawKey;
      }
    } catch (e) {}
    return null;
  }

  static Future<void> clearSecureKeys() async {
    try {
      final privateFile = File(await _getSecureKeyPath('client_private'));
      final publicFile = File(await _getSecureKeyPath('server_public'));
      if (await privateFile.exists()) {
        await privateFile.delete();
      }
      if (await publicFile.exists()) {
        await publicFile.delete();
      }
    } catch (_) {}
  }

  // ----------------------------------------------------
  // RSA-AES Envelope Wrapper HTTP request posting helper
  // ----------------------------------------------------
  static Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    dynamic body,
    String userId = '',
    String deviceId = '',
    String? token,
  }) async {
    try {
      final privateKeyPem = await getSecurePrivateKey();
      final serverPublicKeyPem = await getSecureServerPublicKey();

      Map<String, String> finalHeaders = headers != null ? Map.from(headers) : {};
      finalHeaders['Content-Type'] = 'application/json';
      if (userId.isNotEmpty) finalHeaders['user-id'] = userId;
      if (deviceId.isNotEmpty) finalHeaders['device-id'] = deviceId;
      if (token != null && token.isNotEmpty) {
        finalHeaders['Authorization'] = 'Bearer $token';
      }

      dynamic requestBodyPayload;

      // Check if RSA keys are available for Envelope Encryption
      if (privateKeyPem != null && serverPublicKeyPem != null && privateKeyPem.isNotEmpty && serverPublicKeyPem.isNotEmpty) {
        // 1. Generate dynamic 32-byte AES key
        final randomBytes = List<int>.generate(32, (i) => DateTime.now().microsecondsSinceEpoch % 256);
        final aesKeyBuf = Uint8List.fromList(randomBytes);

        // 2. Encrypt body payload with raw AES Key
        final jsonStr = body is String ? body : jsonEncode(body ?? {});

        final key = enc.Key(aesKeyBuf);
        final iv = enc.IV(aesKeyBuf.sublist(0, 16));
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
        final encryptedPayloadBase64 = encrypter.encrypt(jsonStr, iv: iv).base64;

        // 3. Encrypt dynamic AES key with Server RSA Public Key (using standard OAEP encoding)
        final parser = enc.RSAKeyParser();
        final serverPubKey = parser.parse(serverPublicKeyPem) as RSAPublicKey;
        final rsaEncrypter = enc.Encrypter(enc.RSA(publicKey: serverPubKey, encoding: enc.RSAEncoding.OAEP));
        final encryptedAesKeyBase64 = rsaEncrypter.encryptBytes(aesKeyBuf).base64;

        // 4. Add headers and payload body
        finalHeaders['x-envelope-key'] = encryptedAesKeyBase64;
        requestBodyPayload = jsonEncode({'payload': encryptedPayloadBase64});
      } else {
        // Fallback to traditional symmetric AES encryption
        final encryptedPayloadBase64 = encryptPayload(body, userId: userId, deviceId: deviceId);
        final secHeaders = getSecurityHeaders(body);
        finalHeaders.addAll(secHeaders);
        requestBodyPayload = jsonEncode({'payload': encryptedPayloadBase64});
      }

      // Make the network post
      final response = await http.post(
        Uri.parse(url),
        headers: finalHeaders,
        body: requestBodyPayload,
      );

      // Intercept response and decrypt for all status codes
      final String? responseEnvelopeKeyBase64 = response.headers['x-envelope-key'];
      Map<String, dynamic> data = {};
      try {
        data = Map<String, dynamic>.from(jsonDecode(response.body));
      } catch (_) {}

      String decryptedBodyStr = '';

      // Decrypt using RSA envelope if key header is present
      if (responseEnvelopeKeyBase64 != null && privateKeyPem != null && privateKeyPem.isNotEmpty) {
        final parser = enc.RSAKeyParser();
        final clientPrivKey = parser.parse(privateKeyPem) as RSAPrivateKey;
        final rsaDecrypter = enc.Encrypter(enc.RSA(privateKey: clientPrivKey, encoding: enc.RSAEncoding.OAEP));

        try {
          final decryptedAesKeyBytes = rsaDecrypter.decryptBytes(enc.Encrypted.fromBase64(responseEnvelopeKeyBase64));
          final aesKeyBuf = Uint8List.fromList(decryptedAesKeyBytes);

          final encryptedResponsePayload = data['responsePayload'] ?? data['payload'];
          if (encryptedResponsePayload != null) {
            final key = enc.Key(aesKeyBuf);
            final iv = enc.IV(aesKeyBuf.sublist(0, 16));
            final decipher = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
            decryptedBodyStr = decipher.decrypt(enc.Encrypted.fromBase64(encryptedResponsePayload.toString()), iv: iv);
          }
        } catch (e) {}
      }

      // Fallback: Decrypt using traditional symmetric AES if responsePayload is present
      if (decryptedBodyStr.isEmpty && data['responsePayload'] != null) {
        decryptedBodyStr = decryptPayload(data['responsePayload'].toString(), userId: userId, deviceId: deviceId);
      }

      // Parse decrypted body to check if handshake keys are returned
      final finalBodyStr = decryptedBodyStr.isNotEmpty ? decryptedBodyStr : response.body;
      if (response.statusCode == 200) {
        try {
          final parsedJson = jsonDecode(finalBodyStr);
          if (parsedJson is Map && parsedJson['clientPrivateKey'] != null && parsedJson['serverPublicKey'] != null) {
            await saveSecureKeys(
              parsedJson['clientPrivateKey'].toString(),
              parsedJson['serverPublicKey'].toString()
            );
          }
        } catch (_) {}
      }

      if (decryptedBodyStr.isNotEmpty) {
        return http.Response(decryptedBodyStr, response.statusCode, headers: response.headers);
      }

      return response;
    } catch (err) {
      rethrow;
    }
  }


  /// Derives dynamic per-user / per-device session key
  static String deriveSessionKey([String userId = '', String deviceId = '']) {
    if (userId.isEmpty && deviceId.isEmpty) return _masterApiKey;
    final seed = '$_masterApiKey:$userId:$deviceId';
    return sha256.convert(utf8.encode(seed)).toString().substring(0, 32);
  }

  /// Encrypts JSON payload using AES-256-CBC matching backend cryptoMiddleware.js
  static String encryptPayload(dynamic body, {String userId = '', String deviceId = ''}) {
    if (body == null) return '';
    try {
      final keyStr = deriveSessionKey(userId, deviceId);
      final keyBuf = List<int>.filled(32, 0);
      final secretBytes = utf8.encode(keyStr);
      for (int i = 0; i < secretBytes.length && i < 32; i++) {
        keyBuf[i] = secretBytes[i];
      }
      final ivBuf = keyBuf.sublist(0, 16);

      final key = enc.Key(Uint8List.fromList(keyBuf));
      final iv = enc.IV(Uint8List.fromList(ivBuf));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));

      final jsonStr = body is String ? body : jsonEncode(body);
      final encrypted = encrypter.encrypt(jsonStr, iv: iv);
      return encrypted.base64;
    } catch (e) {
      return '';
    }
  }

  /// Decrypts AES-256-CBC payload string
  static String decryptPayload(String base64Encrypted, {String userId = '', String deviceId = ''}) {
    if (base64Encrypted.isEmpty) return '';

    // Attempt 1: (userId, deviceId)
    String res = _rawDecrypt(base64Encrypted, deriveSessionKey(userId, deviceId));
    if (res.isNotEmpty) return res;

    // Attempt 2: (userId, '')
    if (userId.isNotEmpty && deviceId.isNotEmpty) {
      res = _rawDecrypt(base64Encrypted, deriveSessionKey(userId, ''));
      if (res.isNotEmpty) return res;
    }

    // Attempt 3: Master API Key
    res = _rawDecrypt(base64Encrypted, _masterApiKey);
    return res;
  }

  static String _rawDecrypt(String base64Encrypted, String keyStr) {
    try {
      final keyBuf = List<int>.filled(32, 0);
      final secretBytes = utf8.encode(keyStr);
      for (int i = 0; i < secretBytes.length && i < 32; i++) {
        keyBuf[i] = secretBytes[i];
      }
      final ivBuf = keyBuf.sublist(0, 16);

      final key = enc.Key(Uint8List.fromList(keyBuf));
      final iv = enc.IV(Uint8List.fromList(ivBuf));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));

      final decrypted = encrypter.decrypt(enc.Encrypted.fromBase64(base64Encrypted), iv: iv);
      return decrypted;
    } catch (e) {
      return '';
    }
  }

  /// Generates millisecond timestamp and HMAC-SHA256 signature for outgoing API requests
  static Map<String, String> getSecurityHeaders(dynamic body) {
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final String payloadStr = body != null ? jsonEncode(body) : '{}';

    final List<int> keyBytes = utf8.encode(_masterApiKey);
    final List<int> messageBytes = utf8.encode('$timestamp.$payloadStr');

    final Hmac hmac = Hmac(sha256, keyBytes);
    final Digest digest = hmac.convert(messageBytes);
    final String signature = digest.toString();

    return {
      'x-request-timestamp': timestamp.toString(),
      'x-signature': signature,
    };
  }

  /// Helper to check if VPN or Proxy is active
  static Future<bool> isVpnOrProxyActive() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.any,
        );
        for (final interface in interfaces) {
          final name = interface.name.toLowerCase();
          if (name.contains('tun') ||
              name.contains('ppp') ||
              name.contains('tap') ||
              name.contains('ipsec') ||
              name.contains('wireguard') ||
              name.contains('pflow')) {
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Checks device integrity security status
  static Future<SecurityStatus> checkSecurity() async {
    final bundle = await DeviceIntegrityService.getSecurityBundle();
    final vpnActive = await isVpnOrProxyActive();
    return SecurityStatus(
      isRooted: bundle['isRooted'] ?? false,
      isEmulator: bundle['isEmulator'] ?? false,
      isDevModeEnabled: false,
      isVpnActive: vpnActive,
    );
  }
}

class SecurityStatus {
  final bool isRooted;
  final bool isEmulator;
  final bool isDevModeEnabled;
  final bool isVpnActive;

  const SecurityStatus({
    this.isRooted = false,
    this.isEmulator = false,
    this.isDevModeEnabled = false,
    this.isVpnActive = false,
  });

  bool get isSecure => !isRooted && !isEmulator;
}
