package com.family.nasan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.app.Activity

class RingActivity : Activity() {

    companion object {
        const val ACTION_FINISH_ACTIVITY = "com.family.nasan.ACTION_FINISH_ACTIVITY"
    }

    private val finishReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_FINISH_ACTIVITY) {
                finish()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        turnScreenOnAndKeyguardOff()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(finishReceiver, IntentFilter(ACTION_FINISH_ACTIVITY), Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(finishReceiver, IntentFilter(ACTION_FINISH_ACTIVITY))
        }

        // Build UI programmatically (no Compose/XML dependency needed)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#E53935"))
            setPadding(64, 64, 64, 64)
        }

        val title = TextView(this).apply {
            text = "FAMILY RING"
            textSize = 36f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }

        val subtitle = TextView(this).apply {
            text = "A family member is trying to reach you"
            textSize = 16f
            setTextColor(Color.parseColor("#FFFFFF"))
            gravity = Gravity.CENTER
            alpha = 0.8f
        }

        val dismissButton = Button(this).apply {
            text = "DISMISS ALARM"
            textSize = 20f
            setTextColor(Color.parseColor("#E53935"))
            setBackgroundColor(Color.WHITE)
            setPadding(64, 32, 64, 32)
            setOnClickListener {
                stopRingService()
                finish()
            }
        }

        val spacer1 = android.widget.Space(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 48)
        }
        val spacer2 = android.widget.Space(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 32)
        }

        layout.addView(title)
        layout.addView(spacer1)
        layout.addView(subtitle)
        layout.addView(spacer2)
        layout.addView(dismissButton)

        setContentView(layout)
    }

    private fun turnScreenOnAndKeyguardOff() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    private fun stopRingService() {
        val stopIntent = Intent(this, RingService::class.java).apply {
            action = RingService.ACTION_STOP
        }
        startService(stopIntent)
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(finishReceiver)
        } catch (_: Exception) {}
    }
}
