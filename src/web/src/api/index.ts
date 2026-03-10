import express from 'express';
import path from 'path';
import cors from 'cors';

const app = express();
const port = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../ui')));

// --- Grid State ---
let holdsState: unknown = null;

// Endpoint for the bluetooth service to POST grid data to
app.post('/api/holds', (req, res) => {
  holdsState = req.body;
  res.sendStatus(200);
});

// Endpoint for the React app to GET the current grid state
app.get('/api/holds', (req, res) => {
  if (!holdsState) {
    res.json({});
    return;
  }
  res.json(holdsState);
});

app.get('/api', (req, res) => {
  res.send('Hello World!');
});

// Catch-all: defer unmatched routes to React
app.get(/(.*)/, (req, res) => {
  res.sendFile(path.join(__dirname, '../ui/index.html'));
});

app.listen(Number(port), '0.0.0.0', () => {
  console.log(`Server is running on http://0.0.0.0:${port}`);
});