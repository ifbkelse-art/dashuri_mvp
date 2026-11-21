#!/usr/bin/env python3
"""Adds the MVP contract additions (docs/mvp/MVP_DECISIONS_AND_CONTRACT.md)
to api/openapi/dashuri.v1.yaml. Idempotent: skips paths/schemas that exist."""
import re, sys, pathlib

SPEC = pathlib.Path(__file__).resolve().parent.parent / "api/openapi/dashuri.v1.yaml"

def op(method, op_id, tag, summary, ok, ok_schema=None, req=None, idem=False, errors="", params=(), webhook=False):
    out = [f"    {method}:", f"      operationId: {op_id}", "      tags:", f"        - {tag}", f"      summary: {summary!r}".replace("'", '"')]
    if webhook:
        out += ["      security: []"]
    ps = list(params) + (['        - $ref: "#/components/parameters/IdempotencyKey"'] if idem else [])
    if ps:
        out += ["      parameters:"] + ps
    if req:
        out += ["      requestBody:", "        required: true", "        content:", "          application/json:", "            schema:", f'              $ref: "#/components/schemas/{req}"']
    out += ["      responses:", f'        "{ok}":', "          description: OK"]
    if ok_schema:
        out += ["          content:", "            application/json:", "              schema:", f'                $ref: "#/components/schemas/{ok_schema}"']
    if not webhook:
        out += ['        "401":', '          $ref: "#/components/responses/Problem"']
    if errors:
        out += ['        "409":', f'          description: "Business rule or conflict. `code`/`rule` one of: {errors}"', "          content:", "            application/problem+json:", "              schema:", '                $ref: "#/components/schemas/Problem"']
    out += ['        "422":', '          $ref: "#/components/responses/Problem"']
    if not webhook:
        out += ['        "429":', '          $ref: "#/components/responses/Problem"']
    out += ['        "503":', '          $ref: "#/components/responses/Problem"']
    return "\n".join(out)

def path_param(name):
    return [f"        - name: {name}", "          in: path", "          required: true", "          schema:", "            type: string"]

def q(name, typ="string", enum=None):
    r = [f"        - name: {name}", "          in: query", "          required: false", "          schema:", f"            type: {typ}"]
    if enum:
        r += ["            enum:"] + [f"              - {e}" for e in enum]
    return r

PAGE = q("cursor") + q("limit", "integer")

PATHS = {
 "/v1/me/rules-acceptance": op("post", "acceptCommunityRules", "accounts", "Accept the current community rules (A13).", 200, "AccountStatus", "RulesAcceptanceRequest"),
 "/v1/locations/cities": op("get", "listCities", "accounts", "Supported cities (coarse location, ADR-012).", 200, "CityList", params=q("query")),
 "/v1/locations/resolve": op("post", "resolveCity", "accounts", "Nearest supported city for rounded coordinates; coordinates are not stored.", 200, "City", "ResolveCityRequest"),
 "/v1/discovery/hosts/{userId}": op("get", "getHostCard", "discovery", "Host detail (C07–C09); 404 when blocked either way.", 200, "HostDetail", params=path_param("userId")),
 "/v1/discovery/summary": op("get", "getDiscoverySummary", "discovery", "Online host count.", 200, "DiscoverySummary"),
 "/v1/purchases/cashfree/orders": op("post", "createCashfreeOrder", "purchases", "Create a Cashfree PG order for a Diamond package (ADR-011).", 201, "CashfreeOrder", "CreateCashfreeOrderRequest", idem=True, errors="rail_disabled, product_unknown, phone_required"),
 "/v1/purchases/cashfree/orders/{orderId}": op("get", "getCashfreeOrder", "purchases", "Order state; re-verifies with Cashfree server-to-server and credits once.", 200, "CashfreeOrder", params=path_param("orderId")),
 "/v1/webhooks/cashfree": op("post", "cashfreeWebhook", "webhooks", "Cashfree PG webhook (x-webhook-signature HMAC-SHA256).", 204, webhook=True),
 "/v1/calls/history": op("get", "listCallHistory", "calls", "Own calls, newest first.", 200, "CallSessionPage", params=PAGE),
 "/v1/calls/{callId}/moderation-frames": op("post", "submitModerationFrame", "calls", "Own-camera JPEG during the first 180 s (S7, ADR-013).", 202, "FrameAccepted", "ModerationFrameRequest", errors="moderation_window_closed, not_participant", params=path_param("callId")),
 "/v1/conversations/{conversationId}/read": op("post", "markConversationRead", "chat", "Mark the conversation read up to now.", 204, params=path_param("conversationId")),
 "/v1/admin/hosts/{userId}/kyc-decision": op("post", "decideHostKyc", "admin", "Moderator decision for manual KYC (MVP provider).", 200, "HostStatus", "KycDecisionRequest", params=path_param("userId")),
}

