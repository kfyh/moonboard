import React, { useState, useEffect } from 'react';
import Board from './components/board/Board';
import SettingsPanel from './components/settings/SettingsPanel';
import SlidingPanel from './components/layout/SlidingPanel';
import './App.css';

interface HoldsState {
  START?: string[];
  MOVES?: string[];
  TOP?: string[];
  FLAGS?: string[];
}

interface GridConfig {
  leftPercent: number;
  rightPercent: number;
  topPercent: number;
  bottomPercent: number;
}

const App: React.FC = () => {
  const [holds, setHolds] = useState<HoldsState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isConnected, setIsConnected] = useState<boolean>(false);
  const [showCalibrationGrid, setShowCalibrationGrid] = useState<boolean>(false);
  const [showSettings, setShowSettings] = useState<boolean>(false);

  // Real-time grid config adjustment
  const [gridConfig, setGridConfig] = useState<GridConfig>({
    leftPercent: 7.5,
    rightPercent: 92.5,
    topPercent: 8.0,
    bottomPercent: 92.0,
  });

  // Load grid config from backend on startup
  useEffect(() => {
    const fetchGridConfig = async () => {
      try {
        const response = await fetch('/api/grid-config');
        if (response.ok) {
          const config = await response.json();
          setGridConfig({
            leftPercent: config.leftPercent ?? 7.5,
            rightPercent: config.rightPercent ?? 92.5,
            topPercent: config.topPercent ?? 8.0,
            bottomPercent: config.bottomPercent ?? 92.0,
          });
        }
      } catch (err) {
        console.error('Failed to load grid config from server:', err);
      }
    };
    fetchGridConfig();
  }, []);

  // Connect to SSE stream
  useEffect(() => {
    let eventSource: EventSource | null = null;
    let retryTimeout: NodeJS.Timeout;

    const connectSSE = () => {
      console.log('Connecting to SSE stream...');
      eventSource = new EventSource('/api/holds/stream');

      eventSource.onopen = () => {
        console.log('SSE connection established');
        setIsConnected(true);
        setError(null);
      };

      eventSource.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          setHolds(data);
        } catch (err) {
          console.error('Error parsing holds state:', err);
        }
      };

      eventSource.onerror = (err) => {
        console.error('SSE connection error:', err);
        setIsConnected(false);
        setError('Real-time connection lost. Retrying...');
        eventSource?.close();

        // Retry connection after 3 seconds
        retryTimeout = setTimeout(connectSSE, 3000);
      };
    };

    connectSSE();

    return () => {
      if (eventSource) {
        eventSource.close();
      }
      clearTimeout(retryTimeout);
    };
  }, []);

  const handleSaveCalibration = async () => {
    const response = await fetch('/api/grid-config', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(gridConfig),
    });
    if (!response.ok) {
      throw new Error(`Failed to save grid config: ${response.statusText}`);
    }
  };

  const handleSimulate = async (holdsData: any) => {
    const response = await fetch('/api/holds', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(holdsData),
    });
    if (!response.ok) {
      throw new Error(`Failed to post simulation data: ${response.statusText}`);
    }
  };

  const hasClimb =
    holds &&
    ((holds.START && holds.START.length > 0) ||
      (holds.MOVES && holds.MOVES.length > 0) ||
      (holds.TOP && holds.TOP.length > 0));

  // Render climbDetails inside SlidingPanel
  const climbDetailsContent = (
    <div data-testid="climb-details">
      {hasClimb ? (
        <div className="climb-info">
          <div className="climb-stats-row">
            <div className="stat-box">
              <span className="stat-color" style={{ backgroundColor: '#10B981' }} />
              <div className="stat-text">
                <div className="stat-val">{holds?.START?.length || 0}</div>
                <div className="stat-label">Start Holds</div>
              </div>
            </div>
            <div className="stat-box">
              <span className="stat-color" style={{ backgroundColor: '#3B82F6' }} />
              <div className="stat-text">
                <div className="stat-val">{holds?.MOVES?.length || 0}</div>
                <div className="stat-label">Moves</div>
              </div>
            </div>
            <div className="stat-box">
              <span className="stat-color" style={{ backgroundColor: '#EF4444' }} />
              <div className="stat-text">
                <div className="stat-val">{holds?.TOP?.length || 0}</div>
                <div className="stat-label">Top Holds</div>
              </div>
            </div>
          </div>

          <div className="hold-lists">
            <div className="hold-group">
              <h4 className="hold-group-title" style={{ color: '#10B981' }}>
                Start Holds
              </h4>
              <div className="tag-container">
                {holds?.START?.map((h) => (
                  <span key={h} className="tag">
                    {h}
                  </span>
                ))}
              </div>
            </div>
            <div className="hold-group">
              <h4 className="hold-group-title" style={{ color: '#3B82F6' }}>
                Moves
              </h4>
              <div className="tag-container">
                {holds?.MOVES?.map((h) => (
                  <span key={h} className="tag">
                    {h}
                  </span>
                ))}
              </div>
            </div>
            <div className="hold-group">
              <h4 className="hold-group-title" style={{ color: '#EF4444' }}>
                Top Holds
              </h4>
              <div className="tag-container">
                {holds?.TOP?.map((h) => (
                  <span key={h} className="tag">
                    {h}
                  </span>
                ))}
              </div>
            </div>
          </div>
        </div>
      ) : (
        <div className="no-climb-state">
          <div className="radar-icon">
            <div className="radar-ping" />
          </div>
          <p className="no-climb-text">No active climb selected</p>
          <span className="no-climb-sub">
            Use the BLE service or toggle Settings to open the Climb Simulator.
          </span>
        </div>
      )}
    </div>
  );

  const settingsPanelContent = (
    <SettingsPanel
      gridConfig={gridConfig}
      onChangeGridConfig={setGridConfig}
      showCalibrationGrid={showCalibrationGrid}
      onToggleCalibrationGrid={() => setShowCalibrationGrid(!showCalibrationGrid)}
      onSaveCalibration={handleSaveCalibration}
      onSimulate={handleSimulate}
    />
  );

  return (
    <div className="app-container">
      <header className="header">
        <div className="header-left">
          <h1 className="title">MOONBOARD</h1>
          <span className="subtitle">2016 LED Visualizer</span>
        </div>
        <div className="status-badge">
          <span className={`status-dot ${isConnected ? 'connected' : 'disconnected'}`} />
          <span className="status-text">
            {isConnected ? 'Real-time Connected' : 'Disconnected'}
          </span>
        </div>
      </header>

      {error && (
        <div className="error-banner">
          <p>{error}</p>
        </div>
      )}

      <main className="main-layout">
        {/* Left Side: Board Visualizer */}
        <Board
          gridConfig={gridConfig}
          holds={holds}
          showCalibrationGrid={showCalibrationGrid}
        />

        {/* Right Side: Sliding Panel (Climb Info vs Settings) */}
        <SlidingPanel
          showSettings={showSettings}
          onToggleSettings={() => setShowSettings(!showSettings)}
          climbDetails={climbDetailsContent}
          settingsPanel={settingsPanelContent}
        />
      </main>
    </div>
  );
};

export default App;