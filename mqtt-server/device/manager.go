package device

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"mobile-admin-mqtt-server/types"

	mqtt "github.com/eclipse/paho.mqtt.golang"
)

// 设备管理器
type Manager struct {
	devices map[string]*types.Device
	mutex   sync.RWMutex
	client  mqtt.Client
}

// 创建新的设备管理器
func NewManager(client mqtt.Client) *Manager {
	return &Manager{
		devices: make(map[string]*types.Device),
		client:  client,
	}
}

// 注册设备
func (m *Manager) RegisterDevice(deviceID, clientID string, deviceInfo map[string]string) error {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	device := &types.Device{
		ID:            deviceID,
		ClientID:      clientID,
		LastSeen:      time.Now(),
		NetworkStatus: "unknown",
		DeviceInfo:    deviceInfo,
		IsOnline:      true,
	}

	m.devices[deviceID] = device
	log.Printf("Device registered: %s (ClientID: %s)", deviceID, clientID)
	return nil
}

// 更新设备状态
func (m *Manager) UpdateDeviceStatus(deviceID string, status *types.ClientStatus) error {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	device, exists := m.devices[deviceID]
	if !exists {
		return fmt.Errorf("device not found: %s", deviceID)
	}

	device.NetworkStatus = status.NetworkStatus
	device.LastAction = status.LastAction
	device.LastSeen = time.Now()
	device.IsOnline = true

	log.Printf("Device status updated: %s -> %s", deviceID, status.NetworkStatus)
	return nil
}

// 设备心跳更新
func (m *Manager) UpdateHeartbeat(deviceID string) error {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	device, exists := m.devices[deviceID]
	if !exists {
		return fmt.Errorf("device not found: %s", deviceID)
	}

	device.LastSeen = time.Now()
	device.IsOnline = true
	return nil
}

// 标记设备离线
func (m *Manager) SetDeviceOffline(deviceID string) {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	if device, exists := m.devices[deviceID]; exists {
		device.IsOnline = false
		log.Printf("Device marked as offline: %s", deviceID)
	}
}

// 移除设备
func (m *Manager) RemoveDevice(deviceID string) {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	delete(m.devices, deviceID)
	log.Printf("Device removed: %s", deviceID)
}

// 获取所有设备
func (m *Manager) GetAllDevices() []*types.Device {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	devices := make([]*types.Device, 0, len(m.devices))
	for _, device := range m.devices {
		devices = append(devices, device)
	}
	return devices
}

// 获取特定设备
func (m *Manager) GetDevice(deviceID string) (*types.Device, error) {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	device, exists := m.devices[deviceID]
	if !exists {
		return nil, fmt.Errorf("device not found: %s", deviceID)
	}
	return device, nil
}

// 发送命令到设备
func (m *Manager) SendCommand(deviceID, command string) error {
	// 检查设备是否存在且在线
	device, err := m.GetDevice(deviceID)
	if err != nil {
		return err
	}

	if !device.IsOnline {
		return fmt.Errorf("device is offline: %s", deviceID)
	}

	// 构建命令消息
	msg := types.MQTTMessage{
		Action:    "command",
		Command:   command,
		Timestamp: time.Now().Unix(),
		DeviceID:  deviceID,
	}

	msgBytes, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal command message: %v", err)
	}

	// 发布命令到设备特定主题
	topic := fmt.Sprintf("%s/%s", types.TopicCommandPrefix, deviceID)
	token := m.client.Publish(topic, 1, false, msgBytes)
	token.Wait()

	if token.Error() != nil {
		return fmt.Errorf("failed to publish command: %v", token.Error())
	}

	log.Printf("Command sent to device %s: %s", deviceID, command)
	return nil
}

// 发送命令到Android客户端（简单字符串格式）
func (m *Manager) SendCommandToAndroid(deviceID, command string) error {
	// 检查设备是否存在且在线
	device, err := m.GetDevice(deviceID)
	if err != nil {
		return err
	}

	if !device.IsOnline {
		return fmt.Errorf("device is offline: %s", deviceID)
	}

	// Android客户端期望的主题格式: device/{device_type}/restart4g
	// 从设备信息中获取设备类型，默认使用"oppo"
	deviceType := "oppo"
	if device.DeviceInfo != nil {
		if dt, ok := device.DeviceInfo["device_type"]; ok {
			deviceType = dt
		}
	}

	// 构建Android客户端主题
	topic := fmt.Sprintf("%s/%s/restart4g", types.TopicAndroidDevicePrefix, deviceType)
	
	// 直接发送命令字符串（不是JSON）
	token := m.client.Publish(topic, 1, false, command)
	token.Wait()

	if token.Error() != nil {
		return fmt.Errorf("failed to publish Android command: %v", token.Error())
	}

	log.Printf("Android command sent to topic %s: %s", topic, command)
	return nil
}

// 启动设备清理协程
func (m *Manager) StartCleanup() {
	ticker := time.NewTicker(60 * time.Second) // 每分钟检查一次
	go func() {
		for range ticker.C {
			m.mutex.Lock()
			now := time.Now()
			for deviceID, device := range m.devices {
				// 5分钟未活动视为离线
				if now.Sub(device.LastSeen) > 5*time.Minute {
					device.IsOnline = false
					log.Printf("Device marked as offline due to inactivity: %s", deviceID)
				}
				// 10分钟未活动则移除设备
				if now.Sub(device.LastSeen) > 10*time.Minute {
					delete(m.devices, deviceID)
					log.Printf("Device removed due to long inactivity: %s", deviceID)
				}
			}
			m.mutex.Unlock()
		}
	}()
}