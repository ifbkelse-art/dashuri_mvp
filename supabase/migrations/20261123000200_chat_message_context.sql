-- EXPERIMENT: unified chat + in-call messaging (docs/chat/UNIFIED_CHAT_AND_IN_CALL_MESSAGING.md).
-- Not approved for permanent inclusion; roll back with
-- docs/reels/experiment/drop_chat_message_context.sql.
--
-- In-call messages are ordinary chat.messages rows in the pair's one
-- conversation. These columns are METADATA only: no new message type, no
-- new table, no second store. All are nullable, so existing rows and the
-- existing API (CHAT_MESSAGE_CONTEXT_ENABLED=false) are unaffected.
--
--   context            null/'chat' = sent from the inbox, 'call' = sent from
--                      the in-call panel
--   call_id            the call it was sent during (server-side only; never
--                      returned by the API)
--   client_message_id  the sender's per-message id (the Idempotency-Key):
--                      a database-level duplicate guard that survives the
--                      24 h idempotency-key expiry and crashed requests

alter table chat.messages
  add column context            text check (context in ('chat', 'call')),
  add column call_id            uuid references calls.calls (id),
  add column client_message_id  uuid,
  add constraint messages_call_context check (call_id is null or context = 'call');

create unique index messages_client_dedupe
  on chat.messages (conversation_id, sender_id, client_message_id)
  where client_message_id is not null;
