package com.bkenterprises.dashuri_mobile

import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.provider.Settings
import android.util.Base64
import java.security.MessageDigest
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
                // Device binding (one Free Call Card per device): the nonce is
                // derived here, not by Dart, as base64url(SHA-256(ANDROID_ID)).
                // The server reads it back from the integrity-protected verdict.
                val nonce = deviceBindingNonce()
                if (nonce == null) {
                    result.error("integrity_unavailable", "device id unavailable", null)
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

    @SuppressLint("HardwareIds")
    private fun deviceBindingNonce(): String? {
        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
            ?: return null
        val digest = MessageDigest.getInstance("SHA-256").digest(androidId.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(digest, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }

    private fun cloudProjectNumber(): Long? {
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        val value = info.metaData?.get("dashuri.play_cloud_project_number")?.toString()
        return value?.toLongOrNull()?.takeIf { it > 0 }
    }
}
