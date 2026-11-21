package chat

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestSendMessageValidate(t *testing.T) {
	ok := []string{"hi", strings.Repeat("a", 1000), strings.Repeat("न", 1000), "line one\nline two"}
	for _, b := range ok {
		r := SendMessageRequest{Body: b}
		r.normalize()
		if errs := r.validate(); len(errs) != 0 {
			t.Errorf("rejected %q: %v", b[:min(len(b), 10)], errs)
		}
	}
	bad := map[string]string{"": "required", "   \n ": "required", strings.Repeat("a", 1001): "too_long", "bell\a": "invalid_characters", "\xff\xfe": "invalid_encoding"}
	for b, want := range bad {
		r := SendMessageRequest{Body: b}
		r.normalize()
		if got := r.validate()["body"]; got != want {
			t.Errorf("%q: got %q want %q", b, got, want)
		}
	}
}

func TestMessagingPrivacyValidate(t *testing.T) {
	for _, v := range []string{"everyone", "past_call_partners"} {
		if errs := (MessagingPrivacy{v}).validate(); len(errs) != 0 {
			t.Error(v, errs)
		}
	}
	for _, v := range []string{"", "nobody"} {
		if errs := (MessagingPrivacy{v}).validate(); len(errs) == 0 {
			t.Error("accepted", v)
		}
	}
	if errs := (StartConversationRequest{"nope"}).validate(); errs["peer_user_id"] != "invalid_uuid" {
		t.Error(errs)
	}
}

func TestCursor(t *testing.T) {
	c := Cursor{At: time.Date(2026, 11, 21, 10, 0, 0, 123456000, time.UTC), ID: "11111111-1111-4111-8111-111111111111"}
	got, err := DecodeCursor(c.Encode())
	if err != nil || !got.At.Equal(c.At) || got.ID != c.ID {
		t.Fatalf("%+v %v", got, err)
	}
	for _, bad := range []string{"@@", Cursor{At: c.At, ID: "x"}.Encode(), "YzF8bm90LWEtdGltZXwxMTExMTExMS0xMTExLTQxMTEtODExMS0xMTExMTExMTExMTE"} {
		if _, err := DecodeCursor(bad); err == nil {
			t.Errorf("accepted %q", bad)
		}
	}
}

func TestPreview(t *testing.T) {
	if preview("short") != "short" {
		t.Fatal()
	}
	if p := preview(strings.Repeat("ab", 100)); len([]rune(p)) != previewChars+1 {
		t.Fatal(len([]rune(p)))
	}
}

func TestMessageRejectedProblemHasReason(t *testing.T) {
	rr := httptest.NewRecorder()
	writeError(rr, httptest.NewRequest(http.MethodPost, "/", nil), errMessageRejected())
	var body map[string]any
	_ = json.Unmarshal(rr.Body.Bytes(), &body)
	if rr.Code != 409 || body["reason"] != "contact_details" || body["rule"] != "message_rejected" || body["code"] != "business_rule" {
		t.Fatalf("%d %v", rr.Code, body)
	}
}
