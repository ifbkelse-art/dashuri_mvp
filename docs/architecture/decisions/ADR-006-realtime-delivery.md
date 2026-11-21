# ADR-006: Server-to-client events via Supabase Realtime private channels

- **Status:** Accepted, 2026-11-17

## Context
Incoming calls, call state, billing warnings and message hints need low-latency push to the app. A self-run WebSocket gateway on Cloud Run needs cross-instance fan-out (Redis or Pub/Sub) and connection management.

## Decision
- The Go API publishes broadcast messages to private Supabase Realtime topics `user:<id>` and `call:<id>`.
- Realtime Authorization policies on `realtime.messages` allow authenticated users to **receive** only their own topics, and call topics where they are a participant (`calls.is_participant`). Clients cannot send.
- All client actions go through REST. Events are hints; the API is the source of truth.
- FCM covers the app in the background.

## Alternatives
- **Go WebSocket gateway:** full control, but needs Redis for fan-out across instances.
- **Postgres changes (CDC) to clients:** exposes table shapes and needs client table grants, which conflicts with the deny-by-default model.

## Trade-offs
Depends on Supabase Realtime quotas and latency. Delivery is not guaranteed, which is acceptable because events are hints.

## Future
Swap the `RealtimeGateway`/`RealtimePublisher` adapters for a Go gateway if latency or quotas require it.
