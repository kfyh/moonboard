import React from 'react';
import CalibrationControls from './CalibrationControls';
import ClimbSimulator from './ClimbSimulator';
import MappingUploader from './MappingUploader';

interface GridConfig {
  leftPercent: number;
  rightPercent: number;
  topPercent: number;
  bottomPercent: number;
}

interface SettingsPanelProps {
  gridConfig: GridConfig;
  onChangeGridConfig: (config: GridConfig) => void;
  showCalibrationGrid: boolean;
  onToggleCalibrationGrid: () => void;
  onSaveCalibration: () => Promise<void>;
  onSimulate: (holdsData: any) => Promise<void>;
  onUploadSuccess?: () => void;
}

export const SettingsPanel: React.FC<SettingsPanelProps> = ({
  gridConfig,
  onChangeGridConfig,
  showCalibrationGrid,
  onToggleCalibrationGrid,
  onSaveCalibration,
  onSimulate,
  onUploadSuccess,
}) => {
  return (
    <div className="settings-panel-content" style={{ display: 'flex', flexDirection: 'column', gap: '32px' }} data-testid="settings-panel">
      {/* Calibration Controls */}
      <div style={{ borderBottom: '1px solid rgba(255, 255, 255, 0.08)', paddingBottom: '24px' }}>
        <CalibrationControls
          gridConfig={gridConfig}
          onChange={onChangeGridConfig}
          showCalibrationGrid={showCalibrationGrid}
          onToggleCalibrationGrid={onToggleCalibrationGrid}
          onSave={onSaveCalibration}
        />
      </div>

      {/* Climb Simulator */}
      <div style={{ borderBottom: '1px solid rgba(255, 255, 255, 0.08)', paddingBottom: '24px' }}>
        <ClimbSimulator onSimulate={onSimulate} />
      </div>

      {/* Mapping Uploader */}
      <div>
        <MappingUploader onUploadSuccess={onUploadSuccess} />
      </div>
    </div>
  );
};

export default SettingsPanel;
