# 📱 Android客户端与MQTT服务端通信重构方案

## 🔍 **问题分析**

### 原始问题：
1. ❌ **设备不注册** - Android客户端连接后服务端看不到设备
2. ❌ **状态不上报** - 所有状态发送代码被注释
3. ❌ **命令无法下发** - 服务端无法向客户端发送重启指令

### 根本原因：
- Android客户端没有向服务端注册设备信息
- 缺少设备状态上报机制
- 缺少心跳保活机制

## 🛠️ **修复方案**

### ✅ **已完成的Android客户端修改**

1. **🔧 设备注册机制**
   ```kotlin
   // 连接成功后自动注册设备
   private fun registerDevice(clientId: String, registerTopic: String) {
       val registerData = """
           {
               "action": "register",
               "timestamp": ${System.currentTimeMillis() / 1000},
               "data": {
                   "device_id": "oppo-device",
                   "client_id": "$clientId",
                   "device_info": {
                       "device_type": "oppo",
                       "platform": "android",
                       "client_type": "android_mqtt"
                   }
               }
           }
       """.trimIndent()
       mqttClient.publish(registerTopic, MqttMessage(registerData.toByteArray()))
   }
   ```

2. **📊 状态上报机制**
   ```kotlin
   private fun sendStatus(statusTopic: String, status: String) {
       mqttClient.publish(statusTopic, MqttMessage(status.toByteArray()))
   }
   ```

3. **💓 心跳保活机制**
   ```kotlin
   // 每30秒发送心跳
   private fun startHeartbeat(heartbeatTopic: String) {
       // 自动心跳实现
   }
   ```

4. **📝 完整的消息处理**
   - 接收命令：`device/oppo/restart4g`
   - 发送状态：`device/oppo/status`
   - 设备注册：`device/register`
   - 心跳上报：`device/heartbeat`

## 🎯 **MQTT主题映射**

### Android客户端 ➜ 服务端
```
设备注册: device/register → 服务端识别新设备
状态上报: device/oppo/status → 实时状态监控
心跳保活: device/heartbeat → 设备在线检测
```

### 服务端 ➜ Android客户端  
```
命令下发: device/oppo/restart4g → 执行重启指令
```

## 🚀 **测试步骤**

### 1. 启动MQTT服务端
```bash
cd mqtt-server
go run main.go -broker=localhost -port=1883 -http-port=8080
```

### 2. 检查服务端状态
```bash
# 查看设备列表
curl http://localhost:8080/api/v1/devices

# 查看服务端日志
# 应该看到：Device registered: oppo-device
```

### 3. Android客户端连接
- 输入服务器地址：`tcp://服务器IP:1883`
- 点击连接，查看Toast提示
- 检查是否显示"已连接"状态

### 4. 测试命令下发
```bash
# 发送重启命令
curl -X POST http://localhost:8080/api/v1/command \
  -H "Content-Type: application/json" \
  -d '{"device_id": "oppo-device", "command": "restart4g"}'
```

## 📋 **预期结果**

### 服务端日志应显示：
```
Device registered: oppo-device (ClientID: oppo-xxx)
Android client message - DeviceType: oppo, Action: status, Message: connected
Received message on topic: device/heartbeat
Command sent to topic device/oppo/restart4g: restart4g
```

### Android客户端应显示：
```
Toast: "MQTT 连接成功"
Toast: "收到命令: restart4g"  
Toast: "已重启 4G 网络"
```

### Web API应返回：
```json
{
  "success": true,
  "data": [
    {
      "device_id": "oppo-device",
      "client_id": "oppo-xxx",
      "network_status": "4g_restarted_success",
      "is_online": true,
      "last_seen": "2024-09-20T17:30:00Z"
    }
  ]
}
```

## 🔧 **故障排查**

### 如果设备不显示：
1. 检查服务端是否正确监听1883端口
2. 确认Android客户端连接地址正确
3. 查看服务端日志是否收到注册消息

### 如果命令无法下发：
1. 确认设备在线状态（`is_online: true`）
2. 检查Android客户端是否订阅了正确主题
3. 验证网络连接和防火墙设置

### 如果状态不更新：
1. 检查Android客户端是否发送状态消息
2. 确认服务端是否正确处理状态主题
3. 查看心跳是否正常发送

---

**状态**: Android客户端代码已重构完成，包含完整的设备注册、状态上报和心跳机制。需要重新编译测试。