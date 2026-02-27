#!/usr/bin/env node

/**
 * Test script to verify the SDK can connect to the server
 */

const net = require('net');
const fs = require('fs');

const SOCKET_PATH = '/tmp/com.openlocalkeys.sock';

console.log('Testing OpenLocalKeys Unix Socket connection...\n');
console.log(`Socket path: ${SOCKET_PATH}\n`);

// Check if socket file exists
if (fs.existsSync(SOCKET_PATH)) {
  console.log('✅ Socket file exists\n');
} else {
  console.log('❌ Socket file does not exist');
  console.log('Please start the OpenLocalKeys server:');
  console.log('  cd src-unix-socket && swift run OpenLocalKeys\n');
  process.exit(1);
}

// Try to connect
const client = net.createConnection({ path: SOCKET_PATH }, () => {
  console.log('✅ Connected to server\n');
  console.log('Sending test request...');

  // Send empty JSON object as a test
  client.write('{}');
});

client.on('data', (data) => {
  console.log('\n✅ Received response from server:');
  try {
    const response = JSON.parse(data.toString());
    console.log(JSON.stringify(response, null, 2));
  } catch {
    console.log(data.toString());
  }

  console.log('\n✅ Connection test successful!\n');
  client.end();
});

client.on('error', (err) => {
  console.error('❌ Connection error:', err.message);
  console.error('\nMake sure the OpenLocalKeys server is running:');
  console.error('  swift run OpenLocalKeys\n');
  process.exit(1);
});

client.on('end', () => {
  console.log('Connection closed');
});
