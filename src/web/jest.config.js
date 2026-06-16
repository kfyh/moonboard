module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/test/**/*.test.ts', '**/test/**/*.test.tsx'],
  moduleNameMapper: {
    '\\.(css|less|png|jpg|jpeg|gif)$': '<rootDir>/test/styleMock.js',
  },
};
