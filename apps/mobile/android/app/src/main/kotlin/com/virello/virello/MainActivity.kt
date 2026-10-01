package com.virello.virello

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceChannel = "virello/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // True when Google Play Services are present and up to
                    // date. False on Fire OS devices and de-Googled ROMs —
                    // the app then hides Google Sign-In and Play Billing UI.
                    // Reflection: the amazon flavor has no GMS classes.
                    "hasPlayServices" -> result.success(hasPlayServices())
                    // "amazon" / "play" — which store flavor built this APK.
                    "storeFlavor" -> result.success(BuildConfig.FLAVOR)
                    else -> result.notImplemented()
                }
            }
        // Amazon IAP bridge lives in the `amazon` flavor source set only.
        // Reflection keeps the play flavor compiling without the Amazon SDK.
        try {
            val bridgeClass = Class.forName("com.virello.virello.AmazonBillingBridge")
            val ctor = bridgeClass.getDeclaredConstructor(
                android.content.Context::class.java,
                FlutterEngine::class.java,
            )
            ctor.newInstance(this, flutterEngine)
        } catch (_: ClassNotFoundException) {
            // Play flavor: no Amazon IAP bridge — expected.
        }
    }

    private fun hasPlayServices(): Boolean {
        return try {
            val clazz = Class.forName("com.google.android.gms.common.GoogleApiAvailability")
            val instance = clazz.getMethod("getInstance").invoke(null)
            val code = clazz.getMethod(
                "isGooglePlayServicesAvailable",
                android.content.Context::class.java,
            ).invoke(instance, this) as Int
            code == 0 // ConnectionResult.SUCCESS
        } catch (_: Exception) {
            false
        }
    }
}
