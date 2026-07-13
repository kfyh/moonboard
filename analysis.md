### Key Hypotheses (Why the Server Fails on Raspberry Pi)

#### 1. Outdated dependencies / Missing `npm install` on the Pi (Highly Likely)
* **The Issue:** Your updated code uses Express 5.x routing features (like the new `'/*splat'` wildcard syntax). Express 5 has a new routing parser (`path-to-regexp` v8).
* **The Root Cause:** The `update.sh` script copies only `dist/` and `package.json` to the target `/home/moonboard_web`, but **does not run `npm install`** on the Pi. The `deploy_ssh.sh` script does not bundle `node_modules` because of `nodeExternals()` in your Webpack configuration.
* **Result:** The Raspberry Pi's `node_modules` directory still contains Express 4. When your Webpack-compiled code runs on the Pi, it tries to load Express 4, which fails to parse the Express 5 route syntax or behaves unexpectedly, causing the server to crash.

#### 2. Brittle Relative Paths (`__dirname` Mismatches)
* **The Issue:** In `index.ts`, paths are resolved relative to `__dirname`:
  * `GRID_CONFIG_FILE = path.resolve(__dirname, '../../dist/grid_config.json')`
  * `LED_MAPPINGS_FILE = path.resolve(__dirname, '../../../src/led/led_mapping.json')`
* **The Root Cause:** On the Pi, the directory structure in `/home/moonboard_web` is:
  * `/home/moonboard_web/api/index.js`
  * `/home/moonboard_web/ui/index.html`
* **Result:** 
  * `GRID_CONFIG_FILE` resolves to `/home/dist/grid_config.json` (which does not exist and is write-protected).
  * `LED_MAPPINGS_FILE` resolves to `/src/led/led_mapping.json` (which does not exist).
  * Any request to configure the grid or LED mapping will fail due to `EACCES` (Permission Denied) or `ENOENT` (No Such File) when it tries to write to those root directories.

#### 3. Port Conflict (`EADDRINUSE` on Port 3000)
* **The Issue:** If a previous process (either an orphaned manual run of the Express app or a dev server) is already listening on port 3000, Express will throw an `EADDRINUSE` exception on startup and crash.
* **Result:** Since the systemd service has `Restart=on-failure` enabled, it will loop indefinitely, and clients will receive a `CONNECTION_REFUSED` error.



### Robust Express.js Boilerplate & Best Practices

To resolve the path mismatches, error-handling gaps, and routing complexity, we recommend structuring your backend code using Express Routers and environment variables.

#### 1. Server Entry Point ([src/web/src/api/index.ts](file:///workspace/src/web/src/api/index.ts))
This clean boilerplate moves paths into environment variables, handles asynchronous routing errors globally, and implements graceful shutdown hooks:

```typescript
import express, { Request, Response, NextFunction } from 'express';
import path from 'path';
import cors from 'cors';
import { router as apiRouter } from './routes/api';

export const app = express();
const port = process.env.PORT || 3000;

// Configurable file locations via environment variables (with fallback defaults)
export const UI_DIR = process.env.UI_DIR || path.join(__dirname, '../ui');
export const PERSISTENCE_FILE = process.env.PERSISTENCE_FILE || path.join(__dirname, '../current_problem.json');
export const GRID_CONFIG_FILE = process.env.GRID_CONFIG_FILE || path.resolve(__dirname, '../../dist/grid_config.json');
export const LED_MAPPINGS_FILE = process.env.LED_MAPPINGS_FILE || path.resolve(__dirname, '../../../src/led/led_mapping.json');

app.use(cors());
app.use(express.json());

// Serve UI assets
app.use(express.static(UI_DIR));

// Mount Modular API Router
app.use('/api', apiRouter);

// Explicit root route serving the React UI
app.get('/', (req: Request, res: Response) => {
  res.sendFile(path.join(UI_DIR, 'index.html'));
});

// Catch-all: defer unmatched routes to React (Express 5 compatible wildcard)
app.get('/*splat', (req: Request, res: Response) => {
  res.sendFile(path.join(UI_DIR, 'index.html'));
});

// Global Error Handling Middleware (prevents crashing on route errors)
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error('Unhandled Server Error:', err.stack);
  res.status(500).json({ error: 'Internal Server Error', message: err.message });
});

// Start listening if not in test environment
let server: any;
if (process.env.NODE_ENV !== 'test') {
  server = app.listen(Number(port), '0.0.0.0', () => {
    console.log(`[Moonboard] Web Server running at http://0.0.0.0:${port}`);
  });
}

