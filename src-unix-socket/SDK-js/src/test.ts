import { OpenLocalKeys, requestKeys } from './index';

async function main() {
  const client = new OpenLocalKeys();

  console.log('Socket path:', client.getSocketPath());

  console.log('Checking if OpenLocalKeys is available...');
  const isAvailable = await client.isAvailable();
  console.log('Available:', isAvailable);

  if (!isAvailable) {
    console.error('OpenLocalKeys is not available. Please make sure the app is running.');
    return;
  }

  console.log('\nRequesting keys...');
  try {
    const keys = await client.requestKeys();
    console.log(`\nReceived ${keys.length} key(s):\n`);

    for (const key of keys) {
      console.log(`Name: ${key.displayName}`);
      console.log(`Provider: ${key.provider}`);
      console.log(`Key: ${key.privateKey.substring(0, 10)}...`);
      if (key.customProviderName) {
        console.log(`Custom Provider: ${key.customProviderName}`);
        console.log(`Custom URL: ${key.customProviderURL}`);
      }
      console.log('---');
    }
  } catch (error) {
    console.error('Error:', error);
  }
}

// Run the test
main().catch(console.error);
