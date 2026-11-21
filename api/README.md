# API contract

`openapi/dashuri.v1.yaml` is the contract between the app and the Go backend (OpenAPI 3.1). Edit it first, then update `backend/internal/modules/<module>/dto.go` and the matching Flutter JSON mappers. `backend/internal/app/app_test.go` fails if a contract path is not mounted on the router.
