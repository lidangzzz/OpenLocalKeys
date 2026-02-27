/**
 * OpenLocalKeys HTTP SDK
 *
 * A TypeScript/JavaScript SDK for communicating with the OpenLocalKeys HTTP server.
 * This SDK allows Node.js applications and web applications to request API keys
 * through the HTTP interface.
 *
 * @example
 * ```typescript
 * import { OpenLocalKeys } from 'openlocalkeys-http-sdk';
 *
 * const client = new OpenLocalKeys({
 *   baseUrl: 'http://localhost:8899',
 *   timeout: 60000
 * });
 *
 * const keys = await client.requestKeys();
 * console.log('Received keys:', keys);
 * ```
 */

// TypeScript/JavaScript SDK for OpenLocalKeys HTTP Server

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
 * Configuration options for the OpenLocalKeys client
 */
export interface OpenLocalKeysOptions {
  /** Base URL of the OpenLocalKeys HTTP server (default: http://localhost:8899) */
  baseUrl?: string;

  /** Request timeout in milliseconds (default: 300000 = 5 minutes) */
  timeout?: number;

  /** Number of retries on timeout or error (default: 0) */
  retries?: number;

  /** Retry delay in milliseconds (default: 1000) */
  retryDelay?: number;

  /** Enable verbose logging (default: false) */
  verbose?: boolean;

  /** Custom fetch implementation (for testing or custom HTTP clients) */
  fetch?: typeof fetch;
}

/**
 * Status information about the OpenLocalKeys server
 */
export interface ServerStatus {
  /** Base URL being used */
  baseUrl: string;

  /** Whether the server is running and accessible */
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
  RequestCancelled = 'REQUEST_CANCELLED'
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
 * Main client class for interacting with OpenLocalKeys HTTP server
 */
export class OpenLocalKeys {
  private readonly baseUrl: string;
  private readonly timeout: number;
  private readonly retries: number;
  private readonly retryDelay: number;
  private readonly verbose: boolean;
  private readonly fetchImpl: typeof fetch;

  /**
   * Create a new OpenLocalKeys client
   *
   * @param options - Configuration options
   *
   * @example
   * ```typescript
   * const client = new OpenLocalKeys({
   *   baseUrl: 'http://localhost:8899',
   *   timeout: 60000,
   *   verbose: true
   * });
   * ```
   */
  constructor(options: OpenLocalKeysOptions = {}) {
    this.baseUrl = (options.baseUrl || 'http://localhost:8899').replace(/\/$/, '');
    this.timeout = options.timeout || 300000; // 5 minutes default
    this.retries = options.retries !== undefined ? options.retries : 0;
    this.retryDelay = options.retryDelay || 1000;
    this.verbose = options.verbose || false;
    this.fetchImpl = options.fetch || fetch;

    this.log(`OpenLocalKeys client initialized with baseUrl: ${this.baseUrl}`);
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
    const url = `${this.baseUrl}/keys`;

    this.log(`Requesting keys from: ${url}`);
    this.log(`Timeout: ${effectiveTimeout}ms, Retries: ${this.retries}`);

    return this.withRetry(async () => {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), effectiveTimeout);

      try {
        const response = await this.fetchImpl(url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: JSON.stringify({}),
          signal: controller.signal
        });

        clearTimeout(timeoutId);

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const contentType = response.headers.get('content-type');
        if (!contentType?.includes('application/json')) {
          throw new OpenLocalKeysError(
            ErrorCode.InvalidResponse,
            `Expected JSON response, got ${contentType}`
          );
        }

        const keys = (await response.json()) as APIKey[];
        this.log(`Received ${keys.length} key(s)`);

        return keys;
      } catch (error: any) {
        clearTimeout(timeoutId);

        if (error.name === 'AbortError') {
          throw new OpenLocalKeysError(
            ErrorCode.Timeout,
            `Request timeout after ${effectiveTimeout}ms`
          );
        }

        throw error;
      }
    });
  }

  /**
   * Check if the OpenLocalKeys server is running and accessible
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

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000);

      await this.fetchImpl(`${this.baseUrl}/keys`, {
        method: 'OPTIONS',
        signal: controller.signal
      });

      clearTimeout(timeoutId);

      return {
        baseUrl: this.baseUrl,
        running: true,
        timestamp: new Date().toISOString()
      };
    } catch (error: any) {
      return {
        baseUrl: this.baseUrl,
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

    // At this point, lastError is guaranteed to be assigned since the loop ran at least once
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
 * import { requestKeys } from 'openlocalkeys-http-sdk';
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
 * import { isServerRunning } from 'openlocalkeys-http-sdk';
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
