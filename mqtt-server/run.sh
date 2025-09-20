#!/bin/bash

# MQTT Server 启动脚本

# 设置默认参数
BROKER="localhost"
PORT=1883
HTTP_PORT=8080
USERNAME=""
PASSWORD=""

# 显示使用帮助
show_help() {
    echo "MQTT Server 启动脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -b, --broker HOST       MQTT Broker 主机名 (默认: localhost)"
    echo "  -p, --port PORT         MQTT Broker 端口 (默认: 1883)"
    echo "  --http-port PORT        HTTP API 服务端口 (默认: 8080)"
    echo "  -u, --username USER     MQTT 用户名"
    echo "  -P, --password PASS     MQTT 密码"
    echo "  --dev                   开发模式 (启用详细日志)"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认设置启动"
    echo "  $0 -b mqtt.example.com -p 1883       # 连接远程 MQTT Broker"
    echo "  $0 -u user -P pass --dev             # 使用认证和开发模式"
}

# 检查 Go 是否安装
check_go() {
    if ! command -v go &> /dev/null; then
        echo "错误: 未找到 Go 环境，请先安装 Go 1.21+"
        exit 1
    fi
    
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    echo "检测到 Go 版本: $GO_VERSION"
}

# 检查依赖
check_dependencies() {
    echo "检查项目依赖..."
    if [ ! -f "go.mod" ]; then
        echo "错误: 未找到 go.mod 文件"
        exit 1
    fi
    
    go mod tidy
    if [ $? -ne 0 ]; then
        echo "错误: 依赖安装失败"
        exit 1
    fi
    echo "依赖检查完成"
}

# 启动服务
start_server() {
    echo "启动 MQTT Server..."
    echo "配置信息:"
    echo "  MQTT Broker: $BROKER:$PORT"
    echo "  HTTP API: http://localhost:$HTTP_PORT"
    echo "  用户名: ${USERNAME:-"(无)"}"
    echo ""
    
    # 构建启动命令
    CMD="go run main.go -broker $BROKER -port $PORT -http-port $HTTP_PORT"
    
    if [ ! -z "$USERNAME" ]; then
        CMD="$CMD -username $USERNAME"
    fi
    
    if [ ! -z "$PASSWORD" ]; then
        CMD="$CMD -password $PASSWORD"
    fi
    
    # 执行命令
    exec $CMD
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -b|--broker)
            BROKER="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        --http-port)
            HTTP_PORT="$2"
            shift 2
            ;;
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -P|--password)
            PASSWORD="$2"
            shift 2
            ;;
        --dev)
            export MQTT_DEBUG=true
            echo "开发模式已启用"
            shift
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 -h 或 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 主程序
main() {
    echo "==============================================="
    echo "          MQTT Server 启动程序"
    echo "==============================================="
    echo ""
    
    check_go
    check_dependencies
    start_server
}

# 执行主程序
main