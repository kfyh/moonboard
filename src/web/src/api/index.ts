import express from 'express';
import path from 'path';
import cors from 'cors';
import fs from 'fs';

interface HoldsState {
  START?: string[];
  MOVES?: string[];
  TOP?: string[];
  FLAGS?: string[];
}

export const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../ui')));

const PERSISTENCE_FILE = path.join(__dirname, '../current_problem.json');

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

// --- Grid State ---
let holdsState: HoldsState = loadState();

// SSE clients list
let clients: express.Response[] = [];

// Broadcast holdsState to all SSE clients
const broadcastState = (state: HoldsState) => {
  clients.forEach((client) => {
    client.write(`data: ${JSON.stringify(state)}\n\n`);
  });
};

// Endpoint for the bluetooth/LED service to POST grid data to
app.post('/api/holds', async (req, res) => {
  holdsState = req.body || {};
  res.sendStatus(200);
  
  // Persist state to local file
  await saveState(holdsState);
  
  // Notify all SSE connected clients
  broadcastState(holdsState);
});

// Endpoint for the React app to GET the current grid state
app.get('/api/holds', (req, res) => {
  res.json(holdsState);
});

// Real-time SSE streaming endpoint
app.get('/api/holds/stream', (req, res) => {
  // Set headers for Server-Sent Events
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Content-Encoding': 'none',
  });

  // Send the current holds state immediately on connection
  res.write(`data: ${JSON.stringify(holdsState)}\n\n`);

  // Add client to the list
  clients.push(res);

  // Handle client disconnection
  req.on('close', () => {
    clients = clients.filter((client) => client !== res);
  });
});

const GRID_CONFIG_FILE = path.resolve(__dirname, '../../dist/grid_config.json');
const LED_MAPPINGS_FILE = path.resolve(__dirname, '../../../src/led/led_mapping.json');

const DEFAULT_GRID_CONFIG = {
  leftPercent: 14.4,
  rightPercent: 91.8,
  topPercent: 6.7,
  bottomPercent: 91
};

// GET /api/grid-config
app.get('/api/grid-config', (req, res) => {
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

// POST /api/grid-config
app.post('/api/grid-config', async (req, res) => {
  try {
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
  } catch (err) {
    console.error('Failed to save grid config:', err);
    return res.status(500).send('Error saving grid config');
  }
});

// POST /api/led-mappings
app.post('/api/led-mappings', async (req, res) => {
  try {
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
  } catch (err) {
    console.error('Failed to save LED mappings:', err);
    return res.status(500).send('Error saving LED mappings');
  }
});

// Explicit root route serving the React UI
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../ui/index.html'));
});

app.get('/api', (req, res) => {
  res.send('Hello World!');
});

// Catch-all: defer unmatched routes to React (Express 5 compatible wildcard)
app.get('/*', (req, res) => {
  res.sendFile(path.join(__dirname, '../ui/index.html'));
});

if (process.env.NODE_ENV !== 'test') {
  app.listen(Number(port), '0.0.0.0', () => {
    console.log(`Server is running on http://0.0.0.0:${port}`);
  });
}
