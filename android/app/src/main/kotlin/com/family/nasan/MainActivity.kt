package com.family.nasan

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.family.nasan/ring"
    private var downloadId: Long = -1

    private val downloadReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1)
            if (id == downloadId && id != -1L) {
                val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                val uri = downloadManager.getUriForDownloadedFile(downloadId)
                if (uri != null) {
                    val installIntent = Intent(Intent.ACTION_VIEW)
                    installIntent.setDataAndType(uri, "application/vnd.android.package-archive")
                    installIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                    startActivity(installIntent)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(downloadReceiver, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE), Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(downloadReceiver, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE))
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "downloadAndInstallApk") {
                val url = call.argument<String>("url")
                if (url != null) {
                    try {
                        val request = DownloadManager.Request(Uri.parse(url))
                        request.setTitle("Nasan Update")
                        request.setDescription("Downloading latest update...")
                        request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "nasan_update.apk")
                        request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                        
                        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                        downloadId = manager.enqueue(request)
                        result.success(null)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error("DOWNLOAD_FAILED", e.message, null)
                    }
                } else {
                    result.error("INVALID_URL", "URL cannot be null", null)
                }
            } else if (call.method == "triggerRing") {
                triggerRing()
                result.success(null)
            } else if (call.method == "stopRing") {
                stopRing()
                result.success(null)
            } else if (call.method == "requestPermissions") {
                requestSmsPermissions()
                result.success(null)
            } else if (call.method == "sendSms") {
                val phoneNumber = call.argument<String>("phoneNumber")
                val message = call.argument<String>("message")
                if (phoneNumber != null && message != null) {
                    if (checkSelfPermission(android.Manifest.permission.SEND_SMS) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                        val success = sendSms(phoneNumber, message)
                        result.success(success)
                    } else {
                        // Store pending SMS and request permission
                        pendingSmsPhone = phoneNumber
                        pendingSmsMessage = message
                        pendingSmsResult = result
                        requestPermissions(arrayOf(android.Manifest.permission.SEND_SMS), SMS_SEND_PERMISSION_CODE)
                    }
                } else {
                    result.error("INVALID_ARGS", "Phone number or message is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private var pendingSmsPhone: String? = null
    private var pendingSmsMessage: String? = null
    private var pendingSmsResult: io.flutter.plugin.common.MethodChannel.Result? = null

    companion object {
        private const val SMS_PERMISSION_CODE = 1001
        private const val SMS_SEND_PERMISSION_CODE = 1002
    }

    private fun requestSmsPermissions() {
        val permissions = arrayOf(
            android.Manifest.permission.SEND_SMS,
            android.Manifest.permission.RECEIVE_SMS,
            android.Manifest.permission.READ_SMS
        )
        requestPermissions(permissions, SMS_PERMISSION_CODE)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_SEND_PERMISSION_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                val phone = pendingSmsPhone
                val message = pendingSmsMessage
                val result = pendingSmsResult
                pendingSmsPhone = null
                pendingSmsMessage = null
                pendingSmsResult = null
                if (phone != null && message != null && result != null) {
                    val success = sendSms(phone, message)
                    result.success(success)
                }
            } else {
                pendingSmsResult?.success(false)
                pendingSmsPhone = null
                pendingSmsMessage = null
                pendingSmsResult = null
            }
        }
    }

    private fun triggerRing() {
        val serviceIntent = Intent(this, RingService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun stopRing() {
        val stopIntent = Intent(this, RingService::class.java).apply {
            action = RingService.ACTION_STOP
        }
        startService(stopIntent)
    }

    private fun sendSms(phoneNumber: String, message: String): Boolean {
        return try {
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                this.getSystemService(android.telephony.SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                android.telephony.SmsManager.getDefault()
            }
            smsManager.sendTextMessage(phoneNumber, null, message, null, null)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
