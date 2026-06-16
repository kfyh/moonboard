import React, { useState } from 'react';

interface GridConfig {
  leftPercent: number;
  rightPercent: number;
  topPercent: number;
  bottomPercent: number;
}

interface CalibrationControlsProps {
  gridConfig: GridConfig;
  onChange: (config: GridConfig) => void;
  showCalibrationGrid: boolean;
  onToggleCalibrationGrid: () => void;
  onSave: () => Promise<void>;
}

export const CalibrationControls: React.FC<CalibrationControlsProps> = ({
  gridConfig,
  onChange,
  showCalibrationGrid,
  onToggleCalibrationGrid,
  onSave,
}) => {
  const [isSaving, setIsSaving] = useState(false);
  const [saveStatus, setSaveStatus] = useState<'idle' | 'success' | 'error'>('idle');

  const handleSave = async () => {
    setIsSaving(true);
    setSaveStatus('idle');
    try {
      await onSave();
      setSaveStatus('success');
      setTimeout(() => setSaveStatus('idle'), 3000);
    } catch (err) {
      console.error(err);
      setSaveStatus('error');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="calibration-controls-section" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
      <div className="panel-header-row" style={{ marginBottom: '8px' }}>
        <h3 className="panel-title" style={{ fontSize: '16px', margin: 0 }}>Calibration Settings</h3>
        <button
          onClick={onToggleCalibrationGrid}
          className="btn-compact"
          style={{
            backgroundColor: showCalibrationGrid ? 'rgba(59, 130, 246, 0.2)' : 'transparent',
            borderColor: showCalibrationGrid ? '#3B82F6' : 'rgba(255, 255, 255, 0.2)',
            color: showCalibrationGrid ? '#60A5FA' : '#F3F4F6',
            cursor: 'pointer',
          }}
          data-testid="toggle-guide-btn"
        >
          {showCalibrationGrid ? 'Hide Grid Guide' : 'Show Grid Guide'}
        </button>
      </div>
      <p className="help-text" style={{ fontSize: '12px', color: '#9CA3AF', margin: '0 0 12px 0' }}>
        Adjust percentage bounds to align LEDs exactly with the physical/image holds.
      </p>

      <div className="sliders-container" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
        <div className="slider-group">
          <div className="slider-label-row">
            <span>Left Edge: {gridConfig.leftPercent}%</span>
          </div>
          <input
            type="range"
            min="0"
            max="30"
            step="0.1"
            value={gridConfig.leftPercent}
            onChange={(e) => onChange({ ...gridConfig, leftPercent: parseFloat(e.target.value) })}
            className="slider"
            data-testid="slider-left"
          />
        </div>

        <div className="slider-group">
          <div className="slider-label-row">
            <span>Right Edge: {gridConfig.rightPercent}%</span>
          </div>
          <input
            type="range"
            min="70"
            max="100"
            step="0.1"
            value={gridConfig.rightPercent}
            onChange={(e) => onChange({ ...gridConfig, rightPercent: parseFloat(e.target.value) })}
            className="slider"
            data-testid="slider-right"
          />
        </div>

        <div className="slider-group">
          <div className="slider-label-row">
            <span>Top Edge: {gridConfig.topPercent}%</span>
          </div>
          <input
            type="range"
            min="0"
            max="30"
            step="0.1"
            value={gridConfig.topPercent}
            onChange={(e) => onChange({ ...gridConfig, topPercent: parseFloat(e.target.value) })}
            className="slider"
            data-testid="slider-top"
          />
        </div>

        <div className="slider-group">
          <div className="slider-label-row">
            <span>Bottom Edge: {gridConfig.bottomPercent}%</span>
          </div>
          <input
            type="range"
            min="70"
            max="100"
            step="0.1"
            value={gridConfig.bottomPercent}
            onChange={(e) => onChange({ ...gridConfig, bottomPercent: parseFloat(e.target.value) })}
            className="slider"
            data-testid="slider-bottom"
          />
        </div>
      </div>

      <div style={{ display: 'flex', gap: '12px', alignItems: 'center', marginTop: '8px' }}>
        <button
          onClick={handleSave}
          disabled={isSaving}
          className="btn btn-primary"
          style={{ width: 'auto', padding: '8px 20px' }}
          data-testid="save-calibration-btn"
        >
          {isSaving ? 'Saving...' : 'Save Configuration'}
        </button>
        {saveStatus === 'success' && (
          <span style={{ color: '#10B981', fontSize: '13px', fontWeight: 500 }} data-testid="save-success-msg">
            ✓ Saved successfully!
          </span>
        )}
        {saveStatus === 'error' && (
          <span style={{ color: '#EF4444', fontSize: '13px', fontWeight: 500 }} data-testid="save-error-msg">
            ✗ Error saving configuration
          </span>
        )}
      </div>

      <div className="code-output" style={{ marginTop: '12px' }}>
        <span className="code-title">Save grid_config.json:</span>
        <pre className="code-block">
          {JSON.stringify(gridConfig, null, 2)}
        </pre>
      </div>
    </div>
  );
};

export default CalibrationControls;
