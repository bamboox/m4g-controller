# 📱 Mobile Admin - Android设备远程控制系统

> **本项目由 Qoder 完成** - 提供智能代码生成和项目开发支持

## 🎯 项目概述

Mobile Admin 是一个用于远程控制 Android 设备 4G 网络开关的完整解决方案。通过 MQTT 协议实现实时通信，利用无障碍服务实现无需 root 权限的自动化操作，为系统管理员和自动化测试人员提供便捷的设备管理工具。

### ✨ 核心特性

- 🔄 **远程4G网络控制** - 支持重启、开启、关闭移动数据
- 🔐 **无需Root权限** - 基于Shizuku和无障碍服务实现
- 🌐 **实时通信** - MQTT协议确保指令即时响应
- 📊 **状态监控** - 实时设备状态和操作结果反馈
- 🎛️ **Web管理界面** - HTTP API + Web控制台
- 📱 **Android客户端** - 原生Kotlin应用，支持Android 7.0+

## 🏗️ 系统架构

```
┌─────────────────┐    MQTT     ┌─────────────────┐    HTTP API    ┌─────────────────┐
│                 │ ◄────────► │                 │ ◄───────────► │                 │
│ Android客户端    │             │   MQTT服务器     │                │   Web管理界面    │
│                 │             │                 │                │                 │
│ • MQTT Client   │             │ • Go语言实现     │                │ • 设备列表       │
│ • 4G网络控制     │             │ • 设备管理       │                │ • 命令下发       │
│ • 状态上报       │             │ • 指令转发       │                │ • 状态监控       │
│ • Shizuku集成   │             │ • HTTP API      │                │                 │
└─────────────────┘             └─────────────────┘                └─────────────────┘
```

## 🚀 快速开始

### 环境要求

#### 服务端
- **Go 1.19+** - MQTT服务器开发语言
- **操作系统** - Linux/macOS/Windows

#### Android客户端  
- **Android 7.0+ (API 24)**
- **Shizuku** - 系统级权限管理
- **无障碍服务权限**

#### 开发环境
- **JDK 11+**
- **Android Studio**
- **Gradle 8.6+**

### 安装部署

#### 1. 启动MQTT服务器

```bash
# 克隆项目
git clone <项目地址>
cd mobile-admin

# 启动Go MQTT服务器
cd mqtt-server
go mod tidy
go run main.go -broker=localhost -port=1883 -http-port=8080

# 服务器启动成功后会显示:
# MQTT Broker: localhost:1883
# HTTP API Server: http://localhost:8080
```

#### 2. 构建Android应用

```bash
# 回到项目根目录
cd ..

# 初始化Gradle环境
chmod +x setup-gradle.sh
./setup-gradle.sh

# 构建APK
./gradlew assembleDebug

# 安装到设备
adb install app/build/outputs/apk/debug/app-debug.apk
```

#### 3. 配置Android设备

1. **安装Shizuku**
   ```bash
   # 下载并安装Shizuku
   # 通过无线调试启动: adb shell sh /sdcard/Android/data/moe.shizuku.privileged.api/start.sh
   ```

2. **启用无障碍服务**
   - 设置 → 辅助功能 → 启用应用的无障碍服务

3. **连接MQTT服务器**
   - 打开应用，输入服务器地址: `tcp://服务器IP:1883`
   - 点击连接，确保显示"已连接"状态

## 🎮 使用方法

### Web管理界面

访问 `http://localhost:8080` 打开管理界面

```bash
# 查看所有设备
curl http://localhost:8080/api/v1/devices

# 发送重启4G指令
curl -X POST http://localhost:8080/api/v1/command \
  -H "Content-Type: application/json" \
  -d '{"device_id": "oppo-device", "command": "restart4g"}'
```

### Android应用操作

1. **连接服务器**
   - 输入MQTT服务器地址
   - 点击"连接MQTT"按钮

2. **手动重启4G**
   - 点击"重启4G"按钮
   - 应用会自动执行网络重启操作

3. **远程控制**
   - 设备连接成功后，可通过Web界面远程发送指令
   - 支持的命令: `restart4g`

## 📊 MQTT通信协议

### 主题结构

```
设备注册: device/register
设备状态: device/{device_type}/status  
命令下发: device/{device_type}/restart4g
设备响应: device/response/{device_id}
设备心跳: device/heartbeat
```

### 消息格式

```json
// 设备注册
{
  "action": "register",
  "device_id": "oppo-device", 
  "client_id": "oppo-1234567890"
}

// 状态上报
"connected" | "restarting_4g" | "4g_restarted_success" | "4g_restart_failed"

// 命令下发
"restart4g"
```

