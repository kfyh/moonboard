const react = require('eslint-plugin-react');
const typescriptEslint = require('@typescript-eslint/eslint-plugin');
const tsParser = require('@typescript-eslint/parser');
const prettier = require('eslint-plugin-prettier');

module.exports = [
  {
    files: ['**/*.ts', '**/*.tsx'],
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        ecmaVersion: 2020,
        sourceType: 'module',
        ecmaFeatures: {
          jsx: true,
        },
      },
    },
    plugins: {
      react,
      '@typescript-eslint': typescriptEslint,
      prettier,
    },
    rules: {
      // Place to specify ESLint rules.
    },
    settings: {
      react: {
        version: 'detect',
      },
    },
  },
];
