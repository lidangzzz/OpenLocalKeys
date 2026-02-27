/**
 * OpenLocalKeys Unix Socket SDK
 *
 * A TypeScript/JavaScript SDK for communicating with the OpenLocalKeys Unix socket server.
 * This SDK allows Node.js applications to request API keys through Unix domain sockets.
 *
 * @example
 * ```typescript
 * import { OpenLocalKeys } from 'openlocalkeys-socket-sdk';
 *
 * const client = new OpenLocalKeys({
 *   socketPath: '/tmp/com.openlocalkeys.sock',
 *   timeout: 60000
 * });
 *
 * const keys = await client.requestKeys();
 * console.log('Received keys:', keys);
 * ```
 */

import { Socket } from 'net';
import { existsSync } from 'fs';
import { promisify } from 'util';

// ============================================================================
// Types
// ============================================================================

/**
 * Represents an API key returned from the OpenLocalKeys server
 */
export interface APIKey {
  /** Display name for the API key */
  displayName: string;

  /** The actual API key value */
  privateKey: string;

  /** Provider name (e.g., "OpenAI", "Anthropic") */
  provider: string;

  /** Custom provider name if applicable */
  customProviderName?: string;

  /** Custom provider URL if applicable */
  customProviderURL?: string;
}

/**
 * Configuration options for the OpenLocalKeys socket client
 */
export interface OpenLocalKeysOptions {
  /** Path to the Unix domain socket (default: /tmp/com.openlocalkeys.sock) */
  socketPath?: string;

  /** Request timeout in milliseconds (default: 300000 = 5 minutes) */
  timeout?: number;

  /** Number of retries on timeout or error (default: 0) */
  retries?: number;

  /** Retry delay in milliseconds (default: 1000) */
  retryDelay?: number;

  /** Enable verbose logging (default: false) */
  verbose?: boolean;
}

/**
 * Status information about the OpenLocalKeys socket server
 */
export interface ServerStatus {
  /** Socket path being used */
  socketPath: string;

  /** Whether the server socket exists and is accessible */
  running: boolean;

  /** Timestamp of the status check */
  timestamp: string;

  /** Error message if server is not running */
  error?: string;
}

/**
 * Error codes for OpenLocalKeys errors
 */
export enum ErrorCode {
  ConnectionFailed = 'CONNECTION_FAILED',
  Timeout = 'TIMEOUT',
  InvalidResponse = 'INVALID_RESPONSE',
  ServerError = 'SERVER_ERROR',
  RequestCancelled = 'REQUEST_CANCELLED',
  SocketNotFound = 'SOCKET_NOT_FOUND'
}

/**
 * Custom error class for OpenLocalKeys errors
 */
export class OpenLocalKeysError extends Error {
  constructor(
    public code: ErrorCode,
    message: string,
    public originalError?: Error
  ) {
    super(message);
    this.name = 'OpenLocalKeysError';
  }
}

// ============================================================================
// Main Client Class
// ============================================================================

/**
 * Main client class for interacting with OpenLocalKeys Unix socket server
 */
export class OpenLocalKeys {
  private readonly socketPath: string;
  private readonly timeout: number;
  private readonly retries: number;
  private readonly retryDelay: number;
  private readonly verbose: boolean;

  /**
   * Create a new OpenLocalKeys socket client
   *
   * @param options - Configuration options
   *
   * @example
   * ```typescript
   * const client = new OpenLocalKeys({
   *   socketPath: '/tmp/com.openlocalkeys.sock',
   *   timeout: 60000,
   *   verbose: true
   * });
   * ```
   */
  constructor(options: OpenLocalKeysOptions = {}) {
    this.socketPath = options.socketPath || '/tmp/com.openlocalkeys.sock';
    this.timeout = options.timeout || 300000; // 5 minutes default
    this.retries = options.retries !== undefined ? options.retries : 0;
    this.retryDelay = options.retryDelay || 1000;
    this.verbose = options.verbose || false;

    this.log(`OpenLocalKeys client initialized with socketPath: ${this.socketPath}`);
  }

  // ========================================================================
  // Public Methods
  // ========================================================================

