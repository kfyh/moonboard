import React from 'react';
import downloadImage from '../../../../download.png';
import LedGrid from './LedGrid';

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

interface BoardProps {
  gridConfig: GridConfig;
  holds: HoldsState | null;
  showCalibrationGrid: boolean;
}

export const Board: React.FC<BoardProps> = ({
  gridConfig,
  holds,
  showCalibrationGrid,
}) => {
  return (
    <section className="board-section" data-testid="board">
      <div className="board-wrapper">
        <div className="board-container">
          <img
            src={downloadImage}
            alt="Moonboard 2016 Layout"
            className="board-image"
          />
          <LedGrid
            gridConfig={gridConfig}
            holds={holds}
            showCalibrationGrid={showCalibrationGrid}
          />
        </div>
      </div>
    </section>
  );
};

export default Board;
