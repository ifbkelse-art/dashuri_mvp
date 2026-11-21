package purchases

import (
	"net/http"

	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/idempotency"
	"dashuri/backend/internal/platform/routing"
)

// Routes registers this module's endpoints. Handlers only decode, validate,
// call the service and encode; no business logic lives here.
func Routes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	mux.Handle("GET /v1/purchases/packages", mw.User(s.handleListDiamondPackages))
	mux.Handle("POST /v1/purchases/google-play", mw.User(idempotency.Require(mw.Idempotency, s.handleVerifyGooglePlayPurchase)))
	mux.Handle("POST /v1/webhooks/google-play/rtdn", mw.Webhook(s.handleGooglePlayNotification))
	mux.Handle("POST /v1/purchases/cashfree/orders", mw.User(idempotency.Require(mw.Idempotency, s.handleCreateCashfreeOrder)))
	mux.Handle("GET /v1/purchases/cashfree/orders/{orderId}", mw.User(s.handleGetCashfreeOrder))
	mux.Handle("POST /v1/webhooks/cashfree", mw.Webhook(s.handleCashfreeWebhook))
}

func (s *Service) handleListDiamondPackages(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.ListDiamondPackages(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleVerifyGooglePlayPurchase(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in VerifyGooglePlayRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.VerifyGooglePlayPurchase(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleGooglePlayNotification(w http.ResponseWriter, r *http.Request) {
	raw, err := httpx.ReadRaw(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if err := s.GooglePlayNotification(r.Context(), raw, httpx.HeaderMap(r)); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleCreateCashfreeOrder(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in CreateCashfreeOrderRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.CreateCashfreeOrder(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 201, out)
}

func (s *Service) handleGetCashfreeOrder(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetCashfreeOrder(r.Context(), p, r.PathValue("orderId"))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleCashfreeWebhook(w http.ResponseWriter, r *http.Request) {
	raw, err := httpx.ReadRaw(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if err := s.CashfreeWebhook(r.Context(), raw, httpx.HeaderMap(r)); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
