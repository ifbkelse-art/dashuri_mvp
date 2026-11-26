#!/usr/bin/env python3
"""EXPERIMENT — adds the Dashuri Reels endpoints and schemas to
api/openapi/dashuri.v1.yaml. Idempotent (skips if already present).
Remove them by restoring the backup (docs/reels/experiment/restore.sh)."""
import pathlib, sys

SPEC = pathlib.Path(__file__).resolve().parents[3] / "api/openapi/dashuri.v1.yaml"
MARK = "# --- EXPERIMENT: Dashuri Reels"

P = lambda n: [f"        - name: {n}", "          in: path", "          required: true", "          schema:", "            type: string"]
Q = lambda n, t="string": [f"        - name: {n}", "          in: query", "          required: false", "          schema:", f"            type: {t}"]
IDEM = ['        - $ref: "#/components/parameters/IdempotencyKey"']

def op(method, op_id, summary, ok, ok_schema=None, req=None, params=(), tag="reels", webhook=False, errors=("401", "404", "409", "422", "429", "503")):
    out = [f"    {method}:", f"      operationId: {op_id}", "      tags:", f"        - {tag}", f'      summary: "{summary}"']
    if webhook:
        out.append("      security: []")
    if params:
        out += ["      parameters:"] + list(params)
    if req:
        out += ["      requestBody:", "        required: true", "        content:", "          application/json:", "            schema:", f'              $ref: "#/components/schemas/{req}"']
    out += ["      responses:", f'        "{ok}":', "          description: OK"]
    if ok_schema:
        out += ["          content:", "            application/json:", "              schema:", f'                $ref: "#/components/schemas/{ok_schema}"']
    for e in errors:
        out += [f'        "{e}":', '          $ref: "#/components/responses/Problem"']
    return out

paths = {
  "/v1/reels/config": [op("get", "getReelsConfig", "Whether Reels and uploads are available on this server (REELS_ENABLED, provider configured).", 200, "ReelsConfig", errors=("401",))],
  "/v1/reels/feed": [op("get", "getReelsFeed", "Ranked For You feed or newest-first Following feed; published reels only, blocks and own reports excluded.", 200, "ReelPage", params=Q("tab") + Q("cursor") + Q("limit", "integer"))],
  "/v1/reels/uploads": [op("post", "createReelUpload", "Creates a private reel (awaiting_upload) and a one-time provider upload URL; 503 video_provider_not_configured without credentials; 409 reel_upload_limit.", 201, "ReelUploadTicket", req="CreateReelUploadRequest", params=IDEM)],
  "/v1/reels/{reelId}": [
    op("get", "getReel", "Published reel, or any non-deleted status for its creator.", 200, "Reel", params=P("reelId")),
    op("delete", "deleteReel", "Creator deletes their reel; media purged after any evidence hold.", 204, params=P("reelId")),
  ],
  "/v1/reels/{reelId}/like": [op("put", "setReelLike", "Idempotent like/unlike.", 200, "ReelLikeState", req="ReelLikeRequest", params=P("reelId"))],
  "/v1/reels/{reelId}/share": [op("post", "shareReel", "Counts a share and returns link text.", 200, "ReelShareLink", params=P("reelId"))],
  "/v1/reels/{reelId}/reports": [op("post", "reportReel", "Report (idempotent per reporter). minor_safety/nudity or 3 reporters hide the reel pending review.", 204, req="ReelReportRequest", params=P("reelId") + IDEM)],
  "/v1/reels/{reelId}/appeals": [op("post", "appealReel", "Creator appeals a rejected or removed reel, once.", 204, req="ReelAppealRequest", params=P("reelId") + IDEM)],
  "/v1/reels/events": [op("post", "trackReelEvents", "Client analytics batch (≤ 50). View counters always update; events are stored only with analytics consent.", 202, req="ReelEventsRequest")],
  "/v1/creators/{userId}": [op("get", "getCreator", "Creator profile; `me` = own. 404 when blocked either way.", 200, "CreatorProfile", params=P("userId"))],
  "/v1/creators/{userId}/reels": [op("get", "listCreatorReels", "Creator's published reels; every status on one's own profile.", 200, "ReelPage", params=P("userId") + Q("cursor") + Q("limit", "integer"))],
  "/v1/creators/{userId}/follow": [op("put", "setCreatorFollow", "Idempotent follow/unfollow.", 200, "FollowState", req="FollowRequest", params=P("userId"))],
  "/v1/me/creator": [op("patch", "updateMyCreator", "Update creator bio.", 200, "CreatorProfile", req="UpdateCreatorRequest")],
  "/v1/webhooks/reels/{provider}": [op("post", "reelsProviderWebhook", "Video provider webhook (Mux-Signature HMAC verified over the raw body; deduplicated).", 204, params=P("provider"), tag="webhooks", webhook=True, errors=("401", "404", "422", "503"))],
  "/v1/admin/reels/queue": [op("get", "listReelModerationQueue", "Open moderation cases (moderator/admin) with short-lived review playback.", 200, "ReelQueuePage", params=Q("cursor") + Q("limit", "integer"), tag="admin")],
  "/v1/admin/reels/{reelId}/decision": [op("post", "decideReel", "Moderator decision (approve/reject/remove/restore); audited, append-only; no self-review.", 200, "ReelDecisionResult", req="ReelDecisionRequest", params=P("reelId") + IDEM, tag="admin")],
  "/v1/admin/reels/analytics": [op("get", "getReelsAnalytics", "Aggregate Reels metrics and reel-attributed calls (admin/finance/moderator).", 200, "ReelsAnalytics", params=Q("days", "integer"), tag="admin")],
}

