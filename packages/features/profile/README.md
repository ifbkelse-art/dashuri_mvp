# feature_profile

The signed-in user's profile, other users' public profiles, profile photos and the shared account level (XP).

## Layers

| Layer | Folder | Contents |
|---|---|---|
| Domain | `lib/src/domain/` | Entities: `Profile`, `LevelProgress`, `PhotoUploadTicket`; contract `ProfileRepository`; one use case per action |
| Data | `lib/src/data/` | `ProfileRemoteDataSource` (Go API), JSON mappers, `ProfileRepositoryImpl` |
| Application | `lib/src/application/` | `MyProfileCubit` (add more cubits/blocs per page) |
| Presentation | `lib/src/presentation/` | **Founder-owned pages and widgets** |
| Wiring | `lib/src/di/`, `lib/src/routes/` | `registerProfileFeature(sl)`, `ProfileRoutes` |

## API endpoints used

| Use case | Method | Path | Idempotency-Key |
|---|---|---|---|
| `GetMyProfile` | GET | `/v1/me/profile` | — |
| `UpdateMyProfile` | PATCH | `/v1/me/profile` | — |
| `GetProfile` | GET | `/v1/profiles/{userId}` | — |
| `GetMyLevel` | GET | `/v1/me/level` | — |
| `RequestPhotoUpload` | POST | `/v1/me/photos/upload-tickets` | required |

## Business rules and notes

- Level and XP are read-only here. XP = 8 × eligible Diamonds purchased + eligible Beans earned is computed by the backend `levels` module; one shared level per account.
- Level thresholds, names and rewards are unresolved business decisions; render whatever the API returns.
- Photo upload: request a signed upload ticket from the API, upload directly to Supabase Storage with it, then the backend moderates and attaches the photo.

## Pages to build

- MyProfilePage (RoutePaths.myProfile)
- EditProfilePage (RoutePaths.editProfile)
- PublicProfilePage (RoutePaths.hostProfile)
