# Database tests

`scripts/validate-migrations.sh` applies every migration to a throwaway local Postgres (with minimal stubs for Supabase's `auth`, `realtime` and `storage` schemas) and runs `ledger_invariants.sql`, which proves:

- an unbalanced journal entry is rejected at commit;
- a user wallet balance cannot go negative;
- journal entries and postings cannot be updated or deleted;
- a second settlement for the same call is rejected;
- a person cannot be in two live calls at once.

For full fidelity, run the migrations against the real Supabase stack with `supabase start && supabase db reset` (needs Docker), and add pgTAP tests under this folder (`supabase test db`).
