/**
 * Simple example: Request API keys from OpenLocalKeys
 *
 * This demonstrates the most common use case - requesting API keys
 * from the OpenLocalKeys HTTP server.
 */

import { OpenLocalKeys, APIKey } from '../src/index';

async function main() {
  console.log('🔑 OpenLocalKeys TypeScript SDK Example\n');
  console.log('Requesting API keys from OpenLocalKeys HTTP server...');
  console.log('Server: http://localhost:8899\n');

  // Create the OpenLocalKeys client
  const client = new OpenLocalKeys({
    baseUrl: 'http://localhost:8899',
    timeout: 60000,  // 60 seconds - gives you time to approve in the dialog
    verbose: true    // Enable logging to see what's happening
  });

  try {
    // Request keys - this will show a macOS dialog for approval
    console.log('⏳ Waiting for your approval in the popup dialog...\n');
    const keys: APIKey[] = await client.requestKeys();

    // Success! Display the received keys
    console.log('\n✅ Success! Received keys:\n');
    keys.forEach((key: APIKey, index: number) => {
      console.log(`${index + 1}. ${key.displayName}`);
      console.log(`   Provider: ${key.provider}`);
      if (key.customProviderName) {
        console.log(`   Custom Provider: ${key.customProviderName}`);
      }
      console.log(`   Key: ${maskKey(key.privateKey)}`);
      console.log('');
    });

    console.log(`Total: ${keys.length} key(s) received\n`);

  } catch (error: any) {
    // Handle errors
    console.error('\n❌ Error:', error.message);

    if (error.code === 'TIMEOUT') {
      console.error('The request timed out. Did you approve the dialog in time?');
    } else if (error.code === 'CONNECTION_FAILED') {
      console.error('Cannot connect to OpenLocalKeys server.');
      console.error('Make sure it\'s running: swift run OpenLocalKeysHTTP');
    }
  }
}

/**
 * Mask an API key for safe display
 */
function maskKey(key: string): string {
  if (key.length <= 8) {
    return '*'.repeat(key.length);
  }
  return `${key.substring(0, 4)}...${key.substring(key.length - 4)}`;
}

// Run the example
main()
  .then(() => {
    console.log('✅ Example completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Example failed:', error);
    process.exit(1);
  });
