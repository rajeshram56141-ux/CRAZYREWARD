import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'pubscale_plugin_method_channel.dart';

abstract class PubscalePluginPlatform extends PlatformInterface {
  /// Constructs a PubscalePluginPlatform.
  PubscalePluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static PubscalePluginPlatform _instance = MethodChannelPubscalePlugin();

  /// The default instance of [PubscalePluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelPubscalePlugin].
  static PubscalePluginPlatform get instance => _instance;
  
  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PubscalePluginPlatform] when
  /// they register themselves.
  static set instance(PubscalePluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> initSDK(
      String appId,
      String userId,
      ) {
    throw UnimplementedError('initSDK() has not been implemented.');
  }

  Future<bool> showOfferWall() {
    throw UnimplementedError('showOfferWall() has not been implemented.');
  }
}
