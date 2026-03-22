#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <WiFi.h>

const char* WIFI_SSID = "YOUR_WIFI_NAME";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char* API_URL = "http://YOUR_PC_IP:8000/sensor-data";

const char* DEVICE_ID = "node-1";
const char* ZONE_ID = "zone-1";
const char* DEVICE_NAME = "ESP32 North Field";
const char* FIRMWARE_VERSION = "1.0.0";

unsigned long lastSend = 0;
const unsigned long sendIntervalMs = 60000;

void connectWifi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }
}

String buildPayload() {
  DynamicJsonDocument document(1024);
  document["device_id"] = DEVICE_ID;
  document["zone_id"] = ZONE_ID;
  document["device_name"] = DEVICE_NAME;
  document["timestamp"] = "2026-03-22T08:00:00Z";
  document["firmware_version"] = FIRMWARE_VERSION;

  JsonObject connectivity = document.createNestedObject("connectivity");
  connectivity["connection_state"] = "online";
  connectivity["signal_strength"] = 82;
  connectivity["battery_level"] = 95;
  connectivity["pending_sync"] = false;

  JsonObject environment = document.createNestedObject("environment");
  environment["soil_moisture"] = 51.4;
  environment["temperature"] = 29.7;
  environment["humidity"] = 56.8;

  JsonObject actuators = document.createNestedObject("actuators");
  actuators["pump_online"] = true;
  actuators["relay_state"] = "off";
  actuators["last_action"] = "heartbeat";

  JsonObject optional = document.createNestedObject("optional");
  optional["crop_type"] = "lettuce";
  optional["growth_stage"] = "vegetative";
  optional["gas_ppm"] = 0;

  String payload;
  serializeJson(document, payload);
  return payload;
}

void sendTelemetry() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWifi();
  }

  HTTPClient http;
  http.begin(API_URL);
  http.addHeader("Content-Type", "application/json");
  String payload = buildPayload();
  int statusCode = http.POST(payload);
  http.end();

  Serial.print("POST /sensor-data -> ");
  Serial.println(statusCode);
}

void setup() {
  Serial.begin(115200);
  connectWifi();
}

void loop() {
  unsigned long now = millis();
  if (now - lastSend >= sendIntervalMs) {
    lastSend = now;
    sendTelemetry();
  }
}
