import React, { useState, useRef } from 'react';

interface MappingUploaderProps {
  onUploadSuccess?: () => void;
}

export const MappingUploader: React.FC<MappingUploaderProps> = ({ onUploadSuccess }) => {
  const [dragActive, setDragActive] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [status, setStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [message, setMessage] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleDrag = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true);
    } else if (e.type === 'dragleave') {
      setDragActive(false);
    }
  };

  const handleDrop = async (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      await processFile(e.dataTransfer.files[0]);
    }
  };

  const handleChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    e.preventDefault();
    if (e.target.files && e.target.files[0]) {
      await processFile(e.target.files[0]);
    }
  };

  const onButtonClick = () => {
    fileInputRef.current?.click();
  };

  const processFile = async (file: File) => {
    if (file.type !== 'application/json' && !file.name.endsWith('.json')) {
      setStatus('error');
      setMessage('Only JSON files are allowed.');
      return;
    }

    setIsUploading(true);
    setStatus('idle');
    setMessage(null);

    try {
      const text = await file.text();
      let parsedJson: any;
      try {
        parsedJson = JSON.parse(text);
      } catch (err) {
        setStatus('error');
        setMessage('Invalid JSON file content.');
        setIsUploading(false);
        return;
      }

      // Send the file content to the API
      const response = await fetch('/api/led-mappings', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(parsedJson),
      });

      if (response.ok) {
        setStatus('success');
        setMessage('Mappings uploaded and saved successfully!');
        if (onUploadSuccess) onUploadSuccess();
      } else {
        const errorText = await response.text();
        setStatus('error');
        setMessage(`Upload failed: ${errorText || response.statusText}`);
      }
    } catch (error: any) {
      console.error(error);
      setStatus('error');
      setMessage(`Error reading file: ${error.message}`);
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <div className="mapping-uploader-section" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
      <h3 className="panel-title" style={{ fontSize: '16px', margin: 0 }}>Mapping Uploader</h3>
      <p className="help-text" style={{ fontSize: '12px', color: '#9CA3AF', margin: '0 0 4px 0' }}>
        Upload a custom <code>led_mappings.json</code> to remap LED index sequence configurations.
      </p>

      {/* Drag & Drop Area */}
      <div
        onDragEnter={handleDrag}
        onDragOver={handleDrag}
        onDragLeave={handleDrag}
        onDrop={handleDrop}
        style={{
          border: `2px dashed ${dragActive ? '#3B82F6' : 'rgba(255, 255, 255, 0.15)'}`,
          borderRadius: '12px',
          padding: '24px',
          textAlign: 'center',
          backgroundColor: dragActive ? 'rgba(59, 130, 246, 0.05)' : 'rgba(255, 255, 255, 0.01)',
          cursor: 'pointer',
          transition: 'all 0.2s ease-in-out',
          position: 'relative',
        }}
        onClick={onButtonClick}
        data-testid="drop-zone"
      >
        <input
          ref={fileInputRef}
          type="file"
          style={{ display: 'none' }}
          onChange={handleChange}
          accept=".json,application/json"
          data-testid="file-select-input"
        />

        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
          {/* Upload icon representation */}
          <span style={{ fontSize: '32px', color: dragActive ? '#60A5FA' : '#9CA3AF' }}>⇪</span>
          <span style={{ fontSize: '14px', fontWeight: 500 }}>
            {dragActive ? 'Drop your JSON file here' : 'Drag & drop your led_mappings.json here'}
          </span>
          <span style={{ fontSize: '12px', color: '#6B7280' }}>or click to browse from files</span>
        </div>
      </div>

      {isUploading && (
        <div style={{ color: '#3B82F6', fontSize: '13px', fontWeight: 500 }} data-testid="uploading-msg">
          Uploading and processing file...
        </div>
      )}

      {status === 'success' && message && (
        <div style={{ color: '#10B981', fontSize: '13px', fontWeight: 500 }} data-testid="upload-success-msg">
          ✓ {message}
        </div>
      )}

      {status === 'error' && message && (
        <div style={{ color: '#EF4444', fontSize: '13px', fontWeight: 500 }} data-testid="upload-error-msg">
          ✗ {message}
        </div>
      )}
    </div>
  );
};

export default MappingUploader;
