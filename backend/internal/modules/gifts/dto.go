package gifts

import (
	"regexp"
	"strings"
	"time"
	"unicode/utf8"
)

// Wire types. Keep in sync with api/openapi/dashuri.v1.yaml (Gifts).

// Gift is a public catalogue entry (GET /v1/gifts/catalogue).
type Gift struct {
	Id                  string  `json:"id"`
	Name                string  `json:"name"`
	Description         string  `json:"description"`
	Emoji               string  `json:"emoji"`
	IconAsset           string  `json:"icon_asset"`
	AnimationAsset      string  `json:"animation_asset"`
	AnimationDurationMs int     `json:"animation_duration_ms"`
	SoundAsset          *string `json:"sound_asset"`
	Tier                string  `json:"tier"`
	SortOrder           int     `json:"sort_order"`
	DiamondPrice        int64   `json:"diamond_price"`
}

// Catalogue is the active catalogue plus a version stamp the client can
// compare to refresh (the newest updated_at).
type Catalogue struct {
	Items     []Gift    `json:"items"`
	UpdatedAt time.Time `json:"updated_at"`
}

// SendGiftRequest: POST /v1/calls/{callId}/gifts. The price is never sent.
type SendGiftRequest struct {
	GiftId          string `json:"gift_id"`
	RecipientUserId string `json:"recipient_user_id"`
}

var giftIDRE = regexp.MustCompile(`^[a-z][a-z0-9_]{1,39}$`)

func (r SendGiftRequest) validate() map[string]string {
	errs := map[string]string{}
	if !giftIDRE.MatchString(r.GiftId) {
		errs["gift_id"] = "invalid_value"
	}
	if !isUUID(r.RecipientUserId) {
		errs["recipient_user_id"] = "invalid_uuid"
	}
	return errs
}

// GiftParty is a public participant reference.
type GiftParty struct {
	UserId      string `json:"user_id"`
	DisplayName string `json:"display_name"`
}

// GiftEvent is the public, canonical description of one sent gift: the
// realtime `call.gift` payload and each item of a call's gift history. It
// carries no wallet balances, ledger data or accounting metadata.
type GiftEvent struct {
	GiftTransactionId   string    `json:"gift_transaction_id"`
	GiftId              string    `json:"gift_id"`
	GiftName            string    `json:"gift_name"`
	Emoji               string    `json:"emoji"`
	Tier                string    `json:"tier"`
	DiamondValue        int64     `json:"diamond_value"`
	Sender              GiftParty `json:"sender"`
	Recipient           GiftParty `json:"recipient"`
	CallId              string    `json:"call_id"`
	AnimationAsset      string    `json:"animation_asset"`
	AnimationDurationMs int       `json:"animation_duration_ms"`
	ChatMessageId       *string   `json:"chat_message_id"`
	SentAt              time.Time `json:"sent_at"`
}

// SendGiftResponse is the sender's receipt: the event plus the sender's own
// remaining available Diamonds (never sent to the host).
type SendGiftResponse struct {
	Gift              GiftEvent `json:"gift"`
	AvailableDiamonds int64     `json:"available_diamonds"`
	Replayed          bool      `json:"replayed"`
}

// SentGift is one row of the customer's gift history.
type SentGift struct {
	GiftEvent
	DiamondCost int64 `json:"diamond_cost"`
}

// ReceivedGift is one row of the host's gift history. Beans are the host's
// own earnings; settlement_status is on_hold until the 7-day hold ends.
type ReceivedGift struct {
	GiftEvent
	BeansEarned      int64     `json:"beans_earned"`
	SettlementStatus string    `json:"settlement_status"` // on_hold | released
	ReleasesAt       time.Time `json:"releases_at"`
}

// ReceivedSummary is the host dashboard total.
type ReceivedSummary struct {
	TotalGifts    int64 `json:"total_gifts"`
	TotalDiamonds int64 `json:"total_diamond_value"`
	TotalBeans    int64 `json:"total_beans_earned"`
	TodayGifts    int64 `json:"today_gifts"`
	TodayBeans    int64 `json:"today_beans_earned"`
}

// Page is the list envelope {items, next_cursor}.
type Page[T any] struct {
	Items      []T     `json:"items"`
	NextCursor *string `json:"next_cursor,omitempty"`
}

// ---------------------------------------------------------------- admin

