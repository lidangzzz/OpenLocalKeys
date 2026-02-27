/**
 * Simple Example for OpenLocalKeys Unix Socket SDK
 *
 * This example demonstrates basic usage of the SDK to request API keys.
 *
 * Prerequisites:
 * 1. Start the OpenLocalKeys Unix socket server:
 *    swift run OpenLocalKeys
 *
 * 2. Run this example:
 *    npm run build
 *    node dist/examples/simple-example.js
 */

import { OpenLocalKeys, APIKey, OpenLocalKeysError, ErrorCode } from '../src/index';

async function main() {
  console.log('==========================================');
  console.log('  OpenLocalKeys Unix Socket SDK Example');
  console.log('==========================================\n');

  // Initialize the client
  const client = new OpenLocalKeys({
    socketPath: '/tmp/com.openlocalkeys.sock',
    timeout: 60000,  // 60 seconds
    verbose: true    // Enable logging
  });

  try {
    // Step 1: Check if server is running
    console.log('Step 1: Checking server status...\n');
    const status = await client.getServerStatus();

    if (!status.running) {
      console.error('❌ Server is not running!');
      console.error(`Error: ${status.error}`);
      console.error('\nPlease start the OpenLocalKeys server:');
      console.error('  swift run OpenLocalKeys');
      process.exit(1);
    }

    console.log('✅ Server is running!\n');

    // Step 2: Request API keys
    console.log('Step 2: Requesting API keys...\n');
    console.log('⏳ A popup dialog should appear on your macOS desktop.\n');

    const keys = await client.requestKeys();

    console.log(`\n✅ Successfully received ${keys.length} key(s):\n`);

    // Step 3: Display the keys
    keys.forEach((key: APIKey, index: number) => {
      console.log(`  ${index + 1}. ${key.displayName}`);
      console.log(`     Provider: ${key.provider}`);
      console.log(`     Key: ${maskKey(key.privateKey)}`);

      if (key.customProviderName) {
        console.log(`     Custom Provider: ${key.customProviderName}`);
      }
      if (key.customProviderURL) {
        console.log(`     Custom URL: ${key.customProviderURL}`);
      }
      console.log('');
    });

    // Step 4: Example usage
    if (keys.length > 0) {
      console.log('Step 3: Example usage\n');

      // Find an OpenAI key
      const openaiKey = keys.find(k => k.provider.toLowerCase() === 'openai');

      if (openaiKey) {
        console.log(`Found OpenAI key: ${openaiKey.displayName}`);
        console.log('\nYou can now use it for API calls:');
        console.log(`
  import OpenAI from 'openai';

  const openai = new OpenAI({
    apiKey: '${openaiKey.privateKey}'
  });

  const response = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [{ role: 'user', content: 'Hello!' }]
  });
        `);
      } else {
        console.log('💡 Tip: Add an OpenAI key to see integration examples');
      }
    }

    console.log('==========================================');
    console.log('  Example completed successfully!');
    console.log('==========================================\n');

  } catch (error) {
    if (error instanceof OpenLocalKeysError) {
      console.error('\n❌ Error:', error.message);

      switch (error.code) {
        case ErrorCode.Timeout:
          console.error('\nThe request timed out. This usually means:');
          console.error('  - The user did not respond to the popup dialog');
          console.error('  - The server is not responding');
          break;

        case ErrorCode.ConnectionFailed:
        case ErrorCode.SocketNotFound:
          console.error('\nCannot connect to the server. Make sure:');
          console.error('  - The OpenLocalKeys server is running');
          console.error('  - The socket path is correct');
          break;

        case ErrorCode.InvalidResponse:
          console.error('\nThe server returned an invalid response');
          break;

        default:
          console.error('\nAn unexpected error occurred');
      }
    } else {
      console.error('\n❌ Unexpected error:', error);
    }

    process.exit(1);
  }
}

// Helper function to mask API keys
function maskKey(key: string): string {
  if (key.length <= 8) {
    return '*'.repeat(key.length);
  }
  return `${key.substring(0, 4)}...${key.substring(key.length - 4)}`;
}

// Run the example
main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
