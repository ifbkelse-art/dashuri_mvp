package purchases

import (
	"testing"
	"time"
)

// Google rejects a voidedpurchases startTime older than 30 days. A request
// built at exactly now-30d arrives slightly past the limit, so the lookback
// must stay clearly inside it.
func TestVoidedLookbackStaysInsideGoogleLimit(t *testing.T) {
	const googleLimit = 30 * 24 * time.Hour
	if VoidedLookback >= googleLimit {
		t.Fatalf("lookback %v must be shorter than Google's %v limit", VoidedLookback, googleLimit)
	}
	if googleLimit-VoidedLookback < time.Hour {
		t.Fatalf("keep at least an hour of margin, got %v", googleLimit-VoidedLookback)
	}
}