  /**
   * Request API keys from the OpenLocalKeys server
   *
   * Shows a popup dialog on macOS for user approval.
   *
   * @param options - Optional request options
   * @returns Promise resolving to array of approved API keys
   *
   * @throws {OpenLocalKeysError} If request fails or times out
   *
   * @example
   * ```typescript
   * const keys = await client.requestKeys();
   * console.log(`Received ${keys.length} keys`);
   *
   * // With custom timeout
   * const keys = await client.requestKeys({ timeout: 30000 });
   * ```
   */
  async requestKeys(options?: { timeout?: number }): Promise<APIKey[]> {
    const effectiveTimeout = options?.timeout ?? this.timeout;

    this.log(`Requesting keys from socket: ${this.socketPath}`);
    this.log(`Timeout: ${effectiveTimeout}ms, Retries: ${this.retries}`);

    return this.withRetry(async () => {
      return this.sendMessageWithTimeout('{}', effectiveTimeout);
    });
  }

  /**
   * Check if the OpenLocalKeys socket server is running and accessible
   *
   * @returns Promise resolving to server status
   *
   * @example
   * ```typescript
   * const status = await client.getServerStatus();
   * if (status.running) {
   *   console.log('Server is running');
   * } else {
   *   console.error('Server not available:', status.error);
   * }
   * ```
   */
  async getServerStatus(): Promise<ServerStatus> {
    this.log('Checking server status...');

    // Check if socket file exists
    if (!existsSync(this.socketPath)) {
      return {
        socketPath: this.socketPath,
        running: false,
        timestamp: new Date().toISOString(),
        error: 'Socket file does not exist'
      };
    }

    // Try to connect to verify server is listening (without sending request)
    try {
      await this.canConnectToSocket();
      return {
        socketPath: this.socketPath,
        running: true,
        timestamp: new Date().toISOString()
      };
    } catch (error: any) {
      return {
        socketPath: this.socketPath,
        running: false,
        timestamp: new Date().toISOString(),
        error: error.message || 'Connection failed'
      };
    }
  }

  /**
   * Check if the server is running (simplified version)
   *
   * @returns Promise resolving to true if server is running
   *
   * @example
   * ```typescript
   * if (await client.isServerRunning()) {
   *   console.log('Server is ready');
   * }
   * ```
   */
  async isServerRunning(): Promise<boolean> {
    const status = await this.getServerStatus();
    return status.running;
  }

  /**
   * Wait for the server to be ready
   *
   * @param options - Wait options
   * @returns Promise resolving to true if server is ready
   *
   * @example
   * ```typescript
   * const ready = await client.waitForServer({ timeout: 30000 });
   * if (ready) {
   *   console.log('Server is ready!');
   * }
   * ```
   */
  async waitForServer(options?: {
    timeout?: number;
    interval?: number;
    maxAttempts?: number
  }): Promise<boolean> {
    const timeout = options?.timeout ?? 30000;
    const interval = options?.interval ?? 1000;
    const maxAttempts = options?.maxAttempts ?? (timeout / interval);

    this.log(`Waiting for server (timeout: ${timeout}ms, interval: ${interval}ms)`);

    const startTime = Date.now();
    let attempts = 0;

    while (attempts < maxAttempts) {
      const status = await this.getServerStatus();
      if (status.running) {
        this.log('Server is ready!');
        return true;
      }

      if (Date.now() - startTime > timeout) {
        this.log('Wait timeout');
        return false;
      }

      attempts++;
      this.log(`Attempt ${attempts}/${maxAttempts} - Server not ready, waiting...`);
      await this.delay(interval);
    }

    return false;
  }

  // ========================================================================
  // Private Methods
  // ========================================================================

  /**
   * Check if we can connect to the socket (without sending a request)
   * This is used for server status checks to avoid triggering the dialog
   */
  private canConnectToSocket(): Promise<void> {
    return new Promise((resolve, reject) => {
      const socket = new Socket();
      let resolved = false;

      // Short timeout for connection test
      const timeoutId = setTimeout(() => {
        if (!resolved) {
          resolved = true;
          socket.destroy();
          reject(new Error('Connection timeout'));
        }
      }, 500);

      socket.on('connect', () => {
        if (!resolved) {
          resolved = true;
          clearTimeout(timeoutId);
          socket.destroy(); // Close immediately after connecting
          resolve();
        }
      });

      socket.on('error', (error) => {
        if (!resolved) {
          resolved = true;
          clearTimeout(timeoutId);
          reject(error);
        }
      });

      socket.on('close', () => {
        if (!resolved) {
          resolved = true;
          clearTimeout(timeoutId);
          reject(new Error('Connection closed'));
        }
      });

      // Attempt to connect
      socket.connect(this.socketPath);
    });
  }

