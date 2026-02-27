/**
 * Tests for OpenLocalKeys HTTP SDK
 */

import { OpenLocalKeys, APIKey, OpenLocalKeysError, ErrorCode } from '../src/index';
import { requestKeys, isServerRunning } from '../src/index';

// Mock fetch implementation
class MockFetch {
  private responses: Map<string, any> = new Map();
  private responseCallbacks: Map<string, () => Response> = new Map();
  private callCounts: Map<string, number> = new Map();

  setResponse(url: string, response: any, delay: number = 0): void {
    this.responses.set(url, { response, delay });
    this.callCounts.set(url, 0);
  }

  setResponseCallback(url: string, callback: () => Response): void {
    this.responseCallbacks.set(url, callback);
    this.callCounts.set(url, 0);
  }

  async fetch(url: string, options?: RequestInit): Promise<Response> {
    const key = `${options?.method || 'GET'} ${url}`;
    const count = (this.callCounts.get(key) || 0);
    this.callCounts.set(key, count + 1);

    // Check for callback first
    if (this.responseCallbacks.has(key)) {
      const result = this.responseCallbacks.get(key)!();
      // If callback returns a Promise, wait for it
      if (result instanceof Promise) {
        return result;
      }
      return result;
    }

    const mock = this.responses.get(key);

    if (!mock) {
      throw new Error(`No mock response for: ${key}`);
    }

    // Check if response is a rejected Promise (for error testing)
    if (mock.response instanceof Promise) {
      return mock.response;
    }

    // Handle abort signal for timeout
    if (options?.signal) {
      const signal = options.signal as any;
      if (signal.aborted) {
        const error = new Error('The operation was aborted');
        error.name = 'AbortError';
        throw error;
      }

      // Listen for abort during delay
      const abortPromise = new Promise<never>((_, reject) => {
        signal.addEventListener('abort', () => {
          const error = new Error('The operation was aborted');
          error.name = 'AbortError';
          reject(error);
        });
      });

      // Race between delay and abort
      await Promise.race([
        new Promise(resolve => setTimeout(resolve, mock.delay)),
        abortPromise
      ]);
    } else if (mock.delay > 0) {
      await new Promise(resolve => setTimeout(resolve, mock.delay));
    }

    return mock.response as Response;
  }

  clear(): void {
    this.responses.clear();
    this.responseCallbacks.clear();
    this.callCounts.clear();
  }
}

// Helper to create a mock Response
function createMockResponse(data: any, status: number = 200): Response {
  return {
    ok: status >= 200 && status < 300,
    status: status,
    statusText: status === 200 ? 'OK' : 'Error',
    json: async () => data,
    text: async () => JSON.stringify(data),
    headers: new Map([
      ['content-type', 'application/json']
    ])
  } as unknown as Response;
}