## 🔧 技术栈

### 后端 (MQTT服务器)
- **Go 1.19+** - 主要开发语言
- **Eclipse Paho MQTT** - MQTT客户端库
- **Gorilla Mux** - HTTP路由框架
- **独立MQTT实现** - 无需外部broker依赖

### 前端 (Android客户端)
- **Kotlin** - 主要开发语言
- **AndroidX** - 现代Android开发库
- **Eclipse Paho Android** - MQTT客户端
- **Shizuku** - 系统级权限管理
- **无障碍服务** - 自动化操作实现

### 构建工具
- **Gradle 8.6+** - Android项目构建
- **Go Modules** - Go依赖管理

## 📂 项目结构

```
mobile-admin/
├── 📁 app/                          # Android应用
│   ├── 📁 src/main/java/com/example/restart4g/
│   │   ├── 📄 MainActivity.kt        # 主界面和MQTT逻辑
│   │   └── 📄 MobileDataController.kt # 4G网络控制
│   ├── 📁 src/main/res/
│   │   ├── 📁 layout/               # 界面布局
│   │   └── 📁 xml/                  # 网络安全配置
│   └── 📄 build.gradle.kts          # Android构建配置
├── 📁 mqtt-server/                  # MQTT服务器
│   ├── 📄 main.go                   # 服务器入口
│   ├── 📁 mqtt/                     # MQTT处理逻辑
│   ├── 📁 device/                   # 设备管理
│   ├── 📁 api/                      # HTTP API
│   └── 📁 types/                    # 数据结构定义
├── 📄 build.gradle.kts              # 项目级构建配置
├── 📄 settings.gradle.kts           # Gradle设置
├── 📄 gradle.properties             # Gradle属性配置
└── 📄 README.md                     # 项目文档
```

## 🔐 权限说明

### Android权限
```xml
<!-- 网络通信 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- 系统控制 (需要Shizuku) -->
<uses-permission android:name="android.permission.MODIFY_PHONE_STATE" />
<uses-permission android:name="android.permission.WRITE_SECURE_SETTINGS" />

<!-- 无障碍服务 -->
<uses-permission android:name="android.permission.BIND_ACCESSIBILITY_SERVICE" />
```

### 运行时权限
- **Shizuku权限** - 系统级操作权限
- **无障碍服务** - 模拟用户操作权限
- **网络权限** - MQTT连接权限

## 🐛 故障排查

### 常见问题

#### MQTT连接问题
```bash
# 检查网络连通性
ping 服务器IP

# 检查端口开放
telnet 服务器IP 1883

# 查看Android应用日志
adb logcat | grep -E "(MQTT|mqtt|connection)"
```

#### 4G重启失败
- ✅ 确认Shizuku已启动且已授权
- ✅ 确认无障碍服务已开启
- ✅ 检查设备厂商是否限制相关权限

#### oversize packet错误
- ✅ 使用本地MQTT broker进行测试
- ✅ 简化MQTT消息内容
- ✅ 检查网络配置和防火墙设置

### 调试模式

```bash
# 启动调试模式的MQTT服务器
go run main.go -broker=localhost -port=1883 -http-port=8080 -debug

# Android应用调试日志
adb logcat | grep MainActivity
```

## 🤝 贡献指南

1. **Fork项目** 到你的GitHub账户
2. **创建特性分支** (`git checkout -b feature/AmazingFeature`)
3. **提交更改** (`git commit -m 'Add some AmazingFeature'`)
4. **推送分支** (`git push origin feature/AmazingFeature`)
5. **创建Pull Request**

## 📄 开源协议

本项目采用 MIT 协议 - 查看 [LICENSE](LICENSE) 文件了解详细信息

## 🙏 致谢

- **Eclipse Paho** - 优秀的MQTT客户端库
- **Shizuku** - 强大的Android权限管理方案
- **Go社区** - 丰富的开源生态
- **Android开发社区** - 技术支持和最佳实践

---

## 📞 联系方式

如有问题或建议，欢迎通过以下方式联系：

- 📧 **邮箱**: 项目维护者邮箱
- 🐛 **问题反馈**: [GitHub Issues](项目GitHub地址/issues)
- 💬 **讨论**: [GitHub Discussions](项目GitHub地址/discussions)

---

**🎉 感谢使用 Mobile Admin 远程控制系统！**

> 由 **Qoder** 提供技术支持 - 让代码开发更智能、更高效