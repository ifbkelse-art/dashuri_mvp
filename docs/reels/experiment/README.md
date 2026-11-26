# Reels experiment: recoverability kit

| File | Purpose |
|---|---|
| `BASELINE.md` | Branch, HEAD (`d8c55fa1d2e5c6be27752e29db463b53c15efa48`), `git status` and SHA-256 of the pre-existing `docs/finance` work, recorded **before any change** |
| `tracked_files_at_baseline.sha256` | SHA-256 of every tracked file at baseline (1,456 files) |
| `MODIFIED.txt` + `backup/` | Every existing file the experiment changed, copied **before** its first modification (`backup.sh`) |
| `CREATED.txt` | Every path the experiment added (outside `docs/reels`) |
| `restore.sh` | Dry run by default; `--apply` restores and verifies by hash; `--purge-docs` also removes `docs/reels`. Uses no git commands |
| `drop_reels_schema.sql` | Drops the `reels` schema from a local or staging database where you applied the migration |
| `openapi_reels.py` | Regenerates the Reels section of the OpenAPI file (idempotent) |
| `drop_chat_message_context.sql` | Drops the in-call chat metadata columns (migration `20261123000200`) from a local/staging database where you applied it |

**Updated 22 Nov 2026 (after commit `03ba816`): this kit now undoes REELS ONLY.**
The in-call chat work and the selfie-only camera change were committed
(`03ba816`), as was the realtime fix (`da3c238`). Their paths were taken off
`MODIFIED.txt` / `CREATED.txt`; for files that still carry Reels edits
(`config.go`, `app_config.dart`, `injector.dart`, the OpenAPI file) the backup
is now the committed version. `tracked_files_at_baseline.sha256` now records
commit `03ba816`, so `--apply` verifies against it. To remove the chat feature,
revert the commit; `drop_chat_message_context.sql` still drops its database
columns where the migration was applied.

**History — originally also covered (added 22 Nov 2026):** the unified chat + in-call messaging
experiment (`docs/chat/`) and the responsiveness fixes are registered in
`MODIFIED.txt` / `CREATED.txt`, so `restore.sh --apply` removes them too. Two
files the Reels work had changed without registering
(`host_profile_tab_page.dart`, `chat/module.go`) were added, with backups
taken from the baseline commit and checked against
`tracked_files_at_baseline.sha256`. Re-verified on a full copy of the
working tree: `RESTORE VERIFIED`, and the baseline backend builds.

Verified on 22 Nov 2026 on a full copy of the working tree:
- after `--apply`, every tracked file and the `docs/finance` files match the baseline;
- no extra or missing files;
- the backend builds;
- a deliberately modified file is reported as `DIFFERS`.
