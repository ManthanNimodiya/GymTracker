# GymTracker

A local-first iOS gym tracker built with SwiftUI and SwiftData. No accounts, no cloud sync, no network dependency for your workout data — everything lives on your device.

## Features

- **Plan** — a weekly routine editor with a daily view showing today's recommended exercises, a Skip / On My Way / Done status (Skip prompts for a reason), a 7-day history strip, and tomorrow's preview.
- **Workouts** — log sessions as sets of reps and weight per exercise, browse history.
- **Exercises** — a catalog of your exercises grouped by muscle group (Chest, Back, Shoulders, Legs, Bicep, Tricep, Forearms, Abs), each with optional progress photos.
- **Progress** — a per-exercise chart of your max weight over time.
- **Steps** — today's step count via CoreMotion, opt-in with an explicit "Enable" action.
- **Explore** — a video feed pulled from a YouTube channel's public RSS feed, with a local search bar.

## Requirements

- Xcode 16 or later
- iOS 17.0+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the `.xcodeproj` is generated from `project.yml` and isn't committed

## Getting Started

```bash
git clone https://github.com/ManthanNimodiya/GymTracker.git
cd GymTracker
xcodegen generate
open GymTracker.xcodeproj
```

Build and run on a Simulator or a physical device (a free Apple ID works for local device installs; on-device builds expire after 7 days without a paid developer account).

## Architecture

- **SwiftData** for all persistence — `Exercise`, `WorkoutSession`, `ExerciseSet`, `ProgressPhoto`, `PlanDay`, `PlanExercise`, `DayCheckIn`.
- **CoreMotion** (`CMPedometer`) for step counts — chosen over HealthKit since it needs no paid-account entitlement, just the standard Motion & Fitness permission.
- No third-party dependencies.

## Privacy

Everything is stored locally via SwiftData. The only network request the app makes is fetching a public YouTube RSS feed for the Explore tab.
