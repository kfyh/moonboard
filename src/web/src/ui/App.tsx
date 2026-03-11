import React, { useState, useEffect } from 'react';

const App: React.FC = () => {
  const [holds, setHolds] = useState<unknown>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchHolds = async () => {
      try {
        const response = await fetch('/api/holds');
        if (!response.ok) throw new Error(`HTTP error: ${response.status}`);
        const data = await response.json();
        setHolds(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Unknown error');
      }
    };

    fetchHolds();
  }, []);

  return (
    <div>
      <h1>Holds</h1>
      {error && <p style={{ color: 'red' }}>{error}</p>}
      <pre>{JSON.stringify(holds, null, 2)}</pre>
    </div>
  );
};

export default App;