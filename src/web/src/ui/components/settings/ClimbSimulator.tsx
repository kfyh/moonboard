import React, { useState } from 'react';

interface ClimbSimulatorProps {
  onSimulate: (holdsData: any) => Promise<void>;
}

export const ClimbSimulator: React.FC<ClimbSimulatorProps> = ({ onSimulate }) => {
  const [jsonInput, setJsonInput] = useState<string>(
    JSON.stringify(
      {
        START: ['D3', 'G2'],
        MOVES: ['F5', 'D8', 'G11', 'H13', 'E15'],
        TOP: ['E18'],
        FLAGS: ['custom_simulator_test'],
      },
      null,
      2
    )
  );
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  const triggerSimulation = async (payload: any) => {
    setErrorMsg(null);
    setSuccessMsg(null);
    try {
      await onSimulate(payload);
      setSuccessMsg('Climb state posted successfully!');
      setTimeout(() => setSuccessMsg(null), 3000);
    } catch (err) {
      console.error(err);
      setErrorMsg('Failed to simulate climb');
    }
  };

  const loadPreconfigured = (type: 'climb1' | 'climb2' | 'clear') => {
    if (type === 'climb1') {
      const payload = {
        START: ['D3', 'G2'],
        MOVES: ['F5', 'D8', 'G11', 'H13', 'E15'],
        TOP: ['E18'],
        FLAGS: ['2016_test_1'],
      };
      triggerSimulation(payload);
    } else if (type === 'climb2') {
      const payload = {
        START: ['E6', 'F5'],
        MOVES: ['G7', 'H10', 'F13'],
        TOP: ['G18'],
        FLAGS: ['2016_test_2'],
      };
      triggerSimulation(payload);
    } else {
      triggerSimulation({});
    }
  };

  const handleCustomSubmit = () => {
    setErrorMsg(null);
    setSuccessMsg(null);
    try {
      const parsed = JSON.parse(jsonInput);
      triggerSimulation(parsed);
    } catch (err: any) {
      setErrorMsg(`Invalid JSON: ${err.message}`);
    }
  };

  return (
    <div className="climb-simulator-section" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
      <h3 className="panel-title" style={{ fontSize: '16px', margin: 0 }}>Climb Simulator</h3>
      
      {/* Quick Select Buttons */}
      <div className="button-group" style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
        <button
          onClick={() => loadPreconfigured('climb1')}
          className="btn btn-primary"
          style={{ width: 'auto', flex: '1 1 auto', padding: '10px 14px' }}
          data-testid="load-climb1-btn"
        >
          Load Climb #1 (D3/G2)
        </button>
        <button
          onClick={() => loadPreconfigured('climb2')}
          className="btn btn-primary"
          style={{ width: 'auto', flex: '1 1 auto', padding: '10px 14px' }}
          data-testid="load-climb2-btn"
        >
          Load Climb #2 (E6/F5)
        </button>
        <button
          onClick={() => loadPreconfigured('clear')}
          className="btn btn-secondary"
          style={{ width: 'auto', flex: '1 1 auto', padding: '10px 14px' }}
          data-testid="clear-sim-btn"
        >
          Clear Board
        </button>
      </div>

      {/* JSON Copy-Paste */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
        <label style={{ fontSize: '12px', fontWeight: 600, color: '#D1D5DB' }}>Custom Holds JSON:</label>
        <textarea
          rows={7}
          value={jsonInput}
          onChange={(e) => setJsonInput(e.target.value)}
          style={{
            backgroundColor: 'rgba(0, 0, 0, 0.4)',
            border: '1px solid rgba(255, 255, 255, 0.15)',
            borderRadius: '8px',
            color: '#F3F4F6',
            fontFamily: 'monospace',
            fontSize: '12px',
            padding: '10px',
            resize: 'vertical',
            width: '100%',
            boxSizing: 'border-box',
          }}
          data-testid="sim-json-textarea"
        />
        <button
          onClick={handleCustomSubmit}
          className="btn btn-primary"
          style={{ width: '100%', marginTop: '4px' }}
          data-testid="submit-custom-json-btn"
        >
          Submit Custom JSON
        </button>
      </div>

      {successMsg && (
        <div style={{ color: '#10B981', fontSize: '13px', fontWeight: 500 }} data-testid="sim-success-msg">
          ✓ {successMsg}
        </div>
      )}
      {errorMsg && (
        <div style={{ color: '#EF4444', fontSize: '13px', fontWeight: 500 }} data-testid="sim-error-msg">
          ✗ {errorMsg}
        </div>
      )}
    </div>
  );
};

export default ClimbSimulator;
