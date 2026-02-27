/**
 * OpenLocalKeys HTTP Client SDK
 *
 * A JavaScript/TypeScript client for the OpenLocalKeys HTTP server.
 * Allows web applications and Node.js scripts to request API keys
 * through the HTTP interface.
 */

class OpenLocalKeysHTTP {
  /**
   * Create a new OpenLocalKeys HTTP client
   * @param {string} baseUrl - Base URL of the OpenLocalKeys server (default: http://localhost:8899)
   * @param {Object} options - Configuration options
   * @param {number} options.timeout - Request timeout in milliseconds (default: 300000 = 5 minutes)
   * @param {number} options.retries - Number of retries on timeout (default: 0)
   * @param {boolean} options.verbose - Enable verbose logging (default: false)
   */
  constructor(baseUrl = 'http://localhost:8899', options = {}) {
    this.baseUrl = baseUrl.replace(/\/$/, ''); // Remove trailing slash
    this.timeout = options.timeout || 300000; // 5 minutes
    this.retries = options.retries !== undefined ? options.retries : 0;
    this.verbose = options.verbose || false;
  }

  /**
   * Request API keys from OpenLocalKeys
   * Shows a popup dialog on macOS for user approval
   * @returns {Promise<Array<Object>>} Array of approved API keys
   *
   * @example
   * const client = new OpenLocalKeysHTTP();
   * const keys = await client.requestKeys();
   * console.log('Received keys:', keys);
   *
   * @example
   * // With timeout
   * const keys = await client.requestKeys(60000); // 60 second timeout
   */
  async requestKeys(timeout) {
    const effectiveTimeout = timeout || this.timeout;
    const url = `${this.baseUrl}/keys`;

    this.log(`Requesting keys from: ${url}`);

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), effectiveTimeout);

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({}),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const keys = await response.json();
      this.log(`Received ${keys.length} key(s)`);

      return keys;
    } catch (error) {
      if (error.name === 'AbortError') {
        throw new Error(`Request timeout after ${effectiveTimeout}ms`);
      }

      // Retry logic
      if (this.retries > 0) {
        this.log(`Request failed, retrying... (${this.retries} attempts left)`);
        this.retries--;
        await this.delay(1000); // Wait 1 second before retry
        return this.requestKeys(timeout);
      }

      throw error;
    }
  }

  /**
   * Check if the OpenLocalKeys server is running
   * @returns {Promise<boolean>} True if server is reachable
   *
   * @example
   * const client = new OpenLocalKeysHTTP();
   * const isRunning = await client.isServerRunning();
   * if (!isRunning) {
   *   console.error('OpenLocalKeys server is not running');
   * }
   */
  async isServerRunning() {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000);

      const response = await fetch(`${this.baseUrl}/keys`, {
        method: 'OPTIONS',
        signal: controller.signal,
      });

      clearTimeout(timeoutId);
      return true;
    } catch (error) {
      this.log(`Server health check failed: ${error.message}`);
      return false;
    }
  }

  /**
   * Get the server status
   * @returns {Promise<Object>} Status information
   *
   * @example
   * const status = await client.getStatus();
   * console.log('Server status:', status);
   */
  async getStatus() {
    const isRunning = await this.isServerRunning();
    return {
      baseUrl: this.baseUrl,
      running: isRunning,
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Set a new timeout for requests
   * @param {number} timeout - Timeout in milliseconds
   */
  setTimeout(timeout) {
    this.timeout = timeout;
  }

  /**
   * Set the number of retries
   * @param {number} retries - Number of retries
   */
  setRetries(retries) {
    this.retries = retries;
  }

  // Private helper methods

  log(message) {
    if (this.verbose) {
      console.log(`[OpenLocalKeysHTTP] ${message}`);
    }
  }

  delay(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

// Export for different module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = OpenLocalKeysHTTP;
}

if (typeof window !== 'undefined') {
  window.OpenLocalKeysHTTP = OpenLocalKeysHTTP;
}

// TypeScript type definitions
/**
 * @typedef {Object} APIKey
 * @property {string} displayName - Display name for the key
 * @property {string} privateKey - The actual API key
 * @property {string} provider - Provider name (e.g., "OpenAI", "Anthropic")
 * @property {string|null} customProviderName - Custom provider name if applicable
 * @property {string|null} customProviderURL - Custom provider URL if applicable
 */

// Example usage:
if (typeof window !== 'undefined') {
  // Browser environment
  window.exampleUsage = async function () {
    const client = new OpenLocalKeysHTTP('http://localhost:8899', {
      timeout: 60000, // 60 seconds
      retries: 2,
      verbose: true
    });

    try {
      // Check if server is running
      if (!(await client.isServerRunning())) {
        console.error('OpenLocalKeys server is not running!');
        return;
      }

      // Request keys
      const keys = await client.requestKeys();
      console.log('Received keys:', keys);

      // Use the keys
      keys.forEach(key => {
        console.log(`${key.displayName}: ${key.provider}`);
      });
    } catch (error) {
      console.error('Failed to get keys:', error.message);
    }
  };
}

// Node.js usage:
if (typeof require !== 'undefined') {
  const OpenLocalKeysHTTP = require('./OpenLocalKeysHTTP.js');

  async function exampleNodeUsage() {
    const client = new OpenLocalKeysHTTP('http://localhost:8899', {
      timeout: 60000,
      verbose: true
    });

    try {
      const keys = await client.requestKeys();
      console.log('Keys:', keys);
    } catch (error) {
      console.error('Error:', error.message);
    }
  }

  // Uncomment to run:
  // exampleNodeUsage();
}
