/**
 * @jest-environment jsdom
 */
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import SettingsPanel from '../../src/ui/components/settings/SettingsPanel';

describe('SettingsPanel Component Tests', () => {
  const defaultGridConfig = {
    leftPercent: 7.5,
    rightPercent: 92.5,
    topPercent: 8.0,
    bottomPercent: 92.0,
  };

  let mockOnChangeGridConfig: jest.Mock;
  let mockOnToggleCalibrationGrid: jest.Mock;
  let mockOnSaveCalibration: jest.Mock;
  let mockOnSimulate: jest.Mock;

  beforeAll(() => {
    if (!File.prototype.text) {
      File.prototype.text = function (this: File) {
        return new Promise<string>((resolve, reject) => {
          const reader = new FileReader();
          reader.onload = () => resolve(reader.result as string);
          reader.onerror = () => reject(reader.error);
          reader.readAsText(this);
        });
      };
    }
  });

  beforeEach(() => {
    mockOnChangeGridConfig = jest.fn();
    mockOnToggleCalibrationGrid = jest.fn();
    mockOnSaveCalibration = jest.fn().mockResolvedValue(undefined);
    mockOnSimulate = jest.fn().mockResolvedValue(undefined);
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      text: jest.fn().mockResolvedValue(''),
      json: jest.fn().mockResolvedValue({ success: true }),
    });
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  it('renders all settings sub-sections', () => {
    render(
      <SettingsPanel
        gridConfig={defaultGridConfig}
        onChangeGridConfig={mockOnChangeGridConfig}
        showCalibrationGrid={false}
        onToggleCalibrationGrid={mockOnToggleCalibrationGrid}
        onSaveCalibration={mockOnSaveCalibration}
        onSimulate={mockOnSimulate}
      />
    );

    expect(screen.getByText('Calibration Settings')).toBeInTheDocument();
    expect(screen.getByText('Climb Simulator')).toBeInTheDocument();
    expect(screen.getByText('Mapping Uploader')).toBeInTheDocument();
  });

  it('triggers onChangeGridConfig when sliders are adjusted', () => {
    render(
      <SettingsPanel
        gridConfig={defaultGridConfig}
        onChangeGridConfig={mockOnChangeGridConfig}
        showCalibrationGrid={false}
        onToggleCalibrationGrid={mockOnToggleCalibrationGrid}
        onSaveCalibration={mockOnSaveCalibration}
        onSimulate={mockOnSimulate}
      />
    );

    const leftSlider = screen.getByTestId('slider-left');
    fireEvent.change(leftSlider, { target: { value: '10.5' } });
    expect(mockOnChangeGridConfig).toHaveBeenCalledWith({
      ...defaultGridConfig,
      leftPercent: 10.5,
    });
  });

  it('triggers onToggleCalibrationGrid when guide guide button is clicked', () => {
    render(
      <SettingsPanel
        gridConfig={defaultGridConfig}
        onChangeGridConfig={mockOnChangeGridConfig}
        showCalibrationGrid={false}
        onToggleCalibrationGrid={mockOnToggleCalibrationGrid}
        onSaveCalibration={mockOnSaveCalibration}
        onSimulate={mockOnSimulate}
      />
    );

    const toggleBtn = screen.getByTestId('toggle-guide-btn');
    fireEvent.click(toggleBtn);
    expect(mockOnToggleCalibrationGrid).toHaveBeenCalled();
  });

  it('triggers onSaveCalibration when Save Configuration is clicked', async () => {
    render(
      <SettingsPanel
        gridConfig={defaultGridConfig}
        onChangeGridConfig={mockOnChangeGridConfig}
        showCalibrationGrid={false}
        onToggleCalibrationGrid={mockOnToggleCalibrationGrid}
        onSaveCalibration={mockOnSaveCalibration}
        onSimulate={mockOnSimulate}
      />
    );

    const saveBtn = screen.getByTestId('save-calibration-btn');
    fireEvent.click(saveBtn);

    expect(mockOnSaveCalibration).toHaveBeenCalled();
    await waitFor(() => {
      expect(screen.getByTestId('save-success-msg')).toBeInTheDocument();
    });
  });

  it('triggers onSimulate when preconfigured climb buttons are clicked', () => {
    render(
      <SettingsPanel
        gridConfig={defaultGridConfig}
        onChangeGridConfig={mockOnChangeGridConfig}
        showCalibrationGrid={false}
        onToggleCalibrationGrid={mockOnToggleCalibrationGrid}
        onSaveCalibration={mockOnSaveCalibration}
        onSimulate={mockOnSimulate}
      />
    );

    const climb1Btn = screen.getByTestId('load-climb1-btn');
    fireEvent.click(climb1Btn);
    expect(mockOnSimulate).toHaveBeenCalledWith(
      expect.objectContaining({
        FLAGS: ['2016_test_1'],
      })
    );
  });

  it('triggers onSimulate with custom input JSON when submitted', () => {
    render(
      <SettingsPanel
        gridConfig={defaultGridConfig}
        onChangeGridConfig={mockOnChangeGridConfig}
        showCalibrationGrid={false}
        onToggleCalibrationGrid={mockOnToggleCalibrationGrid}
        onSaveCalibration={mockOnSaveCalibration}
        onSimulate={mockOnSimulate}
      />
    );

    const customJson = { START: ['A1'], MOVES: [], TOP: [] };
    const textarea = screen.getByTestId('sim-json-textarea');
    fireEvent.change(textarea, { target: { value: JSON.stringify(customJson) } });

    const submitBtn = screen.getByTestId('submit-custom-json-btn');
    fireEvent.click(submitBtn);

    expect(mockOnSimulate).toHaveBeenCalledWith(customJson);
  });

  it('handles drag and drop upload of mapping files', async () => {
    render(
      <SettingsPanel
        gridConfig={defaultGridConfig}
        onChangeGridConfig={mockOnChangeGridConfig}
        showCalibrationGrid={false}
        onToggleCalibrationGrid={mockOnToggleCalibrationGrid}
        onSaveCalibration={mockOnSaveCalibration}
        onSimulate={mockOnSimulate}
      />
    );

    const dropZone = screen.getByTestId('drop-zone');
    const mockFileContent = JSON.stringify({ A1: 5, B1: 6 });
    const mockFile = new File([mockFileContent], 'led_mappings.json', {
      type: 'application/json',
    });

    fireEvent.drop(dropZone, {
      dataTransfer: {
        files: [mockFile],
      },
    });

    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledWith(
        '/api/led-mappings',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify({ A1: 5, B1: 6 }),
        })
      );
      expect(screen.getByTestId('upload-success-msg')).toBeInTheDocument();
    });
  });
});
