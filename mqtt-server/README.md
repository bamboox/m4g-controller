# 完整的MQTT服务器 - Android专用

## 概述

这是一个专为Android客户端设计的完整MQTT服务器解决方案，支持设备管理、远程控制和实时通信。

## 🚀 快速开始

### 方式1: 一键部署（推荐）

```bash
# 给脚本添加执行权限
chmod +x deploy.sh

# 一键启动
./deploy.sh
```

脚本会自动：
- 检查Go环境
- 安装依赖
- 构建项目
- 配置MQTT Broker
- 启动服务器

### 方式2: Docker部署

```bash
# 使用Docker Compose（包含MQTT Broker）
chmod +x docker-build.sh
./docker-build.sh compose-up

# 或者手动Docker命令
docker-compose up -d
```

### 方式3: 手动部署

```bash
# 1. 安装依赖
go mod tidy

# 2. 构建项目
go build -o mqtt-server .

# 3. 启动MQTT Broker (Mosquitto)
# macOS: brew install mosquitto && brew services start mosquitto
# Ubuntu: sudo apt-get install mosquitto && sudo systemctl start mosquitto

# 4. 启动服务器
./mqtt-server
```

## 📱 Android客户端集成

### 1. 服务器地址配置

在您的Android应用中，将MQTT服务器地址设置为：

```kotlin
val serverUri = "tcp://YOUR_SERVER_IP:1883"  // 替换为实际IP
```

### 2. 支持的主题格式

**Android客户端订阅**（接收命令）：
- `device/oppo/restart4g` - 重启4G网络命令
- `device/{device_type}/restart4g` - 通用设备命令格式

**Android客户端发布**（发送状态）：
- `device/oppo/status` - 设备状态报告
- `device/{device_type}/status` - 通用状态报告

### 3. 消息格式

**接收的命令（纯字符串）**：
```
"restart4g"
```

**发送的状态报告**：
```kotlin
// 发送状态到服务端
mqttClient.publish("device/oppo/status", MqttMessage("4g_connected".toByteArray()))
```

## 🖥️ Web管理界面

启动服务器后，访问 http://localhost:8080 使用Web管理界面：

- **设备列表** - 查看所有连接的Android设备
- **实时状态** - 监控设备在线状态和网络状态
- **命令发送** - 向指定设备发送重启4G命令
- **日志查看** - 实时查看服务器日志

## 🔧 API接口

### 基础信息
- **Base URL**: `http://localhost:8080/api/v1`
- **Content-Type**: `application/json`

### 主要接口

#### 1. 健康检查
```bash
curl http://localhost:8080/api/v1/health
```

#### 2. 获取设备列表
```bash
curl http://localhost:8080/api/v1/devices
```

#### 3. 发送命令到Android设备
```bash
curl -X POST http://localhost:8080/api/v1/command \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "oppo-device",
    "command": "restart4g",
    "topic": "device/oppo/restart4g"
  }'
```

## ⚙️ 配置选项

### 环境变量配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `MQTT_BROKER` | localhost | MQTT Broker地址 |
| `MQTT_PORT` | 1883 | MQTT端口 |
| `MQTT_USERNAME` | "" | MQTT用户名 |
| `MQTT_PASSWORD` | "" | MQTT密码 |
| `HTTP_PORT` | 8080 | HTTP API端口 |

### 命令行参数

```bash
./mqtt-server -h
```

常用参数：
```bash
./mqtt-server \
  -broker mqtt.example.com \
  -port 1883 \
  -username admin \
  -password secret \
  -http-port 8080
```

## 📋 管理命令

### 服务器管理

```bash
# 启动服务器
./deploy.sh

# 查看服务器状态
./deploy.sh status

# 停止服务器
./deploy.sh stop

# 查看帮助
./deploy.sh help
```

### Docker管理

```bash
# 启动所有服务
./docker-build.sh compose-up

# 查看服务状态
./docker-build.sh logs mqtt-server

# 停止所有服务
./docker-build.sh compose-down

# 清理资源
./docker-build.sh clean
```

### 日志查看

```bash
# 查看实时日志
tail -f mqtt-server.log

# 查看Docker日志
docker-compose logs -f mqtt-server
```

