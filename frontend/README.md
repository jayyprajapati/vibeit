# Vibeit Frontend

Flutter app (Riverpod) that handles OTP login and an internal playlist UI (create/list/detail/add/remove tracks). It talks to the backend in `../backend` for auth, playlists, and mock track search.

## Prerequisites
- Flutter (stable channel)
- A running backend (default at http://127.0.0.1:3000)

## Install deps
```
cd frontend
flutter pub get
```

## Run / debug
- Standard run: `flutter run`
- Clean build artifacts: `flutter clean`
- Update packages: `flutter pub upgrade`
- Debugging: use `flutter run -d <device>` or VS Code/Android Studio debug tools. The API base URL is set in `lib/core/config.dart` (default 127.0.0.1:3000); adjust if your backend is on a device/remote.

## App flow (current state)
- Email screen → request OTP via `/auth/request-otp`
- OTP screen → verify via `/auth/verify-otp`, stores token
- Main shell tabs: Playlists, Platforms (static), Profile
- Playlists tab: create playlist, list user playlists, open details
- Playlist detail: shows tracks, disabled play buttons with tooltip, remove track, add track via search
- Track search: queries `/search/tracks` (hardcoded catalog) and can add to playlist

## Backend dependency
- All playlist/search operations and auth require the backend running and reachable at `apiBaseUrl`.

## Failure tips
- 401/Unauthorized: token missing/expired; log out and re-login.
- Network errors: confirm backend is running and `apiBaseUrl` matches your device host (emulator may need 10.0.2.2 or device IP).
- Empty playlists: create one with the Create button; search uses the mock catalog only.
