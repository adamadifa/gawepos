# AGENTS.md — posmobile (WarungPro)

## Project

Offline-first Flutter POS app ("WarungPro") for Indonesian UMKM. Single-module, no monorepo.

## Commands

```sh
# dependencies
flutter pub get

# regenerate Drift code after schema changes
dart run build_runner build --delete-conflicting-outputs

# test, analyze
flutter test
flutter analyze

# release
flutter build apk --release
```

## Architecture

- **2-layer per feature**: `data/` (repository → Drift DAO), `presentation/` (cubit + pages). No domain layer.
- **State**: flutter_bloc Cubits only (no Events/Bloc classes). State pattern: `Initial / Loading / Loaded / Error`.
- **DI**: `GetIt` singleton locator (`core/di/injection.dart`). Repos → `LazySingleton`, cubits → `Factory` (except `CartCubit` → `LazySingleton`).
- **DB**: Drift SQLite (`lib/core/database/app_database.dart`), 25 tables, schemaVersion 5. MigrationStrategy handles upgrades.
- **Auth**: SHA-256 PIN hash. Default admin PIN: `1234` (username `admin`).
- All repositories share one `AppDatabase` instance. Complex writes (saveOrder, insertProductComplete) use `_db.transaction(...)`.
- Generated file: `app_database.g.dart`. Always rebuild after table changes.
- All code comments in **Bahasa Indonesia**.

## Testing

- Use `NativeDatabase.memory()` for isolated DB tests (see `test/auth_test.dart` for pattern).
- Follow existing test file structure: inline mocks, no separate mock files.

## Conventions

- No `equatable`/`freezed` — plain Dart state classes.
- No DTOs/mappers — Drift-generated models flow directly into cubit states and UI.
- JSON stored in text columns for `allowedMenus` and `cartData`.
- Material 3, custom Indigo Blue palette (`AppConstants`), Poppins font (`google_fonts`).
- Bluetooth printing via `blue_thermal_printer` + `esc_pos_utils_plus`.

## Features

| Dir | Purpose |
|---|---|
| `auth/` | Onboarding, PIN login, shift open/close, user & role management |
| `pos/` | Cart, checkout, payment (cash/QRIS/card/debt), held orders, printer settings |
| `master/` | CRUD: products (multi-unit, price tiers), categories, brands, customers, suppliers |
| `inventory/` | Stock card, opname, returns (sales & purchase), debt tracking |
| `purchases/` | Purchase orders from suppliers (pending→ordered→received) |
| `expenses/` | Record daily operational expenses |
| `reports/` | Dashboard, P&L, sales/purchase/stock/expense/shift reports, PDF export |
