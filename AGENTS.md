# Antigravity Agent Guidelines for Ngam & Ngam Business

## 1. Localization (l10n / i18n) Mandate — CRITICAL RULE
- **ZERO HARDCODED TEXT**: Whenever you add, modify, or refactor any UI screen, widget, dialog, toast, placeholder, label, button, error message, or notification, **NEVER** hardcode user-facing strings in Dart.
- **ALWAYS UPDATE L10N FILES**:
  1. Add/update the key in both `assets/translations/en.json` (English) and `assets/translations/ms.json` (Bahasa Melayu).
  2. Use standard dot-notation namespace hierarchy: e.g., `explore.search_hint`, `booking.confirm_title`, `account.full_name`, `feed.comment_placeholder`.
  3. Keep both `en.json` and `ms.json` strictly 1:1 symmetrical (every key in `en.json` must exist in `ms.json` and vice versa).
  4. Call `.tr()` on the string key in Dart widgets (via `package:easy_localization/easy_localization.dart`):
     ```dart
     Text('account.full_name'.tr())
     showGlassToast(context, 'account.update_success'.tr())
     ```
  5. For dynamic variables, use named args:
     ```dart
     'cart.total_items'.tr(args: [count.toString()])
     // In JSON: "total_items": "Total: {} items"
     ```

## 2. Cloudflare R2 for Storage
- Use `R2StorageService` for media/avatar/attachment uploads (zero egress fees, fast CDN via Cloudflare R2).
- Do not use `dart:io File` directly for cross-platform/web uploads; use `XFile` / `Uint8List bytes`.

## 3. Web & PWA Compatibility
- Ensure all screens and services run properly on Flutter Web/PWA as well as Android/iOS.

## 4. Auto Version Bump on Every Commit
- All repositories (`Ngam`, `Ngam_Business`, `Ngam_Admin`, `Ngam_Teams`) include shared Git hooks under `.githooks/` (`pre-commit` & `prepare-commit-msg`).
- On a fresh clone, enable them once with:
  ```bash
  git config core.hooksPath .githooks
  ```
- On every commit, the hook automatically:
  1. Bumps `pubspec.yaml` patch & build number (`X.Y.Z+B` -> `X.Y.(Z+1)+(B+1)`), unless `pubspec.yaml` was already manually bumped in the commit.
  2. Syncs `web/version.json` (`version`, `build_number`, `released_at`).
  3. Syncs `AppUpdateService.fallbackVersion` in `app_update_service.dart`.
  4. Appends `(vX.Y.Z+B)` to the commit subject if not already present.
- After completing and verifying changes, update `web/version.json`'s `changelog`, commit (letting `.githooks` bump the version), and push automatically.
- To bypass for a single commit, run `SKIP_VERSION_BUMP=1 git commit ...`.

