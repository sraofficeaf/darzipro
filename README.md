# Darzi Pro (درزی پرو)

Production tailoring management ERP & POS platform built with Flutter Web & Mobile with Supabase backend.

## Local Development Setup

### 1. Enable Git Hooks (Required on fresh clone)
This repository includes a strict pre-push gate in `.githooks/pre-push` that compiles `flutter build web --release` before allowing any code to leave the machine. Because `core.hooksPath` is a local Git setting, you must enable it once after a fresh clone:

```bash
git config core.hooksPath .githooks
```

Once configured, any `git push` command automatically runs `flutter build web --release`. If there are compilation or type errors, the push is rejected immediately on your local machine, protecting production from deployment outages.

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run Locally
```bash
flutter run -d chrome
```
