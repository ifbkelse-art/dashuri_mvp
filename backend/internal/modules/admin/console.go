package admin

import (
	"context"
	"net/http"
	"strconv"
	"strings"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/routing"
)

// Admin console read views (2026-11-24). The web console needs lists that
// the decision endpoints never exposed: who the staff member is, pending
// host activations, appeals, pending ledger adjustments, recent audit
// events and display names for ids. All are read-only, staff-only and
// return the minimum fields a reviewer needs. Decisions still go through
// the owning modules' existing endpoints.

// ConsoleRepository is the read model behind the console views.
type ConsoleRepository interface {
	DisplayNames(ctx context.Context, ids []string) (map[string]string, error)
	HostApplications(ctx context.Context, limit int) ([]HostApplication, error)
	Appeals(ctx context.Context, status string, limit int) ([]AppealItem, error)
	Adjustments(ctx context.Context, status string, limit int) ([]AdjustmentItem, error)
	AuditEvents(ctx context.Context, limit int) ([]AuditItem, error)
}

// StaffMe: GET /v1/admin/me.
type StaffMe struct {
	UserId      string   `json:"user_id"`
	DisplayName *string  `json:"display_name"`
	Roles       []string `json:"roles"`
}

// HostApplication is a host waiting for basic activation (age and ID check).
type HostApplication struct {
	UserId              string    `json:"user_id"`
	DisplayName         *string   `json:"display_name"`
	City                *string   `json:"city"`
	State               string    `json:"state"`
	KycState            string    `json:"kyc_state"`
	DeclaredDateOfBirth *string   `json:"declared_date_of_birth"`
	AppliedAt           time.Time `json:"applied_at"`
}

type AppealEnforcement struct {
	Action    string    `json:"action"`
	Reason    string    `json:"reason"`
	CreatedAt time.Time `json:"created_at"`
}

type AppealItem struct {
	AppealId    string            `json:"appeal_id"`
	UserId      string            `json:"user_id"`
	DisplayName *string           `json:"display_name"`
	Statement   string            `json:"statement"`
	Status      string            `json:"status"`
	CreatedAt   time.Time         `json:"created_at"`
	Enforcement AppealEnforcement `json:"enforcement"`
}

type AdjustmentItem struct {
	ProposalId       string    `json:"proposal_id"`
	OwnerUserId      *string   `json:"owner_user_id"`
	OwnerDisplayName *string   `json:"owner_display_name"`
	AccountKind      string    `json:"account_kind"`
	Currency         string    `json:"currency"`
	Amount           int64     `json:"amount"`
	Reason           string    `json:"reason"`
	ProposedBy       string    `json:"proposed_by"`
	ProposedByName   *string   `json:"proposed_by_name"`
	Status           string    `json:"status"`
	CreatedAt        time.Time `json:"created_at"`
	// ProposedByMe: the caller cannot approve their own proposal.
	ProposedByMe bool `json:"proposed_by_me"`
}

type AuditItem struct {
	At         time.Time `json:"at"`
	Actor      string    `json:"actor"`
	ActorName  *string   `json:"actor_name"`
	Action     string    `json:"action"`
	Target     *string   `json:"target"`
	TargetName *string   `json:"target_name"`
	Reason     *string   `json:"reason"`
}

type UserName struct {
	UserId      string `json:"user_id"`
	DisplayName string `json:"display_name"`
}

type ListResponse[T any] struct {
	Items []T `json:"items"`
}

var staffRoles = []auth.Role{auth.RoleModerator, auth.RoleAdmin, auth.RoleFinance}

func consoleRoutes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	reviewers := []auth.Role{auth.RoleModerator, auth.RoleAdmin}
	mux.Handle("GET /v1/admin/me", mw.User(auth.Require(s.handleStaffMe, staffRoles...)))
	mux.Handle("GET /v1/admin/users", mw.User(auth.Require(s.handleUserNames, staffRoles...)))
	mux.Handle("GET /v1/admin/host-applications", mw.User(auth.Require(s.handleHostApplications, reviewers...)))
	mux.Handle("GET /v1/admin/appeals", mw.User(auth.Require(s.handleAppeals, reviewers...)))
	mux.Handle("GET /v1/admin/ledger/adjustments", mw.User(auth.Require(s.handleAdjustments, auth.RoleFinance, auth.RoleAdmin)))
	mux.Handle("GET /v1/admin/audit", mw.User(auth.Require(s.handleAudit, auth.RoleAdmin)))
}

func (s *Service) console() (ConsoleRepository, error) {
	if s.deps.Console == nil {
		return nil, errDB
	}
	return s.deps.Console, nil
}

// StaffMe returns the caller's staff identity and roles.
func (s *Service) StaffMe(ctx context.Context, p auth.Principal) (StaffMe, error) {
	c, err := s.console()
	if err != nil {
		return StaffMe{}, err
	}
	names, err := c.DisplayNames(ctx, []string{p.UserID})
	if err != nil {
		return StaffMe{}, err
	}
	out := StaffMe{UserId: p.UserID, Roles: []string{}}
	if n, ok := names[p.UserID]; ok {
		out.DisplayName = &n
	}
	for _, r := range p.Roles {
		out.Roles = append(out.Roles, string(r))
	}
	return out, nil
}

