package com.family.nasan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class RingReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("RingReceiver", "Received intent: ${intent.action}")
        
        if (intent.action == "com.google.android.c2dm.intent.RECEIVE") {
            val type = intent.getStringExtra("type")
            if (type == "ring") {
                Log.d("RingReceiver", "FCM data 'type=ring' detected, starting RingService")
                startRingService(context)
            } else if (type == "abort") {
                Log.d("RingReceiver", "FCM data 'type=abort' detected, stopping RingService")
                stopRingService(context)
            }
        } else {
            Log.d("RingReceiver", "Alarm fired, starting RingService")
            startRingService(context)
        }
    }

    private fun stopRingService(context: Context) {
        val stopIntent = Intent(context, RingService::class.java).apply {
            action = RingService.ACTION_STOP
        }
        context.startService(stopIntent)
    }

    private fun startRingService(context: Context) {
        val serviceIntent = Intent(context, RingService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
