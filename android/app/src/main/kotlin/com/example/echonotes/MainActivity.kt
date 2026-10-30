package com.example.echonotes

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivityShare"
        private const val CHANNEL = "com.example.echonotes/share_receiver"
        private const val EXTRA_PROCESSED = "com.example.echonotes.PROCESSED"
    }

    private var methodChannel: MethodChannel? = null
    private var initialSharedAudio: Map<String, Any?>? = null

    private fun preSeedAppCheckDebugSecret(ctx: Context = this) {
        val isDebuggable = (ctx.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isDebuggable) return

        try {
            val assetManager = ctx.applicationContext.assets
            val inputStream = try {
                assetManager.open("flutter_assets/.env")
            } catch (_: Exception) {
                assetManager.open(".env")
            }
            val lines = inputStream.bufferedReader().readLines()
            for (line in lines) {
                val trimmed = line.trim()
                if (trimmed.startsWith("APP_CHECK_DEBUG_TOKEN=") || trimmed.startsWith("FIREBASE_APP_CHECK_DEBUG_TOKEN=")) {
                    val token = trimmed.substringAfter("=").trim()
                    if (token.isNotEmpty()) {
                        val targets = mutableListOf(
                            "com.google.firebase.appcheck.debug.store.[DEFAULT]",
                            "com.google.firebase.appcheck.debug.store"
                        )
                        try {
                            val firebaseAppClass = Class.forName("com.google.firebase.FirebaseApp")
                            val getAppsMethod = firebaseAppClass.getMethod("getApps", Context::class.java)
                            val apps = getAppsMethod.invoke(null, ctx.applicationContext) as? List<*>
                            apps?.forEach { app ->
                                val getKeyMethod = app?.javaClass?.getMethod("getPersistenceKey")
                                val key = getKeyMethod?.invoke(app) as? String
                                if (!key.isNullOrEmpty()) {
                                    targets.add("com.google.firebase.appcheck.debug.store.$key")
                                }
                            }
                        } catch (_: Exception) {}

                        for (target in targets.distinct()) {
                            val prefs = ctx.getSharedPreferences(target, Context.MODE_PRIVATE)
                            prefs.edit().putString("com.google.firebase.appcheck.debug.DEBUG_SECRET", token).commit()
                        }
                        Log.i(TAG, "App Check debug token pre-seeded into SharedPreferences stores")
                    }
                }
            }
        } catch (_: Exception) {
            // Harmless if file is not found or not present
        }
    }

    override fun attachBaseContext(newBase: Context?) {
        super.attachBaseContext(newBase)
        if (newBase != null) {
            preSeedAppCheckDebugSecret(newBase)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preSeedAppCheckDebugSecret(this)
        val payload = extractSharedAudio(intent)
        if (payload != null) {
            initialSharedAudio = payload
            intent.putExtra(EXTRA_PROCESSED, true)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedAudio" -> {
                    val payload = initialSharedAudio
                    initialSharedAudio = null
                    result.success(payload)
                }
                "clearInitialSharedAudio" -> {
                    initialSharedAudio = null
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = extractSharedAudio(intent)
        if (payload != null) {
            intent.putExtra(EXTRA_PROCESSED, true)
            if (methodChannel != null) {
                methodChannel?.invokeMethod("onSharedAudioReceived", payload)
            } else {
                initialSharedAudio = payload
            }
        }
    }

    private fun extractSharedAudio(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_SEND) return null
        if (intent.getBooleanExtra(EXTRA_PROCESSED, false)) return null

        val mimeType = intent.type ?: ""
        val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        } ?: intent.data

        if (uri == null) {
            Log.d(TAG, "No URI found in ACTION_SEND intent")
            return null
        }

        try {
            var displayName: String? = null
            var fileSize: Long = -1

            if (uri.scheme == "content") {
                val cursor = contentResolver.query(
                    uri,
                    arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                    null,
                    null,
                    null
                )
                cursor?.use {
                    if (it.moveToFirst()) {
                        val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex != -1) {
                            displayName = it.getString(nameIndex)
                        }
                        val sizeIndex = it.getColumnIndex(OpenableColumns.SIZE)
                        if (sizeIndex != -1) {
                            fileSize = it.getLong(sizeIndex)
                        }
                    }
                }
            }

            if (displayName == null) {
                displayName = uri.lastPathSegment ?: "shared_audio_${System.currentTimeMillis()}"
            }

            // Ensure directory exists
            val sharedDir = File(cacheDir, "shared_audio")
            if (!sharedDir.exists()) {
                sharedDir.mkdirs()
            }

            // Derive a safe file extension if none is provided
            val lowerName = displayName.lowercase()
            val hasExtension = lowerName.lastIndexOf('.') != -1 && lowerName.lastIndexOf('.') > lowerName.lastIndexOf('/')
            val safeExtension = when {
                hasExtension -> ""
                mimeType.contains("opus") -> ".opus"
                mimeType.contains("ogg") -> ".ogg"
                mimeType.contains("mpeg") || mimeType.contains("mp3") -> ".mp3"
                mimeType.contains("wav") -> ".wav"
                mimeType.contains("aac") -> ".aac"
                mimeType.contains("m4a") -> ".m4a"
                mimeType.contains("flac") -> ".flac"
                else -> ".audio"
            }

            val sanitizedBaseName = displayName.replace("[^a-zA-Z0-9._-]".toRegex(), "_")
            val targetFileName = "shared_${System.currentTimeMillis()}_$sanitizedBaseName$safeExtension"
            val tempFile = File(sharedDir, targetFileName)

            val inputStream = contentResolver.openInputStream(uri)
                ?: if (uri.scheme == "file") uri.path?.let { File(it).inputStream() } else null

            if (inputStream == null) {
                Log.e(TAG, "Could not open inputStream for URI: $uri")
                return null
            }

            inputStream.use { input ->
                FileOutputStream(tempFile).use { output ->
                    input.copyTo(output)
                }
            }

            if (tempFile.length() <= 0) {
                Log.e(TAG, "Copied file is empty: ${tempFile.absolutePath}")
                tempFile.delete()
                return null
            }

            val finalMime = if (mimeType.isNotEmpty()) {
                mimeType
            } else {
                contentResolver.getType(uri) ?: "audio/*"
            }

            Log.i(TAG, "Successfully cached shared audio: ${tempFile.absolutePath} (${tempFile.length()} bytes)")

            return mapOf(
                "path" to tempFile.absolutePath,
                "name" to displayName,
                "mimeType" to finalMime,
                "size" to tempFile.length()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error resolving shared audio content URI: $uri", e)
            return null
        }
    }
}
