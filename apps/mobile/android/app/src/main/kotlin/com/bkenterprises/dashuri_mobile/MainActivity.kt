package com.bkenterprises.dashuri_mobile

import android.content.pm.PackageManager
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity: required by payment and video SDKs that show
 * fragments. Hosts the `dashuri/integrity` channel used by the Free Call
 * Card (one card per device, verified server-side with the Play Integrity API).
 */
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dashuri/integrity")
            .setMethodCallHandler { call, result ->
                if (call.method != "requestToken") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val nonce = call.argument<String>("nonce")
                if (nonce.isNullOrEmpty()) {
                    result.error("bad_args", "nonce is required", null)
                    return@setMethodCallHandler
                }
                val builder = IntegrityTokenRequest.builder().setNonce(nonce)
                cloudProjectNumber()?.let { builder.setCloudProjectNumber(it) }
                IntegrityManagerFactory.create(applicationContext)
                    .requestIntegrityToken(builder.build())
                    .addOnSuccessListener { response -> result.success(response.token()) }
                    .addOnFailureListener { e -> result.error("integrity_unavailable", e.message, null) }
            }
    }

    private fun cloudProjectNumber(): Long? {
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        val value = info.metaData?.get("dashuri.play_cloud_project_number")?.toString()
        return value?.toLongOrNull()?.takeIf { it > 0 }
    }
}
