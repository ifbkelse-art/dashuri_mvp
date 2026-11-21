# API contracts

- **Contract file:** `api/openapi/dashuri.v1.yaml` (OpenAPI 3.1). It covers 60 versioned endpoints plus `/healthz` and `/readyz`.
- **Structural checks:** the generator verified that every `$ref` resolves, operationIds are unique and path parameters are declared. An external linter (Redocly or Spectral) was not run in this environment; add one to CI.
- **Route coverage:** `backend/internal/app/app_test.go` checks that every contract path is mounted on the Go router and requires authentication.

## Conventions

| Topic | Rule |
|---|---|
| Versioning | `/v1/...`; additive changes only within v1 |
| Auth | `Authorization: Bearer <Supabase access token>`. Webhooks use provider signatures or OIDC instead. |
| Wire format | JSON, snake_case. Integers for every amount: Diamonds, Beans, `*_paise`. Timestamps are RFC 3339 UTC. |
| Lists | Cursor pagination: `?cursor=&limit=` (1–100, default 20) → `{items, next_cursor}` |
| Errors | `application/problem+json` with stable `code`; business refusals are 409 with `code: business_rule` and `rule: <name>` |
| Idempotency | `Idempotency-Key` header (UUID per user intent) required where marked; replay returns the stored response with `Idempotent-Replayed: true`; same key + different body → 422 |
| Not yet built | Returns 501 `not_implemented`; payouts return 503 `payouts_not_enabled` until R3-7 |

## Endpoints

✓ in the **Idem** column means an Idempotency-Key is required.

### Account, privacy, level

| Method | Path | Request | Response | Idem | Notable errors |
|---|---|---|---|---|---|
| GET | /v1/me | — | AccountStatus | | |
| GET / PATCH | /v1/me/profile | UpdateProfileRequest | Profile | | profile_text_rejected |
| GET | /v1/profiles/{userId} | — | Profile | | not_found (also when blocked) |
| POST | /v1/me/photos/upload-tickets | PhotoUploadTicketRequest | PhotoUploadTicket | ✓ | photo_limit_reached |
| GET | /v1/me/age | — | AgeStatus | | |
| POST | /v1/me/age/declaration | AgeDeclarationRequest | AgeStatus | ✓ | under_18, declaration_locked |
| GET / PUT | /v1/me/consents | UpdateConsentsRequest | ConsentState | | |
| POST | /v1/me/deletion-requests | — | DeletionRequest (202) | ✓ | pending_balance_or_payout |
| POST | /v1/me/data-exports | — | DataExportRequest (202) | ✓ | |
| GET | /v1/me/level | — | LevelProgress | | |

### Discovery, host, payouts

| Method | Path | Request | Response | Idem | Notable errors |
|---|---|---|---|---|---|
| GET | /v1/discovery/hosts | cursor, limit | Page\<HostCard\> | | |
| GET | /v1/host | — | HostStatus | | |
| POST | /v1/host/application | — | HostStatus | ✓ | not_age_eligible, already_applied, host_applications_closed |
| POST | /v1/host/kyc/sessions | — | KycSession | ✓ | |
| PUT | /v1/host/availability | SetAvailabilityRequest | HostStatus | | host_not_approved, in_call |
| POST | /v1/host/availability/heartbeat | — | 204 | | |
| PUT | /v1/host/rate | SetRateRequest (500–10,000) | HostStatus | | rate_outside_level_limits |
| PUT | /v1/host/free-call-opt-in | SetFreeCallOptInRequest | HostStatus | | |
| GET | /v1/host/earnings | — | HostEarnings | | |
| POST | /v1/host/withdrawals | WithdrawalRequest (≥ 100,000 Beans) | Withdrawal (201) | ✓ | payouts_not_enabled (503), below_minimum_withdrawal, insufficient_available_beans, kyc_required, payout_method_missing, account_restricted |
| GET | /v1/host/withdrawals | cursor, limit | Page\<Withdrawal\> | | |

### Free Call Card and calls

