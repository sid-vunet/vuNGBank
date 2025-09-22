const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const port = process.env.PORT || 3000;

// Serve static files from React build
app.use(express.static(path.join(__dirname, 'build')));

// Health check endpoint
app.get('/health', (req, res) => {
  const healthData = {
    status: 'healthy',
    service: 'vubank-frontend',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'production',
    memory: {
      used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + ' MB',
      total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + ' MB'
    }
  };

  res.status(200).json(healthData);
});

// Status endpoint (simpler version)
app.get('/status', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'vubank-frontend',
    timestamp: new Date().toISOString()
  });
});

// Health check endpoint at root for Docker health checks
app.get('/healthcheck', (req, res) => {
  res.status(200).send('OK');
});

// Serve React app for all other routes
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'build', 'index.html'));
});

app.listen(port, '0.0.0.0', () => {
  console.log(`🚀 VuBank Frontend Server running on port ${port}`);
  console.log(`📊 Health endpoint: http://localhost:${port}/health`);
  console.log(`⚡ Status endpoint: http://localhost:${port}/status`);
});