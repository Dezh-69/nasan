package com.family.nasan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val smsMessages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (message in smsMessages) {
                val messageBody = message.messageBody ?: ""
                Log.d("SmsReceiver", "Received SMS: $messageBody")
                
                if (messageBody.contains("<NASAN_RING_TRIGGER>")) {
                    Log.d("SmsReceiver", "Trigger keyword found, starting RingService")
                    abortBroadcast() // Hide SMS from inbox
                    startRingService(context)
                } else if (messageBody.contains("<NASAN_ABORT_TRIGGER>")) {
                    Log.d("SmsReceiver", "Abort keyword found, stopping RingService")
                    abortBroadcast() // Hide SMS from inbox
                    stopRingService(context)
                }
            }
        }
    }

    private fun startRingService(context: Context) {
        val serviceIntent = Intent(context, RingService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    private fun stopRingService(context: Context) {
        val stopIntent = Intent(context, RingService::class.java).apply {
            action = RingService.ACTION_STOP
        }
        context.startService(stopIntent)
    }
}
