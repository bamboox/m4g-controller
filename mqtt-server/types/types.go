package types

import "time"

// 设备信息结构
type Device struct {
	ID            string            `json:"device_id"`
	ClientID      string            `json:"client_id"`
	LastSeen      time.Time         `json:"last_seen"`
	NetworkStatus string            `json:"network_status"`
	LastAction    string            `json:"last_action,omitempty"`
	DeviceInfo    map[string]string `json:"device_info,omitempty"`
	IsOnline      bool              `json:"is_online"`
}

// MQTT消息结构
type MQTTMessage struct {
	Action    string                 `json:"action"`
	Command   string                 `json:"command,omitempty"`
	Timestamp int64                  `json:"timestamp"`
	Data      map[string]interface{} `json:"data,omitempty"`
	DeviceID  string                 `json:"device_id,omitempty"`
}

// 客户端状态结构
type ClientStatus struct {
	DeviceID      string `json:"device_id"`
	NetworkStatus string `json:"network_status"`
	Timestamp     int64  `json:"timestamp"`
	LastAction    string `json:"last_action,omitempty"`
}

// HTTP API请求结构
type CommandRequest struct {
	DeviceID string `json:"device_id"`
	Command  string `json:"command"`
	Topic    string `json:"topic,omitempty"`
}

// HTTP API响应结构
type APIResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// MQTT配置结构
type MQTTConfig struct {
	Broker   string `json:"broker"`
	Port     int    `json:"port"`
	Username string `json:"username,omitempty"`
	Password string `json:"password,omitempty"`
	ClientID string `json:"client_id"`
}

// 主题常量
const (
	// 设备注册主题
	TopicDeviceRegister = "device/register"
	
	// 设备状态报告主题
	TopicDeviceStatus = "device/status"
	
	// 设备心跳主题
	TopicDeviceHeartbeat = "device/heartbeat"
	
	// 命令下发主题前缀 (device/command/{device_id})
	TopicCommandPrefix = "device/command"
	
	// 命令响应主题前缀 (device/response/{device_id})
	TopicResponsePrefix = "device/response"
	
	// 设备离线主题
	TopicDeviceOffline = "device/offline"
	
	// Android客户端兼容主题前缀 (device/{device_id}/restart4g)
	TopicAndroidDevicePrefix = "device"
	
	// 支持的设备类型
	DeviceTypeOPPO = "oppo"
	DeviceTypeGeneric = "generic"
)