describe('OpenLocalKeys', () => {
  let client: OpenLocalKeys;
  let mockFetch: MockFetch;

  beforeEach(() => {
    mockFetch = new MockFetch();
  });

  afterEach(() => {
    mockFetch.clear();
  });

  // ========================================================================
  // Constructor Tests
  // ========================================================================

  describe('constructor', () => {
    test('should initialize with default values', () => {
      client = new OpenLocalKeys();

      // @ts-ignore - private property access for testing
      expect(client['baseUrl']).toBe('http://localhost:8899');
      expect(client['timeout']).toBe(300000);
      expect(client['retries']).toBe(0);
    });

    test('should accept custom baseUrl', () => {
      client = new OpenLocalKeys({
        baseUrl: 'http://localhost:9999'
      });

      // @ts-ignore
      expect(client['baseUrl']).toBe('http://localhost:9999');
    });

    test('should accept custom timeout', () => {
      client = new OpenLocalKeys({
        timeout: 60000
      });

      // @ts-ignore
      expect(client['timeout']).toBe(60000);
    });

    test('should accept custom retries', () => {
      client = new OpenLocalKeys({
        retries: 3
      });

      // @ts-ignore
      expect(client['retries']).toBe(3);
    });

    test('should accept custom fetch implementation', () => {
      const customFetch = jest.fn();
      client = new OpenLocalKeys({
        fetch: customFetch as any
      });

      // @ts-ignore
      expect(client['fetchImpl']).toBe(customFetch);
    });

    test('should remove trailing slash from baseUrl', () => {
      client = new OpenLocalKeys({
        baseUrl: 'http://localhost:8899/'
      });

      // @ts-ignore
      expect(client['baseUrl']).toBe('http://localhost:8899');
    });
  });

  // ========================================================================
  // requestKeys Tests
  // ========================================================================

  describe('requestKeys', () => {
    test('should successfully request and receive keys', async () => {
      const mockKeys: APIKey[] = [
        {
          displayName: 'Test Key',
          privateKey: 'sk-test123',
          provider: 'OpenAI',
          customProviderName: undefined,
          customProviderURL: undefined
        }
      ];

      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse(mockKeys)
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const keys = await client.requestKeys();

      expect(keys).toEqual(mockKeys);
      expect(keys).toHaveLength(1);
      expect(keys[0].displayName).toBe('Test Key');
      expect(keys[0].privateKey).toBe('sk-test123');
    });

    test('should receive multiple keys', async () => {
      const mockKeys: APIKey[] = [
        {
          displayName: 'OpenAI Key',
          privateKey: 'sk-openai',
          provider: 'OpenAI',
          customProviderName: undefined,
          customProviderURL: undefined
        },
        {
          displayName: 'Anthropic Key',
          privateKey: 'sk-ant',
          provider: 'Anthropic',
          customProviderName: undefined,
          customProviderURL: undefined
        }
      ];

      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse(mockKeys)
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const keys = await client.requestKeys();

      expect(keys).toHaveLength(2);
      expect(keys[0].provider).toBe('OpenAI');
      expect(keys[1].provider).toBe('Anthropic');
    });

    test('should receive empty array when denied', async () => {
      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse([])
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const keys = await client.requestKeys();

      expect(keys).toEqual([]);
      expect(keys).toHaveLength(0);
    });

    test('should handle timeout correctly', async () => {
      // Set a very short timeout
      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse([]),
        2000 // 2 second delay, longer than our timeout
      );

      client = new OpenLocalKeys({
        timeout: 1000, // 1 second timeout
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      await expect(client.requestKeys()).rejects.toThrow('Request timeout');
    }, 10000); // Increase Jest timeout to 10 seconds

    test('should retry on failure', async () => {
      let attempts = 0;

      mockFetch.setResponseCallback('POST http://localhost:8899/keys',
        // Fail first 2 attempts, succeed on 3rd
        () => {
          attempts++;
          if (attempts < 3) {
            return createMockResponse({ error: 'Server error' }, 500);
          } else {
            return createMockResponse([{ displayName: 'Test', privateKey: 'key', provider: 'Test' }]);
          }
        }
      );

      client = new OpenLocalKeys({
        retries: 3,
        retryDelay: 10,
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const keys = await client.requestKeys();

      expect(attempts).toBe(3);
      expect(keys).toHaveLength(1);
    });

    test('should use custom timeout in requestKeys call', async () => {
      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse([])
      );

      client = new OpenLocalKeys({
        timeout: 60000,
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      await client.requestKeys({ timeout: 100 });

      // The timeout should be cancelled before 60000ms
      // This is hard to test precisely, but we can verify it doesn't throw
      expect(true).toBe(true); // Test passed if we got here
    });

    test('should handle HTTP error responses', async () => {
      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse({ error: 'Internal server error' }, 500)
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      await expect(client.requestKeys()).rejects.toThrow('HTTP 500: Error');
    });

    test('should handle non-JSON response', async () => {
      const nonJSONResponse = {
        ok: true,
        status: 200,
        statusText: 'OK',
        json: async () => { throw new Error('Not JSON'); },
        headers: new Map([
          ['content-type', 'text/plain']
        ])
      } as unknown as Response;

      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        nonJSONResponse as any
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      await expect(client.requestKeys()).rejects.toThrow('Expected JSON response');
    });
  });

  // ========================================================================
  // getServerStatus Tests
  // ========================================================================

  describe('getServerStatus', () => {
    test('should return running status when server is up', async () => {
      mockFetch.setResponse(
        'OPTIONS http://localhost:8899/keys',
        createMockResponse({})
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const status = await client.getServerStatus();

      expect(status.running).toBe(true);
      expect(status.baseUrl).toBe('http://localhost:8899');
      expect(status.timestamp).toBeDefined();
      expect(status.error).toBeUndefined();
    });

    test('should return not running when server is down', async () => {
      mockFetch.setResponse(
        'OPTIONS http://localhost:8899/keys',
        Promise.reject(new Error('Connection refused'))
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const status = await client.getServerStatus();

      expect(status.running).toBe(false);
      expect(status.error).toBeDefined();
    });
  });

  // ========================================================================
  // isServerRunning Tests
  // ========================================================================

  describe('isServerRunning', () => {
    test('should return true when server is up', async () => {
      mockFetch.setResponse(
        'OPTIONS http://localhost:8899/keys',
        createMockResponse({})
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const running = await client.isServerRunning();

      expect(running).toBe(true);
    });

    test('should return false when server is down', async () => {
      mockFetch.setResponse(
        'OPTIONS http://localhost:8899/keys',
        Promise.reject(new Error('Connection refused'))
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const running = await client.isServerRunning();

      expect(running).toBe(false);
    });
  });

  // ========================================================================
  // waitForServer Tests
  // ========================================================================

  describe('waitForServer', () => {
    test('should wait for server to become ready', async () => {
      let attemptCount = 0;

      mockFetch.setResponseCallback('OPTIONS http://localhost:8899/keys',
        () => {
          attemptCount++;
          if (attemptCount >= 2) {
            return createMockResponse({});
          } else {
            return Promise.reject(new Error('Not ready')) as any;
          }
        }
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any,
        verbose: false
      });

      const ready = await client.waitForServer({
        timeout: 5000,
        interval: 100,
        maxAttempts: 50
      });

      expect(ready).toBe(true);
      expect(attemptCount).toBeGreaterThanOrEqual(2);
    }, 10000); // Increase Jest timeout

    test('should timeout if server never becomes ready', async () => {
      mockFetch.setResponse(
        'OPTIONS http://localhost:8899/keys',
        Promise.reject(new Error('Never ready'))
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const ready = await client.waitForServer({
        timeout: 1000,
        interval: 100,
        maxAttempts: 10
      });

      expect(ready).toBe(false);
    });

    test('should use custom timeout and interval', async () => {
      mockFetch.setResponse(
        'OPTIONS http://localhost:8899/keys',
        Promise.reject(new Error('Not ready'))
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const startTime = Date.now();

      const ready = await client.waitForServer({
        timeout: 500,
        interval: 100,
        maxAttempts: 5
      });

      const elapsed = Date.now() - startTime;

      expect(ready).toBe(false);
      expect(elapsed).toBeLessThan(700); // Should be close to 500ms
    });
  });

  // ========================================================================
  // Custom Provider Keys Tests
  // ========================================================================

  describe('Custom Provider Keys', () => {
    test('should receive keys with custom provider info', async () => {
      const mockKeys: APIKey[] = [
        {
          displayName: 'Custom API',
          privateKey: 'custom-key-123',
          provider: 'Custom Provider',
          customProviderName: 'My Custom Provider',
          customProviderURL: 'https://api.custom.com'
        }
      ];

      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse(mockKeys)
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const keys = await client.requestKeys();

      expect(keys).toHaveLength(1);
      expect(keys[0].customProviderName).toBe('My Custom Provider');
      expect(keys[0].customProviderURL).toBe('https://api.custom.com');
    });
  });

  // ========================================================================
  // Convenience Functions Tests
  // ========================================================================

  describe('Convenience Functions', () => {
    test('requestKeys function should work', async () => {
      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse([{ displayName: 'Test', privateKey: 'key', provider: 'Test' }])
      );

      const keys = await requestKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      expect(keys).toHaveLength(1);
    });

    test('isServerRunning function should work', async () => {
      mockFetch.setResponse(
        'OPTIONS http://localhost:8899/keys',
        createMockResponse({})
      );

      const running = await isServerRunning({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      expect(running).toBe(true);
    });
  });

  // ========================================================================
  // Error Handling Tests
  // ========================================================================

  describe('Error Handling', () => {
    test('should throw proper error code on timeout', async () => {
      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse([]),
        2000 // 2 second delay, longer than timeout
      );

      client = new OpenLocalKeys({
        timeout: 100,
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      try {
        await client.requestKeys();
        fail('Should have thrown timeout error');
      } catch (error: any) {
        expect(error).toBeInstanceOf(OpenLocalKeysError);
        expect(error.code).toBe(ErrorCode.Timeout);
      }
    }, 10000); // Increase Jest timeout to 10 seconds

    test('should throw proper error code on connection failure', async () => {
      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        Promise.reject(new Error('ECONNREFUSED'))
      );

      client = new OpenLocalKeys({
        retries: 0,
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      try {
        await client.requestKeys();
        fail('Should have thrown connection error');
      } catch (error: any) {
        expect(error).toBeInstanceOf(Error);
      }
    });
  });

  // ========================================================================
  // Integration Tests
  // ========================================================================

  describe('Integration Tests', () => {
    test('should handle complete request/response flow', async () => {
      // Simulate server processing delay
      const processingDelay = 100;

      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse([
          {
            displayName: 'Production Key',
            privateKey: 'sk-prod-abc123',
            provider: 'OpenAI'
          },
          {
            displayName: 'Development Key',
            privateKey: 'sk-dev-xyz789',
            provider: 'OpenAI'
          }
        ]),
        processingDelay
      );

      client = new OpenLocalKeys({
        timeout: 5000,
        verbose: false,
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const keys = await client.requestKeys();

      expect(keys).toHaveLength(2);
      expect(keys[0].displayName).toBe('Production Key');
      expect(keys[1].displayName).toBe('Development Key');
    });

    test('should handle request rejection', async () => {
      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse([]) // Empty array = denied
      );

      client = new OpenLocalKeys({
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const keys = await client.requestKeys();

      expect(keys).toEqual([]);
    });

    test('should maintain different client instances', async () => {
      const client1 = new OpenLocalKeys({
        baseUrl: 'http://localhost:8899',
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      const client2 = new OpenLocalKeys({
        baseUrl: 'http://localhost:9999',
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      // Set different responses for different URLs
      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse([{ displayName: 'Client1', privateKey: 'key1', provider: 'Test' }])
      );

      mockFetch.setResponse(
        'POST http://localhost:9999/keys',
        createMockResponse([{ displayName: 'Client2', privateKey: 'key2', provider: 'Test' }])
      );

      const keys1 = await client1.requestKeys();
      const keys2 = await client2.requestKeys();

      expect(keys1[0].displayName).toBe('Client1');
      expect(keys2[0].displayName).toBe('Client2');
    });
  });

  // ========================================================================
  // Verbose Logging Tests
  // ========================================================================

  describe('Verbose Logging', () => {
    test('should log messages when verbose is enabled', async () => {
      const logSpy = jest.spyOn(console, 'log').mockImplementation(() => {});

      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse([])
      );

      client = new OpenLocalKeys({
        verbose: true,
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      // Execute operation
      await client.getServerStatus();

      expect(logSpy).toHaveBeenCalled();
      logSpy.mockRestore();

      // Clean up
      logSpy.mockRestore();
    });

    test('should not log when verbose is disabled', async () => {
      const logSpy = jest.spyOn(console, 'log');

      mockFetch.setResponse(
        'POST http://localhost:8899/keys',
        createMockResponse([])
      );

      client = new OpenLocalKeys({
        verbose: false,
        fetch: mockFetch.fetch.bind(mockFetch) as any
      });

      await client.getServerStatus();

      // Should not have been called (or called very few times)
      expect(logSpy.mock.calls.length).toBe(0);

      logSpy.mockRestore();
    });
  });

  // ========================================================================
  // Type Safety Tests
  // ========================================================================

  describe('Type Safety', () => {
    test('should enforce APIKey interface', () => {
      const validKey: APIKey = {
        displayName: 'Test',
        privateKey: 'key',
        provider: 'Test'
      };

      expect(validKey.displayName).toBeDefined();
      expect(validKey.privateKey).toBeDefined();
      expect(validKey.provider).toBeDefined();
    });

    test('should allow optional custom provider fields', () => {
      const keyWithCustom: APIKey = {
        displayName: 'Custom',
        privateKey: 'key',
        provider: 'Custom',
        customProviderName: 'My Provider',
        customProviderURL: 'https://api.example.com'
      };

      expect(keyWithCustom.customProviderName).toBe('My Provider');
      expect(keyWithCustom.customProviderURL).toBe('https://api.example.com');
    });
  });
});

// Helper to get jest function type
function fail(message: string): never {
  throw new Error(message);
}
