package com.reshapel.bhagavadgita

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Minimal foreground service that keeps the Android process alive during
 * background audio playback.
 *
 * Responsibilities:
 *  - Call startForeground() with a placeholder notification so the OS does
 *    not kill the process when the app is backgrounded or the screen locks.
 *  - Hold no audio state — AudioPlayerController remains the single source
 *    of truth for all playback logic.
 *
 * GITA-8 will replace the placeholder notification with a full
 * MediaStyle notification and media session controls.
 *
 * Usage (from Flutter via MethodChannel / lifecycle observer):
 *   BackgroundAudioService.start(context)
 *   BackgroundAudioService.stop(context)
 */
class BackgroundAudioService : Service() {

    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "bhagavad_gita_playback"
        private const val CHANNEL_NAME = "Bhagavad Gita Playback"

        /** Start the foreground service from any Context. */
        fun start(context: Context) {
            val intent = Intent(context, BackgroundAudioService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Stop the foreground service from any Context. */
        fun stop(context: Context) {
            context.stopService(Intent(context, BackgroundAudioService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        // START_STICKY: if the OS kills the service, restart it without
        // re-delivering the last intent, keeping audio alive across brief
        // resource pressure events.
        return START_STICKY
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    // -------------------------------------------------------------------------
    // Notification helpers
    // -------------------------------------------------------------------------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                // LOW importance: no sound, no heads-up — just keeps the
                // foreground service alive. GITA-8 will upgrade this to a
                // proper MediaStyle notification.
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.description = "Keeps Bhagavad Gita audio playing in the background"
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Bhagavad Gita")
            .setContentText("Playing in background")
            // Use a built-in Android icon that is always available.
            // GITA-8 will replace this with the app's own icon and artwork.
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }
}
