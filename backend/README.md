# Vibeit Backend

Express + TypeScript API that powers OTP auth and the internal playlists. No external music providers are used.

## Prerequisites
- Node.js 20+
- npm
- MongoDB running locally (default uri: mongodb://127.0.0.1:27017/vibeit)

## Setup & Run
1) Install deps: `npm install`
2) Copy env: `cp .env.example .env` (edit as needed)
3) Start dev server: `npm run dev`

Dev server runs on `PORT` (default 3000) and hot-reloads via ts-node-dev.

## Debugging
- VS Code: use the built-in JavaScript Debug Terminal or attach to the `npm run dev` process.
- Logs show in the terminal; unhandled errors are returned as `{ "error": "message" }`.

## Environment Variables
- `PORT` — HTTP port (default 3000)
- `MONGO_URI` — Mongo connection string (default local)
- `JWT_SECRET` — signing secret for auth tokens (set this in prod)
- `OTP_EXPIRY_MINUTES` — numeric minutes until OTP expires (default 5)

## API
All endpoints are JSON. Authenticated routes expect `Authorization: Bearer <token>`.

### Auth
- `POST /auth/request-otp`
   - body: `{ "email": "you@example.com" }`
   - returns: `{ "message": "OTP generated" }` (OTP is logged to server console for demo)
- `POST /auth/verify-otp`
   - body: `{ "email": "you@example.com", "otp": "123456" }`
   - returns: `{ "token", "user": { id, email, createdAt, dailyUsageLimit, usageToday } }`
- `GET /me`
   - headers: `Authorization: Bearer <token>`
   - returns: `{ "user": { ...same fields... } }`

### Playlists (internal source only)
- `POST /playlists`
   - headers: auth required
   - body: `{ "name": "My Playlist" }`
   - returns: `{ "playlist": { id, name, ownerId, source, createdAt, updatedAt, tracks: [] } }`
- `GET /playlists`
   - headers: auth required
   - returns: `{ "playlists": [ { ...playlist... } ] }`
- `GET /playlists/:id`
   - headers: auth required
   - returns: `{ "playlist": { ... } }`
- `POST /playlists/:id/tracks`
   - headers: auth required
   - body: `{ "title": "Track", "artist": "Artist", "album": "Album", "duration": 210 }`
   - returns: `{ "playlist": { ...updated with track... } }`
- `DELETE /playlists/:id/tracks/:trackId`
   - headers: auth required
   - returns: `{ "playlist": { ...updated... } }`

### Search (mock catalog)
- `GET /search/tracks?q=<query>`
   - headers: auth required
   - returns: `{ "tracks": [ { id, title, artist, album, duration } ] }` (results are filtered from a hardcoded list)

## Failure Tips
- 401/403: ensure you pass `Authorization: Bearer <token>` from `/auth/verify-otp`.
- 400 on OTP: check email format or expired/incorrect code; request a new OTP.
- Mongo errors: verify `MONGO_URI` and that Mongo is running locally.
- 500s: check server logs; most errors are surfaced as `{ "error": "message" }`.
