package com.family.nasan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Telephony
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
        private const val RING_ALARM_REQUEST = 2001
        private const val STOP_ALARM_REQUEST = 2002
        const val EXTRA_ACTION = "sms_ring_action"
        const val ACTION_RING = "ring"
        const val ACTION_STOP = "stop"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val smsMessages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        for (message in smsMessages) {
            val messageBody = message.messageBody ?: ""
            Log.d(TAG, "Received SMS, checking for trigger keywords...")

            when {
                messageBody.contains("<NASAN_RING_TRIGGER>") -> {
                    Log.d(TAG, "RING trigger keyword found")
                    abortBroadcast() // Hide SMS from inbox
                    triggerViaAlarm(context, ACTION_RING)
                }
                messageBody.contains("<NASAN_ABORT_TRIGGER>") -> {
                    Log.d(TAG, "ABORT trigger keyword found")
                    abortBroadcast() // Hide SMS from inbox
                    triggerViaAlarm(context, ACTION_STOP)
                }
            }
        }
    }

    /**
     * On Android 12+, BroadcastReceivers for SMS_RECEIVED cannot call
     * startForegroundService() directly — it throws
     * ForegroundServiceStartNotAllowedException when the app is in
     * the background. Exact alarm callbacks ARE exempt from this
     * restriction, so we schedule an immediate alarm that fires
     * RingReceiver, which then starts the foreground service.
     */
    private fun triggerViaAlarm(context: Context, action: String) {
        // Acquire a wake lock so the device doesn't sleep before the alarm fires
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wl = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "nasan:sms_trigger"
        )
        wl.acquire(5000) // 5 seconds max

        try {
            val alarmIntent = Intent(context, RingReceiver::class.java).apply {
                putExtra(EXTRA_ACTION, action)
            }
            val requestCode = if (action == ACTION_RING) RING_ALARM_REQUEST else STOP_ALARM_REQUEST
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            // Fire essentially immediately (100ms from now)
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 100,
                pendingIntent
            )
            Log.d(TAG, "Scheduled immediate alarm for action: $action")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule alarm, falling back to direct start", e)
            // Fallback: try direct start (may work on older Android versions)
            try {
                if (action == ACTION_RING) {
                    val serviceIntent = Intent(context, RingService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                } else {
                    val stopIntent = Intent(context, RingService::class.java).apply {
                        this.action = RingService.ACTION_STOP
                    }
                    context.startService(stopIntent)
                }
            } catch (e2: Exception) {
                Log.e(TAG, "Fallback direct start also failed", e2)
            }
        }
    }
}
