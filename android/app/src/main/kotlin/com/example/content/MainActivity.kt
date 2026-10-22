package com.example.content

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) because local_auth needs a FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    private val aliases = mapOf(
        "default" to "LauncherDefault",
        "weather" to "LauncherWeather",
        "notes" to "LauncherNotes",
        "calendar" to "LauncherCalendar",
        "calculator" to "LauncherCalculator",
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Blocks screenshots and blanks the app in the recents switcher.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/icon_switcher")
            .setMethodCallHandler { call, result ->
                if (call.method != "setIcon") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val chosen = aliases[call.arguments as? String]
                if (chosen == null) {
                    result.error("bad_icon", "Unknown icon ${call.arguments}", null)
                    return@setMethodCallHandler
                }
                // Enable the new alias before disabling the old one so the app always has a
                // launcher entry.
                val ordered = aliases.values.sortedBy { it != chosen }
                for (alias in ordered) {
                    packageManager.setComponentEnabledSetting(
                        ComponentName(this, "${MainActivity::class.java.name.substringBeforeLast('.')}.$alias"),
                        if (alias == chosen) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP,
                    )
                }
                result.success(null)
            }
    }
}
