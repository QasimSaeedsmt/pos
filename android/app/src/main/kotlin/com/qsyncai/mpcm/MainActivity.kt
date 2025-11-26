package com.qsyncai.mpcm

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {

    private val APK_CHANNEL = "apk_install"
    private val MESSAGING_CHANNEL = "com.qsyncai.mpcm/messaging"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Existing APK installation channel - NO CHANGES
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APK_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val path = call.argument<String>("path")
                if (path != null) {
                    installApk(path)
                    result.success(true)
                } else {
                    result.error("PATH_ERROR", "APK path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // NEW: Messaging channel - completely separate
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MESSAGING_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    if (phone != null && message != null) {
                        sendSMS(phone, message, result)
                    } else {
                        result.error("INVALID_PARAMS", "Phone or message is null", null)
                    }
                }
                "sendWhatsApp" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    if (phone != null && message != null) {
                        sendWhatsApp(phone, message, result)
                    } else {
                        result.error("INVALID_PARAMS", "Phone or message is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // NEW: SMS sending method
    private fun sendSMS(phone: String, message: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("smsto:$phone")
                putExtra("sms_body", message)
            }

            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                result.success(true)
            } else {
                result.error("NO_SMS_APP", "No SMS app found", null)
            }
        } catch (e: Exception) {
            result.error("SMS_ERROR", "Failed to send SMS: ${e.message}", null)
        }
    }

    // NEW: WhatsApp sending method
    private fun sendWhatsApp(phone: String, message: String, result: MethodChannel.Result) {
        try {
            val cleanPhone = phone.replace(Regex("[^0-9]"), "")
            val whatsappUrl = "https://wa.me/$cleanPhone?text=${Uri.encode(message)}"
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse(whatsappUrl)
            }

            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                result.success(true)
            } else {
                result.error("NO_WHATSAPP", "WhatsApp not installed", null)
            }
        } catch (e: Exception) {
            result.error("WHATSAPP_ERROR", "Failed to send WhatsApp: ${e.message}", null)
        }
    }

    // EXISTING METHOD - NO CHANGES
    private fun installApk(path: String) {
        val file = File(path)

        val apkUri: Uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.provider",
            file
        )

        val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            data = apkUri
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        startActivity(intent)
    }
}