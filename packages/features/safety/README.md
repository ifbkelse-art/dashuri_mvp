# feature_safety

User-facing safety: reporting, blocking, age eligibility, enforcement notices and appeals.

## Layers

| Layer | Folder | Contents |
|---|---|---|
| Domain | `lib/src/domain/` | Entities: `ReportReceipt`, `BlockedUser`, `AgeStatus`, `EnforcementNotice`, `AppealReceipt`; contract `SafetyRepository`; one use case per action |
| Data | `lib/src/data/` | `SafetyRemoteDataSource` (Go API), JSON mappers, `SafetyRepositoryImpl` |
| Application | `lib/src/application/` | `BlockedUsersCubit` (add more cubits/blocs per page) |
| Presentation | `lib/src/presentation/` | **Founder-owned pages and widgets** |
| Wiring | `lib/src/di/`, `lib/src/routes/` | `registerSafetyFeature(sl)`, `SafetyRoutes` |

## API endpoints used

| Use case | Method | Path | Idempotency-Key |
|---|---|---|---|
| `ReportUser` | POST | `/v1/reports` | required |
| `BlockUser` | POST | `/v1/blocks` | required |
| `UnblockUser` | DELETE | `/v1/blocks/{userId}` | — |
| `ListBlockedUsers` | GET | `/v1/blocks` | — |
| `GetAgeStatus` | GET | `/v1/me/age` | — |
| `SubmitAgeDeclaration` | POST | `/v1/me/age/declaration` | required |
| `ListEnforcementNotices` | GET | `/v1/me/enforcement` | — |
| `SubmitAppeal` | POST | `/v1/appeals` | required |

## Business rules and notes

- Minor protection is mandatory (S7). A self-declared date of birth is the minimum gate, not proof of age; hosts are age-verified through KYC.
- Reporting during a call must also end the call: the call screen calls the video_call EndCall use case, then opens the report route.
- Moderation review, enforcement decisions and evidence handling are backend/admin only; there is no moderator UI in the mobile app.

## Pages to build

- ReportSheet (RoutePaths.report, also opened from the call screen)
- BlockedUsersPage (RoutePaths.blockedUsers)
- AgeGatePage (RoutePaths.ageGate)
- Enforcement notice and appeal pages
