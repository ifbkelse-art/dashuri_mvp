package gifts

import (
	"fmt"
	"strings"
	"time"

	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/platform/apperr"
)

// Limits are the gifting safety controls. Defaults are engineering
// proposals pending a founder decision (docs/gifts/VIRTUAL_GIFTS.md §8);
// they are configuration, not financial rules.
type Limits struct {
	// MaxPerCallPerMinute caps how many gifts one sender may send in one
	// call within a rolling minute (spam and accidental-tap protection).
	MaxPerCallPerMinute int
	// DailySpendCap caps one sender's gift spend over a rolling 24 h
	// (Diamonds). 0 disables the cap.
	DailySpendCap int64
	// Risk flags (recorded on the transaction for review; never block).
	HighValueFlag       int64         // a single gift at or above this
	NewAccountAge       time.Duration // sender account younger than this…
	NewAccountFlagValue int64         // …sending at least this
	PairVolumeFlag      int64         // sender→host spend in 24 h at or above this
}

// DefaultLimits are the proposed safety controls.
func DefaultLimits() Limits {
	return Limits{
		MaxPerCallPerMinute: 6,
		DailySpendCap:       1_000_000,
		HighValueFlag:       100_000,
		NewAccountAge:       72 * time.Hour,
		NewAccountFlagValue: 25_000,
		PairVolumeFlag:      500_000,
	}
}

// Risk flags recorded on gifts.transactions.risk_flags.
const (
	FlagHighValue      = "high_value"
	FlagNewAccount     = "new_sender_account"
	FlagPairVolume     = "repeat_pair_volume"
	FlagPromotionalUse = "promotional_diamonds"
)

// Split takes price from the customer's buckets in the rule set's spend
// order (promotional first unless the rules say otherwise), exactly like
// call settlement. The caller has checked that the buckets cover price.
func Split(r economy.Rules, price, promotional, purchased int64) (fromPromo, fromPurchased int64) {
	if r.SpendOrder == "purchased_first" {
		fromPurchased = min(purchased, price)
		return price - fromPurchased, fromPurchased
	}
	fromPromo = min(promotional, price)
	return fromPromo, price - fromPromo
}

// RiskFlags returns the review signals for one gift (never blocking).
func RiskFlags(l Limits, st SendState, price, fromPromo int64) []string {
	flags := []string{}
	if l.HighValueFlag > 0 && price >= l.HighValueFlag {
		flags = append(flags, FlagHighValue)
	}
	if l.NewAccountAge > 0 && st.Sender.AccountAgeDur < l.NewAccountAge && price >= l.NewAccountFlagValue {
		flags = append(flags, FlagNewAccount)
	}
	if l.PairVolumeFlag > 0 && st.PairSpentLast24h+price >= l.PairVolumeFlag {
		flags = append(flags, FlagPairVolume)
	}
	if fromPromo > 0 {
		flags = append(flags, FlagPromotionalUse)
	}
	return flags
}

// ChatLine is the gift's system message, e.g. "🌹 Asha sent Rose to Meera."
func ChatLine(emoji, sender, gift, recipient string) string {
	if strings.TrimSpace(sender) == "" {
		sender = "Someone"
	}
	if strings.TrimSpace(recipient) == "" {
		recipient = "the host"
	}
	if emoji == "" {
		emoji = "🎁"
	}
	return fmt.Sprintf("%s %s sent %s to %s.", emoji, sender, gift, recipient)
}