S = lambda s: s  # readability
schemas = """    ReelsConfig:
      type: object
      required: [enabled, uploads_available, min_duration_ms, max_duration_ms, max_caption_length, daily_upload_limit, max_upload_bytes]
      properties:
        enabled: {type: boolean}
        uploads_available: {type: boolean}
        min_duration_ms: {type: integer}
        max_duration_ms: {type: integer}
        max_caption_length: {type: integer}
        daily_upload_limit: {type: integer}
        max_upload_bytes: {type: integer}
    ReelHostInfo:
      type: object
      required: [availability, rate_per_minute, is_verified]
      properties:
        availability: {type: string, enum: [online, busy, offline]}
        rate_per_minute: {type: integer, description: Diamonds per minute}
        is_verified: {type: boolean}
    ReelCreatorSummary:
      type: object
      required: [user_id, display_name, photo_url, followed_by_me, host]
      properties:
        user_id: {type: string, format: uuid}
        display_name: {type: string}
        photo_url: {type: [string, "null"]}
        followed_by_me: {type: boolean}
        host:
          description: Null unless the creator is an approved host (paid calls).
          oneOf:
            - $ref: "#/components/schemas/ReelHostInfo"
            - type: "null"
    ReelPlayback:
      type: object
      required: [hls_url, thumbnail_url, expires_at]
      properties:
        hls_url: {type: string, description: Signed HLS URL}
        thumbnail_url: {type: string}
        expires_at: {type: string, format: date-time}
    Reel:
      type: object
      required: [id, creator, caption, language, duration_ms, status, rejection_code, like_count, view_count, share_count, liked_by_me, is_mine, playback, published_at, created_at]
      properties:
        id: {type: string, format: uuid}
        creator: {$ref: "#/components/schemas/ReelCreatorSummary"}
        caption: {type: string, maxLength: 300}
        language: {type: [string, "null"]}
        duration_ms: {type: [integer, "null"]}
        status: {type: string, enum: [awaiting_upload, processing, pending_moderation, in_review, published, rejected, removed, failed, deleted]}
        rejection_code: {type: [string, "null"], description: Only for the creator and moderators}
        like_count: {type: integer}
        view_count: {type: integer}
        share_count: {type: integer}
        liked_by_me: {type: boolean}
        is_mine: {type: boolean}
        playback:
          oneOf:
            - $ref: "#/components/schemas/ReelPlayback"
            - type: "null"
        published_at: {type: [string, "null"], format: date-time}
        created_at: {type: string, format: date-time}
    ReelPage:
      type: object
      required: [items, next_cursor]
      properties:
        items:
          type: array
          items: {$ref: "#/components/schemas/Reel"}
        next_cursor: {type: [string, "null"]}
    CreateReelUploadRequest:
      type: object
      required: [duration_ms]
      properties:
        caption: {type: string, maxLength: 300}
        language: {type: string, pattern: "^[a-z]{2}$"}
        duration_ms: {type: integer, minimum: 15000, maximum: 60000, description: Client-read duration; the server re-checks the provider's}
    ReelUploadTicket:
      type: object
      required: [reel, upload_url, expires_at]
      properties:
        reel: {$ref: "#/components/schemas/Reel"}
        upload_url: {type: string, description: PUT the file here; the URL is the grant}
        expires_at: {type: string, format: date-time}
    ReelLikeRequest:
      type: object
      required: [liked]
      properties:
        liked: {type: boolean}
    ReelLikeState:
      type: object
      required: [liked, like_count]
      properties:
        liked: {type: boolean}
        like_count: {type: integer}
    FollowRequest:
      type: object
      required: [following]
      properties:
        following: {type: boolean}
    FollowState:
      type: object
      required: [following]
      properties:
        following: {type: boolean}
    ReelShareLink:
      type: object
      required: [url, text]
      properties:
        url: {type: string}
        text: {type: string}
    ReelReportRequest:
      type: object
      required: [category]
      properties:
        category: {type: string, enum: [nudity, sexual_content, minor_safety, harassment, violence, hate, spam_or_scam, copyright, privacy, other]}
        details: {type: string, maxLength: 1000}
    ReelAppealRequest:
      type: object
      required: [statement]
      properties:
        statement: {type: string, maxLength: 2000}
    ReelEvent:
      type: object
      required: [event]
      properties:
        event: {type: string, enum: [reel_impression, reel_play_started, reel_play_completed, reel_watch_duration, creator_profile_opened, host_call_cta_clicked]}
        reel_id: {type: string, format: uuid}
        creator_id: {type: string, format: uuid}
        value_ms: {type: integer, minimum: 0, maximum: 600000}
        session_id: {type: string, maxLength: 64}
    ReelEventsRequest:
      type: object
      required: [events]
      properties:
        events:
          type: array
          minItems: 1
          maxItems: 50
          items: {$ref: "#/components/schemas/ReelEvent"}
    CreatorProfile:
      allOf:
        - $ref: "#/components/schemas/ReelCreatorSummary"
        - type: object
          required: [bio, follower_count, following_count, reel_count, is_self]
          properties:
            bio: {type: [string, "null"]}
            follower_count: {type: integer}
            following_count: {type: integer}
            reel_count: {type: integer}
            is_self: {type: boolean}
    UpdateCreatorRequest:
      type: object
      properties:
        bio: {type: [string, "null"], maxLength: 300}
    ReelQueueEntry:
      type: object
      required: [case_id, source, priority, scores, report_count, appeal_statement, created_at, reel]
      properties:
        case_id: {type: string, format: uuid}
        source: {type: string, enum: [automated, report, appeal, provider_unavailable]}
        priority: {type: integer, minimum: 1, maximum: 5}
        scores: {type: [object, "null"], additionalProperties: {type: number}}
        report_count: {type: integer}
        appeal_statement: {type: [string, "null"]}
        created_at: {type: string, format: date-time}
        reel: {$ref: "#/components/schemas/Reel"}
    ReelQueuePage:
      type: object
      required: [items, next_cursor]
      properties:
        items:
          type: array
          items: {$ref: "#/components/schemas/ReelQueueEntry"}
        next_cursor: {type: [string, "null"]}
    ReelDecisionRequest:
      type: object
      required: [decision, reason_code]
      properties:
        decision: {type: string, enum: [approve, reject, remove, restore]}
        reason_code: {type: string, maxLength: 60}
        note: {type: string, maxLength: 2000}
    ReelDecisionResult:
      type: object
      required: [reel_id, status]
      properties:
        reel_id: {type: string, format: uuid}
        status: {type: string}
    ReelsAnalytics:
      type: object
      properties:
        from: {type: string, format: date-time}
        to: {type: string, format: date-time}
        published_reels: {type: integer}
        active_creators: {type: integer}
        impressions: {type: integer}
        plays_started: {type: integer}
        plays_completed: {type: integer}
        watch_seconds: {type: integer}
        likes: {type: integer}
        follows: {type: integer}
        shares: {type: integer}
        reports: {type: integer}
        creator_profile_opens: {type: integer}
        host_call_cta_clicks: {type: integer}
        reel_attributed_calls_started: {type: integer}
        reel_attributed_calls_completed: {type: integer}
        reel_attributed_billed_seconds: {type: integer}
        reel_attributed_diamonds_charged: {type: integer}
        attribution_window_minutes: {type: integer}
"""

text = SPEC.read_text()
if MARK in text:
    print("already present"); sys.exit(0)
path_lines = [f"  {MARK} (paths)"]
for p, ops in paths.items():
    path_lines.append(f"  {p}:")
    for o in ops:
        path_lines += o
text = text.replace("\ncomponents:\n", "\n" + "\n".join(path_lines) + "\ncomponents:\n", 1)
text = text.replace("  - name: purchases\n", "  - name: purchases\n  - name: reels\n    description: EXPERIMENT — Dashuri Reels (REELS_ENABLED)\n", 1)
text = text.rstrip("\n") + f"\n    {MARK} (schemas)\n" + schemas
SPEC.write_text(text)
print(f"added {len(paths)} paths")
