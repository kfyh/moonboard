import React from 'react';

interface SlidingPanelProps {
  showSettings: boolean;
  onToggleSettings: () => void;
  climbDetails: React.ReactNode;
  settingsPanel: React.ReactNode;
}

export const SlidingPanel: React.FC<SlidingPanelProps> = ({
  showSettings,
  onToggleSettings,
  climbDetails,
  settingsPanel,
}) => {
  return (
    <section className="panel-section">
      <div className="sliding-panel-container">
        {!showSettings ? (
          <div className="glass-panel">
            <div className="panel-header-row">
              <h2 className="panel-title">Active Climb Info</h2>
              <button
                onClick={onToggleSettings}
                className="btn btn-primary"
                style={{ width: 'auto', padding: '6px 12px' }}
                id="open-settings-btn"
              >
                Settings
              </button>
            </div>
            {climbDetails}
          </div>
        ) : (
          <div className="glass-panel">
            <div className="panel-header-row">
              <h2 className="panel-title">Settings</h2>
              <button
                onClick={onToggleSettings}
                className="btn btn-secondary"
                style={{ width: 'auto', padding: '6px 12px' }}
                id="close-settings-btn"
              >
                Close
              </button>
            </div>
            {settingsPanel}
          </div>
        )}
      </div>
    </section>
  );
};

export default SlidingPanel;
