package com.crazyreward.games

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PackageInstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_PACKAGE_ADDED) {
            val data = intent.data
            val packageName = data?.schemeSpecificPart
            if (packageName != null) {
                val prefs = context.getSharedPreferences("app_manager_prefs", Context.MODE_PRIVATE)
                prefs.edit()
                    .putLong("install_time_$packageName", System.currentTimeMillis())
                    .putString("last_installed_package", packageName)
                    .putLong("last_installed_time", System.currentTimeMillis())
                    .apply()
            }
        }
    }
}
