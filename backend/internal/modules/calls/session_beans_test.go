package calls

import "testing"

func TestToSessionHostBeansIncludeGifts(t *testing.T) {
	settled := int64(137)
	c := Call{ID: "c1", CallerID: "cust", ReceiverID: "host", BeansEarned: &settled, GiftBeansEarned: 899 + 2999}

	host := toSession(c, "host", nil)
	if host.BeansEarned == nil || *host.BeansEarned != 137+899+2999 {
		t.Fatalf("host total = %v, want %d", host.BeansEarned, 137+899+2999)
	}
	if host.GiftBeansEarned == nil || *host.GiftBeansEarned != 3898 {
		t.Fatalf("gift part = %v, want 3898", host.GiftBeansEarned)
	}

	// The customer never sees Beans.
	cust := toSession(c, "cust", nil)
	if cust.BeansEarned != nil || cust.GiftBeansEarned != nil {
		t.Fatal("customer must not see Beans")
	}

	// Not settled yet: nothing is shown, even if a gift exists.
	c.BeansEarned = nil
	if s := toSession(c, "host", nil); s.BeansEarned != nil || s.GiftBeansEarned != nil {
		t.Fatal("unsettled call must not show a partial total")
	}

	// No gifts: total is the settlement and the gift part is omitted.
	c.BeansEarned, c.GiftBeansEarned = &settled, 0
	if s := toSession(c, "host", nil); *s.BeansEarned != 137 || s.GiftBeansEarned != nil {
		t.Fatalf("no-gift call = %v / %v", s.BeansEarned, s.GiftBeansEarned)
	}
}
