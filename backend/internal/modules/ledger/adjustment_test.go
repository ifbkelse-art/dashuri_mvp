package ledger

import (
	"errors"
	"testing"
)

func TestAdjustmentBalancedPerCurrency(t *testing.T) {
	for _, tc := range []struct {
		kind AccountKind
		amt  int64
		sys  AccountKind
		cur  Currency
	}{
		{UserDiamondPurchased, 500, SystemDiamondAdjustment, Diamond},
		{UserDiamondPromotional, -20, SystemDiamondAdjustment, Diamond},
		{UserBeanAvailable, 1000, SystemBeanAdjustment, Bean},
		{UserBeanHeld, -7, SystemBeanAdjustment, Bean},
	} {
		e, err := Adjustment("p1", User("u1", tc.kind), tc.amt, "fix", "a", "b", now)
		if err != nil {
			t.Fatal(err)
		}
		if err := e.Validate(); err != nil {
			t.Fatalf("%s: %v", tc.kind, err)
		}
		if e.IdempotencyKey != "adjustment:p1" || e.Type != EntryAdjustment {
			t.Fatalf("bad key/type %s %s", e.IdempotencyKey, e.Type)
		}
		if e.Postings[1].Account.Kind != tc.sys || e.Postings[0].Currency != tc.cur || e.Postings[0].Amount != tc.amt {
			t.Fatalf("bad postings %+v", e.Postings)
		}
	}
}

func TestAdjustmentRejectsInvalid(t *testing.T) {
	cases := []struct {
		acct AccountRef
		amt  int64
	}{
		{System(SystemDiamondConsumed), 5},       // system account
		{User("u1", UserDiamondPurchased), 0},    // zero
		{User("u1", AccountKind("unknown")), 10}, // unknown kind
	}
	for _, c := range cases {
		if _, err := Adjustment("p", c.acct, c.amt, "r", "a", "b", now); !errors.Is(err, ErrAdjustment) {
			t.Fatalf("%+v: want ErrAdjustment, got %v", c, err)
		}
	}
}
