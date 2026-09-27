# 📦 PubscalePlugin (Flutter)

A simple Flutter plugin to integrate Pubscale Offerwall in your app using platform interface architecture. Easily initialize the SDK and show the Offerwall screen using a few lines of code.

---

## 🚀 Features

- ✅ Initialize Pubscale SDK  
- ✅ Show Offerwall via platform interface  
- ✅ Clean error handling and debug logging  

---

## 📦 Installation

Add this plugin to your `pubspec.yaml`:

```yaml
dependencies:
  pubscale_plugin:
    path: ./path_to_your_plugin_directory
```

> Update the path as per your local setup.

---

## 🛠️ Android Setup

1. Add Pubscale SDK and dependencies in `android/app/build.gradle`.

2. Add required permissions and metadata in your `AndroidManifest.xml`.

3. Ensure proper Proguard rules are added if you're using code shrinking.

---

## 🧑‍💻 Usage

### 1️⃣ Initialize the SDK

```dart
final initialized = await PubscalePlugin.instance.initSDK(
  appId: 'your_app_id',
  userId: 'unique_user_id',
);
```

---

### 2️⃣ Show Offerwall

```dart
final shown = await PubscalePlugin.instance.showOfferwall();
```

---

## 📄 Method Summary

| Method              | Description                          |
|---------------------|--------------------------------------|
| `initSDK()`         | Initializes the Pubscale SDK         |
| `showOfferwall()`   | Displays the Offerwall screen        |

---

## 📂 Plugin Code

```dart
import 'package:flutter/material.dart';

import 'pubscale_plugin_platform_interface.dart';

class PubscalePlugin {
  static PubscalePlugin? _instance;

  static PubscalePlugin get instance => _instance ??= PubscalePlugin();

  final PubscalePluginPlatform _platform = PubscalePluginPlatform.instance;

  Future<bool> initSDK({
    required String appId,
    required String userId,
  }) async {
    try {
      await _platform.initSDK(appId, userId);
      return true;
    } catch (e) {
      debugPrint('Failed to initialize SDK: $e');
      return false;
    }
  }

  Future<bool> showOfferwall() async {
    try {
      await _platform.showOfferWall();
      return true;
    } catch (e) {
      debugPrint('Failed to show offerwall: $e');
      return false;
    }
  }
}
```

---

## 🧪 Testing Tips

- Use valid `appId` and `userId` from your Pubscale dashboard.
- Always test on real Android devices for full functionality.

---

## 📃 License

MIT License. Free to use, modify, and distribute.