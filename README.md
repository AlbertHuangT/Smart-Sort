# The Trash

A native iOS app that uses on-device AI to identify trash and tell you which bin it belongs in.

Point your camera at any item — the app classifies it in real-time using MobileCLIP image embeddings and tells you whether it's recyclable, compostable, landfill, or hazardous. No internet required for classification.

## Features

- **AI Trash Classification** — On-device image recognition powered by CoreML (MobileCLIP). Snap a photo and get instant results with confidence scores.
- **5 Waste Categories** — Recycle (Blue Bin), Compost (Green Bin), Landfill (Black Bin), Hazardous, and non-trash detection.
- **Arena Quiz Mode** — Test your waste sorting knowledge with timed quizzes.
- **Communities** — Join or create local communities, organize cleanup events, and compete on leaderboards.
- **Events** — Discover nearby community events with location-based sorting.
- **Leaderboards** — Friends leaderboard (via Contacts) and community rankings.
- **Gamification** — Earn credits/points for correct classifications and feedback submissions.
- **User Feedback Loop** — Swipe to confirm or correct AI results. Corrections are collected to improve future accuracy.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| AI Model | MobileCLIP (CoreML `.mlpackage`) |
| Vector Math | Accelerate / vDSP |
| Vision | Apple Vision Framework |
| Backend | Supabase (Auth, Database, Storage, RPC) |
| Auth | Email/password, Phone OTP, Anonymous |
| Dependencies | supabase-swift v2.41.0 (SPM) |

## How Classification Works

```
Camera Capture
    │
    ▼  Center crop to 224×224
MobileCLIP CoreML Model
    │
    ▼  512-dim embedding vector
Cosine Similarity vs Knowledge Base (78 items, pre-normalized)
    │
    ▼  Best match ≥ 0.10 threshold
Result: Item Name + Category + Confidence + Action Tip
```

All classification runs on-device using the Neural Engine — no network calls needed.

## Project Structure

```
The Trash/
├── App/
│   ├── The_TrashApp.swift          # App entry point
│   └── ContentView.swift           # Main TabView (5 tabs)
├── Models/
│   ├── TrashModels.swift           # TrashAnalysisResult, AppState
│   ├── CommunityModels.swift
│   ├── LeaderboardModels.swift
│   └── LocationModels.swift
├── ViewModels/
│   ├── TrashViewModel.swift        # Classification orchestration
│   ├── AuthViewModel.swift         # Auth state management
│   ├── ProfileViewModel.swift
│   └── CurrentUserViewModel.swift
├── Services/
│   ├── RealClassifierService.swift # CoreML + cosine similarity engine
│   ├── SupabaseManager.swift       # Supabase client singleton
│   ├── CommunityService.swift      # Community & event RPCs
│   ├── FeedbackService.swift       # Feedback image upload + logging
│   ├── FriendService.swift         # Contacts-based friend matching
│   ├── UserSettings.swift          # Location, preferences, cache
│   └── LocationManager.swift       # CLLocationManager wrapper
├── Views/
│   ├── Verify/                     # Camera → classify → feedback flow
│   ├── Arena/                      # Quiz mode
│   ├── Community/                  # Community browsing & management
│   ├── Leaderboard/                # Rankings
│   ├── Account/                    # Profile, phone/email binding
│   ├── Auth/                       # Login
│   └── Shared/                     # Reusable components
├── trash_knowledge.json            # Pre-computed embeddings (78 items)
├── MobileCLIPImage.mlpackage       # CoreML model (gitignored)
└── migrations/                     # SQL migration reference copies
```

## Build & Run

**Requirements:** Xcode 16+, iOS 17+

```bash
# Clone
git clone <repo-url>
cd "The Trash"

# Open in Xcode
open "The Trash.xcodeproj"

# Or build from command line
xcodebuild -project "The Trash.xcodeproj" \
  -scheme "The Trash" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

**Setup:**
1. Add `Secrets.swift` with your Supabase credentials (gitignored)
2. Ensure `MobileCLIPImage.mlpackage` is in the project directory (gitignored)
3. Resolve Swift packages in Xcode (supabase-swift)

## Backend (Supabase)

The app uses Supabase for everything server-side:

- **Auth** — Email/password, phone OTP, anonymous sign-in
- **Database** — Postgres with RPC functions for all business logic
- **Storage** — `feedback_images` bucket for user-submitted corrections
- **RLS** — Row Level Security on all tables

Key RPC functions: `increment_credits`, `get_communities_by_city`, `join_community`, `get_nearby_events`, `find_friends_leaderboard`, etc.

SQL migrations are in `supabase/migrations/` and `The Trash/migrations/`.

## License

All rights reserved.