SCHEMAS = """    City:
      type: object
      required: [id, name, state]
      properties:
        id: {type: string}
        name: {type: string}
        state: {type: string}
    CityList:
      type: object
      required: [items]
      properties:
        items:
          type: array
          items: {$ref: "#/components/schemas/City"}
    ResolveCityRequest:
      type: object
      additionalProperties: false
      required: [latitude, longitude]
      properties:
        latitude: {type: number, minimum: -90, maximum: 90}
        longitude: {type: number, minimum: -180, maximum: 180}
    RulesAcceptanceRequest:
      type: object
      additionalProperties: false
      required: [version]
      properties:
        version: {type: string}
    HostDetail:
      allOf:
        - $ref: "#/components/schemas/HostCard"
        - type: object
          properties:
            bio: {type: [string, "null"]}
    DiscoverySummary:
      type: object
      required: [online_count]
      properties:
        online_count: {type: integer}
    CreateCashfreeOrderRequest:
      type: object
      additionalProperties: false
      required: [product_id]
      properties:
        product_id: {type: string}
    CashfreeOrder:
      type: object
      required: [order_id, product_id, amount_paise, diamonds, environment, state, diamonds_credited]
      properties:
        order_id: {type: string}
        product_id: {type: string}
        amount_paise: {type: integer, format: int64}
        diamonds: {type: integer, format: int64}
        payment_session_id: {type: [string, "null"]}
        environment: {type: string, enum: [sandbox, production]}
        state: {type: string, enum: [created, pending, credited, failed, expired]}
        diamonds_credited: {type: integer, format: int64}
    CallSessionPage:
      type: object
      required: [items]
      properties:
        items:
          type: array
          items: {$ref: "#/components/schemas/CallSession"}
        next_cursor: {type: [string, "null"]}
    ModerationFrameRequest:
      type: object
      additionalProperties: false
      required: [image_base64, captured_at]
      properties:
        image_base64: {type: string, description: "JPEG, at most 200 KB before encoding"}
        captured_at: {type: string, format: date-time}
    FrameAccepted:
      type: object
      required: [accepted]
      properties:
        accepted: {type: boolean}
    KycDecisionRequest:
      type: object
      additionalProperties: false
      required: [decision]
      properties:
        decision: {type: string, enum: [approve, reject]}
        date_of_birth: {type: string, format: date}
        reason: {type: string, maxLength: 500}
"""

def main():
    s = SPEC.read_text()
    added = []
    block = ""
    for path, text in PATHS.items():
        if re.search(rf"(?m)^  \"?{re.escape(path)}\"?:$", s):
            continue
        block += f"  {path}:\n{text}\n"
        added.append(path)
    if block:
        i = s.index("\ncomponents:\n")
        s = s[:i + 1] + block + s[i + 1:]
    new_schemas = ""
    for chunk in re.split(r"(?m)^(?=    [A-Z])", SCHEMAS):
        name = chunk.split(":", 1)[0].strip()
        if chunk.strip() and not re.search(rf"(?m)^    {name}:$", s):
            new_schemas += chunk
    if new_schemas:
        i = s.index("\n  schemas:\n") + len("\n  schemas:\n")
        s = s[:i] + new_schemas + s[i:]
    SPEC.write_text(s)
    print("added paths:", added)

if __name__ == "__main__":
    sys.exit(main())
