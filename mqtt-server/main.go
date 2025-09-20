package main

import (
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"

	"mobile-admin-mqtt-server/api"
	"mobile-admin-mqtt-server/mqtt"
	"mobile-admin-mqtt-server/types"

	"github.com/gorilla/mux"
)

// 获取环境变量，如果不存在则使用默认值
func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// 获取环境变量整数值
func getEnvIntOrDefault(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

func main() {
	// 命令行参数（优先级高于环境变量）
	var (
		broker   = flag.String("broker", getEnvOrDefault("MQTT_BROKER", "121.199.162.193"), "MQTT broker hostname")
		port     = flag.Int("port", getEnvIntOrDefault("MQTT_PORT", 1888), "MQTT broker port")
		username = flag.String("username", getEnvOrDefault("MQTT_USERNAME", ""), "MQTT username")
		password = flag.String("password", getEnvOrDefault("MQTT_PASSWORD", ""), "MQTT password")
		httpPort = flag.String("http-port", getEnvOrDefault("HTTP_PORT", "8080"), "HTTP API server port")
	)
	flag.Parse()

	// 创建MQTT配置
	config := &types.MQTTConfig{
		Broker:   *broker,
		Port:     *port,
		Username: *username,
		Password: *password,
	}

	// 初始化MQTT处理器
	mqttHandler, err := mqtt.NewHandler(config)
	if err != nil {
		log.Fatalf("Failed to create MQTT handler: %v", err)
	}
	defer mqttHandler.Disconnect()

	// 启动设备清理协程
	mqttHandler.GetDeviceManager().StartCleanup()

	// 创建HTTP API处理器
	apiHandler := api.NewHandler(mqttHandler.GetDeviceManager())
	apiHandler.SetMQTTClient(mqttHandler.GetMQTTClient())

	// 设置HTTP路由
	router := mux.NewRouter()

	// 应用CORS中间件
	router.Use(apiHandler.CORSMiddleware)

	// API路由
	apiRouter := router.PathPrefix("/api/v1").Subrouter()
	apiRouter.HandleFunc("/health", apiHandler.HealthCheck).Methods("GET", "OPTIONS")
	apiRouter.HandleFunc("/devices", apiHandler.GetDevices).Methods("GET", "OPTIONS")
	apiRouter.HandleFunc("/devices/{id}", apiHandler.GetDevice).Methods("GET", "OPTIONS")
	apiRouter.HandleFunc("/command", apiHandler.SendCommand).Methods("POST", "OPTIONS")

	// 静态文件服务（可选）
	router.PathPrefix("/").Handler(http.StripPrefix("/", http.FileServer(http.Dir("./static/"))))

	// 启动HTTP服务器
	log.Printf("Starting MQTT Server...")
	log.Printf("MQTT Broker: %s:%d", config.Broker, config.Port)
	log.Printf("HTTP API Server: http://localhost:%s", *httpPort)
	log.Printf("API Endpoints:")
	log.Printf("  GET  /api/v1/health")
	log.Printf("  GET  /api/v1/devices")
	log.Printf("  GET  /api/v1/devices/{id}")
	log.Printf("  POST /api/v1/command")
	log.Printf("")
	log.Printf("MQTT Topics:")
	log.Printf("  Subscribe: %s", types.TopicDeviceRegister)
	log.Printf("  Subscribe: %s", types.TopicDeviceStatus)
	log.Printf("  Subscribe: %s", types.TopicDeviceHeartbeat)
	log.Printf("  Subscribe: %s", types.TopicDeviceOffline)
	log.Printf("  Publish:   %s/{device_id}", types.TopicCommandPrefix)
	log.Printf("  Subscribe: %s/{device_id}", types.TopicResponsePrefix)

	// 设置优雅关闭
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-c
		log.Println("Shutting down server...")
		mqttHandler.Disconnect()
		os.Exit(0)
	}()

	// 启动HTTP服务器
	if err := http.ListenAndServe(":"+*httpPort, router); err != nil {
		log.Fatalf("HTTP server failed to start: %v", err)
	}
}
