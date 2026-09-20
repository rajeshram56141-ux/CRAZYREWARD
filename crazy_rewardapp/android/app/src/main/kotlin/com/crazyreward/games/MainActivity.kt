package com.crazyreward.games

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.IntentFilter
import android.os.Bundle

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.crazyreward.games/app_manager"
    private var packageReceiver: PackageInstallReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_PACKAGE_ADDED)
                addDataScheme("package")
            }
            packageReceiver = PackageInstallReceiver()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(packageReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(packageReceiver, filter)
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error registering receiver: " + e.message)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val channelId = "crazyreward"
                val channelName = "Crazyreward"
                val channelDescription = "Crazyreward Notifications and Reward Updates"
                val importance = NotificationManager.IMPORTANCE_HIGH
                val channel = NotificationChannel(channelId, channelName, importance).apply {
                    description = channelDescription
                    enableVibration(true)
                    enableLights(true)
                    setShowBadge(true)
                }
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error creating notification channel: " + e.message)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            packageReceiver?.let { unregisterReceiver(it) }
        } catch (e: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        result.success(isAppInstalled(packageName))
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is null", null)
                    }
                }
                "getAppName" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        try {
                            val pm = context.packageManager
                            val appInfo = pm.getApplicationInfo(packageName, 0)
                            val appLabel = pm.getApplicationLabel(appInfo).toString()
                            result.success(appLabel)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is null", null)
                    }
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val launched = launchApp(packageName)
                        result.success(launched)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is null", null)
                    }
                }
                "getInstallTime" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val prefs = context.getSharedPreferences("app_manager_prefs", Context.MODE_PRIVATE)
                        var installTime = prefs.getLong("install_time_$packageName", 0L)
                        if (installTime == 0L) {
                            try {
                                val info = packageManager.getPackageInfo(packageName, 0)
                                installTime = info.firstInstallTime
                            } catch (e: PackageManager.NameNotFoundException) {
                                installTime = 0L
                            }
                        }
                        result.success(installTime)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is null", null)
                    }
                }
                "getRecentlyInstalledPackage" -> {
                    val startTimeMs = call.argument<Long>("startTimeMs") ?: 0L
                    val pkg = getRecentlyInstalledPackage(startTimeMs)
                    result.success(pkg)
                }
                "checkUsagePermission" -> {
                    result.success(isUsagePermissionGranted())
                }
                "openUsageSettings" -> {
                    openUsageSettings()
                    result.success(true)
                }
                "getAppUsageDuration" -> {
                    val packageName = call.argument<String>("packageName")
                    val startTimeMs = call.argument<Long>("startTimeMs")
                    if (packageName != null && startTimeMs != null) {
                        result.success(getAppUsageDuration(packageName, startTimeMs))
                    } else {
                        result.error("INVALID_ARGUMENT", "packageName or startTimeMs is null", null)
                    }
                }
                "getAvailableStorage" -> {
                    result.success(getAvailableInternalStorageSpace())
                }
                "getUsedStorageBytes" -> {
                    try {
                        val stat = android.os.StatFs(android.os.Environment.getDataDirectory().path)
                        val totalBytes = stat.totalBytes
                        val availableBytes = stat.availableBytes
                        val usedBytes = totalBytes - availableBytes
                        result.success(usedBytes)
                    } catch (e: Exception) {
                        result.success(0L)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isAppInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun launchApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error launching app: " + e.message)
            false
        }
    }

    private fun isUsagePermissionGranted(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageSettings() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                data = Uri.parse("package:" + context.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            try {
                val intentFallback = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intentFallback)
            } catch (ex: Exception) {
                android.util.Log.e("MainActivity", "Error opening usage settings: " + ex.message)
            }
        }
    }

    private fun getAppUsageDuration(packageName: String, startTimeMs: Long): Long {
        try {
            val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val endTime = System.currentTimeMillis()

            if (startTimeMs <= 0L || endTime <= startTimeMs) {
                return 0L
            }

            val events = usageStatsManager.queryEvents(startTimeMs, endTime)
            var totalForegroundMs = 0L
            var resumeTime = 0L

            if (events != null) {
                val event = UsageEvents.Event()
                while (events.hasNextEvent()) {
                    events.getNextEvent(event)
                    val eventPkg = event.packageName ?: ""
                    val type = event.eventType
                    val timeStamp = event.timeStamp

                    val isResume = (type == UsageEvents.Event.ACTIVITY_RESUMED || type == 1)
                    val isPause = (type == UsageEvents.Event.ACTIVITY_PAUSED || type == 2 || type == 23 || type == UsageEvents.Event.ACTIVITY_STOPPED)
                    val isScreenOff = (type == 16 || type == 17)

                    val isBrowser = (eventPkg == "com.android.chrome" || 
                                     eventPkg == "com.android.browser" || 
                                     eventPkg == "com.sec.android.app.sbrowser" || 
                                     eventPkg.contains("chrome") || 
                                     eventPkg.contains("browser") || 
                                     eventPkg.contains("firefox") || 
                                     eventPkg.contains("opera"))
            
                    val isTwa = packageName.endsWith(".twa") || 
                                packageName.contains(".twa.") || 
                                packageName.contains("twa") ||
                                packageName.contains("web") || 
                                packageName.contains("posterai")

                    val isMatch = (eventPkg == packageName) || (isBrowser && isTwa)

                    if (isMatch) {
                        if (isResume) {
                            if (resumeTime <= 0L) {
                                resumeTime = maxOf(timeStamp, startTimeMs)
                            }
                        } else if (isPause) {
                            if (!isTwa) {
                                if (resumeTime > 0L) {
                                    val sessionEnd = minOf(timeStamp, endTime)
                                    if (sessionEnd > resumeTime) {
                                        totalForegroundMs += (sessionEnd - resumeTime)
                                    }
                                    resumeTime = 0L
                                }
                            }
                        }
                    } else if (isScreenOff) {
                        if (resumeTime > 0L) {
                            val sessionEnd = minOf(timeStamp, endTime)
                            if (sessionEnd > resumeTime) {
                                totalForegroundMs += (sessionEnd - resumeTime)
                            }
                            resumeTime = 0L
                        }
                    } else if (isResume) {
                        // Another real app came to foreground (ignore system UI, keyboards, play services overlays)
                        val isSystem = eventPkg.startsWith("com.android.systemui") ||
                                       eventPkg.startsWith("com.google.android.inputmethod") ||
                                       eventPkg == "android" ||
                                       eventPkg.contains("inputmethod") ||
                                       eventPkg.contains("keyboard") ||
                                       eventPkg.startsWith("com.google.android.gms")
                        if (!isSystem && resumeTime > 0L) {
                            val sessionEnd = minOf(timeStamp, endTime)
                            if (sessionEnd > resumeTime) {
                                totalForegroundMs += (sessionEnd - resumeTime)
                            }
                            resumeTime = 0L
                        }
                    }
                }

                // If target app was still in foreground when returning / querying
                if (resumeTime > 0L) {
                    val sessionEnd = endTime
                    if (sessionEnd > resumeTime) {
                        totalForegroundMs += (sessionEnd - resumeTime)
                    }
                }
            }

            return totalForegroundMs / 1000L
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error querying app usage: " + e.message)
            return 0L
        }
    }

    private fun getRecentlyInstalledPackage(startTimeMs: Long): String? {
        try {
            // Layer 1: Check SharedPreferences from dynamic BroadcastReceiver
            val prefs = context.getSharedPreferences("app_manager_prefs", Context.MODE_PRIVATE)
            val lastPkg = prefs.getString("last_installed_package", null)
            val lastTime = prefs.getLong("last_installed_time", 0L)
            if (lastPkg != null && lastTime >= (startTimeMs - 5000L) && isAppInstalled(lastPkg)) {
                return lastPkg
            }

            // Layer 2: Check UsageStatsManager events
            if (isUsagePermissionGranted()) {
                val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                val events = usageStatsManager.queryEvents(startTimeMs - 5000L, System.currentTimeMillis())
                if (events != null) {
                    val event = UsageEvents.Event()
                    val candidates = mutableListOf<String>()
                    while (events.hasNextEvent()) {
                        events.getNextEvent(event)
                        val p = event.packageName
                        if (p != null && p != context.packageName &&
                            !p.startsWith("com.android.") &&
                            !p.startsWith("com.google.android.") &&
                            !p.startsWith("com.sec.android.") &&
                            !p.startsWith("com.samsung.")) {
                            if (!candidates.contains(p)) {
                                candidates.add(p)
                            }
                        }
                    }
                    for (cand in candidates.reversed()) {
                        try {
                            val info = context.packageManager.getPackageInfo(cand, 0)
                            if (info.firstInstallTime >= (startTimeMs - 5000L)) {
                                return cand
                            }
                        } catch (e: Exception) {}
                    }
                }
            }

            // Layer 3: Check PackageManager installed apps
            val pm = context.packageManager
            val packages = pm.getInstalledPackages(0)
            var newestPkg: String? = null
            var newestTime = startTimeMs - 5000L

            for (pkgInfo in packages) {
                val pkgName = pkgInfo.packageName
                if (pkgName == context.packageName ||
                    pkgName.startsWith("com.android.") ||
                    pkgName.startsWith("com.google.android.") ||
                    pkgName.startsWith("com.sec.android.") ||
                    pkgName.startsWith("com.samsung.")) {
                    continue
                }
                if (pkgInfo.firstInstallTime >= newestTime) {
                    newestTime = pkgInfo.firstInstallTime
                    newestPkg = pkgName
                }
            }
            if (newestPkg != null) {
                return newestPkg
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error in getRecentlyInstalledPackage: " + e.message)
        }
        return null
    }

    private fun getAvailableInternalStorageSpace(): Long {
        return try {
            val path = android.os.Environment.getDataDirectory()
            val stat = android.os.StatFs(path.path)
            stat.availableBytes
        } catch (e: Exception) {
            0L
        }
    }
}
