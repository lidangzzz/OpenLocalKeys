import { Socket } from 'net';

/**
 * Represents an API key from OpenLocalKeys
 */
export interface ApiKey {
  /** Display name for the key */
  displayName: string;
  /** The private API key */
  privateKey: string;
  /** Provider name (e.g., "OpenAI", "Anthropic") */
  provider: string;
  /** Custom provider name (only for custom providers) */
  customProviderName?: string;
  /** Custom provider URL (only for custom providers) */
  customProviderURL?: string;
}

/**
 * Options for requesting keys
 */
export interface RequestOptions {
  /** Socket path (default: $TMPDIR/com.openlocalkeys.sock) */
  socketPath?: string;
  /** Request message to send (default: "REQUEST_KEYS") */
  message?: string;
  /** Timeout in milliseconds (default: 30000) */
  timeout?: number;
}

/**
 * Error thrown when the request fails
 */
export class OpenLocalKeysError extends Error {
  constructor(message: string, public code?: string) {
    super(message);
    this.name = 'OpenLocalKeysError';
  }
}

/**
 * OpenLocalKeys SDK for requesting API keys from the macOS app
 */
export class OpenLocalKeys {
  private readonly defaultSocketPath: string;

  constructor() {
    const tmpdir = process.env.TMPDIR || '/tmp';
    this.defaultSocketPath = tmpdir.endsWith('/')
      ? `${tmpdir}com.openlocalkeys.sock`
      : `${tmpdir}/com.openlocalkeys.sock`;
  }

  /**
   * Request API keys from OpenLocalKeys
   *
   * @example
   * ```typescript
   * const client = new OpenLocalKeys();
   * const keys = await client.requestKeys();
   * console.log(keys);
   * ```
   *
   * @param options - Request options
   * @returns Promise resolving to array of API keys
   * @throws OpenLocalKeysError if request fails
   */
  async requestKeys(options: RequestOptions = {}): Promise<ApiKey[]> {
    const socketPath = options.socketPath || this.defaultSocketPath;
    const message = options.message || 'REQUEST_KEYS';
    const timeout = options.timeout || 30000;

    return new Promise((resolve, reject) => {
      const socket = new Socket();
      let responseData = '';

      // Set timeout
      const timeoutId = setTimeout(() => {
        socket.destroy();
        reject(new OpenLocalKeysError(
          `Request timeout after ${timeout}ms`,
          'TIMEOUT'
        ));
      }, timeout);

      socket.on('connect', () => {
        socket.write(message);
      });

      socket.on('data', (data: Buffer) => {
        responseData += data.toString('utf-8');
      });

      socket.on('end', () => {
        clearTimeout(timeoutId);
        try {
          const keys = JSON.parse(responseData);
          resolve(keys);
        } catch (error) {
          reject(new OpenLocalKeysError(
            `Failed to parse response: ${error}`,
            'PARSE_ERROR'
          ));
        }
      });

      socket.on('error', (error: Error) => {
        clearTimeout(timeoutId);
        reject(new OpenLocalKeysError(
          `Socket error: ${error.message}`,
          'SOCKET_ERROR'
        ));
      });

      // Connect to the socket
      socket.connect(socketPath);
    });
  }

  /**
   * Get the default socket path
   *
   * @returns The default socket path
   */
  getSocketPath(): string {
    return this.defaultSocketPath;
  }

  /**
   * Check if OpenLocalKeys is available
   *
   * @returns Promise resolving to true if socket exists
   */
  async isAvailable(): Promise<boolean> {
    const fs = await import('fs');
    return fs.promises
      .access(this.defaultSocketPath)
      .then(() => true)
      .catch(() => false);
  }
}

/**
 * Convenience function to request keys
 *
 * @example
 * ```typescript
 * import { requestKeys } from 'openlocalkeys';
 *
 * const keys = await requestKeys();
 * console.log(keys);
 * ```
 *
 * @param options - Request options
 * @returns Promise resolving to array of API keys
 */
export async function requestKeys(options?: RequestOptions): Promise<ApiKey[]> {
  const client = new OpenLocalKeys();
  return client.requestKeys(options);
}

// Export default
export default OpenLocalKeys;
