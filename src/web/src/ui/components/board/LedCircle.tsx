import React from 'react';

interface LedCircleProps {
  colLetter: string;
  rowNum: number;
  holdType: 'START' | 'MOVES' | 'TOP';
  x: number;
  y: number;
}

export const LedCircle: React.FC<LedCircleProps> = ({
  colLetter,
  rowNum,
  holdType,
  x,
  y,
}) => {
  let ledClass = '';
  if (holdType === 'START') ledClass = 'led-start';
  if (holdType === 'MOVES') ledClass = 'led-moves';
  if (holdType === 'TOP') ledClass = 'led-top';

  return (
    <div
      className={`led-base ${ledClass}`}
      style={{
        left: `${x}%`,
        top: `${y}%`,
      }}
      data-testid={`led-${colLetter}${rowNum}`}
    >
      <span className="led-label">{colLetter}{rowNum}</span>
    </div>
  );
};

export default LedCircle;
