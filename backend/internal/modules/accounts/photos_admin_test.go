package accounts

import (
	"context"
	"strings"
	"testing"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

func TestPhotoDecisionRequestValidate(t *testing.T) {
	long := strings.Repeat("न", MaxDecisionReason+1)
	ok := strings.Repeat("x", MaxDecisionReason)
	for _, c := range []struct {
		r     PhotoDecisionRequest
		field string
	}{
		{PhotoDecisionRequest{Decision: ""}, "decision"},
		{PhotoDecisionRequest{Decision: "maybe"}, "decision"},
		{PhotoDecisionRequest{Decision: "reject", Reason: &long}, "reason"},
	} {
		if errs := c.r.validate(); errs[c.field] == "" {
			t.Errorf("%+v: want %s error", c.r, c.field)
		}
	}
	for _, r := range []PhotoDecisionRequest{{Decision: "approve"}, {Decision: "reject", Reason: &ok}} {
		if errs := r.validate(); len(errs) != 0 {
			t.Errorf("%+v rejected: %v", r, errs)
		}
	}
}

func TestModeratorOnly(t *testing.T) {
	s := NewService(Deps{})
	cust := auth.Principal{UserID: "u", Roles: []auth.Role{auth.RoleCustomer, auth.RoleHost}}
	if _, err := s.ListPendingPhotos(context.Background(), cust, "", 10); apperr.As(err).Kind != apperr.KindForbidden {
		t.Fatalf("customer list: %v", err)
	}
	if _, err := s.DecidePhoto(context.Background(), cust, "11111111-1111-4111-8111-111111111111", PhotoDecisionRequest{Decision: "approve"}); apperr.As(err).Kind != apperr.KindForbidden {
		t.Fatalf("customer decide: %v", err)
	}
	// Moderator passes the role check and reaches the (missing) database.
	mod := auth.Principal{UserID: "m", Roles: []auth.Role{auth.RoleModerator}}
	if _, err := s.ListPendingPhotos(context.Background(), mod, "", 10); apperr.As(err).Kind != apperr.KindUnavailable {
		t.Fatalf("moderator list: %v", err)
	}
	if err := s.DeleteMyPhoto(context.Background(), cust, "nope"); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("bad id: %v", err)
	}
}
