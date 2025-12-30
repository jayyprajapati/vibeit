# Vibeit Monorepo

Flutter frontend and Node.js/Express backend. This phase covers infrastructure only.

## Structure
- backend/ — Express + TypeScript API
- frontend/ — Flutter app

## Prerequisites
- Node.js 20+
- npm
- Flutter (stable channel)

## Backend
1. Change into the backend directory:
   cd backend
2. Install dependencies:
   npm install
3. Create env file:
   cp .env.example .env
4. Start dev server:
   npm run dev

The server listens on PORT (defaults to 3000) and exposes GET /health.

## Frontend
1. Change into the frontend directory:
   cd frontend
2. Fetch dependencies:
   flutter pub get
3. Run on an Android emulator or device:
   flutter run

The app shows a single dark-themed screen with the text "Vibeit - Setup Complete".

## Environment Variables
- PORT: HTTP port for the backend (default 3000)
