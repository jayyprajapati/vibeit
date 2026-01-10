# Vibeit Backend

Express + TypeScript API that powers OTP auth, internal playlists, and read-only integrations with Spotify and YouTube Music.

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
- `SPOTIFY_CLIENT_ID` — Spotify app client id
- `SPOTIFY_CLIENT_SECRET` — Spotify app client secret
- `SPOTIFY_REDIRECT_URI` — backend callback registered in Spotify (e.g. https://<ngrok-id>.ngrok-free.app/spotify/callback)
- `SPOTIFY_FRONTEND_REDIRECT` — where to send the user after a successful/failed Spotify auth (e.g. http://localhost:5173/platforms)
- `GOOGLE_CLIENT_ID` — Google OAuth client id (YouTube Music)
- `GOOGLE_CLIENT_SECRET` — Google OAuth client secret (YouTube Music)
- `YTM_REDIRECT_URI` — backend callback registered in Google Cloud Console (e.g. https://<ngrok-id>.ngrok-free.app/ytm/callback)
- `YTM_FRONTEND_REDIRECT` — where to send the user after a successful/failed YTM auth (e.g. http://localhost:5173/platforms)

Note: Spotify does not accept plain `http://` redirect URIs for production or some dev accounts; use a secure `https://` URL. For local development you can expose your local backend via ngrok and use the generated `https://<ngrok-id>.ngrok-free.app` domain as `SPOTIFY_REDIRECT_URI` and Spotify App Redirect URL.

Example ngrok flow:
1. Run your backend locally: `npm run dev` (server on port 3000)
2. Run `ngrok http 3000` to get a public HTTPS URL (e.g., `https://abcd1234.ngrok-free.app`).
3. In the Spotify Developer Dashboard, set your app's Redirect URI to `https://<ngrok-id>.ngrok-free.app/spotify/callback` and save.
4. Set `SPOTIFY_REDIRECT_URI` in your backend `.env` to match the ngrok URL and restart the server.
5. Ensure your Flutter `apiBaseUrl` points to your backend (if you run your mobile app on a device/emulator, use the ngrok URL for public access).

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

### Spotify (read-only)
- `GET /spotify/auth-url`
   - headers: auth required
   - returns: `{ "url": "https://accounts.spotify.com/..." }` (open in browser)
- `GET /spotify/callback`
   - handles Spotify redirect, stores tokens, then redirects to `SPOTIFY_FRONTEND_REDIRECT`
- `GET /spotify/playlists`
   - headers: auth required
   - returns cached playlists if fetched within the last 24h, otherwise refreshes from Spotify and updates the cache
- `POST /spotify/sync-now`
   - headers: auth required
   - forces an immediate refresh from Spotify and updates cache + timestamps

### YouTube Music (read-only)
- `GET /ytm/auth-url`
   - headers: auth required
   - returns: `{ "url": "https://accounts.google.com/..." }` (open in browser)
- `GET /ytm/callback`
   - handles Google redirect, stores tokens, then redirects to `YTM_FRONTEND_REDIRECT`
- `GET /ytm/playlists`
   - headers: auth required
   - increments daily usage; returns cached playlists if fetched within the last 24h, otherwise refreshes from YouTube Music and updates the cache
- `POST /ytm/sync-now`
   - headers: auth required
   - increments daily usage; forces an immediate refresh from YouTube Music and updates cache + timestamps
   - returns `429` with `{ "error": "Daily usage limit exceeded for YouTube Music" }` if the user's `usageToday` meets `dailyUsageLimit`

## Failure Tips
- 401/403: ensure you pass `Authorization: Bearer <token>` from `/auth/verify-otp`.
- 400 on OTP: check email format or expired/incorrect code; request a new OTP.
- Mongo errors: verify `MONGO_URI` and that Mongo is running locally.
- 500s: check server logs; most errors are surfaced as `{ "error": "message" }`.
