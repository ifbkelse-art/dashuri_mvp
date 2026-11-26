package gifts

import (
	"net/http"
	"strconv"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/idempotency"
	"dashuri/backend/internal/platform/routing"
)

// Routes registers this module's endpoints. Sending is a financial
// mutation: it requires an Idempotency-Key (UUIDv4), checked twice — by the
// shared HTTP idempotency store and, durably, by the unique
// (sender, client_request_id) on gifts.transactions.
func Routes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	mux.Handle("GET /v1/gifts/catalogue", mw.User(s.handleGetCatalogue))
	mux.Handle("POST /v1/calls/{callId}/gifts", mw.User(idempotency.Require(mw.Idempotency, s.handleSendGift)))
	mux.Handle("GET /v1/calls/{callId}/gifts", mw.User(s.handleListCallGifts))
	mux.Handle("GET /v1/me/gifts/sent", mw.User(s.handleListSentGifts))
	mux.Handle("GET /v1/host/gifts", mw.User(auth.Require(s.handleListReceivedGifts, auth.RoleHost)))
	mux.Handle("GET /v1/host/gifts/summary", mw.User(auth.Require(s.handleGetReceivedSummary, auth.RoleHost)))

	staff := []auth.Role{auth.RoleAdmin, auth.RoleFinance, auth.RoleModerator}
	mux.Handle("GET /v1/admin/gifts", mw.User(auth.Require(s.handleAdminList, staff...)))
	mux.Handle("POST /v1/admin/gifts", mw.User(idempotency.Require(mw.Idempotency, auth.Require(s.handleAdminCreate, auth.RoleAdmin))))
	mux.Handle("PATCH /v1/admin/gifts/{giftId}", mw.User(auth.Require(s.handleAdminUpdate, auth.RoleAdmin)))
	mux.Handle("POST /v1/admin/gifts/{giftId}/price", mw.User(idempotency.Require(mw.Idempotency, auth.Require(s.handleAdminPrice, auth.RoleAdmin))))
	mux.Handle("GET /v1/admin/gifts/{giftId}/price-history", mw.User(auth.Require(s.handleAdminPriceHistory, staff...)))
	mux.Handle("GET /v1/admin/gifts/performance", mw.User(auth.Require(s.handleAdminPerformance, staff...)))
	mux.Handle("GET /v1/admin/gifts/transactions", mw.User(auth.Require(s.handleAdminTransactions, staff...)))
}

func principal(r *http.Request) auth.Principal {
	p, _ := auth.FromContext(r.Context())
	return p
}

func write[T any](w http.ResponseWriter, r *http.Request, status int, out T, err error) {
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, status, out)
}

func (s *Service) handleGetCatalogue(w http.ResponseWriter, r *http.Request) {
	out, err := s.GetCatalogue(r.Context(), principal(r))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleSendGift(w http.ResponseWriter, r *http.Request) {
	var in SendGiftRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.SendGift(r.Context(), principal(r), r.PathValue("callId"), r.Header.Get("Idempotency-Key"), in)
	status := http.StatusCreated
	if out.Replayed {
		status = http.StatusOK
	}
	write(w, r, status, out, err)
}

func (s *Service) handleListCallGifts(w http.ResponseWriter, r *http.Request) {
	out, err := s.ListCallGifts(r.Context(), principal(r), r.PathValue("callId"))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleListSentGifts(w http.ResponseWriter, r *http.Request) {
	page, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.ListSentGifts(r.Context(), principal(r), page)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleListReceivedGifts(w http.ResponseWriter, r *http.Request) {
	page, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.ListReceivedGifts(r.Context(), principal(r), page)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleGetReceivedSummary(w http.ResponseWriter, r *http.Request) {
	out, err := s.GetReceivedSummary(r.Context(), principal(r))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleAdminList(w http.ResponseWriter, r *http.Request) {
	out, err := s.AdminListGifts(r.Context())
	write(w, r, http.StatusOK, map[string]any{"items": out}, err)
}

func (s *Service) handleAdminCreate(w http.ResponseWriter, r *http.Request) {
	var in CreateGiftRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.AdminCreateGift(r.Context(), principal(r), in)
	write(w, r, http.StatusCreated, out, err)
}

func (s *Service) handleAdminUpdate(w http.ResponseWriter, r *http.Request) {
	var in UpdateGiftRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.AdminUpdateGift(r.Context(), principal(r), r.PathValue("giftId"), in)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleAdminPrice(w http.ResponseWriter, r *http.Request) {
	var in ChangePriceRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.AdminChangePrice(r.Context(), principal(r), r.PathValue("giftId"), in)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleAdminPriceHistory(w http.ResponseWriter, r *http.Request) {
	out, err := s.AdminPriceHistory(r.Context(), r.PathValue("giftId"))
	write(w, r, http.StatusOK, map[string]any{"items": out}, err)
}

func (s *Service) handleAdminPerformance(w http.ResponseWriter, r *http.Request) {
	days := 30
	if v := r.URL.Query().Get("days"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil {
			httpx.WriteError(w, r, apperr.Validation(map[string]string{"days": "must_be_1_to_365"}))
			return
		}
		days = n
	}
	out, err := s.AdminPerformance(r.Context(), days)
	write(w, r, http.StatusOK, map[string]any{"items": out, "days": days}, err)
}

func (s *Service) handleAdminTransactions(w http.ResponseWriter, r *http.Request) {
	page, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	q := r.URL.Query()
	out, err := s.AdminListTransactions(r.Context(), q.Get("user_id"), q.Get("call_id"), q.Get("flagged") == "true", page)
	write(w, r, http.StatusOK, out, err)
}
