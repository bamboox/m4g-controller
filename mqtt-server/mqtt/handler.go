package mqtt

import (
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"mobile-admin-mqtt-server/device"
	"mobile-admin-mqtt-server/types"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/google/uuid"
)

// MQTT处理器
type Handler struct {
	client        mqtt.Client
	deviceManager *device.Manager
	config        *types.MQTTConfig
}

// 创建新的MQTT处理器
func NewHandler(config *types.MQTTConfig) (*Handler, error) {
	// 生成唯一的客户端ID
	if config.ClientID == "" {
		config.ClientID = fmt.Sprintf("mqtt-server-%s", uuid.New().String()[:8])
	}

	// 创建MQTT客户端选项
	opts := mqtt.NewClientOptions()
	opts.AddBroker(fmt.Sprintf("tcp://%s:%d", config.Broker, config.Port))
	opts.SetClientID(config.ClientID)
	
	if config.Username != "" {
		opts.SetUsername(config.Username)
	}
	if config.Password != "" {
		opts.SetPassword(config.Password)
	}

	opts.SetCleanSession(true)
	opts.SetAutoReconnect(true)
	opts.SetKeepAlive(30 * time.Second)
	opts.SetPingTimeout(10 * time.Second)

	// 设置连接丢失处理器
	opts.SetConnectionLostHandler(func(client mqtt.Client, err error) {
		log.Printf("MQTT connection lost: %v", err)
	})

	// 设置重连处理器
	opts.SetOnConnectHandler(func(client mqtt.Client) {
		log.Println("MQTT client connected")
	})

	// 创建客户端
	client := mqtt.NewClient(opts)

	// 连接到MQTT broker
	if token := client.Connect(); token.Wait() && token.Error() != nil {
		return nil, fmt.Errorf("failed to connect to MQTT broker: %v", token.Error())
	}

	handler := &Handler{
		client: client,
		config: config,
	}

	// 创建设备管理器
	handler.deviceManager = device.NewManager(client)

	// 订阅主题
	if err := handler.subscribeTopics(); err != nil {
		return nil, err
	}

	log.Printf("MQTT Handler initialized with broker: %s:%d", config.Broker, config.Port)
	return handler, nil
}

// 订阅MQTT主题
func (h *Handler) subscribeTopics() error {
	topics := map[string]byte{
		types.TopicDeviceRegister:  1,
		types.TopicDeviceStatus:    1,
		types.TopicDeviceHeartbeat: 1,
		types.TopicDeviceOffline:   1,
		// 订阅所有设备的响应主题
		fmt.Sprintf("%s/+", types.TopicResponsePrefix): 1,
		// 订阅Android客户端主题格式: device/+/restart4g
		fmt.Sprintf("%s/+/restart4g", types.TopicAndroidDevicePrefix): 1,
		// 订阅Android客户端状态主题: device/+/status  
		fmt.Sprintf("%s/+/status", types.TopicAndroidDevicePrefix): 1,
	}

	for topic, qos := range topics {
		if token := h.client.Subscribe(topic, qos, h.messageHandler); token.Wait() && token.Error() != nil {
			return fmt.Errorf("failed to subscribe to topic %s: %v", topic, token.Error())
		}
		log.Printf("Subscribed to topic: %s", topic)
	}

	return nil
}

// MQTT消息处理器
func (h *Handler) messageHandler(client mqtt.Client, msg mqtt.Message) {
	topic := msg.Topic()
	payload := msg.Payload()

	log.Printf("Received message on topic: %s", topic)

	// 检查是否是Android客户端的主题格式
	if h.isAndroidClientTopic(topic) {
		h.handleAndroidClientMessage(topic, payload)
		return
	}

	// 尝试解析为JSON消息
	var mqttMsg types.MQTTMessage
	if err := json.Unmarshal(payload, &mqttMsg); err != nil {
		log.Printf("Failed to unmarshal message as JSON, treating as plain text: %v", err)
		// 如果不是JSON，尝试作为简单字符串处理
		h.handlePlainTextMessage(topic, string(payload))
		return
	}

	// 根据主题处理消息
	switch {
	case topic == types.TopicDeviceRegister:
		h.handleDeviceRegister(&mqttMsg)
	case topic == types.TopicDeviceStatus:
		h.handleDeviceStatus(&mqttMsg)
	case topic == types.TopicDeviceHeartbeat:
		h.handleDeviceHeartbeat(&mqttMsg)
	case topic == types.TopicDeviceOffline:
		h.handleDeviceOffline(&mqttMsg)
	case strings.HasPrefix(topic, types.TopicResponsePrefix):
		h.handleDeviceResponse(&mqttMsg, topic)
	default:
		log.Printf("Unknown topic: %s", topic)
	}
}

// 处理设备注册
func (h *Handler) handleDeviceRegister(msg *types.MQTTMessage) {
	if msg.Data == nil {
		log.Printf("Invalid register message: missing data")
		return
	}

	deviceID, ok := msg.Data["device_id"].(string)
	if !ok {
		log.Printf("Invalid register message: missing device_id")
		return
	}

	clientID, _ := msg.Data["client_id"].(string)
	if clientID == "" {
		clientID = deviceID
	}

	// 处理设备信息
	deviceInfo := make(map[string]string)
	if info, ok := msg.Data["device_info"].(map[string]interface{}); ok {
		for k, v := range info {
			if str, ok := v.(string); ok {
				deviceInfo[k] = str
			}
		}
	}

	// 注册设备
	if err := h.deviceManager.RegisterDevice(deviceID, clientID, deviceInfo); err != nil {
		log.Printf("Failed to register device: %v", err)
		return
	}

	// 发送注册确认
	response := types.MQTTMessage{
		Action:    "register_ack",
		Timestamp: time.Now().Unix(),
		DeviceID:  deviceID,
		Data: map[string]interface{}{
			"status":  "success",
			"message": "Device registered successfully",
		},
	}

	responseBytes, _ := json.Marshal(response)
	responseTopic := fmt.Sprintf("%s/%s", types.TopicResponsePrefix, deviceID)
	
	if token := h.client.Publish(responseTopic, 1, false, responseBytes); token.Wait() && token.Error() != nil {
		log.Printf("Failed to send register ACK: %v", token.Error())
	}
}

