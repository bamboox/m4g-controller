package com.example.restart4g

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import android.widget.Switch
import androidx.appcompat.app.AppCompatActivity
import org.eclipse.paho.android.service.MqttAndroidClient
import org.eclipse.paho.client.mqttv3.*
import rikka.shizuku.Shizuku
import android.util.Log
import android.view.WindowManager

class MainActivity : AppCompatActivity() {

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var mqttClient: MqttAndroidClient
    private lateinit var etServerUri: EditText
    private lateinit var btnConnectMqtt: Button
    private lateinit var btnDisconnectMqtt: Button
    private lateinit var tvConnectionStatus: TextView
    private lateinit var switchKeepScreenOn: Switch
    private var isConnected = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // 保持屏幕常亮
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        initViews()
        setupClickListeners()
    }

    private fun initViews() {
        etServerUri = findViewById(R.id.et_server_uri)
        btnConnectMqtt = findViewById(R.id.btn_connect_mqtt)
        btnDisconnectMqtt = findViewById(R.id.btn_disconnect_mqtt)
        tvConnectionStatus = findViewById(R.id.tv_connection_status)
        switchKeepScreenOn = findViewById(R.id.switch_keep_screen_on)
    }

    private fun setupClickListeners() {
        findViewById<Button>(R.id.btn_restart4g).setOnClickListener {
            restart4GAuto()
        }

        btnConnectMqtt.setOnClickListener {
            connectMqtt()
        }

        btnDisconnectMqtt.setOnClickListener {
            disconnectMqtt()
        }
        
        // 屏幕常亮开关事件
        switchKeepScreenOn.setOnCheckedChangeListener { _, isChecked ->
            toggleKeepScreenOn(isChecked)
        }
    }

    private fun connectMqtt() {
        val serverUri = etServerUri.text.toString().trim()
        if (serverUri.isEmpty()) {
            Toast.makeText(this, "请输入服务器地址", Toast.LENGTH_SHORT).show()
            return
        }

        initMqtt(serverUri)
    }

    private fun disconnectMqtt() {
        if (::mqttClient.isInitialized && mqttClient.isConnected()) {
            mqttClient.disconnect()
            updateConnectionStatus(false, "已断开连接")
        }
    }

    private fun updateConnectionStatus(connected: Boolean, message: String) {
        isConnected = connected
        tvConnectionStatus.text = message
        tvConnectionStatus.setTextColor(
            if (connected) android.graphics.Color.GREEN 
            else android.graphics.Color.RED
        )
        btnConnectMqtt.isEnabled = !connected
        btnDisconnectMqtt.isEnabled = connected
    }

    private fun initMqtt(serverUri: String) {
        val clientId = "oppo-" + System.currentTimeMillis()
        val commandTopic = "device/oppo/restart4g"  // 接收命令的主题
        val statusTopic = "device/oppo/status"      // 发送状态的主题
        val registerTopic = "device/register"       // 设备注册主题

        try {
            mqttClient = MqttAndroidClient(applicationContext, serverUri, clientId)

            // 设置 MQTT 连接选项
            val options = MqttConnectOptions().apply {
                isCleanSession = false  // 改为false，保持会话
                connectionTimeout = 10   // 缩短连接超时
                keepAliveInterval = 30   // 缩短心跳间隔
                isAutomaticReconnect = true
                maxInflight = 5          // 减少并发消息数
                // 添加连接可靠性配置
                setMqttVersion(MqttConnectOptions.MQTT_VERSION_3_1_1)
            }

            mqttClient.setCallback(object : MqttCallbackExtended {
                override fun connectComplete(reconnect: Boolean, serverURI: String) {
                    runOnUiThread {
                        updateConnectionStatus(true, "已连接: $serverURI")
                        Toast.makeText(applicationContext, "MQTT 连接成功", Toast.LENGTH_SHORT).show()
                    }
                    
                    // 订阅命令主题
                    try {
                        mqttClient.subscribe(commandTopic, 1)
                        Log.d("MainActivity", "订阅命令主题: $commandTopic")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "订阅失败", e)
                    }
                    
                    // 延迟发送数据，避免连接后立即发送大量数据包
                    Handler(Looper.getMainLooper()).postDelayed({
                        // 发送设备注册信息
                        registerDevice(clientId, registerTopic)
                        
                        // 延迟发送初始状态
                        Handler(Looper.getMainLooper()).postDelayed({
                            sendStatus(statusTopic, "connected")
                        }, 2000)
                    }, 500) // 500ms后开始，不再发送心跳
                }

                override fun connectionLost(cause: Throwable?) {
                    runOnUiThread {
                        updateConnectionStatus(false, "连接断开: ${cause?.message ?: "未知原因"}")
                        Toast.makeText(applicationContext, "MQTT 断开", Toast.LENGTH_SHORT).show()
                    }
                    Log.w("MainActivity", "MQTT连接断开，原因: ${cause?.message}", cause)
                    
                    // 可选：手动重连增强（备用方案）
                    // 如果自动重连失败，5秒后手动重试
                    // Handler(Looper.getMainLooper()).postDelayed({
                    //     if (!mqttClient.isConnected) {
                    //         try {
                    //             Log.d("MainActivity", "尝试手动重连 MQTT")
                    //             mqttClient.reconnect()
                    //         } catch (e: Exception) {
                    //             Log.e("MainActivity", "手动重连失败", e)
                    //         }
                    //     }
                    // }, 5000)
                }

                override fun messageArrived(topic: String, message: MqttMessage) {
                    val msg = message.toString()
                    Log.d("MainActivity", "收到消息 - 主题: $topic, 内容: $msg")
                    
                    runOnUiThread {
                        Toast.makeText(applicationContext, "收到命令: $msg", Toast.LENGTH_SHORT).show()
                    }
                    
                    // 处理命令
                    when (msg.trim()) {
                        "restart4g" -> {
                            sendStatus(statusTopic, "command_received: restart4g")
                            restart4GAuto()
                        }
                        else -> {
                            Log.d("MainActivity", "未知命令: $msg")
                            sendStatus(statusTopic, "unknown_command: $msg")
                        }
                    }
                }

                override fun deliveryComplete(token: IMqttDeliveryToken) {
                    Log.d("MainActivity", "消息发送完成")
                }
            })

            updateConnectionStatus(false, "正在连接...")
            
            mqttClient.connect(options, null, object : IMqttActionListener {
                override fun onSuccess(asyncActionToken: IMqttToken) {
                    Log.d("MainActivity", "MQTT连接成功")
                }

                override fun onFailure(asyncActionToken: IMqttToken, exception: Throwable) {
                    runOnUiThread {
                        val errorMsg = when {
                            exception.message?.contains("Connection refused") == true -> "服务器拒绝连接"
                            exception.message?.contains("timeout") == true -> "连接超时"
                            exception.message?.contains("Network") == true -> "网络错误"
                            else -> exception.message ?: "未知错误"
                        }
                        updateConnectionStatus(false, "连接失败: $errorMsg")
                        Toast.makeText(applicationContext, "MQTT 连接失败: $errorMsg", Toast.LENGTH_LONG).show()
                    }
                }
            })
        } catch (e: Exception) {
            runOnUiThread {
                val errorMsg = when (e) {
                    is IllegalArgumentException -> "服务器地址格式错误"
                    is SecurityException -> "权限不足"
                    else -> e.message ?: "初始化失败"
                }
                updateConnectionStatus(false, "初始化失败: $errorMsg")
                Toast.makeText(this, "初始化MQTT失败: $errorMsg", Toast.LENGTH_LONG).show()
                
                Log.e("MainActivity", "MQTT初始化失败", e)
            }
        }
    }

    private fun restart4GAuto() {
        sendStatus("device/oppo/status", "restarting_4g")
        restart4GByAirplane()
    }

    // 设备注册方法 - 简化数据包大小
    private fun registerDevice(clientId: String, registerTopic: String) {
        try {
            // 简化注册数据，减少包大小
            val registerData = """
                {
                    "action": "register",
                    "device_id": "oppo-device",
                    "client_id": "$clientId"
                }
            """.trimIndent()
            
            // 延迟发送，避免连接后立即发送大量数据
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    if (::mqttClient.isInitialized && mqttClient.isConnected) {
                        mqttClient.publish(registerTopic, MqttMessage(registerData.toByteArray()))
                        Log.d("MainActivity", "发送设备注册: $registerData")
                    }
                } catch (e: Exception) {
                    Log.e("MainActivity", "延迟注册设备失败", e)
                }
            }, 1000) // 1秒后发送
            
        } catch (e: Exception) {
            Log.e("MainActivity", "注册设备失败", e)
        }
    }
    
    // 发送状态方法
    private fun sendStatus(statusTopic: String, status: String) {
        try {
            if (::mqttClient.isInitialized && mqttClient.isConnected) {
                mqttClient.publish(statusTopic, MqttMessage(status.toByteArray()))
                Log.d("MainActivity", "发送状态: $status 到 $statusTopic")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "发送状态失败", e)
        }
    }


    private fun restart4GByAirplane() {
        if (!Shizuku.pingBinder()) {
            Toast.makeText(this, "Shizuku 未运行", Toast.LENGTH_SHORT).show()
            sendStatus("device/oppo/status", "4g_restart_failed: Shizuku 未运行")
            return
        }

        if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
            Shizuku.requestPermission(0)
            Toast.makeText(this, "请求 Shizuku 权限", Toast.LENGTH_SHORT).show()
            sendStatus("device/oppo/status", "4g_restart_failed: 权限不足")
            return
        }
        
        Thread {
            try {
                MobileDataController.restart4G()
                runOnUiThread {
                    Toast.makeText(this, "已重启 4G 网络", Toast.LENGTH_SHORT).show()
                    sendStatus("device/oppo/status", "4g_restarted_success")
                }
            } catch (e: Exception) {
                runOnUiThread {
                    Toast.makeText(this, "重启4G失败: ${e.message}", Toast.LENGTH_LONG).show()
                    sendStatus("device/oppo/status", "4g_restart_failed: ${e.message}")
                }
            }
        }.start()
    }
    
    /**
     * 控制屏幕常亮功能
     * @param keepOn true表示保持屏幕常亮，false表示允许屏幕自动熄灭
     */
    private fun toggleKeepScreenOn(keepOn: Boolean) {
        if (keepOn) {
            // 添加保持屏幕常亮标志
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            Toast.makeText(this, "已开启屏幕常亮", Toast.LENGTH_SHORT).show()
            Log.d("MainActivity", "屏幕常亮已开启")
        } else {
            // 移除保持屏幕常亮标志
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            Toast.makeText(this, "已关闭屏幕常亮", Toast.LENGTH_SHORT).show()
            Log.d("MainActivity", "屏幕常亮已关闭")
        }
    }
    
    override fun onResume() {
        super.onResume()
        // 当Activity重新进入前台时，根据开关状态重新设置屏幕常亮
        if (::switchKeepScreenOn.isInitialized && switchKeepScreenOn.isChecked) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
    
    override fun onPause() {
        super.onPause()
        // 当Activity进入后台时，可以选择是否保持屏幕常亮
        // 这里我们在后台时仍然保持常亮设置，因为这是一个远程控制应用
        // 如果需要在后台时关闭常亮，可以取消下面的注释
        // window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}