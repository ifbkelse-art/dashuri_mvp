-- Rolls back supabase/migrations/20261123000200_chat_message_context.sql on a
-- local or staging database where YOU applied it. Never run on production.
-- Message rows are kept; only the in-call metadata is dropped.
-- Set CHAT_MESSAGE_CONTEXT_ENABLED=false (the default) on the backend first.
drop index if exists chat.messages_client_dedupe;
alter table chat.messages
  drop constraint if exists messages_call_context,
  drop column if exists client_message_id,
  drop column if exists call_id,
  drop column if exists context;