// decide applies every send rule to the state read under lock. It is pure
// (no I/O) so each rule is unit-tested. Order matters: idempotent replay
// first, then authorisation, call, parties, gift, controls and balance.
func decide(r economy.Rules, l Limits, req SendRequest, st SendState, newID func() string) (SendPlan, error) {
	if st.Existing != nil {
		if st.Existing.RequestHash != req.RequestHash {
			return SendPlan{}, apperr.Validation(map[string]string{"Idempotency-Key": "reused_with_different_request"})
		}
		return SendPlan{Replay: true, Transaction: *st.Existing}, nil
	}
	if !st.CallFound {
		return SendPlan{}, apperr.NotFound("call")
	}
	c := st.Call
	switch req.SenderID {
	case c.CallerID:
	case c.ReceiverID:
		return SendPlan{}, apperr.Forbidden("hosts_cannot_send_gifts", "only the customer can send gifts")
	default:
		return SendPlan{}, apperr.NotFound("call")
	}
	if req.RecipientID != c.ReceiverID {
		return SendPlan{}, apperr.Validation(map[string]string{"recipient_user_id": "not_call_host"})
	}
	if c.Phase != "active" {
		return SendPlan{}, apperr.BusinessRule("call_not_giftable", "gifts can only be sent during an active call")
	}
	s := st.Sender
	if !s.Exists || s.Status != "active" {
		return SendPlan{}, apperr.BusinessRule("account_restricted", "gifts are not available on this account")
	}
	if !s.AgeEligible {
		return SendPlan{}, apperr.BusinessRule("not_age_eligible", "confirm you are 18 or older first")
	}
	if s.HostState == "approved" {
		// Host accounts never send gifts (no host-to-host value transfer).
		return SendPlan{}, apperr.Forbidden("hosts_cannot_send_gifts", "host accounts cannot send gifts")
	}
	h := st.Recipient
	if !h.Exists || h.Status != "active" || !h.AgeEligible || h.HostState != "approved" {
		return SendPlan{}, apperr.BusinessRule("host_cannot_receive_gifts", "this host cannot receive gifts right now")
	}
	if st.Blocked {
		return SendPlan{}, apperr.BusinessRule("blocked", "gifts are not possible with this user")
	}
	if !st.GiftFound {
		return SendPlan{}, apperr.NotFound("gift")
	}
	g := st.Gift
	if !g.SellableAt(req.Now) {
		return SendPlan{}, apperr.BusinessRule("gift_unavailable", "this gift is not available")
	}
	price := g.DiamondPrice
	if price <= 0 {
		return SendPlan{}, apperr.BusinessRule("gift_unavailable", "this gift is not available")
	}
	if l.MaxPerCallPerMinute > 0 && st.SentInCallLastMinute >= l.MaxPerCallPerMinute {
		return SendPlan{}, &apperr.Error{Kind: apperr.KindRateLimited, Code: "gift_rate_limited", Detail: "please wait a moment before sending another gift"}
	}
	if l.DailySpendCap > 0 && st.SpentLast24h+price > l.DailySpendCap {
		return SendPlan{}, apperr.BusinessRule("gift_spend_limit", "you have reached the daily gift limit")
	}
	available := st.Promotional + st.Purchased - st.Reserved
	if available < price {
		return SendPlan{}, apperr.BusinessRule("insufficient_diamonds", "not enough Diamonds for this gift")
	}
	fromPromo, fromPurchased := Split(r, price, st.Promotional, st.Purchased)
	if fromPromo > st.Promotional || fromPurchased > st.Purchased {
		return SendPlan{}, apperr.BusinessRule("insufficient_diamonds", "not enough Diamonds for this gift")
	}
	beans, err := r.BeansForDiamonds(price)
	if err != nil {
		return SendPlan{}, apperr.Internal(err)
	}
	tx := Transaction{
		ID: newID(), SenderID: req.SenderID, RecipientID: c.ReceiverID, CallID: c.ID,
		GiftID: g.ID, GiftName: g.Name, Tier: g.Tier, Emoji: g.Emoji, AnimationAsset: g.AnimationAsset,
		DiamondPrice: price, FromPromotional: fromPromo, FromPurchased: fromPurchased, HostBeans: beans,
		RuleSetVersion: r.Version, ClientRequestID: req.ClientRequestID, RequestHash: req.RequestHash,
		RiskFlags: RiskFlags(l, st, price, fromPromo), CreatedAt: req.Now,
		SenderName: s.DisplayName, RecipientName: h.DisplayName, AnimationDurMs: g.AnimationDurationMs,
	}
	return SendPlan{
		Transaction: tx,
		ChatBody:    ChatLine(g.Emoji, s.DisplayName, g.Name, h.DisplayName),
		XPDelta:     beans * r.XPBeanWeight,
	}, nil
}
