package org.awrad.almuslim

import android.app.*
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.*
import android.view.*
import android.widget.TextView

class DhikrOverlayService : Service() {
    private lateinit var wm: WindowManager
    private var bubble: TextView? = null
    private val handler = Handler(Looper.getMainLooper())
    private var texts = listOf("سبحان الله")
    private var seconds = 10
    private var index = 0
    private val rotate = object : Runnable {
        override fun run() {
            bubble?.text = texts[index++ % texts.size] + "   ×"
            handler.postDelayed(this, seconds * 1000L)
        }
    }
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        texts = intent?.getStringArrayListExtra("texts")?.filter { it.isNotBlank() }?.takeIf { it.isNotEmpty() } ?: listOf("سبحان الله")
        seconds = (intent?.getIntExtra("seconds", 10) ?: 10).coerceAtLeast(5)
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("floating", "الذكر العائم", NotificationManager.IMPORTANCE_LOW))
        val stop = PendingIntent.getService(this, 2, Intent(this, DhikrOverlayService::class.java).setAction("STOP"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        if (intent?.action == "STOP") { stopSelf(); return START_NOT_STICKY }
        val open = PendingIntent.getActivity(this, 1, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "floating") else Notification.Builder(this)
        startForeground(22, builder.setContentTitle("الذكر العائم يعمل").setContentText("يمكنك إيقافه من هنا").setSmallIcon(android.R.drawable.ic_popup_reminder).setContentIntent(open).addAction(android.R.drawable.ic_delete, "إيقاف", stop).build())
        if (bubble == null) showBubble()
        handler.removeCallbacks(rotate); handler.post(rotate)
        return START_NOT_STICKY
    }
    private fun showBubble() {
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val params = WindowManager.LayoutParams(WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT)
        params.gravity = Gravity.TOP or Gravity.START; params.x = 20; params.y = 180
        val view = TextView(this)
        view.textSize = 19f; view.setTextColor(Color.WHITE); view.setTypeface(null, Typeface.BOLD)
        view.setPadding(28, 18, 28, 18)
        view.background = GradientDrawable().apply { setColor(Color.rgb(22, 75, 63)); cornerRadius = 40f }
        var x = 0; var y = 0; var downX = 0f; var downY = 0f; var moved = false
        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> { x = params.x; y = params.y; downX = event.rawX; downY = event.rawY; moved = false }
                MotionEvent.ACTION_MOVE -> { val dx = event.rawX - downX; val dy = event.rawY - downY; if (kotlin.math.abs(dx) + kotlin.math.abs(dy) > 12) moved = true; params.x = (x + dx).toInt().coerceAtLeast(0); params.y = (y + dy).toInt().coerceAtLeast(0); wm.updateViewLayout(view, params) }
                MotionEvent.ACTION_UP -> if (!moved) stopSelf()
            }; true
        }
        bubble = view; wm.addView(view, params)
    }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        bubble?.let { wm.removeView(it) }; bubble = null
        super.onDestroy()
    }
}
