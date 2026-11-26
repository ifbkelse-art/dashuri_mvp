package gifts

import (
	"context"
	"strings"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Catalogue administration (docs/gifts/VIRTUAL_GIFTS.md §7). Prices change
// only through ChangePrice, which writes gifts.price_changes and an
// audit.events row in the same transaction. Completed gift transactions
// store the price they were charged, so a price change never alters them.

func toAdminGift(i Item) AdminGift {
	return AdminGift{
		Gift: toGift(i), Active: i.Active, AvailableFrom: i.AvailableFrom, AvailableUntil: i.AvailableUntil,
		EarningRule: i.EarningRule, RetiredAt: i.RetiredAt, CreatedAt: i.CreatedAt, UpdatedAt: i.UpdatedAt,
	}
}

// AdminListGifts: GET /v1/admin/gifts — the whole catalogue (incl. inactive).
func (s *Service) AdminListGifts(ctx context.Context) ([]AdminGift, error) {
	repo, err := s.repo()
	if err != nil {
		return nil, err
	}
	items, err := repo.Catalogue(ctx, true)
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]AdminGift, 0, len(items))
	for _, it := range items {
		out = append(out, toAdminGift(it))
	}
	return out, nil
}

// AdminCreateGift: POST /v1/admin/gifts (admin role).
func (s *Service) AdminCreateGift(ctx context.Context, p auth.Principal, in CreateGiftRequest) (AdminGift, error) {
	if errs := in.validate(); len(errs) > 0 {
		return AdminGift{}, apperr.Validation(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return AdminGift{}, err
	}
	dur := in.AnimationDurationMs
	if dur == 0 {
		dur = 5000
	}
	it := Item{
		ID: in.Id, Name: strings.TrimSpace(in.Name), Description: strings.TrimSpace(in.Description),
		Emoji: strings.TrimSpace(in.Emoji), IconAsset: in.IconAsset, AnimationAsset: in.AnimationAsset,
		AnimationDurationMs: dur, SoundAsset: in.SoundAsset, Tier: in.Tier, SortOrder: in.SortOrder,
		DiamondPrice: in.DiamondPrice, Active: in.Active, AvailableFrom: in.AvailableFrom,
		AvailableUntil: in.AvailableUntil, EarningRule: "standard_conversion",
	}
	if err := repo.CreateItem(ctx, it, p.UserID, strings.TrimSpace(in.Reason)); err != nil {
		return AdminGift{}, mapErr(err)
	}
	got, err := repo.Item(ctx, in.Id)
	return toAdminGift(got), mapErr(err)
}

// AdminUpdateGift: PATCH /v1/admin/gifts/{giftId} — metadata, active
// status, sort order, schedule, retirement. Never the price.
func (s *Service) AdminUpdateGift(ctx context.Context, p auth.Principal, giftID string, in UpdateGiftRequest) (AdminGift, error) {
	if errs := in.validate(); len(errs) > 0 {
		return AdminGift{}, apperr.Validation(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return AdminGift{}, err
	}
	it, err := repo.Item(ctx, giftID)
	if err != nil {
		return AdminGift{}, mapErr(err)
	}
	if it.RetiredAt != nil {
		return AdminGift{}, apperr.BusinessRule("gift_retired", "a retired gift cannot be changed")
	}
	set := func(dst *string, v *string) {
		if v != nil {
			*dst = strings.TrimSpace(*v)
		}
	}
	set(&it.Name, in.Name)
	set(&it.Description, in.Description)
	set(&it.Emoji, in.Emoji)
	set(&it.IconAsset, in.IconAsset)
	set(&it.AnimationAsset, in.AnimationAsset)
	set(&it.Tier, in.Tier)
	if in.AnimationDurationMs != nil {
		it.AnimationDurationMs = *in.AnimationDurationMs
	}
	if in.SoundAsset != nil {
		if v := strings.TrimSpace(*in.SoundAsset); v == "" {
			it.SoundAsset = nil
		} else {
			it.SoundAsset = &v
		}
	}
	if in.SortOrder != nil {
		it.SortOrder = *in.SortOrder
	}
	if in.Active != nil {
		it.Active = *in.Active
	}
	if in.ClearSchedule {
		it.AvailableFrom, it.AvailableUntil = nil, nil
	}
	if in.AvailableFrom != nil {
		it.AvailableFrom = in.AvailableFrom
	}
	if in.AvailableUntil != nil {
		it.AvailableUntil = in.AvailableUntil
	}
	if it.AvailableFrom != nil && it.AvailableUntil != nil && !it.AvailableUntil.After(*it.AvailableFrom) {
		return AdminGift{}, apperr.Validation(map[string]string{"available_until": "must_be_after_available_from"})
	}
	if in.Retire {
		now := s.now()
		it.RetiredAt, it.Active = &now, false
	}
	if err := repo.UpdateItem(ctx, it, p.UserID); err != nil {
		return AdminGift{}, mapErr(err)
	}
	got, err := repo.Item(ctx, giftID)
	return toAdminGift(got), mapErr(err)
}

// AdminChangePrice: POST /v1/admin/gifts/{giftId}/price (admin role). The
// new price applies to gifts sent after the change only.
func (s *Service) AdminChangePrice(ctx context.Context, p auth.Principal, giftID string, in ChangePriceRequest) (AdminGift, error) {
	if errs := in.validate(); len(errs) > 0 {
		return AdminGift{}, apperr.Validation(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return AdminGift{}, err
	}
	it, err := repo.Item(ctx, giftID)
	if err != nil {
		return AdminGift{}, mapErr(err)
	}
	if it.RetiredAt != nil {
		return AdminGift{}, apperr.BusinessRule("gift_retired", "a retired gift cannot be repriced")
	}
	if it.DiamondPrice == in.DiamondPrice {
		return toAdminGift(it), nil
	}
	if _, err := repo.ChangePrice(ctx, PricePatch{GiftID: giftID, NewPrice: in.DiamondPrice, ActorID: p.UserID, Reason: strings.TrimSpace(in.Reason)}); err != nil {
		return AdminGift{}, mapErr(err)
	}
	got, err := repo.Item(ctx, giftID)
	return toAdminGift(got), mapErr(err)
}

// AdminPriceHistory: GET /v1/admin/gifts/{giftId}/price-history.
func (s *Service) AdminPriceHistory(ctx context.Context, giftID string) ([]PriceChangeItem, error) {
	repo, err := s.repo()
	if err != nil {
		return nil, err
	}
	if _, err := repo.Item(ctx, giftID); err != nil {
		return nil, mapErr(err)
	}
	rows, err := repo.PriceHistory(ctx, giftID, 100)
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]PriceChangeItem, 0, len(rows))
	for _, r := range rows {
		out = append(out, PriceChangeItem(r))
	}
	return out, nil
}

// AdminPerformance: GET /v1/admin/gifts/performance?days=30.
func (s *Service) AdminPerformance(ctx context.Context, days int) ([]GiftPerformance, error) {
	if days < 1 || days > 365 {
		return nil, apperr.Validation(map[string]string{"days": "must_be_1_to_365"})
	}
	repo, err := s.repo()
	if err != nil {
		return nil, err
	}
	rows, err := repo.Performance(ctx, s.now().Add(-time.Duration(days)*24*time.Hour))
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]GiftPerformance, 0, len(rows))
	for _, r := range rows {
		out = append(out, GiftPerformance{GiftId: r.GiftID, GiftName: r.GiftName, Count: r.Count, DiamondValue: r.Diamonds,
			HostBeans: r.HostBeans, UniqueSenders: r.UniqueSenders, UniqueHosts: r.UniqueHosts})
	}
	return out, nil
}

