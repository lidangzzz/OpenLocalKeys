/**
 * Basic usage example for OpenLocalKeys HTTP SDK
 *
 * This example demonstrates the simplest way to request API keys
 */

import { OpenLocalKeys, APIKey } from '../src/index';

async function basicUsage() {
  // Example 1: Simple usage with defaults
  console.log('=== Example 1: Simple Usage ===');

  const client = new OpenLocalKeys({
    timeout: 60000,      // 60 seconds
    verbose: true        // Enable logging
  });

  try {
    const keys = await client.requestKeys();
    console.log(`Received ${keys.length} keys:`);
    keys.forEach((key, index) => {
      console.log(`  ${index + 1}. ${key.displayName} (${key.provider})`);
      console.log(`     Key: ${maskKey(key.privateKey)}`);
    });
  } catch (error: any) {
    console.error('Error:', error.message);
  }

  // Example 2: Check if server is running
  console.log('\n=== Example 2: Check Server Status ===');

  const status = await client.getServerStatus();
  console.log('Server status:', status);
  console.log('Is running:', status.running);

  // Example 3: Wait for server
  console.log('\n=== Example 3: Wait for Server ===');

  const ready = await client.waitForServer({
    timeout: 10000,      // 10 seconds
    interval: 500,        // Check every 500ms
    maxAttempts: 20
  });

  if (ready) {
    console.log('Server is ready!');
  } else {
    console.log('Server did not become ready in time');
  }

  // Example 4: Use with custom timeout
  console.log('\n=== Example 4: Custom Timeout ===');

  try {
    const keys = await client.requestKeys({
      timeout: 30000  // 30 seconds
    });
    console.log('Got keys with custom timeout');
  } catch (error: any) {
    console.error('Timeout or error:', error.message);
  }

  // Example 5: Request with retry
  console.log('\n=== Example 5: With Retry ===');

  const retryClient = new OpenLocalKeys({
    timeout: 10000,
    retries: 3,         // Retry 3 times on failure
    retryDelay: 1000,   // Wait 1 second between retries
    verbose: true
  });

  try {
    const keys = await retryClient.requestKeys();
    console.log('Got keys after retries');
  } catch (error: any) {
    console.error('Failed after retries:', error.message);
  }
}

// Helper function to mask API keys
function maskKey(key: string): string {
  if (key.length <= 8) {
    return '*'.repeat(key.length);
  }
  return `${key.substring(0, 4)}***${key.substring(key.length - 4)}`;
}

// Run the examples if this file is executed directly
if (require.main === module) {
  basicUsage()
    .then(() => console.log('\n✅ All examples completed'))
    .catch((error) => {
      console.error('❌ Example failed:', error);
      process.exit(1);
    });
}

export { basicUsage };
