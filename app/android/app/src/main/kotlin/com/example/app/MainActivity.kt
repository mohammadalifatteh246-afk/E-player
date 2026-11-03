package com.example.app

import android.Manifest
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.os.Build
import android.provider.MediaStore
import android.util.Rational
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    companion object {
        private const val SCANNER_CHANNEL = "com.example.app/media_scanner"
        private const val PIP_CHANNEL = "com.example.app/pip"
        private const val ACTION_PIP_PLAY = "com.example.app.ACTION_PIP_PLAY"
        private const val ACTION_PIP_PAUSE = "com.example.app.ACTION_PIP_PAUSE"
        private const val ACTION_PIP_FORWARD = "com.example.app.ACTION_PIP_FORWARD"
        private const val ACTION_PIP_REWIND = "com.example.app.ACTION_PIP_REWIND"
        private const val REQUEST_CODE_PLAY = 101
        private const val REQUEST_CODE_PAUSE = 102
        private const val REQUEST_CODE_FORWARD = 103
        private const val REQUEST_CODE_REWIND = 104
        private const val MIN_ASPECT_RATIO = 1.0 / 2.39
        private const val MAX_ASPECT_RATIO = 2.39 / 1.0
    }

    private val PERMISSION_REQUEST_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null
    private var pipChannel: MethodChannel? = null
    private var pipReceiver: BroadcastReceiver? = null
    private var isPlayingState: Boolean = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Media Scanner Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCANNER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAndRequestPermissions" -> {
                    checkAndRequestPermissions(result)
                }
                "queryMediaStore" -> {
                    val mediaList = queryMediaStore()
                    result.success(mediaList)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Picture-in-Picture Platform Channel
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPipSupported" -> {
                        val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                        result.success(supported)
                    }
                    "enterPictureInPictureMode" -> {
                        val width = call.argument<Int>("videoWidth") ?: 0
                        val height = call.argument<Int>("videoHeight") ?: 0
                        val isPlaying = call.argument<Boolean>("isPlaying") ?: true
                        val success = enterPipMode(width, height, isPlaying)
                        result.success(success)
                    }
                    "setAutoEnterEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val width = call.argument<Int>("videoWidth")
                        val height = call.argument<Int>("videoHeight")
                        setAutoEnterEnabled(enabled, width, height)
                        result.success(true)
                    }
                    "toggleDesktopOverlay" -> {
                        // Desktop overlay is a no-op on Android, return true for interface compatibility
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }

        registerPipReceiver()
    }

    private fun registerPipReceiver() {
        if (pipReceiver != null) return
        pipReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    ACTION_PIP_PLAY -> {
                        pipChannel?.invokeMethod("onPipAction", "play")
                        updatePipActions(isPlaying = true)
                    }
                    ACTION_PIP_PAUSE -> {
                        pipChannel?.invokeMethod("onPipAction", "pause")
                        updatePipActions(isPlaying = false)
                    }
                    ACTION_PIP_FORWARD -> {
                        pipChannel?.invokeMethod("onPipAction", "seek_forward_10")
                    }
                    ACTION_PIP_REWIND -> {
                        pipChannel?.invokeMethod("onPipAction", "seek_rewind_10")
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_PIP_PLAY)
            addAction(ACTION_PIP_PAUSE)
            addAction(ACTION_PIP_FORWARD)
            addAction(ACTION_PIP_REWIND)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pipReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(pipReceiver, filter)
        }
    }

    private fun buildRemoteActions(isPlaying: Boolean): List<RemoteAction> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return emptyList()
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        // Rewind 10s
        val rewindIntent = Intent(ACTION_PIP_REWIND).setPackage(packageName)
        val rewindPendingIntent = PendingIntent.getBroadcast(this, REQUEST_CODE_REWIND, rewindIntent, flags)
        val rewindAction = RemoteAction(
            Icon.createWithResource(this, android.R.drawable.ic_media_rew),
            "Rewind 10s",
            "Rewind 10s",
            rewindPendingIntent
        )

        // Play/Pause toggle
        val playPauseAction = if (isPlaying) {
            val pauseIntent = Intent(ACTION_PIP_PAUSE).setPackage(packageName)
            val pausePendingIntent = PendingIntent.getBroadcast(this, REQUEST_CODE_PAUSE, pauseIntent, flags)
            RemoteAction(
                Icon.createWithResource(this, android.R.drawable.ic_media_pause),
                "Pause",
                "Pause playback",
                pausePendingIntent
            )
        } else {
            val playIntent = Intent(ACTION_PIP_PLAY).setPackage(packageName)
            val playPendingIntent = PendingIntent.getBroadcast(this, REQUEST_CODE_PLAY, playIntent, flags)
            RemoteAction(
                Icon.createWithResource(this, android.R.drawable.ic_media_play),
                "Play",
                "Start playback",
                playPendingIntent
            )
        }

        // Forward 10s
        val forwardIntent = Intent(ACTION_PIP_FORWARD).setPackage(packageName)
        val forwardPendingIntent = PendingIntent.getBroadcast(this, REQUEST_CODE_FORWARD, forwardIntent, flags)
        val forwardAction = RemoteAction(
            Icon.createWithResource(this, android.R.drawable.ic_media_ff),
            "Forward 10s",
            "Forward 10s",
            forwardPendingIntent
        )

        return listOf(rewindAction, playPauseAction, forwardAction)
    }

    private fun calculateClampedRational(width: Int, height: Int): Rational {
        if (width <= 0 || height <= 0) {
            return Rational(16, 9)
        }
        val rawRatio = width.toDouble() / height.toDouble()
        val clamped = rawRatio.coerceIn(MIN_ASPECT_RATIO, MAX_ASPECT_RATIO)
        val num = (clamped * 1000).toInt()
        val den = 1000
        return Rational(num, den)
    }

    private fun enterPipMode(width: Int, height: Int, isPlaying: Boolean): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (!packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
                return false
            }
            try {
                isPlayingState = isPlaying
                val rational = calculateClampedRational(width, height)
                val builder = PictureInPictureParams.Builder()
                    .setAspectRatio(rational)
                    .setActions(buildRemoteActions(isPlaying))
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    builder.setAutoEnterEnabled(isPlaying)
                }
                return enterPictureInPictureMode(builder.build())
            } catch (e: Exception) {
                e.printStackTrace()
                return false
            }
        }
        return false
    }

    private fun setAutoEnterEnabled(enabled: Boolean, width: Int?, height: Int?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
                return
            }
            try {
                val builder = PictureInPictureParams.Builder()
                    .setAutoEnterEnabled(enabled)
                if (width != null && height != null && width > 0 && height > 0) {
                    builder.setAspectRatio(calculateClampedRational(width, height))
                }
                builder.setActions(buildRemoteActions(isPlaying = enabled))
                setPictureInPictureParams(builder.build())
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun updatePipActions(isPlaying: Boolean) {
        isPlayingState = isPlaying
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val builder = PictureInPictureParams.Builder()
                    .setActions(buildRemoteActions(isPlaying))
                setPictureInPictureParams(builder.build())
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) {
            pipChannel?.invokeMethod("onPipEntered", null)
        } else {
            pipChannel?.invokeMethod("onPipExited", null)
        }
    }

    override fun onDestroy() {
        pipReceiver?.let {
            unregisterReceiver(it)
            pipReceiver = null
        }
        super.onDestroy()
    }

    private fun checkAndRequestPermissions(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) { // Android 13+ (API 33+)
            val videoPerm = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_VIDEO)
            val audioPerm = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO)
            if (videoPerm == PackageManager.PERMISSION_GRANTED && audioPerm == PackageManager.PERMISSION_GRANTED) {
                result.success(true)
            } else {
                pendingResult = result
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.READ_MEDIA_VIDEO, Manifest.permission.READ_MEDIA_AUDIO),
                    PERMISSION_REQUEST_CODE
                )
            }
        } else { // Android 12 and below
            val readPerm = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE)
            if (readPerm == PackageManager.PERMISSION_GRANTED) {
                result.success(true)
            } else {
                pendingResult = result
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE),
                    PERMISSION_REQUEST_CODE
                )
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val isGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingResult?.success(isGranted)
            pendingResult = null
        }
    }

    private fun queryMediaStore(): List<Map<String, Any>> {
        val mediaItems = mutableListOf<Map<String, Any>>()

        // Query Videos via Android ContentResolver
        val videoProjection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_MODIFIED,
            MediaStore.Video.Media.DURATION
        )

        try {
            contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                videoProjection,
                null,
                null,
                "${MediaStore.Video.Media.DATE_MODIFIED} DESC"
            )?.use { cursor ->
                val dataCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATA)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
                val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_MODIFIED)
                val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)

                while (cursor.moveToNext()) {
                    val path = cursor.getString(dataCol) ?: continue
                    val name = cursor.getString(nameCol) ?: File(path).name
                    val size = cursor.getLong(sizeCol)
                    val dateModified = cursor.getLong(dateCol) * 1000 // sec to ms
                    val duration = cursor.getLong(durationCol)
                    val parent = File(path).parent ?: ""

                    mediaItems.add(
                        mapOf(
                            "path" to path,
                            "name" to name,
                            "parentFolder" to parent,
                            "sizeBytes" to size,
                            "durationMs" to duration,
                            "lastPlayed" to dateModified
                        )
                    )
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Query Audio via Android ContentResolver
        val audioProjection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.DURATION
        )

        try {
            contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                audioProjection,
                "${MediaStore.Audio.Media.IS_MUSIC} != 0",
                null,
                "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"
            )?.use { cursor ->
                val dataCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
                val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)

                while (cursor.moveToNext()) {
                    val path = cursor.getString(dataCol) ?: continue
                    val name = cursor.getString(nameCol) ?: File(path).name
                    val size = cursor.getLong(sizeCol)
                    val dateModified = cursor.getLong(dateCol) * 1000
                    val duration = cursor.getLong(durationCol)
                    val parent = File(path).parent ?: ""

                    mediaItems.add(
                        mapOf(
                            "path" to path,
                            "name" to name,
                            "parentFolder" to parent,
                            "sizeBytes" to size,
                            "durationMs" to duration,
                            "lastPlayed" to dateModified
                        )
                    )
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return mediaItems
    }
}
