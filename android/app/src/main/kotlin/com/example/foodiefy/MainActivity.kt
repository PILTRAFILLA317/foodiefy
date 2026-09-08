package com.example.foodiefy

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.json.JSONArray
import java.util.UUID

class MainActivity : FlutterActivity() {
    private var shareChannel: MethodChannel? = null
    private val ttl = 86400000L
    private val prefs get() = getSharedPreferences("foodiefy_share", MODE_PRIVATE)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) receive(intent)
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foodiefy/share")
        shareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "peek" -> {
                    val events = pendingEvents()
                    val data = events.minByOrNull { it.getLong("created") }
                    if (data == null) result.success(null) else {
                        val urls = data.getJSONArray("urls")
                        result.success(mapOf("id" to data.getString("id"), "created" to data.getLong("created"), "urls" to (0 until urls.length()).map { urls.getString(it) }))
                    }
                }
                "ack" -> {
                    val id = call.arguments as? String
                    if (id != null && runCatching { UUID.fromString(id) }.isSuccess) prefs.edit().remove(id).commit()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receive(intent)
    }
    private fun pendingEvents(): List<JSONObject> {
        val events = mutableListOf<JSONObject>()
        for ((key, raw) in prefs.all) {
            val value = try { JSONObject(raw as String) } catch (_: Exception) { null }
            if (value == null || System.currentTimeMillis() - value.optLong("created") > ttl) prefs.edit().remove(key).commit()
            else events.add(value)
        }
        return events
    }
    private fun receive(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return
        if (pendingEvents().size >= 20) {
            Toast.makeText(this, "Procesa los enlaces pendientes en Foodiefy antes de compartir más.", Toast.LENGTH_LONG).show()
            return
        }
        val text = intent.getStringExtra(Intent.EXTRA_TEXT).orEmpty()
        if (text.length > 32768) return
        val urls = Regex("https?://[^\\s<>\"']+", RegexOption.IGNORE_CASE).findAll(text)
            .map { it.value.trimEnd('.', ',', ';', '!', '?', ')', ']') }
            .filter { raw ->
                try { val u = java.net.URI(raw); raw.length <= 4096 && u.host != null && u.rawUserInfo == null } catch (_: Exception) { false }
            }.distinct().take(10).toList()
        val data = JSONObject().put("id", UUID.randomUUID().toString()).put("created", System.currentTimeMillis()).put("urls", JSONArray(urls))
        if (prefs.edit().putString(data.getString("id"), data.toString()).commit()) {
            intent.action = Intent.ACTION_MAIN
            intent.removeExtra(Intent.EXTRA_TEXT)
            shareChannel?.invokeMethod("changed", null)
        }
    }
}
