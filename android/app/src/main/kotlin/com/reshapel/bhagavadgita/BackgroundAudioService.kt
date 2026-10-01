package com.reshapel.bhagavadgita

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

/**
 * MediaSessionService that handles background audio playback with proper
 * Android media notifications and lock-screen controls.
 *
 * This service uses ExoPlayer (via just_audio_background) for playback and
 * exposes a MediaSession so Android can show media controls in the
 * notification, lock screen, and on external devices (Bluetooth, Wear OS, etc.).
 *
 * GITA-7 introduced a minimal foreground service; GITA-8 upgrades this to a
 * full MediaSessionService with MediaStyle notifications.
 */
class BackgroundAudioService : MediaSessionService() {

    private var mediaSession: MediaSession? = null
    private var player: ExoPlayer? = null

    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "bhagavad_gita_playback"
        private const val CHANNEL_NAME = "Bhagavad Gita Playback"

        /**
         * Start the foreground service from any Context.
         *
         * On API 26+ this will call startForegroundService() which requires
         * the notification to be shown within 5 seconds.
         */
        fun start(context: Context) {
            val intent = Intent(context, BackgroundAudioService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /**
         * Stop the foreground service from any Context.
         */
        fun stop(context: Context) {
            context.stopService(Intent(context, BackgroundAudioService::class.java))
        }
    }

    override fun onCreate() {
        super.onCreate()

        // Initialize ExoPlayer with appropriate audio attributes for media playback
        player = ExoPlayer.Builder(this)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                    .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                    .build(),
                /* handleAudioFocus = */ true,
            )
            .build()

        // Create a MediaSession that links the player to Android's media framework
        mediaSession = MediaSession.Builder(this, player!!)
            .setId("bhagavad_gita_session")
            .build()
    }

    override fun onDestroy() {
        mediaSession?.release()
        mediaSession = null

        player?.release()
        player = null

        super.onDestroy()
    }

    override fun onBind(intent: Intent?) = mediaSession?.sessionBinder

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo) = mediaSession

    override fun onUpdateNotification(
        session: MediaSession,
        startInForegroundRequired: Boolean,
    ) {
        // Build a MediaStyle notification that shows media controls
        val notification = buildNotification(session)

        if (startInForegroundRequired) {
            startForeground(NOTIFICATION_ID, notification)
        } else {
            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, notification)
        }
    }

    // -------------------------------------------------------------------------
    // Notification helpers
    // -------------------------------------------------------------------------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.description = "Bhagavad Gita media notification"
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(session: MediaSession): Notification {
        createNotificationChannel()

        // Build notification with MediaStyle to show media controls
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Bhagavad Gita")
            .setContentText("Playing in background")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            // Use the MediaSession token so the notification shows
            // media controls and syncs with the lock screen
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1) // Show play/pause in compact view
            )
            .build()
    }
}