// AdminListTransactions: GET /v1/admin/gifts/transactions — investigation
// list (filters: user_id as sender or recipient, call_id, flagged).
func (s *Service) AdminListTransactions(ctx context.Context, userID, callID string, flagged bool, page PageRequest) (Page[AdminGiftTransaction], error) {
	if userID != "" && !isUUID(userID) {
		return Page[AdminGiftTransaction]{}, apperr.Validation(map[string]string{"user_id": "invalid_uuid"})
	}
	if callID != "" && !isUUID(callID) {
		return Page[AdminGiftTransaction]{}, apperr.Validation(map[string]string{"call_id": "invalid_uuid"})
	}
	repo, err := s.repo()
	if err != nil {
		return Page[AdminGiftTransaction]{}, err
	}
	rows, next, err := s.history(ctx, repo, HistoryQuery{UserID: userID, As: "any", CallID: callID, Flagged: flagged}, page)
	if err != nil {
		return Page[AdminGiftTransaction]{}, err
	}
	out := Page[AdminGiftTransaction]{Items: []AdminGiftTransaction{}, NextCursor: next}
	for _, t := range rows {
		flags := t.RiskFlags
		if flags == nil {
			flags = []string{}
		}
		out.Items = append(out.Items, AdminGiftTransaction{GiftEvent: toEvent(t), FromPromotional: t.FromPromotional,
			FromPurchased: t.FromPurchased, HostBeans: t.HostBeans, RuleSetVersion: t.RuleSetVersion,
			LedgerEntryId: t.LedgerEntryID, RiskFlags: flags})
	}
	return out, nil
}