| Method | Path | Request | Response | Idem | Notable errors |
|---|---|---|---|---|---|
| GET | /v1/free-call/card | — | FreeCallCard | | |
| POST | /v1/free-call/requests | FreeCallRequestBody (Play Integrity token) | FreeCallRequest | ✓ | free_call_unavailable_on_platform, card_already_used, device_already_used, integrity_check_failed |
| GET | /v1/free-call/requests/{requestId} | — | FreeCallRequest | | |
| POST | /v1/calls | CallRequestBody | CallSession (201) | ✓ | host_unavailable, host_busy, blocked, insufficient_diamonds, caller_in_call, not_age_eligible, account_restricted, self_call |
| GET | /v1/calls/{callId} | — | CallSession | | |
| POST | /v1/calls/{callId}/accept, /decline | — | CallSession | | illegal_call_transition, call_expired |
| POST | /v1/calls/{callId}/end | EndCallRequest {reason} | CallSession | ✓ | |
| POST | /v1/calls/{callId}/credentials | — | CallCredentials | | call_not_joinable |
| POST | /v1/webhooks/video/{provider} | raw | 204 | | invalid_signature |

### Chat, wallet, purchases

| Method | Path | Request | Response | Idem | Notable errors |
|---|---|---|---|---|---|
| GET / POST | /v1/conversations | StartConversationRequest | Page\<Conversation\> / Conversation | ✓ (POST) | messaging_not_allowed, blocked |
| GET / POST | /v1/conversations/{id}/messages | SendMessageRequest (≤ 1,000 chars) | Page\<ChatMessage\> / ChatMessage | ✓ (POST) | messaging_not_allowed, blocked, message_rejected |
| GET / PUT | /v1/me/messaging-privacy | MessagingPrivacy | MessagingPrivacy | | |
| GET | /v1/wallet | — | WalletSummary | | |
| GET | /v1/wallet/entries | cursor, limit | Page\<WalletEntry\> | | |
| GET | /v1/purchases/packages | — | DiamondPackageList | | |
| POST | /v1/purchases/google-play | VerifyGooglePlayRequest | PurchaseVerification | ✓ (+ unique token) | purchase_token_invalid, purchase_already_used_by_other_account, product_unknown |
| POST | /v1/webhooks/google-play/rtdn | Pub/Sub push | 204 | | |

### Safety, notifications, staff

| Method | Path | Request | Response | Idem |
|---|---|---|---|---|
| POST | /v1/reports | ReportRequest | ReportReceipt | ✓ |
| POST / GET | /v1/blocks | BlockRequest | BlockedUser / Page | ✓ (POST) |
| DELETE | /v1/blocks/{userId} | — | 204 | |
| GET | /v1/me/enforcement | — | Page\<EnforcementNotice\> | |
| POST | /v1/appeals | AppealRequest | AppealReceipt | ✓ |
| PUT | /v1/me/devices | DeviceRegistration | 204 | |
| DELETE | /v1/me/devices/{token} | — | 204 | |
| GET | /v1/notifications | — | Page\<InboxItem\> | |
| POST | /v1/notifications/{id}/read | — | 204 | |
| GET | /v1/admin/moderation/queue *(moderator)* | — | Page\<ModerationCase\> | |
| POST | /v1/admin/reports/{id}/decisions *(moderator)* | ModerationDecisionRequest | ModerationDecision | ✓ |
| POST | /v1/admin/appeals/{id}/decisions *(moderator, different reviewer)* | AppealDecisionRequest | ModerationDecision | ✓ |
| GET | /v1/admin/ledger/reconciliation *(finance)* | — | ReconciliationReport | |
| POST | /v1/admin/ledger/adjustments *(finance; second approver)* | AdjustmentRequest | AdjustmentProposal | ✓ |
| POST | /v1/admin/payout-cycles/{id}/approve *(finance)* | — | PayoutCycleApproval | ✓ |

## What the contract deliberately does not claim

- Play Billing behaviour beyond verifying a token and processing refunds and voids is not assumed. The exact acknowledge/consume sequence must be confirmed against current Google documentation.
- No payout-provider capability is assumed. `PayoutProvider` is provider-neutral and payouts are disabled.
- No video-provider event names are assumed. Webhook payloads are normalised by the adapter.
