package tz.co.pelekapro.mobile

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MAP_CONFIGURATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != IS_CONFIGURED_METHOD) {
                result.notImplemented()
                return@setMethodCallHandler
            }

            result.success(isGoogleMapsConfigured())
        }
    }

    private fun isGoogleMapsConfigured(): Boolean {
        return try {
            val applicationInfo = packageManager.getApplicationInfo(
                packageName,
                PackageManager.GET_META_DATA,
            )
            val apiKey = applicationInfo.metaData
                ?.getString(GOOGLE_MAPS_API_KEY_METADATA)
                ?.trim()

            !apiKey.isNullOrEmpty() && apiKey != MISSING_GOOGLE_MAPS_API_KEY
        } catch (_: Exception) {
            false
        }
    }

    private companion object {
        const val MAP_CONFIGURATION_CHANNEL =
            "tz.co.pelekapro.mobile/google_maps_configuration"
        const val IS_CONFIGURED_METHOD = "isConfigured"
        const val GOOGLE_MAPS_API_KEY_METADATA = "com.google.android.geo.API_KEY"
        const val MISSING_GOOGLE_MAPS_API_KEY = "GOOGLE_MAPS_API_KEY_NOT_CONFIGURED"
    }
}
