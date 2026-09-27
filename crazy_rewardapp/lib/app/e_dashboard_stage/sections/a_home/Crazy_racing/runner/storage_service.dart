import 'package:get_storage/get_storage.dart';
import 'game_config.dart';

class RunnerStorageService {
  static final GetStorage _storage = GetStorage();

  static int getBestScore() {
    try {
      return _storage.read(GameConfig.keyBestScore) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static void saveBestScore(int score) {
    try {
      final currentBest = getBestScore();
      if (score > currentBest) {
        _storage.write(GameConfig.keyBestScore, score);
      }
    } catch (_) {}
  }

  static int getTotalCoins() {
    try {
      return _storage.read(GameConfig.keyTotalCoins) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static void addCoins(int coins) {
    try {
      final current = getTotalCoins();
      _storage.write(GameConfig.keyTotalCoins, current + coins);
    } catch (_) {}
  }

  static bool isSoundEnabled() {
    try {
      return _storage.read(GameConfig.keySoundEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  static void setSoundEnabled(bool value) {
    try {
      _storage.write(GameConfig.keySoundEnabled, value);
    } catch (_) {}
  }

  static bool isMusicEnabled() {
    try {
      return _storage.read(GameConfig.keyMusicEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  static void setMusicEnabled(bool value) {
    try {
      _storage.write(GameConfig.keyMusicEnabled, value);
    } catch (_) {}
  }

  static bool isVibrationEnabled() {
    try {
      return _storage.read(GameConfig.keyVibrateEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  static void setVibrationEnabled(bool value) {
    try {
      _storage.write(GameConfig.keyVibrateEnabled, value);
    } catch (_) {}
  }

  static bool isTutorialDone() {
    try {
      return _storage.read(GameConfig.keyTutorialDone) ?? false;
    } catch (_) {
      return false;
    }
  }

  static void setTutorialDone(bool value) {
    try {
      _storage.write(GameConfig.keyTutorialDone, value);
    } catch (_) {}
  }

  static bool isTutorialEnabled() {
    try {
      return _storage.read(GameConfig.keyTutorialEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  static void setTutorialEnabled(bool value) {
    try {
      _storage.write(GameConfig.keyTutorialEnabled, value);
      if (value) {
        // If re-enabling tutorial, reset tutorial done state
        setTutorialDone(false);
      }
    } catch (_) {}
  }

  static String getGraphicsQuality() {
    try {
      return _storage.read(GameConfig.keyGraphicsQuality) ?? 'High';
    } catch (_) {
      return 'High';
    }
  }

  static void setGraphicsQuality(String quality) {
    try {
      _storage.write(GameConfig.keyGraphicsQuality, quality);
    } catch (_) {}
  }

  static bool isShowFpsEnabled() {
    try {
      return _storage.read(GameConfig.keyShowFps) ?? false;
    } catch (_) {
      return false;
    }
  }

  static void setShowFpsEnabled(bool value) {
    try {
      _storage.write(GameConfig.keyShowFps, value);
    } catch (_) {}
  }

  static String getControlMode() {
    try {
      return _storage.read('crazy_runner_control_mode') ?? 'hybrid';
    } catch (_) {
      return 'hybrid';
    }
  }

  static void setControlMode(String mode) {
    try {
      _storage.write('crazy_runner_control_mode', mode);
    } catch (_) {}
  }

  static String getSwipeSensitivity() {
    try {
      return _storage.read('crazy_runner_swipe_sensitivity') ?? 'Normal';
    } catch (_) {
      return 'Normal';
    }
  }

  static void setSwipeSensitivity(String sensitivity) {
    try {
      _storage.write('crazy_runner_swipe_sensitivity', sensitivity);
    } catch (_) {}
  }

  static bool deductCoins(int amount) {
    try {
      final current = getTotalCoins();
      if (current >= amount) {
        _storage.write(GameConfig.keyTotalCoins, current - amount);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static bool isCarUnlocked(String carId, {bool defaultUnlocked = false}) {
    if (defaultUnlocked) return true;
    try {
      return _storage.read('runner_car_unlocked_$carId') ?? false;
    } catch (_) {
      return false;
    }
  }

  static void unlockCar(String carId) {
    try {
      _storage.write('runner_car_unlocked_$carId', true);
    } catch (_) {}
  }

  static int getCarUpgradeLevel(String carId) {
    try {
      return _storage.read('runner_car_upgrade_lvl_$carId') ?? 1;
    } catch (_) {
      return 1;
    }
  }

  static void setCarUpgradeLevel(String carId, int level) {
    try {
      _storage.write('runner_car_upgrade_lvl_$carId', level);
    } catch (_) {}
  }

  // ----------------------------------------------------
  // Modular 5-Category Car Upgrades Persistence
  // ----------------------------------------------------
  static int getCategoryUpgradeLevel(String carId, String categoryKey) {
    try {
      return _storage.read('runner_upg_${carId}_$categoryKey') ?? 1;
    } catch (_) {
      return 1;
    }
  }

  static void setCategoryUpgradeLevel(String carId, String categoryKey, int level) {
    try {
      final int clamped = level.clamp(1, 5);
      _storage.write('runner_upg_${carId}_$categoryKey', clamped);
      // Sync overall car level (average of 5 categories)
      final int speedLvl = getCategoryUpgradeLevel(carId, 'speed');
      final int accelLvl = getCategoryUpgradeLevel(carId, 'acceleration');
      final int handlingLvl = getCategoryUpgradeLevel(carId, 'handling');
      final int brakingLvl = getCategoryUpgradeLevel(carId, 'braking');
      final int nitroLvl = getCategoryUpgradeLevel(carId, 'nitro');
      final int avgLvl = ((speedLvl + accelLvl + handlingLvl + brakingLvl + nitroLvl) / 5).round().clamp(1, 5);
      setCarUpgradeLevel(carId, avgLvl);
    } catch (_) {}
  }

  static int getCarTotalUpgradePoints(String carId) {
    final int speedLvl = getCategoryUpgradeLevel(carId, 'speed');
    final int accelLvl = getCategoryUpgradeLevel(carId, 'acceleration');
    final int handlingLvl = getCategoryUpgradeLevel(carId, 'handling');
    final int brakingLvl = getCategoryUpgradeLevel(carId, 'braking');
    final int nitroLvl = getCategoryUpgradeLevel(carId, 'nitro');
    return speedLvl + accelLvl + handlingLvl + brakingLvl + nitroLvl; // 5 to 25
  }

  static String getSelectedCarId() {
    try {
      return _storage.read('runner_selected_car_id') ?? 'starter_apex';
    } catch (_) {
      return 'starter_apex';
    }
  }

  static void setSelectedCarId(String carId) {
    try {
      _storage.write('runner_selected_car_id', carId);
    } catch (_) {}
  }

  static int getSelectedCarIndex() {
    try {
      return _storage.read('runner_selected_car_index') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static void setSelectedCarIndex(int index) {
    try {
      _storage.write('runner_selected_car_index', index);
    } catch (_) {}
  }

  static void resetAllData() {
    try {
      _storage.write(GameConfig.keyBestScore, 0);
      _storage.write(GameConfig.keyTotalCoins, 0);
      _storage.write('runner_selected_car_index', 0);
      _storage.write('runner_selected_car_id', 'starter_apex');
      for (final carId in ['starter_apex', 'sports_volt', 'super_solar', 'muscle_viper', 'hyper_spectre']) {
        for (final cat in ['speed', 'acceleration', 'handling', 'braking', 'nitro']) {
          _storage.write('runner_upg_${carId}_$cat', 1);
        }
        _storage.write('runner_car_upgrade_lvl_$carId', 1);
      }
    } catch (_) {}
  }
}
