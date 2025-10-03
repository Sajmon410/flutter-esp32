const WebSocket = require('ws');
const express = require('express');

const app = express();
const PORT = 3000;

const server = app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

// Create WebSocket server on top of the same HTTP server
const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
  console.log('ESP32/Client connected');

  ws.on('message', (message, isBinary) => {
    if (isBinary) {
      // Binary frame (JPEG) from ESP32
      console.log('Received frame of size:', message.length);

      // Forward to all other clients (browser/Flutter)
      wss.clients.forEach((client) => {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
          client.send(message, { binary: true });
        }
      });
    } else {
      // Handle text messages (if any)
      console.log('Text message:', message.toString());

      // Optionally forward text too
      wss.clients.forEach((client) => {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
          client.send(message);
        }
      });
    }
  });

  ws.on('close', () => {
    console.log('Client disconnected');
  });
});