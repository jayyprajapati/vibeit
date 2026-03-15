# DotBeats Monorepo

Flutter + Node/Express stack for OTP auth and an internal playlist system (no external music services).

## What's inside
- `backend/` — TypeScript Express API with OTP login, playlists, Spotify OAuth (read-only), and mock track search
- `frontend/` — Flutter app (Riverpod) for auth, playlists UI, and Spotify playlists viewer

## Quick start
Backend:
- `cd backend && npm install`
- `cp .env.example .env`
- `npm run dev` (defaults to http://127.0.0.1:3000)

Frontend:
- `cd frontend && flutter pub get`
- `flutter run` (make sure `apiBaseUrl` in `lib/core/config.dart` matches your backend host)

## App flow (high level)
- Request OTP → Verify OTP → token saved
- Playlists tab: create/list/open playlists; add tracks via mock search; remove tracks; play buttons are disabled with a tooltip
- Platforms tab: connect Spotify (Authorization Code flow), view cached playlists (24h TTL), manually sync when needed; cache is used if refresh fails
- Profile tab shows account data

## If something breaks
- Backend 500/connection issues: check server logs and `MONGO_URI`; ensure server is running
- Auth 401: token missing/expired — log out and sign back in
- Mobile emulator/device: point `apiBaseUrl` to 10.0.2.2 (Android emulator) or your machine IP for physical devices
