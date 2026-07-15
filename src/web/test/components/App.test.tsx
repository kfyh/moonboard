/**
 * @jest-environment jsdom
 */
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import App from '../../src/ui/App';

// Mock EventSource for SSE streaming
class MockEventSource {
  url: string;
  onopen: (() => void) | null = null;
  onmessage: ((event: { data: string }) => void) | null = null;
  onerror: ((err: any) => void) | null = null;

  constructor(url: string) {
    this.url = url;
    // Simulate async connection open
    setTimeout(() => {
      if (this.onopen) this.onopen();
    }, 10);
  }

  close = jest.fn();
}

beforeAll(() => {
  global.EventSource = MockEventSource as any;
});

describe('App Component Tests', () => {
  beforeEach(() => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: jest.fn().mockResolvedValue({
        leftPercent: 7.5,
        rightPercent: 92.5,
        topPercent: 8.0,
        bottomPercent: 92.0,
      }),
    });
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  it('renders header, status, and board', async () => {
    render(<App />);

    expect(screen.getByText('MOONBOARD')).toBeInTheDocument();
    expect(screen.getByText('2016 LED Visualizer')).toBeInTheDocument();
    expect(screen.getByTestId('board')).toBeInTheDocument();

    // Check that we mock loading configuration on mount
    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledWith('/api/grid-config');
    });
  });

  it('toggles settings panel visibility via the sliding panel buttons', async () => {
    render(<App />);

    // Wait for initial grid-config fetch
    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledWith('/api/grid-config');
    });

    // Initially in Active Climb mode
    expect(screen.getByTestId('climb-details')).toBeInTheDocument();
    expect(screen.queryByTestId('settings-panel')).not.toBeInTheDocument();

    // Open settings
    const settingsBtn = document.getElementById('open-settings-btn');
    expect(settingsBtn).toBeInTheDocument();
    fireEvent.click(settingsBtn!);

    // Now in Settings mode
    expect(screen.getByTestId('settings-panel')).toBeInTheDocument();
    expect(screen.queryByTestId('climb-details')).not.toBeInTheDocument();

    // Close settings
    const closeBtn = document.getElementById('close-settings-btn');
    expect(closeBtn).toBeInTheDocument();
    fireEvent.click(closeBtn!);

    // Back in Active Climb mode
    expect(screen.getByTestId('climb-details')).toBeInTheDocument();
    expect(screen.queryByTestId('settings-panel')).not.toBeInTheDocument();
  });
});
