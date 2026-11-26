package admin

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/routing"
)

type fakeConsole struct {
	adjustments []AdjustmentItem
	lastStatus  string
	lastLimit   int
}

func (f *fakeConsole) DisplayNames(_ context.Context, ids []string) (map[string]string, error) {
	out := map[string]string{}
	for _, id := range ids {
		if id == "11111111-1111-4111-8111-111111111111" {
			out[id] = "Priya"
		}
	}
	return out, nil
}
func (f *fakeConsole) HostApplications(_ context.Context, limit int) ([]HostApplication, error) {
	f.lastLimit = limit
	return nil, nil
}
func (f *fakeConsole) Appeals(_ context.Context, status string, limit int) ([]AppealItem, error) {
	f.lastStatus, f.lastLimit = status, limit
	return nil, nil
}
func (f *fakeConsole) Adjustments(_ context.Context, status string, _ int) ([]AdjustmentItem, error) {
	f.lastStatus = status
	return append([]AdjustmentItem(nil), f.adjustments...), nil
}
func (f *fakeConsole) AuditEvents(_ context.Context, _ int) ([]AuditItem, error) { return nil, nil }

// mux mounts the console routes with a stack that injects the given roles.
func consoleMux(f *fakeConsole, userID string, roles ...auth.Role) *http.ServeMux {
	s := NewService(Deps{Console: f})
	inject := func(h http.HandlerFunc) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h(w, r.WithContext(auth.WithPrincipal(r.Context(), auth.Principal{UserID: userID, Roles: roles, Status: "active"})))
		})
	}
	mux := http.NewServeMux()
	consoleRoutes(mux, s, routing.Stack{User: inject, UserAllowingSuspended: inject})
	return mux
}

func get(mux *http.ServeMux, path string) *httptest.ResponseRecorder {
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, httptest.NewRequest("GET", path, nil))
	return w
}

const me = "22222222-2222-4222-8222-222222222222"

func TestConsoleRoleMatrix(t *testing.T) {
	type c struct {
		path string
		want map[auth.Role]int
	}
	cases := []c{
		{"/v1/admin/me", map[auth.Role]int{auth.RoleCustomer: 403, auth.RoleHost: 403, auth.RoleModerator: 200, auth.RoleAdmin: 200, auth.RoleFinance: 200}},
		{"/v1/admin/host-applications", map[auth.Role]int{auth.RoleCustomer: 403, auth.RoleHost: 403, auth.RoleModerator: 200, auth.RoleAdmin: 200, auth.RoleFinance: 403}},
		{"/v1/admin/appeals", map[auth.Role]int{auth.RoleCustomer: 403, auth.RoleModerator: 200, auth.RoleAdmin: 200, auth.RoleFinance: 403}},
		{"/v1/admin/ledger/adjustments", map[auth.Role]int{auth.RoleCustomer: 403, auth.RoleModerator: 403, auth.RoleAdmin: 200, auth.RoleFinance: 200}},
		{"/v1/admin/audit", map[auth.Role]int{auth.RoleCustomer: 403, auth.RoleModerator: 403, auth.RoleFinance: 403, auth.RoleAdmin: 200}},
		{"/v1/admin/users?ids=11111111-1111-4111-8111-111111111111", map[auth.Role]int{auth.RoleCustomer: 403, auth.RoleHost: 403, auth.RoleModerator: 200, auth.RoleFinance: 200}},
	}
	for _, tc := range cases {
		for role, want := range tc.want {
			w := get(consoleMux(&fakeConsole{}, me, role), tc.path)
			if w.Code != want {
				t.Errorf("%s as %s: got %d, want %d (%s)", tc.path, role, w.Code, want, w.Body.String())
			}
		}
	}
}

func TestStaffMeReturnsRoles(t *testing.T) {
	w := get(consoleMux(&fakeConsole{}, me, auth.RoleCustomer, auth.RoleAdmin), "/v1/admin/me")
	var out StaffMe
	_ = json.Unmarshal(w.Body.Bytes(), &out)
	if out.UserId != me || len(out.Roles) != 2 || out.Roles[1] != "admin" {
		t.Fatalf("%+v", out)
	}
}

func TestUserNamesValidation(t *testing.T) {
	mux := consoleMux(&fakeConsole{}, me, auth.RoleModerator)
	if w := get(mux, "/v1/admin/users"); w.Code != 422 {
		t.Fatalf("missing ids: %d", w.Code)
	}
	if w := get(mux, "/v1/admin/users?ids=not-a-uuid"); w.Code != 422 {
		t.Fatalf("bad id: %d", w.Code)
	}
	w := get(mux, "/v1/admin/users?ids=11111111-1111-4111-8111-111111111111,33333333-3333-4333-8333-333333333333")
	var out ListResponse[UserName]
	_ = json.Unmarshal(w.Body.Bytes(), &out)
	if w.Code != 200 || len(out.Items) != 1 || out.Items[0].DisplayName != "Priya" {
		t.Fatalf("%d %+v", w.Code, out)
	}
}

func TestListParams(t *testing.T) {
	f := &fakeConsole{}
	mux := consoleMux(f, me, auth.RoleModerator)
	if w := get(mux, "/v1/admin/appeals"); w.Code != 200 || f.lastStatus != "open" || f.lastLimit != 50 {
		t.Fatalf("defaults: %d %q %d", w.Code, f.lastStatus, f.lastLimit)
	}
	if w := get(mux, "/v1/admin/appeals?status=bogus"); w.Code != 422 {
		t.Fatalf("bad status: %d", w.Code)
	}
	if w := get(mux, "/v1/admin/host-applications?limit=0"); w.Code != 422 {
		t.Fatalf("bad limit: %d", w.Code)
	}
	if w := get(mux, "/v1/admin/host-applications?limit=101"); w.Code != 422 {
		t.Fatalf("limit too big: %d", w.Code)
	}
	if w := get(mux, "/v1/admin/host-applications?limit=10"); w.Code != 200 || f.lastLimit != 10 {
		t.Fatalf("limit: %d %d", w.Code, f.lastLimit)
	}
	w := get(mux, "/v1/admin/host-applications")
	if w.Body.String() != "{\"items\":[]}\n" && w.Body.String() != "{\"items\":[]}" {
		t.Fatalf("empty list must be [] not null: %s", w.Body.String())
	}
}

func TestAdjustmentsMarkOwnProposals(t *testing.T) {
	f := &fakeConsole{adjustments: []AdjustmentItem{{ProposalId: "a", ProposedBy: me}, {ProposalId: "b", ProposedBy: "someone-else"}}}
	w := get(consoleMux(f, me, auth.RoleFinance), "/v1/admin/ledger/adjustments")
	var out ListResponse[AdjustmentItem]
	_ = json.Unmarshal(w.Body.Bytes(), &out)
	if f.lastStatus != "awaiting_second_approval" || len(out.Items) != 2 || !out.Items[0].ProposedByMe || out.Items[1].ProposedByMe {
		t.Fatalf("%q %+v", f.lastStatus, out)
	}
}

func TestConsoleUnavailableWithoutRepo(t *testing.T) {
	s := NewService(Deps{})
	if _, err := s.HostApplications(context.Background(), 10); err == nil {
		t.Fatal("expected 503 without a database")
	}
}
