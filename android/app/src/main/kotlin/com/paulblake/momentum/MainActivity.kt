package com.paulblake.momentum

import android.content.ComponentName
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A fragment activity: Health Connect's permission screen needs it
class MainActivity : FlutterFragmentActivity() {
    // Settings → App icon: the launcher alias picked, switched to once the
    // app leaves the screen (switching while it shows can close it)
    private var pendingIcon: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        firstIcon()
    }

    // A new install starts on Light; opened first in dark mode, it takes
    // Charged instead, once. Android can't follow dark mode the way iOS's
    // icon does, so after that only Settings → App icon changes it
    private fun firstIcon() {
        val prefs = getSharedPreferences("momentum_icon", MODE_PRIVATE)
        if (prefs.getBoolean("firstIconDone", false)) return
        prefs.edit().putBoolean("firstIconDone", true).apply()
        val dark = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        // Never over an icon someone picked (one set before this check existed)
        val neverPicked = iconActivities().all {
            packageManager.getComponentEnabledSetting(ComponentName(this, it.name)) ==
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
        }
        if (dark && neverPicked && pendingIcon == null) pendingIcon = "IconCharged"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "momentum/app_icon").setMethodCallHandler { call, result ->
            when (call.method) {
                "current" -> result.success(pendingIcon ?: enabledIcon())
                "set" -> {
                    val alias = call.arguments as? String
                    if (alias == null || alias !in iconAliases()) {
                        result.error("unknown", "No launcher icon $alias", null)
                    } else {
                        pendingIcon = alias
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onStop() {
        super.onStop()
        val alias = pendingIcon ?: return
        pendingIcon = null
        if (alias == enabledIcon()) return
        // The new one first, so there's always a launcher icon
        setEnabled(alias, true)
        for (other in iconAliases()) {
            if (other != alias) setEnabled(other, false)
        }
    }

    /** The launcher aliases in the manifest, enabled or not. */
    private fun iconActivities(): List<ActivityInfo> {
        @Suppress("DEPRECATION")
        val info = packageManager.getPackageInfo(
            packageName,
            PackageManager.GET_ACTIVITIES or PackageManager.MATCH_DISABLED_COMPONENTS,
        )
        return info.activities.orEmpty().filter { it.targetActivity != null && aliasName(it).startsWith("Icon") }
    }

    /** ".IconCharged" → "IconCharged" */
    private fun aliasName(activity: ActivityInfo) = activity.name.substringAfterLast('.')

    private fun iconAliases() = iconActivities().map(::aliasName)

    private fun enabledIcon(): String? = iconActivities().firstOrNull {
        when (packageManager.getComponentEnabledSetting(ComponentName(this, it.name))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> it.enabled
            else -> false
        }
    }?.let(::aliasName)

    private fun setEnabled(alias: String, enabled: Boolean) {
        packageManager.setComponentEnabledSetting(
            ComponentName(packageName, "$packageName.$alias"),
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }
}
