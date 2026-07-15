import path from 'path';

export const UI_DIR = process.env.UI_DIR || path.resolve(__dirname, '../ui');
export const PERSISTENCE_FILE = process.env.PERSISTENCE_FILE || path.resolve(__dirname, '../../current_problem.json');
export const GRID_CONFIG_FILE = process.env.GRID_CONFIG_FILE || path.resolve(__dirname, '../../grid_config.json');
export const LED_MAPPINGS_FILE = process.env.LED_MAPPINGS_FILE || path.resolve(__dirname, '../../led_mapping.json');
