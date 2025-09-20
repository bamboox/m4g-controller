#!/bin/bash

# Android客户端MQTT测试脚本

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置参数
MQTT_BROKER="localhost"
MQTT_PORT=1883
HTTP_API="http://localhost:8080"
DEVICE_TYPE="oppo"

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}          Android MQTT 客户端测试${NC}"
echo -e "${BLUE}===============================================${NC}"
echo ""

# 检查依赖
check_dependencies() {
    echo -e "${YELLOW}检查依赖工具...${NC}"
    
    # 检查mosquitto客户端工具
    if ! command -v mosquitto_pub &> /dev/null; then
        echo -e "${RED}错误: 未找到 mosquitto_pub 工具${NC}"
        echo "请安装 mosquitto 客户端:"
        echo "  macOS: brew install mosquitto"
        echo "  Ubuntu: sudo apt-get install mosquitto-clients"
        exit 1
    fi
    
    if ! command -v mosquitto_sub &> /dev/null; then
        echo -e "${RED}错误: 未找到 mosquitto_sub 工具${NC}"
        exit 1
    fi
    
    # 检查curl
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}错误: 未找到 curl 工具${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}依赖检查完成${NC}"
    echo ""
}

# 测试HTTP API
test_http_api() {
    echo -e "${YELLOW}测试HTTP API...${NC}"
    
    # 测试健康检查
    echo "1. 健康检查:"
    response=$(curl -s "${HTTP_API}/api/v1/health")
    if echo "$response" | grep -q '"success":true'; then
        echo -e "   ${GREEN}✓ 服务器运行正常${NC}"
    else
        echo -e "   ${RED}✗ 服务器连接失败${NC}"
        echo "   响应: $response"
        return 1
    fi
    
    # 测试设备列表
    echo "2. 获取设备列表:"
    response=$(curl -s "${HTTP_API}/api/v1/devices")
    if echo "$response" | grep -q '"success":true'; then
        echo -e "   ${GREEN}✓ 设备列表获取成功${NC}"
        device_count=$(echo "$response" | grep -o '"device_id"' | wc -l)
        echo "   当前设备数量: $device_count"
    else
        echo -e "   ${RED}✗ 设备列表获取失败${NC}"
    fi
    
    echo ""
}

# 模拟Android客户端连接
simulate_android_client() {
    echo -e "${YELLOW}模拟Android客户端连接...${NC}"
    
    # 生成客户端ID
    CLIENT_ID="${DEVICE_TYPE}-$(date +%s)"
    echo "客户端ID: $CLIENT_ID"
    
    # 1. 模拟设备注册（可选，因为服务端支持自动注册）
    echo "1. 发送设备注册消息:"
    register_msg='{
        "action": "register",
        "timestamp": '$(date +%s)',
        "data": {
            "device_id": "'${CLIENT_ID}'",
            "client_id": "'${CLIENT_ID}'",
            "device_info": {
                "device_type": "'${DEVICE_TYPE}'",
                "platform": "android",
                "manufacturer": "OPPO",
                "model": "Find X5",
                "version": "12.0"
            }
        }
    }'
    
    mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
        -t "device/register" \
        -m "$register_msg"
    
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✓ 注册消息发送成功${NC}"
    else
        echo -e "   ${RED}✗ 注册消息发送失败${NC}"
    fi
    
    sleep 2
    
    # 2. 模拟状态报告
    echo "2. 发送设备状态报告:"
    mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
        -t "device/${DEVICE_TYPE}/status" \
        -m "4g_connected"
    
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✓ 状态报告发送成功${NC}"
    else
        echo -e "   ${RED}✗ 状态报告发送失败${NC}"
    fi
    
    sleep 2
    
    # 3. 模拟心跳
    echo "3. 发送心跳消息:"
    heartbeat_msg='{
        "action": "heartbeat",
        "timestamp": '$(date +%s)',
        "device_id": "'${CLIENT_ID}'"
    }'
    
    mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
        -t "device/heartbeat" \
        -m "$heartbeat_msg"
    
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✓ 心跳消息发送成功${NC}"
    else
        echo -e "   ${RED}✗ 心跳消息发送失败${NC}"
    fi
    
    echo ""
}

# 测试命令发送
test_command_sending() {
    echo -e "${YELLOW}测试命令发送...${NC}"
    
    # 1. 通过HTTP API发送命令
    echo "1. 通过HTTP API发送restart4g命令:"
    response=$(curl -s -X POST "${HTTP_API}/api/v1/command" \
        -H "Content-Type: application/json" \
        -d '{
            "device_id": "'${DEVICE_TYPE}'-device",
            "command": "restart4g"
        }')
    
    if echo "$response" | grep -q '"success":true'; then
        echo -e "   ${GREEN}✓ 命令发送成功${NC}"
    else
        echo -e "   ${RED}✗ 命令发送失败${NC}"
        echo "   响应: $response"
    fi
    
    sleep 2
    
    # 2. 直接通过MQTT发送命令（模拟服务端行为）
    echo "2. 直接通过MQTT发送restart4g命令:"
    mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
        -t "device/${DEVICE_TYPE}/restart4g" \
        -m "restart4g"
    
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✓ MQTT命令发送成功${NC}"
    else
        echo -e "   ${RED}✗ MQTT命令发送失败${NC}"
    fi
    
    echo ""
}

# 订阅命令主题（模拟Android客户端）
monitor_commands() {
    echo -e "${YELLOW}启动命令监听（模拟Android客户端）...${NC}"
    echo "监听主题: device/${DEVICE_TYPE}/restart4g"
    echo "按 Ctrl+C 停止监听"
    echo ""
    
    mosquitto_sub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
        -t "device/${DEVICE_TYPE}/restart4g" \
        -v
}

# 显示菜单
show_menu() {
    echo -e "${BLUE}请选择测试选项:${NC}"
    echo "1. 检查依赖"
    echo "2. 测试HTTP API"
    echo "3. 模拟Android客户端连接"
    echo "4. 测试命令发送"
    echo "5. 监听命令（模拟Android客户端）"
    echo "6. 完整测试流程"
    echo "7. 退出"
    echo ""
    read -p "请输入选项 (1-7): " choice
}

# 完整测试流程
full_test() {
    echo -e "${BLUE}开始完整测试流程...${NC}"
    echo ""
    
    check_dependencies
    test_http_api
    simulate_android_client
    test_command_sending
    
    echo -e "${GREEN}===============================================${NC}"
    echo -e "${GREEN}            测试完成!${NC}"
    echo -e "${GREEN}===============================================${NC}"
    echo ""
    echo "要监听命令，请选择选项 5"
}

# 主程序
main() {
    while true; do
        show_menu
        
        case $choice in
            1)
                check_dependencies
                ;;
            2)
                test_http_api
                ;;
            3)
                simulate_android_client
                ;;
            4)
                test_command_sending
                ;;
            5)
                monitor_commands
                ;;
            6)
                full_test
                ;;
            7)
                echo -e "${BLUE}再见!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择${NC}"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
        echo ""
    done
}

# 检查命令行参数
if [ "$1" = "--auto" ]; then
    # 自动运行完整测试
    full_test
else
    # 交互式菜单
    main
fi