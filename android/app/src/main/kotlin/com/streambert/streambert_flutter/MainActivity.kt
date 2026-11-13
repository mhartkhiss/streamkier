package com.streambert.streambert_flutter

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startBackgroundMediaService()
    }

    override fun onResume() {
        super.onResume()
        keepWebViewsAwake()
    }

    override fun onPause() {
        super.onPause()
        keepWebViewsAwake()
    }

    override fun onStop() {
        super.onStop()
        keepWebViewsAwake()
    }

    override fun onDestroy() {
        try {
            stopService(Intent(this, BackgroundMediaService::class.java))
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    private fun startBackgroundMediaService() {
        try {
            val serviceIntent = Intent(this, BackgroundMediaService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } catch (_: Exception) {
        }
    }

    private fun keepWebViewsAwake() {
        val resumeRunnable = Runnable {
            try {
                val root = window?.decorView ?: return@Runnable
                resumeAllWebViews(root)
            } catch (_: Exception) {
            }
        }
        mainHandler.post(resumeRunnable)
        mainHandler.postDelayed(resumeRunnable, 150)
        mainHandler.postDelayed(resumeRunnable, 500)
    }

    private fun resumeAllWebViews(view: View) {
        if (view is WebView) {
            try {
                view.dispatchWindowVisibilityChanged(View.VISIBLE)
                view.onResume()
                view.resumeTimers()
            } catch (_: Exception) {
            }
        }
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                val child = view.getChildAt(i)
                if (child != null) {
                    resumeAllWebViews(child)
                }
            }
        }
    }
}
