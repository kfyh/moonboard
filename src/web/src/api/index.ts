import express from 'express';
import path from 'path';
import cors from 'cors';
import { UI_DIR } from './config';
import { apiRouter } from './routes/api';

export const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static(UI_DIR));

// Mount the modular API router
app.use('/api', apiRouter);

// Explicit root route serving the React UI
app.get('/', (req, res) => {
  res.sendFile(path.join(UI_DIR, 'index.html'));
});

// Catch-all: defer unmatched routes to React (Express 4 & 5 compatible regex)
app.get(/.*/, (req, res) => {
  res.sendFile(path.join(UI_DIR, 'index.html'));
});

// Global error handler middleware
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Global error handler caught an error:', err);
  if (res.headersSent) {
    return next(err);
  }
  res.status(500).json({ error: 'Internal Server Error' });
});

let server: any;

if (process.env.NODE_ENV !== 'test') {
  server = app.listen(Number(port), '0.0.0.0', () => {
    console.log(`Server is running on http://0.0.0.0:${port}`);
  });

  // Graceful shutdown logic for SIGTERM / SIGINT
  const gracefulShutdown = (signal: string) => {
    console.log(`Received ${signal}. Shutting down server gracefully...`);
    if (server) {
      server.close(() => {
        console.log('Http server closed.');
        process.exit(0);
      });
      // Force exit after 10s if server close hangs
      setTimeout(() => {
        console.error('Could not close connections in time, forcefully shutting down');
        process.exit(1);
      }, 10000);
    } else {
      process.exit(0);
    }
  };

  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
}
