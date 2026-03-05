module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/test/**/*.test.ts', '**/test/**/*.test.tsx'],
  moduleNameMapper: {
    '\.(css|less)$': '<rootDir>/test/styleMock.js',
  },
};
