import request from 'supertest';
import fs from 'fs';

// Mock fs before importing the app
jest.mock('fs', () => {
  const actualFs = jest.requireActual('fs');
  const mockStorage: { [path: string]: string } = {};

  return {
    ...actualFs,
    existsSync: jest.fn((pathStr: string) => {
      if (
        pathStr.includes('grid_config.json') ||
        pathStr.includes('led_mapping.json') ||
        pathStr.includes('current_problem.json')
      ) {
        return mockStorage[pathStr] !== undefined;
      }
      return actualFs.existsSync(pathStr);
    }),
    readFileSync: jest.fn((pathStr: string, encoding: string) => {
      if (
        pathStr.includes('grid_config.json') ||
        pathStr.includes('led_mapping.json') ||
        pathStr.includes('current_problem.json')
      ) {
        if (mockStorage[pathStr] !== undefined) {
          return mockStorage[pathStr];
        }
        throw new Error(`ENOENT: no such file or directory, open '${pathStr}'`);
      }
      return actualFs.readFileSync(pathStr, encoding);
    }),
    writeFileSync: jest.fn((pathStr: string, content: string) => {
      mockStorage[pathStr] = content;
    }),
    mkdirSync: jest.fn(() => {}),
    promises: {
      writeFile: jest.fn(async (pathStr: string, content: string) => {
        mockStorage[pathStr] = content;
      }),
    },
  };
});

// Import the app
import { app } from '../src/api/index';

describe('Backend API Tests', () => {
  // Test GET /api/holds
  it('GET /api/holds should return current holds state', async () => {
    const res = await request(app).get('/api/holds');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({});
  });

  // Test POST /api/holds
  it('POST /api/holds should update holds state', async () => {
    const payload = {
      START: ['D3'],
      MOVES: ['F5'],
      TOP: ['E18'],
    };
    const postRes = await request(app)
      .post('/api/holds')
      .send(payload);
    expect(postRes.status).toBe(200);

    const getRes = await request(app).get('/api/holds');
    expect(getRes.body).toEqual(payload);
  });

  // Test GET /api/grid-config
  it('GET /api/grid-config should return default config if file does not exist', async () => {
    const res = await request(app).get('/api/grid-config');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      leftPercent: 7.5,
      rightPercent: 92.5,
      topPercent: 8.0,
      bottomPercent: 92.0,
    });
  });

  // Test POST /api/grid-config
  it('POST /api/grid-config should save grid configuration', async () => {
    const newConfig = {
      leftPercent: 10,
      rightPercent: 90,
      topPercent: 12,
      bottomPercent: 88,
    };
    const postRes = await request(app)
      .post('/api/grid-config')
      .send(newConfig);
    expect(postRes.status).toBe(200);
    expect(postRes.body.success).toBe(true);

    const getRes = await request(app).get('/api/grid-config');
    expect(getRes.body).toEqual(newConfig);
  });

  // Test POST /api/led-mappings
  it('POST /api/led-mappings should save LED mappings', async () => {
    const mockMappings = {
      A1: 0,
      B1: 1,
    };
    const postRes = await request(app)
      .post('/api/led-mappings')
      .send(mockMappings);
    expect(postRes.status).toBe(200);
    expect(postRes.body.success).toBe(true);
  });

  it('POST /api/led-mappings should reject invalid payload', async () => {
    const postRes = await request(app)
      .post('/api/led-mappings')
      .send(null as any);
    expect(postRes.status).toBe(400);
  });
});
