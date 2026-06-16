/**
 * @jest-environment jsdom
 */
import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import Board from '../../src/ui/components/board/Board';

describe('Board Component Tests', () => {
  const defaultGridConfig = {
    leftPercent: 7.5,
    rightPercent: 92.5,
    topPercent: 8.0,
    bottomPercent: 92.0,
  };

  const mockHolds = {
    START: ['D3', 'G2'],
    MOVES: ['F5'],
    TOP: ['E18'],
  };

  it('renders Board and displays background image', () => {
    render(
      <Board
        gridConfig={defaultGridConfig}
        holds={null}
        showCalibrationGrid={false}
      />
    );

    const img = screen.getByAltText('Moonboard 2016 Layout');
    expect(img).toBeInTheDocument();
  });

  it('renders active LED circles when holds are provided', () => {
    render(
      <Board
        gridConfig={defaultGridConfig}
        holds={mockHolds}
        showCalibrationGrid={false}
      />
    );

    // Active holds should be rendered
    const startHold1 = screen.getByTestId('led-D3');
    const startHold2 = screen.getByTestId('led-G2');
    const moveHold = screen.getByTestId('led-F5');
    const topHold = screen.getByTestId('led-E18');

    expect(startHold1).toBeInTheDocument();
    expect(startHold2).toBeInTheDocument();
    expect(moveHold).toBeInTheDocument();
    expect(topHold).toBeInTheDocument();

    expect(startHold1).toHaveClass('led-start');
    expect(moveHold).toHaveClass('led-moves');
    expect(topHold).toHaveClass('led-top');
  });

  it('renders calibration guide dots when showCalibrationGrid is true', () => {
    render(
      <Board
        gridConfig={defaultGridConfig}
        holds={null}
        showCalibrationGrid={true}
      />
    );

    // Check a few calibration dots
    expect(screen.getByTestId('cal-A1')).toBeInTheDocument();
    expect(screen.getByTestId('cal-K18')).toBeInTheDocument();
    expect(screen.getByTestId('cal-F10')).toBeInTheDocument();
  });
});
