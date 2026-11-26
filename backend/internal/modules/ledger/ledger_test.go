package ledger

import (
	"errors"
	"testing"
	"time"
)

var now = time.Date(2026, 11, 17, 10, 0, 0, 0, time.UTC)

func TestTemplatesAreBalanced(t *testing.T) {
	settle, err := CallSettlement(CallCharge{CallID: "c1", CustomerID: "u1", HostID: "h1", FromPromotional: 1000, FromPurchased: 3333, HostBeans: 2599, At: now})
	if err != nil {
		t.Fatal(err)
	}
	entries := []Entry{
		PurchaseCredit("u1", "p1", "tokhash", 54000, "v1", now),
		settle,
		FreeCallCompensation("f1", "h1", 2000, "v1", now),
		BeanRelease("h1", "e1", 2599, now),
		WithdrawalRequested("h1", "w1", 100000, now),
		PayoutSettled("h1", "w1", 100000, true, now),
		PayoutSettled("h1", "w2", 100000, false, now),
		PromoExpiry("u1", "g1", 500, now),
		PurchaseReversal("u1", "p1", 20000, now),
		BeanClawback("h1", "case1", 1500, now),
	}
	for _, e := range entries {
		if err := e.Validate(); err != nil {
			t.Errorf("%s: %v", e.Type, err)
		}
	}
}

func TestUnbalancedRejected(t *testing.T) {
	e := Entry{IdempotencyKey: "k", Postings: []Posting{
		{User("u1", UserDiamondPurchased), Diamond, -10},
		{System(SystemDiamondConsumed), Diamond, 9},
	}}
	if !errors.Is(e.Validate(), ErrUnbalanced) {
		t.Fatal("expected ErrUnbalanced")
	}
}

func TestCrossCurrencyCannotBalance(t *testing.T) {
	// Diamonds and Beans are separate currencies: a Diamond debit cannot be
	// balanced by a Bean credit.
	e := Entry{IdempotencyKey: "k", Postings: []Posting{
		{User("u1", UserDiamondPurchased), Diamond, -100},
		{User("h1", UserBeanHeld), Bean, 100},
	}}
	if !errors.Is(e.Validate(), ErrUnbalanced) {
		t.Fatal("expected ErrUnbalanced")
	}
}

func TestWrongCurrencyForAccount(t *testing.T) {
	e := Entry{IdempotencyKey: "k", Postings: []Posting{
		{User("u1", UserDiamondPurchased), Bean, -1},
		{System(SystemBeanIssued), Bean, 1},
	}}
	if !errors.Is(e.Validate(), ErrCurrencyAccount) {
		t.Fatal("expected ErrCurrencyAccount")
	}
}

func TestSettlementKeyIsPerCall(t *testing.T) {
	a, _ := CallSettlement(CallCharge{CallID: "c9", CustomerID: "u", HostID: "h", FromPurchased: 10, At: now})
	b, _ := CallSettlement(CallCharge{CallID: "c9", CustomerID: "u", HostID: "h", FromPurchased: 99, At: now})
	if a.IdempotencyKey != b.IdempotencyKey {
		t.Fatal("two settlements of one call must share the idempotency key")
	}
	if _, err := CallSettlement(CallCharge{CallID: "c0"}); !errors.Is(err, ErrNothingToSettle) {
		t.Fatal("zero charge must not produce an entry")
	}
}

func TestMissingKeyRejected(t *testing.T) {
	e := PurchaseCredit("u1", "p1", "", 1, "v1", now)
	e.IdempotencyKey = ""
	if !errors.Is(e.Validate(), ErrMissingKey) {
		t.Fatal("expected ErrMissingKey")
	}
}

func TestGiftSendIsBalancedAndKeyedPerGift(t *testing.T) {
	e, err := GiftSend(GiftCharge{GiftTransactionID: "g1", CallID: "c1", CustomerID: "u1", HostID: "h1", GiftID: "rose",
		FromPromotional: 500, FromPurchased: 1000, HostBeans: 899, RuleSetVersion: "v1", At: now})
	if err != nil {
		t.Fatal(err)
	}
	if err := e.Validate(); err != nil {
		t.Fatal(err)
	}
	if e.IdempotencyKey != "gift_send:g1" || e.Type != EntryGiftSend || e.Reference != "g1" {
		t.Fatalf("bad entry %+v", e)
	}
	var diamonds, beans int64
	for _, p := range e.Postings {
		if p.Account.UserID == "u1" {
			diamonds += p.Amount
		}
		if p.Account.UserID == "h1" {
			beans += p.Amount
		}
	}
	if diamonds != -1500 || beans != 899 {
		t.Fatalf("customer %d, host %d", diamonds, beans)
	}
}

func TestGiftSendRejectsInvalid(t *testing.T) {
	for _, c := range []GiftCharge{
		{GiftTransactionID: "g", CustomerID: "u", HostID: "h"},                                         // nothing charged
		{GiftTransactionID: "g", CustomerID: "u", HostID: "u", FromPurchased: 10},                      // self gift
		{GiftTransactionID: "", CustomerID: "u", HostID: "h", FromPurchased: 10},                       // no id
		{GiftTransactionID: "g", CustomerID: "u", HostID: "h", FromPurchased: 10, HostBeans: -1},       // negative beans
		{GiftTransactionID: "g", CustomerID: "u", HostID: "h", FromPromotional: -5, FromPurchased: 10}, // negative split
	} {
		if _, err := GiftSend(c); !errors.Is(err, ErrInvalidGiftCharge) {
			t.Fatalf("%+v: want ErrInvalidGiftCharge, got %v", c, err)
		}
	}
}
