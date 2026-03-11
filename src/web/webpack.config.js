const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const nodeExternals = require('webpack-node-externals');

const apiConfig = {
  entry: './src/api/index.ts',
  target: 'node',
  externals: [nodeExternals()],
  output: {
    path: path.resolve(__dirname, 'dist/api'),
    filename: 'index.js',
  },
  module: {
    rules: [
      {
        test: /\.ts$/,
        use: 'ts-loader',
        exclude: /node_modules/,
      },
    ],
  },
  resolve: {
    extensions: ['.ts', '.js'],
  },
};

const uiConfig = {
  entry: './src/ui/index.tsx',
  output: {
    path: path.resolve(__dirname, 'dist/ui'),
    filename: '[name].[contenthash].js',
    clean: true,
  },
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        use: 'ts-loader',
        exclude: /node_modules/,
      },
      {
        test: /\.css$/,
        use: ['style-loader', 'css-loader'],
      },
    ],
  },
  resolve: {
    extensions: ['.tsx', '.ts', '.js'],
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: './src/ui/public/index.html',
    }),
  ],
  devServer: {
    static: {
      directory: path.join(__dirname, 'dist/ui'),
    },
    compress: true,
    port: process.env.UI_PORT || 3000,
    proxy: [
      {
        context: ['/api'],
        target: 'http://localhost:3001',
      },
    ],
  },
};

module.exports = [apiConfig, uiConfig];
