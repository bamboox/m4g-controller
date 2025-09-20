#!/bin/bash

# MQTT Server 一键部署脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    MQTT Server 一键部署脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查系统要求
check_requirements() {
    echo -e "${YELLOW}检查系统要求...${NC}"
    
    # 检查Go环境
    if ! command -v go &> /dev/null; then
        echo -e "${RED}错误: 未安装Go环境${NC}"
        echo "请先安装Go 1.21或更高版本"
        exit 1
    fi
    
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    echo "Go版本: $GO_VERSION"
    
    # 检查Docker（可选）
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓ Docker已安装${NC}"
        DOCKER_AVAILABLE=true
    else
        echo -e "${YELLOW}⚠ Docker未安装，将使用本地运行模式${NC}"
        DOCKER_AVAILABLE=false
    fi
    
    echo ""
}

# 安装依赖
install_dependencies() {
    echo -e "${YELLOW}安装Go依赖...${NC}"
    
    if [ ! -f "go.mod" ]; then
        echo -e "${RED}错误: 未找到go.mod文件${NC}"
        exit 1
    fi
    
    go mod tidy
    go mod download
    
    echo -e "${GREEN}✓ 依赖安装完成${NC}"
    echo ""
}

# 构建项目
build_project() {
    echo -e "${YELLOW}构建MQTT服务器...${NC}"
    
    # 构建二进制文件
    go build -o mqtt-server .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 构建成功${NC}"
    else
        echo -e "${RED}✗ 构建失败${NC}"
        exit 1
    fi
    
    echo ""
}

# 检查MQTT Broker
check_mqtt_broker() {
    echo -e "${YELLOW}检查MQTT Broker...${NC}"
    
    # 检查是否有运行中的MQTT Broker
    if command -v mosquitto_pub &> /dev/null; then
        if mosquitto_pub -h localhost -t test -m "test" &> /dev/null; then
            echo -e "${GREEN}✓ 检测到运行中的MQTT Broker${NC}"
            return 0
        fi
    fi
    
    echo -e "${YELLOW}⚠ 未检测到MQTT Broker${NC}"
    
    if [ "$DOCKER_AVAILABLE" = true ]; then
        echo "选择MQTT Broker部署方式:"
        echo "1) 使用Docker启动Mosquitto (推荐)"
        echo "2) 手动安装Mosquitto"
        echo "3) 使用外部MQTT Broker"
        
        read -p "请选择 (1-3): " choice
        
        case $choice in
            1)
                start_mosquitto_docker
                ;;
            2)
                install_mosquitto_local
                ;;
            3)
                configure_external_broker
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                exit 1
                ;;
        esac
    else
        echo "选择MQTT Broker部署方式:"
        echo "1) 手动安装Mosquitto"
        echo "2) 使用外部MQTT Broker"
        
        read -p "请选择 (1-2): " choice
        
        case $choice in
            1)
                install_mosquitto_local
                ;;
            2)
                configure_external_broker
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                exit 1
                ;;
        esac
    fi
}

# 使用Docker启动Mosquitto
start_mosquitto_docker() {
    echo -e "${YELLOW}使用Docker启动Mosquitto...${NC}"
    
    # 创建配置目录
    mkdir -p mosquitto/data mosquitto/log
    
    # 启动Mosquitto容器
    docker run -d \
        --name mqtt-broker \
        -p 1883:1883 \
        -p 9001:9001 \
        -v $(pwd)/mosquitto/config:/mosquitto/config \
        -v $(pwd)/mosquitto/data:/mosquitto/data \
        -v $(pwd)/mosquitto/log:/mosquitto/log \
        eclipse-mosquitto:2.0
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Mosquitto启动成功${NC}"
        sleep 5  # 等待服务启动
    else
        echo -e "${RED}✗ Mosquitto启动失败${NC}"
        exit 1
    fi
}

# 本地安装Mosquitto
install_mosquitto_local() {
    echo -e "${YELLOW}安装Mosquitto...${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install mosquitto
            brew services start mosquitto
        else
            echo -e "${RED}请先安装Homebrew或手动安装Mosquitto${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y mosquitto mosquitto-clients
            sudo systemctl start mosquitto
            sudo systemctl enable mosquitto
        elif command -v yum &> /dev/null; then
            sudo yum install -y mosquitto mosquitto-clients
            sudo systemctl start mosquitto
            sudo systemctl enable mosquitto
        else
            echo -e "${RED}请手动安装Mosquitto${NC}"
            exit 1
        fi
    else
        echo -e "${RED}不支持的操作系统: $OSTYPE${NC}"
        echo "请手动安装Mosquitto"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Mosquitto安装完成${NC}"
}

