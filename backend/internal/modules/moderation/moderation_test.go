package moderation

import (
	"encoding/base64"
	"strings"
	"testing"
	"time"
)

func TestMaxGap(t *testing.T) {
	t0 := time.Date(2026, 11, 21, 10, 0, 0, 0, time.UTC)
	s := func(n int) time.Time { return t0.Add(time.Duration(n) * time.Second) }
	if g := MaxGap(t0, s(180), []time.Time{s(10), s(30), s(50), s(70), s(90), s(110), s(130), s(150), s(170)}); g != 20*time.Second {
		t.Fatalf("regular frames: %v", g)
	}
	if g := MaxGap(t0, s(100), []time.Time{s(10), s(80)}); g != 70*time.Second {
		t.Fatalf("gap: %v", g)
	}
	if g := MaxGap(t0, s(90), nil); g != 90*time.Second {
		t.Fatalf("no frames: %v", g)
	}
	if g := MaxGap(t0, s(30), []time.Time{s(-5), s(200)}); g != 30*time.Second {
		t.Fatalf("out of range: %v", g)
	}
}

func TestDecodeFrame(t *testing.T) {
	jpeg := append([]byte{0xFF, 0xD8, 0xFF, 0xE0}, []byte("data")...)
	if _, err := DecodeFrame(base64.StdEncoding.EncodeToString(jpeg)); err != nil {
		t.Fatal(err)
	}
	if _, err := DecodeFrame("data:image/jpeg;base64," + base64.StdEncoding.EncodeToString(jpeg)); err != nil {
		t.Fatal(err)
	}
	if _, err := DecodeFrame(base64.StdEncoding.EncodeToString([]byte("\x89PNG...."))); err == nil {
		t.Fatal("png accepted")
	}
	big := append([]byte{0xFF, 0xD8, 0xFF}, make([]byte, MaxFrameBytes)...)
	if _, err := DecodeFrame(base64.StdEncoding.EncodeToString(big)); err == nil || !strings.Contains(err.Error(), "validation") {
		t.Fatalf("oversized frame: %v", err)
	}
	if _, err := DecodeFrame("%%%"); err == nil {
		t.Fatal("garbage accepted")
	}
}

func TestQueueCursor(t *testing.T) {
	c := QueueCursor{Priority: 1, CreatedAt: time.Date(2026, 1, 1, 0, 0, 0, 5, time.UTC), ID: "3f1c7b1e-0000-4000-8000-000000000001"}
	got, err := decodeQueueCursor(encodeQueueCursor(c))
	if err != nil || got.Priority != 1 || !got.CreatedAt.Equal(c.CreatedAt) || got.ID != c.ID {
		t.Fatalf("%+v %v", got, err)
	}
}

func TestScoreThreshold(t *testing.T) {
	s := NudityScore{SexualActivity: 0.1, SexualDisplay: 0.2, Erotica: 0.6, VerySuggestive: 0.99}
	if !s.Flagged(DefaultFlagThreshold) || s.Flagged(0.61) {
		t.Fatal("threshold")
	}
}
