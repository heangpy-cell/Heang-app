# LINK GRAB — Flutter Mobile App

## 📁 Project Structure

```
link_grab/
├── lib/
│   ├── main.dart                    ← App entry + bottom nav shell
│   ├── models/
│   │   └── download_item.dart       ← Download data model
│   ├── providers/
│   │   └── download_provider.dart   ← State management (ChangeNotifier)
│   ├── screens/
│   │   ├── home_screen.dart         ← Main UI (paste, platforms, downloads)
│   │   ├── my_files_screen.dart     ← Completed downloads
│   │   ├── history_screen.dart      ← All download history
│   │   └── guide_screen.dart        ← How to use guide
│   └── widgets/
│       ├── platform_chip.dart       ← Platform icon buttons
│       ├── download_card.dart       ← Active download with progress bar
│       └── saved_card.dart          ← Completed file card
└── pubspec.yaml
```

## 🚀 Setup & Run

### 1. Install Flutter
Download from: https://docs.flutter.dev/get-started/install/windows

### 2. Get dependencies
```bash
cd link_grab
flutter pub get
```

### 3. Run on Android device / Emulator
```bash
flutter run
```

### 4. Build APK
```bash
flutter build apk --release
# APK at: build/app/outputs/flutter-apk/app-release.apk
```

## ✨ Features
- **PASTE** link from clipboard
- **Auto-detect** platform (TikTok, YouTube, Facebook, Instagram, Telegram, Pinterest, Twitter)
- **Progress bar** with real-time simulation
- **Pause / Stop** downloads
- **My Files** — completed downloads
- **History** — all download history
- **Settings** — HD quality, auto-detect, notifications
- **Guide** — step-by-step instructions in Khmer
