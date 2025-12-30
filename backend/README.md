# Vibeit Backend

Node.js + Express + TypeScript service for the Vibeit monorepo.

## Prerequisites
- Node.js 20+
- npm

## Setup
1. Install dependencies:
   npm install
2. Copy environment template and adjust if needed:
   cp .env.example .env
3. Start the dev server:
   npm run dev

## Environment
- PORT: Port for the HTTP server (defaults to 3000 if unset)

## Scripts
- npm run dev: Start the server with ts-node-dev for live reload.

## Endpoints
- GET /health → { "status": "ok" }
