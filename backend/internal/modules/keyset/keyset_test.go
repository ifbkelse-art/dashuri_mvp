package keyset

import (
	"strings"
	"testing"
	"time"
)

func TestRoundTrip(t *testing.T) {
	c := Cursor{At: time.Date(2026, 11, 21, 10, 0, 0, 123456000, time.FixedZone("IST", 19800)), ID: "11111111-1111-4111-8111-111111111111"}
	got, err := Decode(c.Encode())
	if err != nil || !got.At.Equal(c.At) || got.ID != c.ID {
		t.Fatalf("%+v %v", got, err)
	}
	if c, err := Decode(""); c != nil || err != nil {
		t.Fatal("empty must be first page")
	}
}

func TestRejects(t *testing.T) {
	for _, bad := range []string{
		"@@", "Zm9v", strings.Repeat("A", 201),
		Cursor{At: time.Now(), ID: "x' or 1=1"}.Encode(),
		"YzF8bm90LWEtdGltZXwxMTExMTExMS0xMTExLTQxMTEtODExMS0xMTExMTExMTExMTE",
	} {
		if _, err := Decode(bad); err == nil {
			t.Errorf("accepted %q", bad)
		}
	}
}
