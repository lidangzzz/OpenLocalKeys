/**
 * Express.js server example using OpenLocalKeys HTTP SDK
 *
 * This example shows how to integrate OpenLocalKeys into a Node.js web application
 */

import express, { Request, Response } from 'express';
import { OpenLocalKeys, APIKey } from '../src/index';

const app = express();
const PORT = 3000;

// Initialize OpenLocalKeys client
const olkClient = new OpenLocalKeys({
  baseUrl: 'http://localhost:8899',
  timeout: 60000,
  retries: 2,
  verbose: true
});

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ============================================================================
// Routes
// ============================================================================

/**
 * Health check endpoint
 */
app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'ok',
    service: 'OpenLocalKeys Example Server',
    version: '1.0.0'
  });
});

/**
 * Get API keys from OpenLocalKeys
 *
 * This endpoint requests keys from the OpenLocalKeys HTTP server.
 * A popup dialog will appear on macOS for user approval.
 *
 * POST /api/keys
 *
 * Response:
 * {
 *   "keys": [
 *     {
 *       "displayName": "My OpenAI Key",
 *       "privateKey": "sk-...",
 *       "provider": "OpenAI"
 *     }
 *   ]
 * }
 */
app.post('/api/keys', async (req: Request, res: Response) => {
  try {
    console.log('[/api/keys] Request received');

    // Check if OpenLocalKeys server is running
    const status = await olkClient.getServerStatus();

    if (!status.running) {
      console.error('[/api/keys] OpenLocalKeys server not running');
      return res.status(503).json({
        error: 'OpenLocalKeys server is not running',
        message: 'Please start the OpenLocalKeys HTTP server: swift run OpenLocalKeysHTTP',
        status
      });
    }

    // Request keys from OpenLocalKeys
    const keys = await olkClient.requestKeys({
      timeout: 60000
    });

    console.log(`[/api/keys] Received ${keys.length} key(s)`);

    res.json({
      success: true,
      keys: keys,
      count: keys.length
    });

  } catch (error: any) {
    console.error('[/api/keys] Error:', error.message);

    // Check if it's a timeout error
    if (error.name === 'AbortError' || error.message.includes('timeout')) {
      return res.status(408).json({
        error: 'Request timeout',
        message: 'User did not respond in time or operation timed out'
      });
    }

    res.status(500).json({
      error: 'Failed to request keys',
      message: error.message
    });
  }
});

/**
 * Check OpenLocalKeys server status
 *
 * GET /api/keys/status
 *
 * Response:
 * {
 *   "running": true,
 *   "baseUrl": "http://localhost:8899",
 *   "timestamp": "2024-02-26T..."
 * }
 */
app.get('/api/keys/status', async (_req: Request, res: Response) => {
  try {
    const status = await olkClient.getServerStatus();

    res.json({
      status: status.running ? 'running' : 'not_running',
      ...status
    });

  } catch (error: any) {
    console.error('[/api/keys/status] Error:', error.message);

    res.status(500).json({
      error: 'Failed to check server status',
      message: error.message
    });
  }
});

/**
 * Example: Use the keys to make an API call
 *
 * POST /api/proxy/openai
 *
 * Body:
 * {
 *   "prompt": "Hello, world!",
 *   "model": "gpt-4"
 * }
 */
