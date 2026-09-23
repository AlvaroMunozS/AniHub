package com.alvaromunozs.anihub

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Installs an APK over the running app with a [PackageInstaller] session.
 *
 * The `install` call answers `cancelled` when the user declines, or an error.
 * On success Android replaces the process, so it usually never answers.
 */
class ApkInstaller(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var sessionId = -1

    /** The confirmation screen, held until the activity is in front. */
    private var confirmation: Intent? = null
    private var confirmationShown = false
    private var resumed = false

    private val statusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) = onStatus(intent)
    }

    fun register() {
        val filter = IntentFilter(ACTION_STATUS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(statusReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            activity.registerReceiver(statusReceiver, filter)
        }
    }

    fun unregister() {
        activity.unregisterReceiver(statusReceiver)
        answerError("The activity was destroyed")
    }

    fun onResume() {
        resumed = true
        if (confirmation != null && !confirmationShown) {
            showConfirmation()
        } else if (confirmationShown) {
            // Some Android versions send no status when the confirmation is
            // dismissed without choosing, which would leave the call hanging.
            val id = sessionId
            mainHandler.postDelayed({
                if (pending != null && sessionId == id) answer(CANCELLED)
            }, DISMISS_GRACE_MS)
        }
    }

    fun onPause() {
        resumed = false
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "install") {
            result.notImplemented()
            return
        }
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("invalid_arguments", "Missing path", null)
            return
        }
        if (pending != null) {
            result.error("busy", "Another installation is in progress", null)
            return
        }
        pending = result
        // Copying the APK into the session takes a moment; keep it off the
        // main thread.
        Thread {
            try {
                commit(File(path))
            } catch (error: Exception) {
                mainHandler.post { answerError(error.message ?: error.toString()) }
            }
        }.start()
    }

    private fun commit(apk: File) {
        val installer = activity.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        ).apply {
            setAppPackageName(activity.packageName)
            setSize(apk.length())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Honored only once AniHub is the installer of record, that
                // is after its first self-update; otherwise Android asks.
                setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            }
        }
        val id = installer.createSession(params)
        try {
            installer.openSession(id).use { session ->
                apk.inputStream().use { input ->
                    session.openWrite("anihub.apk", 0, apk.length()).use { output ->
                        input.copyTo(output)
                        session.fsync(output)
                    }
                }
                apk.delete()
                val intent = Intent(ACTION_STATUS).setPackage(activity.packageName)
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    // The installer adds the status as extras.
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
                mainHandler.post { sessionId = id }
                session.commit(
                    PendingIntent.getBroadcast(activity, id, intent, flags).intentSender,
                )
            }
        } catch (error: Exception) {
            installer.abandonSession(id)
            throw error
        }
    }

    private fun onStatus(intent: Intent) {
        val id = intent.getIntExtra(PackageInstaller.EXTRA_SESSION_ID, -1)
        if (pending == null || id != sessionId) return
        when (val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                confirmation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                if (confirmation == null) {
                    answerError("The installer sent no confirmation screen")
                } else if (resumed) {
                    showConfirmation()
                }
            }
            PackageInstaller.STATUS_SUCCESS -> answer(SUCCESS)
            PackageInstaller.STATUS_FAILURE_ABORTED -> answer(CANCELLED)
            else -> answerError(
                intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: "Status $status",
            )
        }
    }

    private fun showConfirmation() {
        val intent = confirmation ?: return
        confirmationShown = true
        activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun answer(value: String) {
        val result = pending ?: return
        reset()
        result.success(value)
    }

    private fun answerError(message: String) {
        val result = pending ?: return
        reset()
        result.error("install_failed", message, null)
    }

    private fun reset() {
        pending = null
        sessionId = -1
        confirmation = null
        confirmationShown = false
    }

    private companion object {
        const val ACTION_STATUS = "com.alvaromunozs.anihub.INSTALL_STATUS"
        const val SUCCESS = "success"
        const val CANCELLED = "cancelled"
        const val DISMISS_GRACE_MS = 1500L
    }
}
