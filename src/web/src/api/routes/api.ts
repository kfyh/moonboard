import express, { Request, Response, NextFunction, RequestHandler } from 'express';
import fs from 'fs';
import path from 'path';
import { PERSISTENCE_FILE, GRID_CONFIG_FILE, LED_MAPPINGS_FILE } from '../config';

export interface HoldsState {
  START?: string[];
  MOVES?: string[];
  TOP?: string[];
  FLAGS?: string[];
}

export const apiRouter = express.Router();

let holdsState: HoldsState = {};
let clients: Response[] = [];

// Helper to wrap async routes
const asyncHandler = (fn: (req: Request, res: Response, next: NextFunction) => Promise<any>): RequestHandler => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

// Load holds state from the file on startup
const loadState = (): HoldsState => {
  try {
    if (fs.existsSync(PERSISTENCE_FILE)) {
      const data = fs.readFileSync(PERSISTENCE_FILE, 'utf8');
      return JSON.parse(data);
    }
  } catch (err) {
    console.error('Failed to load holds state from file:', err);
  }
  return {};
};

// Save holds state to the file asynchronously
const saveState = async (state: HoldsState) => {
  try {
    const dir = path.dirname(PERSISTENCE_FILE);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    await fs.promises.writeFile(PERSISTENCE_FILE, JSON.stringify(state, null, 2), 'utf8');
  } catch (err) {
    console.error('Failed to save holds state to file:', err);
  }
};

// Broadcast holdsState to all SSE clients
const broadcastState = (state: HoldsState) => {
  clients.forEach((client) => {
    client.write(`data: ${JSON.stringify(state)}\n\n`);
  });
};

// Initialize state
holdsState = loadState();

const DEFAULT_GRID_CONFIG = {
  leftPercent: 14.4,
  rightPercent: 91.8,
  topPercent: 6.7,
  bottomPercent: 91
};

// GET /api (mounted on /api, so this is GET /)
apiRouter.get('/', (req, res) => {
  res.send('Hello World!');
});

// GET /api/holds -> GET /holds
apiRouter.get('/holds', (req, res) => {
  res.json(holdsState);
});

// POST /api/holds -> POST /holds
apiRouter.post('/holds', asyncHandler(async (req, res) => {
  holdsState = req.body || {};
  res.sendStatus(200);
  await saveState(holdsState);
  broadcastState(holdsState);
}));

// GET /api/holds/stream -> GET /holds/stream
apiRouter.get('/holds/stream', (req, res) => {
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

// GET /api/grid-config -> GET /grid-config
apiRouter.get('/grid-config', (req, res) => {
  try {
    if (fs.existsSync(GRID_CONFIG_FILE)) {
      const data = fs.readFileSync(GRID_CONFIG_FILE, 'utf8');
      return res.json(JSON.parse(data));
    }
  } catch (err) {
    console.error('Failed to read grid config:', err);
  }
  return res.json(DEFAULT_GRID_CONFIG);
});

// POST /api/grid-config -> POST /grid-config
apiRouter.post('/grid-config', asyncHandler(async (req, res) => {
  const config = req.body;
  if (!config || typeof config !== 'object') {
    return res.status(400).send('Invalid grid config payload');
  }
  const dir = path.dirname(GRID_CONFIG_FILE);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  await fs.promises.writeFile(GRID_CONFIG_FILE, JSON.stringify(config, null, 2), 'utf8');
  return res.status(200).json({ success: true, config });
}));

// POST /api/led-mappings -> POST /led-mappings
apiRouter.post('/led-mappings', asyncHandler(async (req, res) => {
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
  return res.status(200).json({ success: true });
}));
