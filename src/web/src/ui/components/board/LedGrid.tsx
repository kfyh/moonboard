import React from 'react';
import LedCircle from './LedCircle';

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

interface LedGridProps {
  gridConfig: GridConfig;
  holds: HoldsState | null;
  showCalibrationGrid: boolean;
}

export const LedGrid: React.FC<LedGridProps> = ({
  gridConfig,
  holds,
  showCalibrationGrid,
}) => {
  const columns = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K'];
  const rows = Array.from({ length: 18 }, (_, i) => i + 1);

  const getCoordinates = (colIdx: number, rowNum: number) => {
    const { leftPercent, rightPercent, topPercent, bottomPercent } = gridConfig;
    const x = leftPercent + (colIdx / 10) * (rightPercent - leftPercent);
    const y = bottomPercent - ((rowNum - 1) / 17) * (bottomPercent - topPercent);
    return { x, y };
  };

  const getHoldType = (colLetter: string, rowNum: number): 'START' | 'MOVES' | 'TOP' | null => {
    if (!holds) return null;
    const name = `${colLetter}${rowNum}`;
    if (holds.START?.includes(name)) return 'START';
    if (holds.MOVES?.includes(name)) return 'MOVES';
    if (holds.TOP?.includes(name)) return 'TOP';
    return null;
  };

  return (
    <div className="grid-overlay" data-testid="led-grid">
      {/* Calibration Faint Dots */}
      {showCalibrationGrid &&
        rows.map((rowNum) =>
          columns.map((colLetter, colIdx) => {
            const { x, y } = getCoordinates(colIdx, rowNum);
            const holdType = getHoldType(colLetter, rowNum);
            if (holdType) return null; // Let the active hold draw instead
            return (
              <div
                key={`cal-${colLetter}${rowNum}`}
                className="calibration-dot"
                style={{
                  left: `${x}%`,
                  top: `${y}%`,
                }}
                data-testid={`cal-${colLetter}${rowNum}`}
              >
                <span className="calibration-text">
                  {colLetter}{rowNum}
                </span>
              </div>
            );
          })
        )}

      {/* Active LED circles */}
      {holds &&
        rows.map((rowNum) =>
          columns.map((colLetter, colIdx) => {
            const holdType = getHoldType(colLetter, rowNum);
            if (!holdType) return null;

            const { x, y } = getCoordinates(colIdx, rowNum);

            return (
              <LedCircle
                key={`led-${colLetter}${rowNum}`}
                colLetter={colLetter}
                rowNum={rowNum}
                holdType={holdType}
                x={x}
                y={y}
              />
            );
          })
        )}
    </div>
  );
};

export default LedGrid;
