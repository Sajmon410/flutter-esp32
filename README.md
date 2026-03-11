# 📡 Remote ESP32-CAM Monitoring System  
**Flutter App with Cloud Integration and Location-Based Photo Management**  
_Bachelor’s Thesis Project  2025_

## 🧭 Overview  
This cross-platform mobile application, developed in Flutter, enables remote monitoring and control of ESP32-CAM devices via WebSocket and a cloud-hosted backend. The system supports real-time JPEG frame streaming, photo capture, local storage, and interactive map-based photo browsing. Each ESP32-CAM is assigned a fixed GPS location, allowing spatial organization of captured images.

## 🔧 Architecture  
- **ESP32-CAM**: Captures JPEG frames and transmits them over WebSocket. Each device has a predefined static location.  
- **Cloud Backend (AWS EC2)**: Hosts the WebSocket server, enabling public access and stable communication.  
- **Flutter Mobile App**: Provides UI for camera selection, live stream viewing, photo capture, and location-based gallery management.

## 📌 Features  

### 📡 Real-Time JPEG Streaming  
Connect to any ESP32-CAM and view its live feed as a sequence of JPEG images over WebSocket.

### 📸 Photo Capture  
Capture snapshots from the live feed and store them locally with timestamp metadata.

### 📍 Fixed Geolocation Assignment  
Each camera is mapped to a static GPS coordinate, allowing location-based organization.

### 🗺️ Interactive Map View  
Browse captured photos by location. Tap on a map pin to view a gallery of images taken at that site.

### 🧹 Photo Management  
Delete unwanted or low-quality images directly from the map interface.

### 💾 Local Storage + SQLite  
Images are saved to device storage, while metadata (location, time, path) is indexed in a local SQLite database for offline access.

### 🧭 Multi-Camera Support  
Select between multiple ESP32-CAM devices via map or list interface, each with unique IP and location.

## 🛠️ Technologies Used  
- Flutter (Dart)  
- ESP32-CAM (Arduino)  
- WebSocket protocol  
- AWS EC2 (Ubuntu server)
- Node.js
- Google Maps Flutter SDK  
- SQLite  
- PhotoManager & Custom Info Window plugins
<hr/>  
✅ Demo: https://www.youtube.com/shorts/VMPHYj3vsZk <hr/>
<p align="center">
  <img src="https://github.com/user-attachments/assets/f315b29d-cbe4-4621-a4f8-19f1227e646d" width="250"/>
  <img src="https://github.com/user-attachments/assets/b3107c60-8160-4d96-8910-831aa8fe5c23" width="250"/>
  <img width="250" src="https://github.com/user-attachments/assets/6dc5ee63-acf2-4e3f-a363-3b2b6704d80e" />
  <img src="https://github.com/user-attachments/assets/19548a68-9169-4c9a-a683-d55f77ce3038" width="250"/>
  <img width="250" src="https://github.com/user-attachments/assets/128e1879-91d2-4bc0-bb24-19b2ab380740" />
  <img width="250" src="https://github.com/user-attachments/assets/b0705cb3-b06e-4a06-bd56-01bba9afbf36" />

</p>


