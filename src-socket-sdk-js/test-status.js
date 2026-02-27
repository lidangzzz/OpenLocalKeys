#!/usr/bin/env node

/**
 * Test script to verify server status check doesn't trigger dialog
 */

const net = require('net');
const fs = require('fs');

const SOCKET_PATH = '/tmp/com.openlocalkeys.sock';

console.log('Testing server status check...\n');

// Check if socket file exists
if (fs.existsSync(SOCKET_PATH)) {
  console.log('✅ Socket file exists');
} else {
  console.log('❌ Socket file not found');
  console.log('Please start the server: swift run OpenLocalKeys');
  process.exit(1);
}

// Test connection WITHOUT sending data
console.log('Testing connection (no data sent)...');

const socket = net.createConnection({ path: SOCKET_PATH }, () => {
  console.log('✅ Connected to server successfully');
  console.log('   Closing connection without sending data...');
  socket.destroy();
  console.log('\n✅ Server is running and ready!');
  console.log('   (No dialog should have appeared)');
  process.exit(0);
});

socket.on('error', (err) => {
  console.error('❌ Connection failed:', err.message);
  process.exit(1);
});

setTimeout(() => {
  console.log('❌ Connection timeout');
  socket.destroy();
  process.exit(1);
}, 2000);