app.post('/api/proxy/openai', async (req: Request, res: Response) => {
  try {
    const { prompt, model = 'gpt-4' } = req.body;

    console.log('[/api/proxy/openai] Request received');
    console.log('[/api/proxy/openai] Prompt:', prompt);
    console.log('[/api/proxy/openai] Model:', model);

    // Get keys from OpenLocalKeys
    const keys = await olkClient.requestKeys();

    if (keys.length === 0) {
      return res.status(400).json({
        error: 'No API keys available'
      });
    }

    // Find OpenAI key
    const openaiKey = keys.find(k => k.provider.toLowerCase() === 'openai');

    if (!openaiKey) {
      return res.status(400).json({
        error: 'No OpenAI key found'
      });
    }

    console.log('[/api/proxy/openai] Using key:', maskKey(openaiKey.privateKey));

    // Make API call to OpenAI
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openaiKey.privateKey}`
      },
      body: JSON.stringify({
        model: model,
        messages: [
          { role: 'user', content: prompt }
        ]
      })
    });

    if (!openaiResponse.ok) {
      const errorText = await openaiResponse.text();
      console.error('[/api/proxy/openai] OpenAI API error:', errorText);
      return res.status(500).json({
        error: 'OpenAI API error',
        message: errorText
      });
    }

    const openaiData = await openaiResponse.json();

    console.log('[/api/proxy/openai] OpenAI response received');
    console.log('[/api/proxy/openai] Usage:', openaiData.usage);

    res.json({
      success: true,
      response: openaiData,
      keyUsed: openaiKey.displayName
    });

  } catch (error: any) {
    console.error('[/api/proxy/openai] Error:', error.message);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// ============================================================================
// Static Pages
// ============================================================================

app.get('/', (_req: Request, res: Response) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <title>OpenLocalKeys HTTP SDK - Example Server</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                max-width: 800px;
                margin: 0 auto;
                padding: 20px;
                background: #f5f5f5;
            }
            .container {
                background: white;
                border-radius: 8px;
                padding: 30px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                margin-bottom: 20px;
            }
            h1 { color: #333; }
            h2 { color: #555; margin-top: 0; }
            code {
                background: #f4f4f4;
                padding: 2px 6px;
                border-radius: 4px;
                font-family: 'Monaco', 'Courier New', monospace;
                font-size: 13px;
            }
            pre {
                background: #f4f4f4;
                padding: 15px;
                border-radius: 8px;
                overflow-x: auto;
            }
            button {
                background: #007AFF;
                color: white;
                border: none;
                padding: 10px 20px;
                border-radius: 6px;
                cursor: pointer;
                font-size: 14px;
            }
            button:hover {
                background: #0051D5;
            }
            .endpoint {
                margin-bottom: 20px;
            }
            .endpoint h3 {
                font-size: 16px;
                margin: 0 0 10px 0;
            }
            .method {
                display: inline-block;
                background: #007AFF;
                color: white;
                padding: 2px 8px;
                border-radius: 4px;
                font-size: 12px;
                font-weight:  bold;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🔑 OpenLocalKeys HTTP SDK</h1>
            <p>A TypeScript/JavaScript SDK for the OpenLocalKeys HTTP server</p>

            <h2>Available API Endpoints</h2>

            <div class="endpoint">
                <h3>POST /api/keys</h3>
                <p>Request API keys from OpenLocalKeys</p>
                <span class="method">POST</span> <code>/api/keys</code>
            </div>

            <div class="endpoint">
                <h3>GET /api/keys/status</h3>
                <p>Check if OpenLocalKeys server is running</p>
                <span class="method">GET</span> <code>/api/keys/status</code>
            </div>

            <div class="endpoint">
                <h3>POST /api/proxy/openai</h3>
                <p>Proxy request to OpenAI using keys from OpenLocalKeys</p>
                <span class="method">POST</span> <code>/api/proxy/openai</code>
            </div>

            <h2>Example: Request Keys</h2>
            <pre>curl -X POST http://localhost:3000/api/keys -H "Content-Type: application/json"</pre>

            <h2>Example: Check Status</h2>
            <pre>curl http://localhost:3000/api/keys/status</pre>

            <h2>Example: OpenAI Proxy</h2>
            <pre>curl -X POST http://localhost:3000/api/proxy/openai \\
  -H "Content-Type: application/json" \\
  -d '{"prompt": "Hello, world!", "model": "gpt-4"}'</pre>

            <p><em>Make sure the OpenLocalKeys HTTP server is running first: <code>swift run OpenLocalKeysHTTP</code></em></p>
        </div>
    </body>
    </html>
  `);
});

// ============================================================================
// Start Server
// ============================================================================

app.listen(PORT, () => {
  console.log(`\n🚀 Example server running at http://localhost:${PORT}`);
  console.log(`📝 Documentation: http://localhost:${PORT}\n`);
  console.log('⚠️  Make sure OpenLocalKeys HTTP server is running:');
  console.log('   swift run OpenLocalKeysHTTP\n');
});

// Helper function to mask keys
function maskKey(key: string): string {
  if (key.length <= 8) {
    return '*'.repeat(key.length);
  }
  return `${key.substring(0, 4)}***${key.substring(key.length - 4)}`;
}
