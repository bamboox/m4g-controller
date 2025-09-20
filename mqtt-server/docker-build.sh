#!/bin/bash

# Docker 构建和部署脚本

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
IMAGE_NAME="mqtt-server"
TAG="latest"
COMPOSE_FILE="docker-compose.yml"

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}          MQTT Server Docker 构建脚本${NC}"
echo -e "${BLUE}===============================================${NC}"
echo ""

# 显示帮助信息
show_help() {
    echo -e "${YELLOW}用法: $0 [命令] [选项]${NC}"
    echo ""
    echo -e "${YELLOW}命令:${NC}"
    echo "  build           构建Docker镜像"
    echo "  run             运行单个容器"
    echo "  compose-up      使用Docker Compose启动服务"
    echo "  compose-down    停止Docker Compose服务"
    echo "  logs            查看日志"
    echo "  clean           清理镜像和容器"
    echo "  help            显示此帮助信息"
    echo ""
    echo -e "${YELLOW}选项:${NC}"
    echo "  -t, --tag TAG   指定镜像标签 (默认: latest)"
    echo "  -f, --file FILE 指定compose文件 (默认: docker-compose.yml)"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo "  $0 build -t v1.0"
    echo "  $0 compose-up"
    echo "  $0 logs mqtt-server"
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: Docker未安装或未在PATH中${NC}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}错误: Docker服务未运行${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker环境检查通过${NC}"
}

# 检查Docker Compose是否安装
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}错误: Docker Compose未安装${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker Compose环境检查通过${NC}"
}

# 构建Docker镜像
build_image() {
    echo -e "${YELLOW}开始构建Docker镜像...${NC}"
    echo "镜像名称: ${IMAGE_NAME}:${TAG}"
    echo ""
    
    docker build -t "${IMAGE_NAME}:${TAG}" .
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 镜像构建成功${NC}"
        echo ""
        echo "镜像信息:"
        docker images "${IMAGE_NAME}:${TAG}"
    else
        echo -e "${RED}✗ 镜像构建失败${NC}"
        exit 1
    fi
}

# 运行单个容器
run_container() {
    echo -e "${YELLOW}启动MQTT Server容器...${NC}"
    echo ""
    
    # 停止并删除已存在的容器
    docker stop mqtt-server 2>/dev/null
    docker rm mqtt-server 2>/dev/null
    
    docker run -d \
        --name mqtt-server \
        -p 8080:8080 \
        -e MQTT_BROKER=host.docker.internal \
        -e MQTT_PORT=1883 \
        -e HTTP_PORT=8080 \
        "${IMAGE_NAME}:${TAG}"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 容器启动成功${NC}"
        echo ""
        echo "容器状态:"
        docker ps | grep mqtt-server
        echo ""
        echo -e "${BLUE}访问地址: http://localhost:8080${NC}"
    else
        echo -e "${RED}✗ 容器启动失败${NC}"
        exit 1
    fi
}

# 使用Docker Compose启动服务
compose_up() {
    check_docker_compose
    
    echo -e "${YELLOW}使用Docker Compose启动服务...${NC}"
    echo ""
    
    # 创建必要的目录
    mkdir -p mosquitto/data mosquitto/log
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "${COMPOSE_FILE}" up -d
    else
        docker compose -f "${COMPOSE_FILE}" up -d
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 服务启动成功${NC}"
        echo ""
        echo "服务状态:"
        if command -v docker-compose &> /dev/null; then
            docker-compose -f "${COMPOSE_FILE}" ps
        else
            docker compose -f "${COMPOSE_FILE}" ps
        fi
        echo ""
        echo -e "${BLUE}访问地址:${NC}"
        echo "  Web界面: http://localhost:8080"
        echo "  MQTT端口: localhost:1883"
        echo "  WebSocket: ws://localhost:9001"
    else
        echo -e "${RED}✗ 服务启动失败${NC}"
        exit 1
    fi
}

# 停止Docker Compose服务
compose_down() {
    check_docker_compose
    
    echo -e "${YELLOW}停止Docker Compose服务...${NC}"
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "${COMPOSE_FILE}" down
    else
        docker compose -f "${COMPOSE_FILE}" down
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 服务已停止${NC}"
    else
        echo -e "${RED}✗ 停止服务失败${NC}"
        exit 1
    fi
}

# 查看日志
show_logs() {
    local service_name=$1
    
    if [ -z "$service_name" ]; then
        echo -e "${YELLOW}可用的服务:${NC}"
        echo "  mqtt-server"
        echo "  mosquitto"
        echo ""
        echo "用法: $0 logs [服务名]"
        return
    fi
    
    echo -e "${YELLOW}查看 ${service_name} 日志...${NC}"
    echo ""
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "${COMPOSE_FILE}" logs -f "$service_name"
    else
        docker compose -f "${COMPOSE_FILE}" logs -f "$service_name"
    fi
}

# 清理镜像和容器
clean_up() {
    echo -e "${YELLOW}清理Docker资源...${NC}"
    echo ""
    
    # 停止并删除容器
    echo "停止运行中的容器..."
    docker stop mqtt-server mosquitto 2>/dev/null
    docker rm mqtt-server mosquitto 2>/dev/null
    
    # 删除镜像
    echo "删除镜像..."
    docker rmi "${IMAGE_NAME}:${TAG}" 2>/dev/null
    
    # 清理未使用的资源
    echo "清理未使用的资源..."
    docker system prune -f
    
    echo -e "${GREEN}✓ 清理完成${NC}"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--tag)
                TAG="$2"
                shift 2
                ;;
            -f|--file)
                COMPOSE_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done
}

# 主函数
main() {
    # 解析选项参数
    local args=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--tag|-f|--file)
                parse_args "$@"
                return
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    # 获取命令
    local command="${args[0]}"
    
    if [ -z "$command" ]; then
        show_help
        exit 1
    fi
    
    # 检查Docker环境
    check_docker
    
    # 执行对应命令
    case "$command" in
        build)
            build_image
            ;;
        run)
            build_image
            run_container
            ;;
        compose-up)
            compose_up
            ;;
        compose-down)
            compose_down
            ;;
        logs)
            show_logs "${args[1]}"
            ;;
        clean)
            clean_up
            ;;
        help)
            show_help
            ;;
        *)
            echo -e "${RED}未知命令: $command${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"