// UserNames resolves up to 50 user ids to display names (unknown ids are
// left out). Staff screens use it to name report targets and photo owners.
func (s *Service) UserNames(ctx context.Context, raw string) (ListResponse[UserName], error) {
	c, err := s.console()
	if err != nil {
		return ListResponse[UserName]{}, err
	}
	var ids []string
	seen := map[string]bool{}
	for _, id := range strings.Split(raw, ",") {
		if id = strings.TrimSpace(id); id == "" || seen[id] {
			continue
		}
		if !uuidRE.MatchString(id) {
			return ListResponse[UserName]{}, apperr.Validation(map[string]string{"ids": "invalid_uuid"})
		}
		seen[id] = true
		ids = append(ids, id)
	}
	if len(ids) == 0 {
		return ListResponse[UserName]{}, apperr.Validation(map[string]string{"ids": "required"})
	}
	if len(ids) > 50 {
		return ListResponse[UserName]{}, apperr.Validation(map[string]string{"ids": "too_many"})
	}
	names, err := c.DisplayNames(ctx, ids)
	if err != nil {
		return ListResponse[UserName]{}, err
	}
	out := ListResponse[UserName]{Items: []UserName{}}
	for _, id := range ids {
		if n, ok := names[id]; ok {
			out.Items = append(out.Items, UserName{UserId: id, DisplayName: n})
		}
	}
	return out, nil
}

func (s *Service) HostApplications(ctx context.Context, limit int) (ListResponse[HostApplication], error) {
	c, err := s.console()
	if err != nil {
		return ListResponse[HostApplication]{}, err
	}
	items, err := c.HostApplications(ctx, limit)
	return ListResponse[HostApplication]{Items: nonNil(items)}, err
}

var appealStatuses = map[string]bool{"open": true, "upheld": true, "overturned": true, "all": true}

func (s *Service) Appeals(ctx context.Context, status string, limit int) (ListResponse[AppealItem], error) {
	if status == "" {
		status = "open"
	}
	if !appealStatuses[status] {
		return ListResponse[AppealItem]{}, apperr.Validation(map[string]string{"status": "invalid_value"})
	}
	c, err := s.console()
	if err != nil {
		return ListResponse[AppealItem]{}, err
	}
	items, err := c.Appeals(ctx, status, limit)
	return ListResponse[AppealItem]{Items: nonNil(items)}, err
}

var adjustmentStatuses = map[string]bool{"awaiting_second_approval": true, "posted": true, "rejected": true, "all": true}

func (s *Service) Adjustments(ctx context.Context, p auth.Principal, status string, limit int) (ListResponse[AdjustmentItem], error) {
	if status == "" {
		status = "awaiting_second_approval"
	}
	if !adjustmentStatuses[status] {
		return ListResponse[AdjustmentItem]{}, apperr.Validation(map[string]string{"status": "invalid_value"})
	}
	c, err := s.console()
	if err != nil {
		return ListResponse[AdjustmentItem]{}, err
	}
	items, err := c.Adjustments(ctx, status, limit)
	for i := range items {
		items[i].ProposedByMe = items[i].ProposedBy == p.UserID
	}
	return ListResponse[AdjustmentItem]{Items: nonNil(items)}, err
}

func (s *Service) AuditEvents(ctx context.Context, limit int) (ListResponse[AuditItem], error) {
	c, err := s.console()
	if err != nil {
		return ListResponse[AuditItem]{}, err
	}
	items, err := c.AuditEvents(ctx, limit)
	return ListResponse[AuditItem]{Items: nonNil(items)}, err
}

func nonNil[T any](v []T) []T {
	if v == nil {
		return []T{}
	}
	return v
}

// limitParam reads ?limit= (default 50, 1..100).
func limitParam(r *http.Request) (int, error) {
	v := r.URL.Query().Get("limit")
	if v == "" {
		return 50, nil
	}
	n, err := strconv.Atoi(v)
	if err != nil || n < 1 || n > 100 {
		return 0, apperr.Validation(map[string]string{"limit": "out_of_range"})
	}
	return n, nil
}

func reply(w http.ResponseWriter, r *http.Request, v any, err error) {
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, v)
}

func (s *Service) handleStaffMe(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.StaffMe(r.Context(), p)
	reply(w, r, out, err)
}

func (s *Service) handleUserNames(w http.ResponseWriter, r *http.Request) {
	out, err := s.UserNames(r.Context(), r.URL.Query().Get("ids"))
	reply(w, r, out, err)
}

func (s *Service) handleHostApplications(w http.ResponseWriter, r *http.Request) {
	limit, err := limitParam(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.HostApplications(r.Context(), limit)
	reply(w, r, out, err)
}

func (s *Service) handleAppeals(w http.ResponseWriter, r *http.Request) {
	limit, err := limitParam(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.Appeals(r.Context(), r.URL.Query().Get("status"), limit)
	reply(w, r, out, err)
}

func (s *Service) handleAdjustments(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	limit, err := limitParam(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.Adjustments(r.Context(), p, r.URL.Query().Get("status"), limit)
	reply(w, r, out, err)
}

func (s *Service) handleAudit(w http.ResponseWriter, r *http.Request) {
	limit, err := limitParam(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.AuditEvents(r.Context(), limit)
	reply(w, r, out, err)
}
