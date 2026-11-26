# ADR-014: Verified Host status and level-based price ceilings

- **Status:** Accepted, 2026-11-23 (founder spec "Verified Host system & level-based Diamond pricing"). Resolves the S2 ladder that was left open.

## Context
S2 said hosts set their own price between 500 and 10,000 D/min, "limited by level", but left the ladder undecided. As built, every level could charge 10,000. The founder has now set the ladder:
- the maximum is level × 1,000;
- prices above 3,000 need a new premium **Verified Host** status, reviewed by staff from a face video and an ID document.

The existing "verified" flag (`HostCard.is_verified`) meant "hosting KYC approved". Every listed host had it, so it carried no signal.

## Decision
1. **Separate statuses.** Hosting approval (manual KYC) still decides who may host. Verified Host is a separate state machine:
   - `hosting.hosts.verification_status`, plus `hosting.verification_applications` for the workflow record;
   - only moderators and admins act on it, never on their own account;
   - every action is audited in `audit.events`.
2. **One pricing function.** `economy.Rules` (rule set `2026-11-23-verified-pricing`) provides `EligibleMaxRate(level, verified) = verified ? level×1000 : min(level×1000, 3000)`, never below 500. The same function is used for:
   - validation on `PUT /v1/host/rate`;
   - capping on revoke/suspend and on a level drop;
   - capping at call creation;
   - the discovery display.
3. **Atomic enforcement on the host row lock.** Rate updates, verification changes and call creation all take `hosting.hosts … FOR UPDATE` and read XP and status inside the transaction. A purchase reversal caps the price in the same transaction as its negative XP event. Call creation re-checks and caps before snapshotting the call rate, which also catches drops that bypassed the other paths. As a backstop, the database refuses a rate above 3,000 unless the row is `verified`.
4. **Never re-price live calls; never raise automatically.** The call rate stays a snapshot. Approvals and level-ups leave the stored price alone.
5. **Private evidence, metadata only in Postgres.**
   - Objects go to the private bucket `host-verification-evidence` through signed URLs.
   - Staff get audited 5-minute read URLs.
   - Retention is handled by a daily purge job.
   - No biometric templates are created.
6. **Ranking signal, not a gate.** In the recommended sort, verified hosts get a configurable XP-equivalent boost (`DISCOVERY_VERIFIED_BOOST_XP`). The explicit `verification` filter is the only thing that hides non-verified hosts.

## Consequences
- **Migration.**
  - Existing stored prices above min(3,000, level max) are lowered, each with an audit row (`system:migration`).
  - No host is grandfathered as Verified.
  - `HostCard.is_verified` changes meaning: clients that showed it for all hosts now show it only for Verified Hosts.
- **Tests and fixtures.** Test fixtures that priced hosts above 1,000 D/min now give those hosts the matching level XP, and set `verified` above 3,000.
- **Admin UI.** Reviewers need the future admin web app; until then the admin endpoints are the interface.
- **Rule configuration.** The threshold (3,000) and step (1,000) are in `economy.Rules`. The DB CHECK hard-codes 3,000 and must change with it.
