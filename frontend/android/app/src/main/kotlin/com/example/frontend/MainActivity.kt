package com.example.frontend

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 确保 SharedPreferences 在 Android 端可用
        // 强制初始化 SharedPreferences
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            android.util.Log.d("MainActivity", "SharedPreferences 初始化成功: $prefs")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "SharedPreferences 初始化失败", e)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 显式注册所有插件
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        android.util.Log.d("MainActivity", "Flutter 插件注册完成")
    }
}
