# The Trash Architecture

## 1. System Overview

The Trash is an Expo + React Native app backed by Supabase.

- Frontend: Expo Router + React Native + Zustand
- Local AI: `src/services/classifier.js` + `assets/trash_knowledge.json`
- Backend: Supabase Auth / Postgres RPC / Realtime / Edge Functions
- Source of truth for DB schema: `supabase/migrations/`

## 2. Frontend Structure

### App shell

- `the-trash-rn/app/_layout.js`: root providers and navigation stack
- `the-trash-rn/app/index.js`: auth/guest entry
- `the-trash-rn/app/(tabs)/`: tab routes (verify/arena/leaderboard/community/profile)
- `the-trash-rn/app/(modals)/`: modal flows (account, invite, location, history, etc.)

### State layer

- `the-trash-rn/src/stores/authStore.js`: auth session state
- `the-trash-rn/src/stores/trashStore.js`: camera + classify flow
- `the-trash-rn/src/stores/arenaStore.js`: duel/game state machine
- `the-trash-rn/src/stores/communityStore.js`: events/groups/admin actions
- `the-trash-rn/src/stores/leaderboardStore.js`: leaderboard + communities

### Service layer

- `the-trash-rn/src/services/supabase.js`: Supabase client bootstrap
- `the-trash-rn/src/services/auth.js`: sign-in/up/phone OTP
- `the-trash-rn/src/services/account.js`: bind phone/email, upgrade guest
- `the-trash-rn/src/services/arena.js`: RPC facade for arena modes
- `the-trash-rn/src/services/community.js`: events/groups/community RPC
- `the-trash-rn/src/services/leaderboard.js`: community/friends ranking

## 3. Backend Contract

- SQL migrations live in `supabase/migrations/` only.
- RPC drift checks:
  - `scripts/check_backend_contracts.sh`
  - `scripts/check_migration_mirror.sh`
- Convenience commands:
  - `make contracts`
  - `make migrations-check`
  - `make doctor`

## 4. Main User Flows

### Verify

1. Capture photo (`src/components/camera/CameraView.js`)
2. Run classifier (`src/services/classifier.js`)
3. Save result/history (`src/stores/trashStore.js`)
4. Optional correction feedback (`src/services/feedback.js`)

### Arena

1. Create/accept challenge via RPC (`src/services/arena.js`)
2. Sync duel events via realtime (`src/services/realtime.js`)
3. Persist duel state + finalize results (`src/stores/arenaStore.js`)

### Community

1. Resolve city/location (`src/stores/locationStore.js`)
2. Fetch events/groups (`src/services/community.js`)
3. Join RSVP/admin moderation actions (`src/stores/communityStore.js`)

### Auth & Account

1. Login/signup/phone OTP (`src/services/auth.js`)
2. Bind email/phone or upgrade guest (`src/services/account.js`)
3. Refresh session/profile (`src/stores/authStore.js`)

## 5. Current Gaps

1. No automated unit/integration tests in RN workspace.
2. `arenaStore` is large and could be split by mode/realtime concerns.
3. Several modules currently swallow errors in UI and only log warnings.