// Graceful Shutdown
const shutdown = () => {
  console.log('[Moonboard] Shutting down web server...');
  if (server) {
    server.close(() => {
      console.log('[Moonboard] HTTP server closed.');
      process.exit(0);
    });
  } else {
    process.exit(0);
  }
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
```

#### 2. Modular API Router ([src/web/src/api/routes/api.ts](file:///workspace/src/web/src/api/routes/api.ts))
By modularizing your routing logic, you separate application concerns and avoid bloating the server configuration file:

```typescript
import { Router, Request, Response, NextFunction } from 'express';
import fs from 'fs';
import path from 'path';
import { PERSISTENCE_FILE, GRID_CONFIG_FILE, LED_MAPPINGS_FILE } from '../index';

export const router = Router();

interface HoldsState {
  START?: string[];
  MOVES?: string[];
  TOP?: string[];
  FLAGS?: string[];
}

let holdsState: HoldsState = {};
let clients: Response[] = [];

// Helper to wrap async route handlers to catch exceptions
const asyncHandler = (fn: Function) => (req: Request, res: Response, next: NextFunction) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// Initial state load
try {
  if (fs.existsSync(PERSISTENCE_FILE)) {
    holdsState = JSON.parse(fs.readFileSync(PERSISTENCE_FILE, 'utf8'));
  }
} catch (err) {
  console.error('Failed to load holds state from file:', err);
}

// Broadcast helper for SSE
const broadcastState = (state: HoldsState) => {
  clients.forEach((client) => {
    client.write(`data: ${JSON.stringify(state)}\n\n`);
  });
};

// --- API Endpoints ---

router.get('/holds', (req: Request, res: Response) => {
  res.json(holdsState);
});

router.post('/holds', asyncHandler(async (req: Request, res: Response) => {
  holdsState = req.body || {};
  res.sendStatus(200);

  // Write asynchronously
  const dir = path.dirname(PERSISTENCE_FILE);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  await fs.promises.writeFile(PERSISTENCE_FILE, JSON.stringify(holdsState, null, 2), 'utf8');

  // Broadcast update
  broadcastState(holdsState);
}));

router.get('/holds/stream', (req: Request, res: Response) => {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Content-Encoding': 'none',
  });

  res.write(`data: ${JSON.stringify(holdsState)}\n\n`);
  clients.push(res);

  req.on('close', () => {
    clients = clients.filter((client) => client !== res);
  });
});

router.get('/grid-config', (req: Request, res: Response) => {
  try {
    if (fs.existsSync(GRID_CONFIG_FILE)) {
      return res.json(JSON.parse(fs.readFileSync(GRID_CONFIG_FILE, 'utf8')));
    }
  } catch (err) {
    console.error('Failed to read grid config:', err);
  }
  res.json({
    leftPercent: 14.4,
    rightPercent: 91.8,
    topPercent: 6.7,
    bottomPercent: 91,
  });
});

router.post('/grid-config', asyncHandler(async (req: Request, res: Response) => {
  const config = req.body;
  if (!config || typeof config !== 'object') {
    return res.status(400).send('Invalid grid config payload');
  }

  const dir = path.dirname(GRID_CONFIG_FILE);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  await fs.promises.writeFile(GRID_CONFIG_FILE, JSON.stringify(config, null, 2), 'utf8');
  res.status(200).json({ success: true, config });
}));

router.post('/led-mappings', asyncHandler(async (req: Request, res: Response) => {
  const mappings = req.body;
  if (!mappings || (typeof mappings !== 'object' && typeof mappings !== 'string')) {
    return res.status(400).send('Invalid LED mappings payload');
  }

  const dir = path.dirname(LED_MAPPINGS_FILE);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  const content = typeof mappings === 'string' ? mappings : JSON.stringify(mappings, null, 2);
  await fs.promises.writeFile(LED_MAPPINGS_FILE, content, 'utf8');
  res.status(200).json({ success: true });
}));
