package com.family.nasan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Timer
import java.util.TimerTask

class RingService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var timeoutTimer: Timer? = null

    companion object {
        const val ACTION_STOP = "com.family.nasan.ACTION_STOP"
        private const val CHANNEL_ID = "nasan_ring_channel"
        private const val NOTIFICATION_ID = 101
        private const val TIMEOUT_MS = 60000L // 60 seconds
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopRinging()
            stopSelf()
            return START_NOT_STICKY
        }

        startForeground(NOTIFICATION_ID, createNotification())
        startRinging()
        
        // Start full screen activity
        val activityIntent = Intent(this, RingActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        try {
            startActivity(activityIntent)
        } catch (e: Exception) {
            Log.e("RingService", "Failed to start activity directly, relying on fullScreenIntent", e)
        }
        
        // Setup timeout
        timeoutTimer = Timer()
        timeoutTimer?.schedule(object : TimerTask() {
            override fun run() {
                Log.d("RingService", "Ringing timeout reached")
                val stopIntent = Intent(this@RingService, RingService::class.java).apply {
                    action = ACTION_STOP
                }
                startService(stopIntent)
            }
        }, TIMEOUT_MS)

        return START_STICKY
    }

    private fun startRinging() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val originalVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)

            // Read ringtone preference from Flutter's SharedPreferences
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val ringtoneType = flutterPrefs.getString("flutter.ringtone_type", "default") ?: "default"
            val customPath = flutterPrefs.getString("flutter.ringtone_path", null)

            val ringtoneUri = when (ringtoneType) {
                "system_alarm_1" -> {
                    // Alternative alarm sound - try alarm first, fall back to ringtone
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                }
                "system_alarm_2" -> {
                    // System ringtone
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                }
                "system_alarm_3" -> {
                    // System notification sound
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                }
                "custom" -> {
                    if (customPath != null) {
                        android.net.Uri.fromFile(java.io.File(customPath))
                    } else {
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                    }
                }
                else -> {
                    // Default
                    android.net.Uri.parse("android.resource://" + packageName + "/" + R.raw.defaultsound)
                }
            }

            Log.d("RingService", "Using ringtone type: $ringtoneType, URI: $ringtoneUri")

            mediaPlayer = MediaPlayer().apply {
                setDataSource(this@RingService, ringtoneUri!!)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                setOnPreparedListener { mp ->
                    mp.start()
                }
                prepareAsync()
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibrator = vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            
            val pattern = longArrayOf(0, 1000, 1000)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }

        } catch (e: Exception) {
            Log.e("RingService", "Failed to start ringing", e)
        }
    }

    private fun stopRinging() {
        timeoutTimer?.cancel()
        timeoutTimer = null
        
        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                release()
            }
            mediaPlayer = null
            
            vibrator?.cancel()
            vibrator = null
            
            // Finish RingActivity if it's open (we can broadcast to it)
            sendBroadcast(Intent(RingActivity.ACTION_FINISH_ACTIVITY))

            notifySenderRingStopped()
        } catch (e: Exception) {
            Log.e("RingService", "Error stopping ring", e)
        }
    }

    private fun notifySenderRingStopped() {
        val prefs = getSharedPreferences("RingPrefs", Context.MODE_PRIVATE)
        val senderUid = prefs.getString("lastSenderUid", null) ?: return
        
        // Don't send multiple times
        prefs.edit().remove("lastSenderUid").apply()

        try {
            val engine = io.flutter.embedding.engine.FlutterEngine(applicationContext)
            val entrypoint = io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint(
                io.flutter.FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "backgroundStopRing"
            )
            engine.dartExecutor.executeDartEntrypoint(entrypoint)
            
            val channel = io.flutter.plugin.common.MethodChannel(engine.dartExecutor.binaryMessenger, "com.family.nasan/ring_background")
            
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                channel.invokeMethod("sendAbort", mapOf("targetUid" to senderUid))
                
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    engine.destroy()
                }, 5000)
            }, 1000)
        } catch (e: Exception) {
            Log.e("RingService", "Failed to start Flutter engine in background", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Family Ring",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Critical alerts from family members"
                setBypassDnd(true)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val fullScreenIntent = Intent(this, RingActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, 0, fullScreenIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, RingService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Family Ring")
            .setContentText("A family member is trying to locate your phone.")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPendingIntent)
            .setOngoing(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopRinging()
        super.onDestroy()
    }
}
