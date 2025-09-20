# Android MainActivity 修改说明

## 修改概述

我已经成功修改了您的Android客户端MainActivity，现在支持前端输入MQTT服务器地址，默认值为 `tcp://192.168.1.12:1883`。

## 主要修改内容

### 1. UI界面更新

**新增的UI组件：**
- `EditText` - 服务器地址输入框（默认值：tcp://192.168.1.12:1883）
- `Button` - 连接MQTT按钮
- `Button` - 断开连接按钮
- `TextView` - 连接状态显示

**布局文件 (activity_main.xml) 更新：**
```xml
- 服务器地址输入框
- 连接/断开按钮组
- 连接状态显示
- 原有的重启4G按钮
```

### 2. MainActivity功能增强

**新增功能：**
1. **动态服务器地址设置** - 用户可以输入自定义MQTT服务器地址
2. **连接状态管理** - 实时显示MQTT连接状态
3. **手动连接控制** - 用户可以手动连接/断开MQTT
4. **状态报告** - 向服务端发送4G重启状态
5. **错误处理增强** - 更好的错误提示和异常处理

**代码主要变更：**

```kotlin
// 新增UI控件属性
private lateinit var etServerUri: EditText
private lateinit var btnConnectMqtt: Button  
private lateinit var btnDisconnectMqtt: Button
private lateinit var tvConnectionStatus: TextView
private var isConnected = false

// 新增方法
private fun initViews() // 初始化UI控件
private fun setupClickListeners() // 设置点击事件
private fun connectMqtt() // 连接MQTT
private fun disconnectMqtt() // 断开MQTT
private fun updateConnectionStatus() // 更新连接状态

// 修改的方法
private fun initMqtt(serverUri: String) // 支持动态服务器地址
private fun restart4GAuto() // 增加连接检查和状态报告
private fun restart4GByAirplane() // 增加状态报告到服务端
```

## 使用方法

### 1. 启动应用
应用启动后会显示：
- 服务器地址输入框（默认：tcp://192.168.1.12:1883）
- 连接MQTT按钮
- 连接状态显示
- 重启4G按钮

### 2. 连接MQTT服务器
1. 在输入框中输入MQTT服务器地址（或使用默认值）
2. 点击"连接MQTT"按钮
3. 观察连接状态显示

### 3. 使用重启4G功能
- 连接成功后，点击"一键重启4G"按钮
- 应用会自动向服务端发送状态报告

## 状态报告功能

应用现在会向服务端主题 `device/oppo/status` 发送以下状态：

1. **开始重启**: `"restarting_4g"`
2. **重启成功**: `"4g_restarted_success"`  
3. **重启失败**: `"4g_restart_failed: {错误信息}"`

## 与MQTT服务端的兼容性

修改后的Android客户端完全兼容我们创建的MQTT服务端：

- **订阅主题**: `device/oppo/restart4g` (接收重启命令)
- **发布主题**: `device/oppo/status` (发送状态报告)
- **命令格式**: 纯字符串 `"restart4g"`

## 测试步骤

1. **启动MQTT服务端**:
   ```bash
   cd mqtt-server
   go run main.go
   ```

2. **修改Android客户端服务器地址**:
   - 将默认地址改为您的实际服务器IP
   - 或者在应用中直接输入服务器地址

3. **测试连接**:
   - 启动Android应用
   - 点击"连接MQTT"
   - 检查连接状态

4. **测试命令接收**:
   - 在Web管理界面 (http://localhost:8080) 发送restart4g命令
   - 或使用API测试工具

## 错误处理

修改后的代码包含完善的错误处理：

- **连接失败** - 显示具体错误信息
- **网络断开** - 自动更新连接状态
- **权限不足** - 提示Shizuku权限问题
- **命令执行失败** - 向服务端报告错误状态

## 后续建议

1. **保存服务器地址** - 可以添加SharedPreferences保存用户输入的服务器地址
2. **自动重连** - 可以添加网络断开后的自动重连功能
3. **更多状态** - 可以添加更多设备状态的报告（电池、网络强度等）

您的Android客户端现在完全支持动态服务器地址配置，并且与我们的MQTT服务端完美配合工作！