// AdminGift is the full catalogue row for staff.
type AdminGift struct {
	Gift
	Active         bool       `json:"active"`
	AvailableFrom  *time.Time `json:"available_from"`
	AvailableUntil *time.Time `json:"available_until"`
	EarningRule    string     `json:"earning_rule"`
	RetiredAt      *time.Time `json:"retired_at"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

// CreateGiftRequest: POST /v1/admin/gifts.
type CreateGiftRequest struct {
	Id                  string     `json:"id"`
	Name                string     `json:"name"`
	Description         string     `json:"description"`
	Emoji               string     `json:"emoji"`
	IconAsset           string     `json:"icon_asset"`
	AnimationAsset      string     `json:"animation_asset"`
	AnimationDurationMs int        `json:"animation_duration_ms"`
	SoundAsset          *string    `json:"sound_asset"`
	Tier                string     `json:"tier"`
	SortOrder           int        `json:"sort_order"`
	DiamondPrice        int64      `json:"diamond_price"`
	Active              bool       `json:"active"`
	AvailableFrom       *time.Time `json:"available_from"`
	AvailableUntil      *time.Time `json:"available_until"`
	Reason              string     `json:"reason"`
}

// UpdateGiftRequest: PATCH /v1/admin/gifts/{giftId}. Metadata, status,
// order and schedule only; the price changes through /price (audited).
type UpdateGiftRequest struct {
	Name                *string    `json:"name"`
	Description         *string    `json:"description"`
	Emoji               *string    `json:"emoji"`
	IconAsset           *string    `json:"icon_asset"`
	AnimationAsset      *string    `json:"animation_asset"`
	AnimationDurationMs *int       `json:"animation_duration_ms"`
	SoundAsset          *string    `json:"sound_asset"`
	Tier                *string    `json:"tier"`
	SortOrder           *int       `json:"sort_order"`
	Active              *bool      `json:"active"`
	AvailableFrom       *time.Time `json:"available_from"`
	AvailableUntil      *time.Time `json:"available_until"`
	ClearSchedule       bool       `json:"clear_schedule"`
	Retire              bool       `json:"retire"`
}

// ChangePriceRequest: POST /v1/admin/gifts/{giftId}/price.
type ChangePriceRequest struct {
	DiamondPrice int64  `json:"diamond_price"`
	Reason       string `json:"reason"`
}

// PriceChangeItem is one audited price change.
type PriceChangeItem struct {
	OldPrice  *int64    `json:"old_price"`
	NewPrice  int64     `json:"new_price"`
	ChangedBy string    `json:"changed_by"`
	Reason    string    `json:"reason"`
	ChangedAt time.Time `json:"changed_at"`
}

// GiftPerformance is one row of GET /v1/admin/gifts/performance.
type GiftPerformance struct {
	GiftId        string `json:"gift_id"`
	GiftName      string `json:"gift_name"`
	Count         int64  `json:"count"`
	DiamondValue  int64  `json:"diamond_value"`
	HostBeans     int64  `json:"host_beans"`
	UniqueSenders int64  `json:"unique_senders"`
	UniqueHosts   int64  `json:"unique_hosts"`
}

// AdminGiftTransaction is one row of the investigation list (staff only).
type AdminGiftTransaction struct {
	GiftEvent
	FromPromotional int64    `json:"from_promotional"`
	FromPurchased   int64    `json:"from_purchased"`
	HostBeans       int64    `json:"host_beans"`
	RuleSetVersion  string   `json:"rule_set_version"`
	LedgerEntryId   string   `json:"ledger_entry_id"`
	RiskFlags       []string `json:"risk_flags"`
}

// Validation limits for catalogue writes.
const (
	MaxGiftPrice = 1_000_000
)

var tiers = map[string]bool{"common": true, "rare": true, "epic": true, "legendary": true, "mythic": true}

func validText(v string, minLen, maxLen int) bool {
	n := utf8.RuneCountInString(strings.TrimSpace(v))
	return n >= minLen && n <= maxLen
}

func validateMeta(name, emoji, icon, anim *string, dur *int, tier *string, from, until *time.Time) map[string]string {
	errs := map[string]string{}
	if name != nil && !validText(*name, 1, 40) {
		errs["name"] = "invalid_length"
	}
	if emoji != nil && !validText(*emoji, 1, 8) {
		errs["emoji"] = "invalid_length"
	}
	if icon != nil && !validText(*icon, 1, 200) {
		errs["icon_asset"] = "invalid_length"
	}
	if anim != nil && !validText(*anim, 1, 200) {
		errs["animation_asset"] = "invalid_length"
	}
	if dur != nil && (*dur < 1000 || *dur > 10000) {
		errs["animation_duration_ms"] = "must_be_1000_to_10000"
	}
	if tier != nil && !tiers[*tier] {
		errs["tier"] = "invalid_value"
	}
	if from != nil && until != nil && !until.After(*from) {
		errs["available_until"] = "must_be_after_available_from"
	}
	return errs
}

func (r CreateGiftRequest) validate() map[string]string {
	var dur *int // 0 = default (5,000 ms)
	if r.AnimationDurationMs != 0 {
		dur = &r.AnimationDurationMs
	}
	errs := validateMeta(&r.Name, &r.Emoji, &r.IconAsset, &r.AnimationAsset, dur, &r.Tier, r.AvailableFrom, r.AvailableUntil)
	if !giftIDRE.MatchString(r.Id) {
		errs["id"] = "invalid_value"
	}
	if utf8.RuneCountInString(r.Description) > 200 {
		errs["description"] = "too_long"
	}
	if r.DiamondPrice < 1 || r.DiamondPrice > MaxGiftPrice {
		errs["diamond_price"] = "must_be_1_to_1000000"
	}
	if !validText(r.Reason, 3, 500) {
		errs["reason"] = "required"
	}
	return errs
}

func (r UpdateGiftRequest) validate() map[string]string {
	errs := validateMeta(r.Name, r.Emoji, r.IconAsset, r.AnimationAsset, r.AnimationDurationMs, r.Tier, r.AvailableFrom, r.AvailableUntil)
	if r.Description != nil && utf8.RuneCountInString(*r.Description) > 200 {
		errs["description"] = "too_long"
	}
	if r.Retire && r.Active != nil && *r.Active {
		errs["active"] = "retired_gift_cannot_be_active"
	}
	return errs
}

func (r ChangePriceRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.DiamondPrice < 1 || r.DiamondPrice > MaxGiftPrice {
		errs["diamond_price"] = "must_be_1_to_1000000"
	}
	if !validText(r.Reason, 3, 500) {
		errs["reason"] = "required"
	}
	return errs
}

var uuidRE = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

func isUUID(s string) bool { return uuidRE.MatchString(s) }
