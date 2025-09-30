#include "esp_camera.h"
#include <WiFi.h>
#include <WebSocketsClient.h>

#define CAMERA_MODEL_AI_THINKER
#include "camera_pins.h"

// WiFi credentials
const char* ssid = "Sajmonet";
const char* pass = "Simon4sbb";

// WebSocket server info
const char* ws_server_host = "";
const uint16_t ws_server_port = 3000;
const char* ws_server_path = "/";

WebSocketsClient webSocket;

void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
  switch(type) {
    case WStype_DISCONNECTED:
      Serial.println("WebSocket disconnected");
      break;
    case WStype_CONNECTED:
      Serial.println("WebSocket connected");
      break;
    case WStype_TEXT:
      Serial.printf("Message: %s\n", payload);
      break;
    default:
      break;
  }
}

void setup() {
  Serial.begin(115200);

  // Connect to WiFi
   int n = WiFi.scanNetworks();
 Serial.println("scan done");
 if (n == 0) {
 Serial.println("no networks found");
 } else {
 Serial.print(n);
 Serial.println(" networks found");
 for (int i = 0; i < n; ++i) {
 // ispisi redni broj mreze i njen SSID (naziv)
 Serial.print(i + 1);
 Serial.print(": ");
 Serial.println(WiFi.SSID(i));
 // jacina signala
 Serial.print("Jacina signala (RSSI): ");
 Serial.println(WiFi.RSSI(i));
 Serial.println("-----------------------");
 }
 }
 WiFi.begin(ssid, pass);
 
 while (WiFi.status() != WL_CONNECTED) 
 {
 Serial.print(".");
 delay(1000);
 }
 Serial.println("\r\nWiFi connected");

  // Camera configuration
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 16000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_QVGA; // 320x240
  config.jpeg_quality = 12;
  config.fb_count = 2;

  if(esp_camera_init(&config) != ESP_OK){
    Serial.println("Camera init failed");
    return;
  }

  // Start WebSocket
  webSocket.begin(ws_server_host, ws_server_port, ws_server_path);
  webSocket.onEvent(webSocketEvent);

  Serial.println("Camera initialized successfully!");
}

void loop() {
  webSocket.loop();  // required

  camera_fb_t * fb = esp_camera_fb_get();
  if(!fb) return;

  if(webSocket.isConnected()){
    // send as binary frame
    webSocket.sendBIN(fb->buf, fb->len);
  }

  esp_camera_fb_return(fb);
  delay(200); // ~5 FPS
}
