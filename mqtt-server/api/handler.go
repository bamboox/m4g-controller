package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"mobile-admin-mqtt-server/device"
	"mobile-admin-mqtt-server/types"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/gorilla/mux"
)

// API处理器
type Handler struct {
	deviceManager *device.Manager
	mqttClient    mqtt.Client
}

// 创建新的API处理器
func NewHandler(deviceManager *device.Manager) *Handler {
	return &Handler{
		deviceManager: deviceManager,
	}
}

// 设置MQTT客户端（用于直接发送消息）
func (h *Handler) SetMQTTClient(client mqtt.Client) {
	h.mqttClient = client
}

// 获取所有设备列表
func (h *Handler) GetDevices(w http.ResponseWriter, r *http.Request) {
	devices := h.deviceManager.GetAllDevices()

	response := types.APIResponse{
		Success: true,
		Message: "Devices retrieved successfully",
		Data:    devices,
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(response)
}

// 获取特定设备信息
func (h *Handler) GetDevice(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	deviceID := vars["id"]

	device, err := h.deviceManager.GetDevice(deviceID)
	if err != nil {
		response := types.APIResponse{
			Success: false,
			Message: err.Error(),
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(response)
		return
	}

	response := types.APIResponse{
		Success: true,
		Message: "Device retrieved successfully",
		Data:    device,
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(response)
}

// 发送命令给设备
func (h *Handler) SendCommand(w http.ResponseWriter, r *http.Request) {
	var req types.CommandRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response := types.APIResponse{
			Success: false,
			Message: "Invalid request body",
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(response)
		return
	}

	// 检查是否是Android客户端格式（通过topic字段判断）
	var err error
	if req.Topic != "" {
		// 使用指定的主题发送命令
		err = h.sendCommandToTopic(req.Topic, req.Command)
	} else if strings.Contains(req.DeviceID, "oppo") || strings.Contains(req.DeviceID, "android") {
		// Android客户端格式
		err = h.deviceManager.SendCommandToAndroid(req.DeviceID, req.Command)
	} else {
		// 标准格式
		err = h.deviceManager.SendCommand(req.DeviceID, req.Command)
	}

	if err != nil {
		response := types.APIResponse{
			Success: false,
			Message: err.Error(),
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(response)
		return
	}

	response := types.APIResponse{
		Success: true,
		Message: "Command sent successfully",
		Data: map[string]string{
			"device_id": req.DeviceID,
			"command":   req.Command,
			"topic":     req.Topic,
		},
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(response)
}

// 健康检查
func (h *Handler) HealthCheck(w http.ResponseWriter, r *http.Request) {
	response := types.APIResponse{
		Success: true,
		Message: "MQTT Server is running",
		Data: map[string]interface{}{
			"status": "healthy",
			"time":   "now",
		},
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(response)
}

// CORS中间件
func (h *Handler) CORSMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// 发送命令到指定主题
func (h *Handler) sendCommandToTopic(topic, command string) error {
	if h.mqttClient == nil {
		return fmt.Errorf("MQTT client not set")
	}

	token := h.mqttClient.Publish(topic, 1, false, command)
	token.Wait()

	if token.Error() != nil {
		return fmt.Errorf("failed to publish to topic %s: %v", topic, token.Error())
	}

	return nil
}