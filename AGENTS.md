# 🤖 AGENTS.md — Rules for AI Agents & Contributors

> **This file is the single source of truth for any AI agent (Claude Code, Cursor, Copilot, Gemini CLI, etc.) or new contributor working on this repository. Read it fully BEFORE making any change, and follow every rule.**
>
> **این فایل مرجع اصلی قوانین برای هر هوش مصنوعی یا توسعه‌دهنده‌ای است که روی این ریپو کار می‌کند. قبل از هر تغییری آن را کامل بخوان و به همهٔ قوانین پایبند باش.**

---

## 1. Project identity — do not break these

This is **Smart Day Planner (دستیار روزانه هوشمند ایرانی)**:

- **Stack:** Flutter / Dart — Android + iOS, **offline-first**, no paid APIs by default.
- **Language & UX:** Persian UI, right-to-left (RTL), **Shamsi (Jalali) calendar**, currency is **Toman**.
- **State management:** Riverpod providers + `ChangeNotifier` repositories.
- **Storage:** `sqflite` for tasks & finance (`DatabaseService`), `shared_preferences` for the rest.
- **Security (never weaken):** PIN hashing = PBKDF2-HMAC-SHA256 (100k iterations); backups = PBKDF2 (200k) + **AES-GCM** (`backupFormatVersion = 2`). No plain SHA-256, no CBC, no hardcoded secrets.
- **Feature flags:** risky platform features are gated with `bool.fromEnvironment` (`FeatureFlags`, `ENABLE_*`). Respect them.
- **CI:** `.github/workflows/flutter_ci.yml` runs `flutter test` + builds a debug APK on every push to `main`. Keep it green.

## 2. Before you touch anything

1. Read `docs/PROJECT_STATE.md` and this `AGENTS.md`.
2. Read the code around what you are changing (including its tests).
3. Never assume — this codebase is large (20k+ lines); search before editing (`grep` is your friend).

## 3. Architecture rules (where code must live)

- `lib/domain/` — pure Dart: repository **ports/interfaces** and use-cases. No Flutter/plugin imports.
- `lib/models/` — immutable data models with `toJson`/`fromJson`.
- `lib/services/` — real implementations (repositories, planners, NLU, crypto, platform wrappers).
- `lib/application/` — action controllers / coordinators (glue between UI and repositories).
- `lib/presentation/` + `lib/screens/` + `lib/widgets/` — UI only.
- **Never** put business logic in widgets; **never** call `SharedPreferences`/`sqflite` directly from UI — always go through a repository/service.
- **Never** bypass a repository port to reach a concrete repository in application/domain layers.

## 4. Persian & locale rules

- All user-facing strings are **Persian** and the UI stays **RTL**.
- Numbers → `PersianFormat.digits(...)`; money → `PersianFormat.money(...)`; dates → `PersianFormat.jalaliDate/jalaliLong(...)`; durations → `PersianFormat.minutes(...)`.
- **Never** print raw English digits or Gregorian dates to the user.
- Dates/calendar logic must use `shamsi_date` (`Jalali`) for anything the user sees (month ranges, week starts on **Saturday**, etc.).
- Keep `fa_IR` localization setup in `main.dart` intact.

## 5. Data & migration safety

- Money amounts are stored as **positive ints (Toman)** with a `type` field (`income`/`expense`); sign is derived (`signedAmount`).
- **Do NOT rename/remove keys** in `toJson`/`fromJson` of models used in backups (`Task`, `FinanceTransaction`, `DebtItem`, `MoneyAllocation`, `PlannedExpenseGoal`, `CategoryBudget`) — that breaks restore of existing encrypted backups.
- **Do NOT change the encrypted backup format** (`type`, `format`, `salt`, `iv`, `data`, `iterations` fields in `BackupService`) without a migration path for `backupFormatVersion`.
- **Do NOT change the sqflite schema** (`DatabaseService`) without an explicit migration (`onUpgrade`).
- Keep `fromJson` tolerant (use `??` defaults and `firstWhere(..., orElse:)`) so old data still loads.

## 6. Security rules (hard rules)

- Never weaken PBKDF2 iteration counts or switch AES-GCM back to AES-CBC/SHA-256.
- Never commit tokens, API keys, passwords, or credentials of any kind. (The repository must contain no `ghp_...` or similar secrets.)
- Never hardcode an API key in source; use `--dart-define` or `OnlineAiConfig` user settings.
- Keep constant-time comparisons for PIN verification (`SecurityService`).

## 7. Feature-flag rules

- New risky platform features (voice, calendar, notifications, PDF/share, encrypted backup, offline LLM/speech) **must** be wrapped in a `FeatureFlags.ENABLE_*` flag.
- A flag = `bool.fromEnvironment('ENABLE_X', defaultValue: ...)`. Safe builds ship with risky flags **off**.
- Update `test/feature_flags_test.dart` and `test/feature_gating_widget_test.dart` when adding/changing flags.

## 8. Testing rules (strict)

- Every behavior change / bugfix **must** come with or update a test.
- Tests live in `test/`, are plain Dart + `flutter_test`, use fakes from `test/fakes/` — no real device.
- Run before pushing: `flutter test --exclude-tags=needs-real-device`.
- Keep the full suite green (currently ~250 tests, 5 skipped).
- Logic-heavy classes (planners, NLU, crypto, insight services) are **pure** and must stay pure for easy testing — do not add plugin/UI dependencies to them.

## 9. Commit & Git rules

- Commit messages are in **Persian**, match existing style, start with a type prefix:
  - `fix:` / `feat:` / `refactor:` / `docs:` / `test:` / `chore:`
- **One logical change per commit** (do not mix a bugfix with an unrelated refactor).
- Never commit build artifacts: `build/`, `*.apk`, `*.aab`, `.dart_tool/` (already in `.gitignore`).
- Push to `main` triggers CI — do not leave the branch red.

## 10. Code quality rules

- No dead code, no unused imports/variables, no commented-out blocks left behind.
- `analyze` clean: run `flutter analyze` when possible.
- Keep files focused; split a file that is growing instead of making a giant one (project convention).
- Async: never `await` long work on the UI thread unnecessarily; handle errors; avoid silent `catch (_)` except where intentional and documented.
- Pure functions over singletons when a class has no state (e.g. `const SmartPlanner()`).
- Respect `analysis_options.yaml` lints.

## 11. Environment constraints

- Some sandboxes have **no Flutter/Dart installed**. If you cannot run `flutter analyze`/`flutter test`, you MUST:
  1. Make edits carefully and verify syntax/logic by reading.
  2. Not claim tests pass — say they must run on CI.
  3. Rely on GitHub Actions CI as the source of truth, and check its result.
- Do not run a dev server for this project unless asked.

## 12. Behavior-preservation rule

- When asked to fix something, fix **that** — do not rewrite unrelated code, do not reformat whole files, do not change public behavior unless requested or clearly part of the fix.
- If a change could affect user data (backup, migrations, crypto), call it out explicitly.

---

## 📌 Quick checklist (run through this before finishing any task)

- [ ] Read `docs/PROJECT_STATE.md` + this file
- [ ] Change is in the right layer (domain/models/services/application/presentation)
- [ ] Persian strings & `PersianFormat` used for any user-visible text/number/date
- [ ] No backup/DB/schema key changes without migration
- [ ] Security not weakened
- [ ] New risky feature gated behind `FeatureFlags`
- [ ] Test added/updated and suite expected green
- [ ] One-concern commit with a Persian `fix:`/`feat:`-style message
- [ ] No secrets, no build artifacts committed