  /**
   * Send a message to the socket server and wait for response
   */
  private sendMessageWithTimeout(
    message: string,
    timeout: number,
    silent = false
  ): Promise<APIKey[]> {
    return new Promise((resolve, reject) => {
      const socket = new Socket();
      let responseData = '';
      let timeoutId: NodeJS.Timeout;

      // Set timeout
      timeoutId = setTimeout(() => {
        if (!silent) this.log(`Request timeout after ${timeout}ms`);
        socket.destroy();
        reject(new OpenLocalKeysError(
          ErrorCode.Timeout,
          `Request timeout after ${timeout}ms`
        ));
      }, timeout);

      // Handle connection errors
      socket.on('error', (error) => {
        clearTimeout(timeoutId);
        if (!silent) this.log(`Socket error: ${error.message}`);
        reject(new OpenLocalKeysError(
          ErrorCode.ConnectionFailed,
          `Failed to connect to socket: ${error.message}`,
          error
        ));
      });

      // Handle incoming data
      socket.on('data', (data) => {
        responseData += data.toString();

        // Try to parse complete JSON response
        try {
          const keys = JSON.parse(responseData) as APIKey[];
          clearTimeout(timeoutId);
          socket.destroy();
          if (!silent) this.log(`Received ${keys.length} key(s)`);
          resolve(keys);
        } catch {
          // Response incomplete, wait for more data
        }
      });

      // Handle connection close
      socket.on('close', () => {
        clearTimeout(timeoutId);

        // If we have data, try to parse it
        if (responseData.trim().length > 0) {
          try {
            const keys = JSON.parse(responseData) as APIKey[];
            if (!silent) this.log(`Received ${keys.length} key(s)`);
            resolve(keys);
          } catch (error) {
            reject(new OpenLocalKeysError(
              ErrorCode.InvalidResponse,
              `Failed to parse response: ${responseData}`,
              error as Error
            ));
          }
        } else {
          reject(new OpenLocalKeysError(
            ErrorCode.ConnectionFailed,
            'Connection closed without response'
          ));
        }
      });

      // Connect to the socket
      if (!silent) this.log(`Connecting to ${this.socketPath}...`);
      socket.connect(this.socketPath);

      // Send the message once connected
      socket.on('connect', () => {
        if (!silent) this.log('Connected, sending request...');
        socket.write(message);
      });
    });
  }

  /**
   * Execute a function with retry logic
   */
  private async withRetry<T>(fn: () => Promise<T>): Promise<T> {
    let lastError: Error;

    for (let attempt = 0; attempt <= this.retries; attempt++) {
      try {
        return await fn();
      } catch (error: any) {
        lastError = error;

        if (attempt < this.retries) {
          this.log(`Attempt ${attempt + 1} failed, retrying... (${this.retries - attempt} attempts left)`);
          this.log(`Error: ${error.message}`);
          await this.delay(this.retryDelay);
        }
      }
    }

    throw lastError!;
  }

  /**
   * Delay execution for a specified number of milliseconds
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Log a message if verbose mode is enabled
   */
  private log(message: string): void {
    if (this.verbose) {
      console.log(`[OpenLocalKeys] ${message}`);
    }
  }
}

// ============================================================================
// Convenience Functions
// ============================================================================

/**
 * Quickly request API keys with default settings
 *
 * @param options - Optional configuration
 * @returns Promise resolving to array of API keys
 *
 * @example
 * ```typescript
 * import { requestKeys } from 'openlocalkeys-socket-sdk';
 *
 * const keys = await requestKeys({ verbose: true });
 * ```
 */
export async function requestKeys(options?: OpenLocalKeysOptions): Promise<APIKey[]> {
  const client = new OpenLocalKeys(options);
  return client.requestKeys();
}

/**
 * Check if the OpenLocalKeys server is running
 *
 * @param options - Optional configuration
 * @returns Promise resolving to true if server is running
 *
 * @example
 * ```typescript
 * import { isServerRunning } from 'openlocalkeys-socket-sdk';
 *
 * if (await isServerRunning()) {
 *   console.log('Ready!');
 * }
 * ```
 */
export async function isServerRunning(options?: OpenLocalKeysOptions): Promise<boolean> {
  const client = new OpenLocalKeys(options);
  return client.isServerRunning();
}

// ============================================================================
// Node.js Export
// ============================================================================

export default OpenLocalKeys;
