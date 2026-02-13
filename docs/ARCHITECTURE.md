# The Trash Architecture

## 1. System Overview

The app is a SwiftUI iOS client with a local CoreML classifier and Supabase backend.

- Frontend: SwiftUI + Theme system + Feature-based views
- Local AI: `RealClassifierService` (MobileCLIP embedding + cosine similarity)
- Backend: Supabase Auth / Postgres / RPC / Realtime / Storage

## 2. Frontend Layers

### App shell

- `The Trash/App/The_TrashApp.swift`
  - App entry, dependency wiring (`AuthViewModel`, `TrashViewModel`, `ThemeManager`)
- `The Trash/App/ContentView.swift`
  - Root tab shell and custom bottom tab bar

### Theme abstraction layer

- `The Trash/Theme/TrashTheme.swift` (protocol + semantic tokens)
- `The Trash/Theme/ThemeComponents.swift` (cross-feature shared controls)
- `The Trash/Theme/NeumorphicTheme.swift`
- `The Trash/Theme/VibrantTheme.swift`
- `The Trash/Theme/EcoSkeuomorphicTheme.swift`

### Feature modules

- Verify: `The Trash/Views/Verify/`
- Arena: `The Trash/Views/Arena/`
- Leaderboard: `The Trash/Views/Leaderboard/`
- Community: `The Trash/Views/Community/`
- Account/Auth/Admin/Profile: `The Trash/Views/{Account,Auth,Admin,Profile}/`

## 3. Backend Layers

### Client gateway

- `The Trash/Services/SupabaseManager.swift`
  - Single Supabase client instance

### Domain services

- `CommunityService`: community/event/admin RPC and table access
- `ArenaService` + `DuelRealtimeManager`: duel and realtime sync
- `FriendService`: contacts sync + leaderboard RPC
- `FeedbackService`: Storage upload + feedback log insert
- `AchievementService`: achievements and trigger RPCs

### SQL source of truth

- `supabase/migrations/` is backend schema source
- `The Trash/migrations/` is app-side mirror used for reference

## 4. End-to-end Interaction Flows

### Verify flow

1. Camera capture (`CameraManager`)
2. Local classify (`RealClassifierService`)
3. State update (`TrashViewModel.appState`)
4. Optional feedback upload (`FeedbackService`)
5. Gamification RPC (`increment_credits` + achievements)

### Community/Event flow

1. Location selection (`UserSettings` + `LocationManager`)
2. Events/communities fetch via `CommunityService` RPC
3. Join/register actions via RPC with optimistic UI updates
4. Admin actions (approval/remove/grant credits) via RPC

### Arena flow

1. Challenge/create/accept via `ArenaService`
2. Question/answer submit RPC
3. Duel realtime broadcast sync via `DuelRealtimeManager`

## 5. Audit Findings (this pass)

### Fixed

- Global width overflow caused by theme background decorative layers expanding root layout
  - Fixed with container-bound sizing and clipping in theme background wrappers
- Community tab page container issue
  - Replaced `.page` `TabView` in `CommunityView` with explicit conditional rendering

### Detected contract risk

- RPC usage and migration functions are not fully aligned between:
  - Swift calls
  - `supabase/migrations`
  - `The Trash/migrations`

Use `scripts/check_backend_contracts.sh` to verify drift.

## 6. Recommended Next Refactors

1. Split service DTOs from domain models (avoid large model files)
2. Introduce per-feature `Repository` protocol to improve testability
3. Add `The TrashTests` for ViewModel + Service contract tests
4. Add CI step to run `scripts/check_backend_contracts.sh`
