# MQTT Server Docker 部署指南

## 概述

本文档介绍如何使用Docker部署MQTT服务器，包括MQTT Broker（Mosquitto）和Go编写的MQTT服务端。

## 文件结构

```
mqtt-server/
├── Dockerfile              # 多阶段构建配置
├── docker-compose.yml      # Docker Compose配置
├── .dockerignore           # Docker忽略文件
├── docker-build.sh         # 构建和部署脚本
├── mosquitto/
│   └── config/
│       └── mosquitto.conf  # Mosquitto配置
└── static/                 # Web静态文件
```

## 快速开始

### 1. 使用Docker Compose（推荐）

这是最简单的部署方式，会同时启动MQTT Broker和服务端：

```bash
# 给脚本添加执行权限
chmod +x docker-build.sh

# 一键启动所有服务
./docker-build.sh compose-up
```

服务启动后：
- **Web管理界面**: http://localhost:8080
- **MQTT端口**: localhost:1883
- **WebSocket端口**: ws://localhost:9001

### 2. 单独构建和运行

如果您已经有MQTT Broker，可以只运行服务端：

```bash
# 构建镜像
./docker-build.sh build

# 运行容器（需要外部MQTT Broker）
./docker-build.sh run
```

## 部署选项

### 选项1: Docker Compose（完整部署）

包含MQTT Broker和服务端的完整解决方案：

```bash
# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 停止所有服务
docker-compose down
```

### 选项2: 仅构建服务端镜像

```bash
# 构建镜像
docker build -t mqtt-server:latest .

# 运行容器（连接外部MQTT Broker）
docker run -d \
  --name mqtt-server \
  -p 8080:8080 \
  -e MQTT_BROKER=your-mqtt-broker.com \
  -e MQTT_PORT=1883 \
  mqtt-server:latest
```

## 环境变量

可以通过环境变量配置服务端：

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `MQTT_BROKER` | localhost | MQTT Broker地址 |
| `MQTT_PORT` | 1883 | MQTT端口 |
| `MQTT_USERNAME` | "" | MQTT用户名 |
| `MQTT_PASSWORD` | "" | MQTT密码 |
| `HTTP_PORT` | 8080 | HTTP API端口 |

### 使用环境变量示例

```bash
# 通过环境变量配置
docker run -d \
  --name mqtt-server \
  -p 8080:8080 \
  -e MQTT_BROKER=mqtt.example.com \
  -e MQTT_PORT=1883 \
  -e MQTT_USERNAME=admin \
  -e MQTT_PASSWORD=password \
  mqtt-server:latest
```

## 管理脚本使用

`docker-build.sh` 脚本提供了完整的Docker管理功能：

```bash
# 显示帮助
./docker-build.sh help

# 构建镜像
./docker-build.sh build

# 构建并运行
./docker-build.sh run

# 使用Docker Compose启动
./docker-build.sh compose-up

# 停止Docker Compose服务
./docker-build.sh compose-down

# 查看服务日志
./docker-build.sh logs mqtt-server
./docker-build.sh logs mosquitto

# 清理资源
./docker-build.sh clean
```

### 高级选项

```bash
# 指定镜像标签
./docker-build.sh build -t v1.0

# 使用自定义compose文件
./docker-build.sh compose-up -f custom-compose.yml
```

## 数据持久化

Docker Compose配置包含数据持久化：

- **Mosquitto数据**: `./mosquitto/data`
- **Mosquitto日志**: `./mosquitto/log`
- **配置文件**: `./mosquitto/config`

这些目录会自动创建并挂载到容器中。

## 网络配置

服务使用自定义网络 `mqtt-network`：

- MQTT Broker和服务端在同一网络中
- 服务端通过容器名 `mosquitto` 连接Broker
- 外部设备通过宿主机端口访问

## 健康检查

两个服务都配置了健康检查：

- **MQTT Broker**: 发送测试消息检查连接
- **服务端**: 检查HTTP API健康状态

查看健康状态：
```bash
docker-compose ps
```

## 日志管理

### 查看实时日志

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f mqtt-server
docker-compose logs -f mosquitto
```

### 日志文件位置

- **容器日志**: 通过 `docker logs` 命令查看
- **Mosquitto日志**: `./mosquitto/log/mosquitto.log`

## 故障排除

### 常见问题

1. **端口被占用**
   ```bash
   # 检查端口使用情况
   lsof -i :8080
   lsof -i :1883
   
   # 修改端口映射
   # 编辑 docker-compose.yml 中的 ports 配置
   ```

2. **权限问题**
   ```bash
   # 确保脚本有执行权限
   chmod +x docker-build.sh
   
   # 检查目录权限
   ls -la mosquitto/
   ```

3. **镜像构建失败**
   ```bash
   # 检查Dockerfile语法
   docker build --no-cache -t mqtt-server:latest .
   
   # 查看构建日志
   ./docker-build.sh build
   ```

4. **服务无法连接**
   ```bash
   # 检查容器状态
   docker-compose ps
   
   # 检查网络连接
   docker network ls
   docker network inspect mqtt-server_mqtt-network
   ```

### 调试命令

```bash
# 进入服务端容器
docker exec -it mqtt-server sh

# 进入Mosquitto容器
docker exec -it mqtt-broker sh

# 检查服务端配置
docker exec mqtt-server ./mqtt-server -h

# 测试MQTT连接
docker exec mqtt-broker mosquitto_pub -h localhost -t test -m "hello"
```

## 生产环境部署

### 安全配置

1. **启用MQTT认证**
   ```bash
   # 编辑 mosquitto/config/mosquitto.conf
   allow_anonymous false
   password_file /mosquitto/config/passwd
   ```

2. **使用HTTPS**
   - 配置反向代理（Nginx/Traefik）
   - 添加SSL证书

3. **网络安全**
   ```yaml
   # docker-compose.yml 中添加
   networks:
     mqtt-network:
       internal: true  # 内部网络
   ```

### 性能优化

1. **资源限制**
   ```yaml
   # docker-compose.yml 中添加
   services:
     mqtt-server:
       deploy:
         resources:
           limits:
             memory: 256M
             cpus: '0.5'
   ```

2. **日志轮转**
   ```yaml
   logging:
     driver: "json-file"
     options:
       max-size: "10m"
       max-file: "3"
   ```

## 监控

### 健康检查API

```bash
# 检查服务端健康状态
curl http://localhost:8080/api/v1/health

# 检查设备列表
curl http://localhost:8080/api/v1/devices
```

### 使用Prometheus监控（可选）

可以集成Prometheus进行监控：

```yaml
# 添加到 docker-compose.yml
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
```

## 备份和恢复

### 数据备份

```bash
# 备份Mosquitto数据
tar -czf mosquitto-backup-$(date +%Y%m%d).tar.gz mosquitto/

# 备份Docker卷（如果使用）
docker run --rm -v mqtt-server_mosquitto-data:/data -v $(pwd):/backup alpine tar -czf /backup/data-backup.tar.gz /data
```

### 数据恢复

```bash
# 恢复数据
tar -xzf mosquitto-backup-YYYYMMDD.tar.gz

# 重启服务
docker-compose restart
```

## 更新和维护

### 更新服务端

```bash
# 拉取最新代码
git pull

# 重新构建和部署
./docker-build.sh compose-down
./docker-build.sh compose-up
```

### 更新Mosquitto

```bash
# 编辑 docker-compose.yml 更改镜像版本
# image: eclipse-mosquitto:2.1

# 重新部署
docker-compose up -d
```

这个Docker部署方案提供了完整的MQTT服务器解决方案，支持开发和生产环境使用！