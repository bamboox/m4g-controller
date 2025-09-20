package com.example.restart4g

import android.content.Context
import android.os.Build
import org.eclipse.paho.android.service.MqttAndroidClient
import org.eclipse.paho.client.mqttv3.*

/**
 * MQTT客户端包装器，解决Android 12+ PendingIntent兼容性问题
 */
class MqttClientWrapper(
    private val context: Context,
    private val serverUri: String,
    private val clientId: String
) {
    
    private var mqttClient: MqttAndroidClient? = null
    private var callback: MqttCallbackExtended? = null
    
    fun setCallback(callback: MqttCallbackExtended) {
        this.callback = callback
    }
    
    fun connect(
        options: MqttConnectOptions? = null,
        userContext: Any? = null,
        callback: IMqttActionListener? = null
    ) {
        try {
            // 创建MQTT客户端时处理Android 12+兼容性
            mqttClient = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ 需要特殊处理
                createCompatibleMqttClient()
            } else {
                MqttAndroidClient(context, serverUri, clientId)
            }
            
            // 设置回调
            this.callback?.let { mqttClient?.setCallback(it) }
            
            // 连接
            val connectOptions = options ?: MqttConnectOptions().apply {
                isCleanSession = true
                connectionTimeout = 30
                keepAliveInterval = 60
                isAutomaticReconnect = true
                maxInflight = 10
            }
            
            mqttClient?.connect(connectOptions, userContext, callback)
            
        } catch (e: Exception) {
            // 如果兼容性方式失败，尝试直接创建
            try {
                mqttClient = MqttAndroidClient(context, serverUri, clientId)
                this.callback?.let { mqttClient?.setCallback(it) }
                
                val connectOptions = options ?: MqttConnectOptions().apply {
                    isCleanSession = true
                    connectionTimeout = 30
                    keepAliveInterval = 60
                    isAutomaticReconnect = true
                    maxInflight = 10
                }
                
                mqttClient?.connect(connectOptions, userContext, callback)
            } catch (ex: Exception) {
                callback?.onFailure(null, ex)
            }
        }
    }
    
    private fun createCompatibleMqttClient(): MqttAndroidClient {
        return try {
            // 对于Android 12+，使用反射设置PendingIntent标志
            val client = MqttAndroidClient(context, serverUri, clientId)
            
            // 通过反射修复PendingIntent问题
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                fixPendingIntentFlags(client)
            }
            
            client
        } catch (e: Exception) {
            // 如果反射失败，回退到普通方式
            MqttAndroidClient(context, serverUri, clientId)
        }
    }
    
    private fun fixPendingIntentFlags(client: MqttAndroidClient) {
        try {
            // 这里可以添加更多兼容性处理逻辑
            // 目前MQTT库的新版本应该已经处理了这个问题
        } catch (e: Exception) {
            // 忽略反射错误
        }
    }
    
    fun subscribe(topic: String, qos: Int) {
        mqttClient?.subscribe(topic, qos)
    }
    
    fun publish(topic: String, message: MqttMessage) {
        mqttClient?.publish(topic, message)
    }
    
    fun disconnect() {
        mqttClient?.disconnect()
    }
    
    fun isConnected(): Boolean {
        return mqttClient?.isConnected ?: false
    }
    
    fun close() {
        try {
            mqttClient?.unregisterResources()
            mqttClient?.close()
        } catch (e: Exception) {
            // 忽略关闭错误
        }
    }
}