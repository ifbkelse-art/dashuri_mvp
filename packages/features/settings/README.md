# feature_settings

Privacy consents, account deletion and personal-data export requests (DPDP), plus links to other settings sections.

## Layers

| Layer | Folder | Contents |
|---|---|---|
| Domain | `lib/src/domain/` | Entities: `ConsentState`, `DeletionRequest`, `DataExportRequest`; contract `SettingsRepository`; one use case per action |
| Data | `lib/src/data/` | `SettingsRemoteDataSource` (Go API), JSON mappers, `SettingsRepositoryImpl` |
| Application | `lib/src/application/` | `SettingsCubit` (add more cubits/blocs per page) |
| Presentation | `lib/src/presentation/` | **Founder-owned pages and widgets** |
| Wiring | `lib/src/di/`, `lib/src/routes/` | `registerSettingsFeature(sl)`, `SettingsRoutes` |

## API endpoints used

| Use case | Method | Path | Idempotency-Key |
|---|---|---|---|
| `GetConsents` | GET | `/v1/me/consents` | — |
| `UpdateConsents` | PUT | `/v1/me/consents` | — |
| `RequestAccountDeletion` | POST | `/v1/me/deletion-requests` | required |
| `RequestDataExport` | POST | `/v1/me/data-exports` | required |

## Business rules and notes

- Account deletion cannot erase ledger records that law or tax rules require Dashuri to keep; the server anonymises instead. Retention periods need a lawyer's review (DPDP).
- Non-sensitive local preferences (theme, last tab) use `dashuri_storage` `KeyValueStore` and need no API.

## Pages to build

- SettingsPage (RoutePaths.settings)
