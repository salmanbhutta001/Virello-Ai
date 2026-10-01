package com.virello.virello

import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
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
                    "hasPlayServices" -> {
                        val code = GoogleApiAvailability.getInstance()
                            .isGooglePlayServicesAvailable(this)
                        result.success(code == ConnectionResult.SUCCESS)
                    }
                    // "amazon" / "play" / "unknown" — which store flavor built this APK.
                    "storeFlavor" -> {
                        result.success(BuildConfig.FLAVOR)
                    }
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
}