# 配置外部Broker
configure_external_broker() {
    echo -e "${YELLOW}配置外部MQTT Broker...${NC}"
    
    read -p "请输入MQTT Broker地址 (默认: localhost): " broker_host
    broker_host=${broker_host:-localhost}
    
    read -p "请输入MQTT端口 (默认: 1883): " broker_port
    broker_port=${broker_port:-1883}
    
    read -p "请输入用户名 (可选): " username
    read -p "请输入密码 (可选): " password
    
    # 保存配置到环境变量文件
    cat > .env << EOF
MQTT_BROKER=$broker_host
MQTT_PORT=$broker_port
MQTT_USERNAME=$username
MQTT_PASSWORD=$password
EOF
    
    echo -e "${GREEN}✓ 外部Broker配置完成${NC}"
}

# 启动服务器
start_server() {
    echo -e "${YELLOW}启动MQTT服务器...${NC}"
    
    # 读取环境变量配置（如果存在）
    if [ -f ".env" ]; then
        source .env
    fi
    
    # 构建启动命令
    CMD="./mqtt-server"
    
    if [ ! -z "$MQTT_BROKER" ]; then
        CMD="$CMD -broker $MQTT_BROKER"
    fi
    
    if [ ! -z "$MQTT_PORT" ]; then
        CMD="$CMD -port $MQTT_PORT"
    fi
    
    if [ ! -z "$MQTT_USERNAME" ]; then
        CMD="$CMD -username $MQTT_USERNAME"
    fi
    
    if [ ! -z "$MQTT_PASSWORD" ]; then
        CMD="$CMD -password $MQTT_PASSWORD"
    fi
    
    echo "启动命令: $CMD"
    echo ""
    
    # 后台启动服务器
    nohup $CMD > mqtt-server.log 2>&1 &
    SERVER_PID=$!
    
    # 保存PID
    echo $SERVER_PID > mqtt-server.pid
    
    sleep 3
    
    # 检查服务是否启动成功
    if ps -p $SERVER_PID > /dev/null; then
        echo -e "${GREEN}✓ MQTT服务器启动成功${NC}"
        echo "PID: $SERVER_PID"
        echo "日志文件: mqtt-server.log"
        echo ""
        show_access_info
    else
        echo -e "${RED}✗ MQTT服务器启动失败${NC}"
        echo "请检查日志文件: mqtt-server.log"
        exit 1
    fi
}

# 显示访问信息
show_access_info() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    MQTT服务器已启动成功！${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${GREEN}访问地址:${NC}"
    echo "  Web管理界面: http://localhost:8080"
    echo "  API接口: http://localhost:8080/api/v1"
    echo "  MQTT端口: localhost:1883"
    echo ""
    echo -e "${GREEN}API示例:${NC}"
    echo "  健康检查: curl http://localhost:8080/api/v1/health"
    echo "  设备列表: curl http://localhost:8080/api/v1/devices"
    echo ""
    echo -e "${GREEN}Android客户端配置:${NC}"
    echo "  服务器地址: tcp://YOUR_SERVER_IP:1883"
    echo "  （将YOUR_SERVER_IP替换为实际服务器IP）"
    echo ""
    echo -e "${YELLOW}管理命令:${NC}"
    echo "  查看日志: tail -f mqtt-server.log"
    echo "  停止服务: kill \$(cat mqtt-server.pid)"
    echo "  重启服务: $0"
    echo ""
}

# 停止已运行的服务器
stop_existing_server() {
    if [ -f "mqtt-server.pid" ]; then
        PID=$(cat mqtt-server.pid)
        if ps -p $PID > /dev/null; then
            echo -e "${YELLOW}停止已运行的服务器 (PID: $PID)...${NC}"
            kill $PID
            sleep 2
            rm -f mqtt-server.pid
        fi
    fi
}

# 主函数
main() {
    # 检查命令行参数
    if [ "$1" = "stop" ]; then
        stop_existing_server
        echo -e "${GREEN}服务器已停止${NC}"
        exit 0
    fi
    
    if [ "$1" = "status" ]; then
        if [ -f "mqtt-server.pid" ]; then
            PID=$(cat mqtt-server.pid)
            if ps -p $PID > /dev/null; then
                echo -e "${GREEN}服务器运行中 (PID: $PID)${NC}"
            else
                echo -e "${RED}服务器未运行${NC}"
                rm -f mqtt-server.pid
            fi
        else
            echo -e "${RED}服务器未运行${NC}"
        fi
        exit 0
    fi
    
    if [ "$1" = "help" ]; then
        echo "用法: $0 [命令]"
        echo ""
        echo "命令:"
        echo "  (无参数)  启动服务器"
        echo "  stop      停止服务器"
        echo "  status    查看服务器状态"
        echo "  help      显示此帮助"
        exit 0
    fi
    
    # 停止已运行的服务器
    stop_existing_server
    
    # 执行部署流程
    check_requirements
    install_dependencies
    build_project
    check_mqtt_broker
    start_server
}

# 运行主函数
main "$@"