// 处理设备状态
func (h *Handler) handleDeviceStatus(msg *types.MQTTMessage) {
	if msg.Data == nil {
		return
	}

	var status types.ClientStatus
	if data, err := json.Marshal(msg.Data); err == nil {
		if err := json.Unmarshal(data, &status); err != nil {
			log.Printf("Failed to parse status data: %v", err)
			return
		}
	}

	if status.DeviceID == "" && msg.DeviceID != "" {
		status.DeviceID = msg.DeviceID
	}

	if err := h.deviceManager.UpdateDeviceStatus(status.DeviceID, &status); err != nil {
		log.Printf("Failed to update device status: %v", err)
	}
}

// 处理设备心跳
func (h *Handler) handleDeviceHeartbeat(msg *types.MQTTMessage) {
	deviceID := msg.DeviceID
	if deviceID == "" && msg.Data != nil {
		if id, ok := msg.Data["device_id"].(string); ok {
			deviceID = id
		}
	}

	if deviceID == "" {
		log.Printf("Invalid heartbeat message: missing device_id")
		return
	}

	if err := h.deviceManager.UpdateHeartbeat(deviceID); err != nil {
		log.Printf("Failed to update heartbeat: %v", err)
	}
}

// 处理设备离线
func (h *Handler) handleDeviceOffline(msg *types.MQTTMessage) {
	deviceID := msg.DeviceID
	if deviceID == "" && msg.Data != nil {
		if id, ok := msg.Data["device_id"].(string); ok {
			deviceID = id
		}
	}

	if deviceID != "" {
		h.deviceManager.SetDeviceOffline(deviceID)
	}
}

// 处理设备响应
func (h *Handler) handleDeviceResponse(msg *types.MQTTMessage, topic string) {
	// 从主题中提取设备ID
	parts := strings.Split(topic, "/")
	if len(parts) >= 3 {
		deviceID := parts[2]
		log.Printf("Received response from device %s: %s", deviceID, msg.Action)
		
		// 这里可以添加响应处理逻辑
		// 比如记录命令执行结果，通知Web界面等
	}
}

// 获取设备管理器
func (h *Handler) GetDeviceManager() *device.Manager {
	return h.deviceManager
}

// 获取MQTT客户端
func (h *Handler) GetMQTTClient() mqtt.Client {
	return h.client
}

// 断开连接
func (h *Handler) Disconnect() {
	if h.client.IsConnected() {
		h.client.Disconnect(1000)
		log.Println("MQTT client disconnected")
	}
}

// 检查是否为Android客户端主题
func (h *Handler) isAndroidClientTopic(topic string) bool {
	// 检查是否匹配 device/{device_type}/restart4g 或 device/{device_type}/status
	parts := strings.Split(topic, "/")
	if len(parts) == 3 && parts[0] == "device" {
		action := parts[2]
		return action == "restart4g" || action == "status"
	}
	return false
}

// 处理Android客户端消息
func (h *Handler) handleAndroidClientMessage(topic string, payload []byte) {
	parts := strings.Split(topic, "/")
	if len(parts) != 3 {
		log.Printf("Invalid Android client topic format: %s", topic)
		return
	}

	deviceType := parts[1] // oppo, xiaomi, etc.
	action := parts[2]     // restart4g, status
	message := string(payload)

	log.Printf("Android client message - DeviceType: %s, Action: %s, Message: %s", deviceType, action, message)

	// 根据action类型处理
	switch action {
	case "restart4g":
		// 这是从服务端发送给客户端的命令，不需要处理
		log.Printf("Command topic received (should be published by server): %s", topic)
	case "status":
		// 处理设备状态报告
		h.handleAndroidDeviceStatus(deviceType, message)
	default:
		log.Printf("Unknown Android client action: %s", action)
	}
}

// 处理简单文本消息
func (h *Handler) handlePlainTextMessage(topic string, message string) {
	log.Printf("Plain text message on topic %s: %s", topic, message)
	
	// 可以根据需要添加处理逻辑
	// 比如如果是特定主题的简单命令
}

// 处理Android设备状态
func (h *Handler) handleAndroidDeviceStatus(deviceType string, statusMessage string) {
	// 生成设备ID（使用设备类型作为标识）
	deviceID := fmt.Sprintf("%s-device", deviceType)
	
	// 尝试注册设备（如果不存在）
	if _, err := h.deviceManager.GetDevice(deviceID); err != nil {
		// 设备不存在，自动注册
		deviceInfo := map[string]string{
			"device_type": deviceType,
			"platform":    "android",
			"client_type": "android_mqtt",
		}
		
		h.deviceManager.RegisterDevice(deviceID, fmt.Sprintf("%s-client", deviceType), deviceInfo)
		log.Printf("Auto-registered Android device: %s", deviceID)
	}
	
	// 更新设备状态
	status := &types.ClientStatus{
		DeviceID:      deviceID,
		NetworkStatus: statusMessage,
		Timestamp:     time.Now().Unix(),
		LastAction:    "status_report",
	}
	
	if err := h.deviceManager.UpdateDeviceStatus(deviceID, status); err != nil {
		log.Printf("Failed to update Android device status: %v", err)
	}
}