## 🔍 测试和调试

### 1. 测试MQTT连接

```bash
# 使用测试脚本
chmod +x test-android.sh
./test-android.sh

# 或手动测试
mosquitto_pub -h localhost -t "device/oppo/restart4g" -m "restart4g"
mosquitto_sub -h localhost -t "device/oppo/status" -v
```

### 2. 测试HTTP API

```bash
# 健康检查
curl http://localhost:8080/api/v1/health

# 获取设备列表
curl http://localhost:8080/api/v1/devices
```

### 3. Android客户端测试流程

1. **启动服务器**
   ```bash
   ./deploy.sh
   ```

2. **配置Android客户端**
   - 将服务器地址改为实际IP：`tcp://192.168.1.100:1883`

3. **测试连接**
   - Android应用连接MQTT服务器
   - 在Web界面查看设备是否出现在列表中

4. **测试命令发送**
   - 在Web界面发送restart4g命令
   - 检查Android设备是否收到命令并执行

## 🛠️ 故障排除

### 常见问题

1. **端口被占用**
   ```bash
   # 查看端口使用
   lsof -i :8080
   lsof -i :1883
   
   # 修改端口
   ./mqtt-server -http-port 8081
   ```

2. **MQTT连接失败**
   ```bash
   # 检查Mosquitto状态
   mosquitto_pub -h localhost -t test -m "hello"
   
   # 重启Mosquitto
   brew services restart mosquitto  # macOS
   sudo systemctl restart mosquitto  # Linux
   ```

3. **Android客户端连接失败**
   - 检查防火墙设置
   - 确认IP地址正确
   - 检查网络连通性

### 调试技巧

1. **启用详细日志**
   ```bash
   export MQTT_DEBUG=true
   ./mqtt-server
   ```

2. **检查服务状态**
   ```bash
   ./deploy.sh status
   ```

3. **查看实时日志**
   ```bash
   tail -f mqtt-server.log
   ```

## 📊 性能和扩展

### 性能优化

- **并发连接**: 支持数百个Android设备同时连接
- **消息处理**: 异步处理，低延迟响应
- **资源使用**: 内存占用 < 50MB，CPU使用率低

### 扩展功能

- **设备分组**: 支持按设备类型分组管理
- **命令队列**: 支持批量命令发送
- **状态监控**: 实时设备状态监控
- **日志记录**: 完整的操作日志

## 🔒 安全配置

### 生产环境建议

1. **启用MQTT认证**
   ```bash
   # 创建用户密码文件
   mosquitto_passwd -c /etc/mosquitto/passwd username
   
   # 修改mosquitto配置
   allow_anonymous false
   password_file /etc/mosquitto/passwd
   ```

2. **使用HTTPS**
   - 配置反向代理（Nginx）
   - 添加SSL证书

3. **网络安全**
   - 配置防火墙规则
   - 使用VPN连接

## 📁 项目结构

```
mqtt-server/
├── main.go                 # 主程序入口
├── go.mod                  # Go模块配置
├── deploy.sh               # 一键部署脚本
├── docker-build.sh         # Docker构建脚本
├── docker-compose.yml      # Docker编排配置
├── Dockerfile              # Docker镜像构建
├── types/                  # 数据类型定义
│   └── types.go
├── mqtt/                   # MQTT处理模块
│   └── handler.go
├── device/                 # 设备管理模块
│   └── manager.go
├── api/                    # HTTP API模块
│   └── handler.go
├── static/                 # Web管理界面
│   └── index.html
├── mosquitto/              # MQTT Broker配置
│   └── config/
│       └── mosquitto.conf
└── README.md               # 本文档
```

## 📞 支持

如果遇到问题：

1. 查看 [故障排除](#-故障排除) 部分
2. 检查日志文件：`tail -f mqtt-server.log`
3. 运行测试脚本：`./test-android.sh`
4. 查看项目Issues

## 🎯 下一步

1. **启动服务器**: `./deploy.sh`
2. **配置Android客户端**: 修改服务器地址
3. **测试连接**: 使用Web界面监控设备
4. **发送命令**: 测试4G重启功能

这个完整的MQTT服务器已经准备好为您的Android应用提供可靠的远程控制服务！