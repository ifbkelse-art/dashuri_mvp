package reels

import (
	"net/http"
	"strconv"

	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/idempotency"
	"dashuri/backend/internal/platform/routing"
)

// Routes registers the Reels endpoints (EXPERIMENT; all return 503
// reels_disabled while REELS_ENABLED=false). Handlers only decode, call the
// service and encode.
func Routes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	mux.Handle("GET /v1/reels/config", mw.User(s.handleConfig))
	mux.Handle("GET /v1/reels/feed", mw.User(s.handleFeed))
	mux.Handle("POST /v1/reels/uploads", mw.User(idempotency.Require(mw.Idempotency, s.handleCreateUpload)))
	mux.Handle("POST /v1/reels/{reelId}/upload-complete", mw.User(s.handleCompleteUpload))
	mux.Handle("GET /v1/reels/{reelId}", mw.User(s.handleGetReel))
	mux.Handle("DELETE /v1/reels/{reelId}", mw.User(s.handleDeleteReel))
	mux.Handle("PUT /v1/reels/{reelId}/like", mw.User(s.handleLike))
	mux.Handle("POST /v1/reels/{reelId}/share", mw.User(s.handleShare))
	mux.Handle("POST /v1/reels/{reelId}/reports", mw.User(idempotency.Require(mw.Idempotency, s.handleReport)))
	mux.Handle("POST /v1/reels/{reelId}/appeals", mw.User(idempotency.Require(mw.Idempotency, s.handleAppeal)))
	mux.Handle("POST /v1/reels/events", mw.User(s.handleEvents))
	mux.Handle("GET /v1/creators/{userId}", mw.User(s.handleGetCreator))
	mux.Handle("GET /v1/creators/{userId}/reels", mw.User(s.handleCreatorReels))
	mux.Handle("PUT /v1/creators/{userId}/follow", mw.User(s.handleFollow))
	mux.Handle("PATCH /v1/me/creator", mw.User(s.handleUpdateMyCreator))
	mux.Handle("POST /v1/webhooks/reels/{provider}", mw.Webhook(s.handleWebhook))
	mux.Handle("GET /v1/admin/reels/queue", mw.User(auth.Require(s.handleQueue, auth.RoleModerator, auth.RoleAdmin)))
	mux.Handle("POST /v1/admin/reels/{reelId}/decision", mw.User(idempotency.Require(mw.Idempotency, auth.Require(s.handleDecide, auth.RoleModerator, auth.RoleAdmin))))
	mux.Handle("GET /v1/admin/reels/analytics", mw.User(auth.Require(s.handleAnalytics, auth.RoleAdmin, auth.RoleFinance, auth.RoleModerator)))
}

func limitParam(r *http.Request) int {
	n, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	return n
}

func write[T any](w http.ResponseWriter, r *http.Request, status int, out T, err error) {
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, status, out)
}

func noContent(w http.ResponseWriter, r *http.Request, err error) {
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleConfig(w http.ResponseWriter, r *http.Request) {
	httpx.WriteJSON(w, http.StatusOK, s.Config())
}

func (s *Service) handleFeed(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	q := r.URL.Query()
	out, err := s.Feed(r.Context(), p, q.Get("tab"), q.Get("cursor"), limitParam(r))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleCreateUpload(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in CreateUploadRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.CreateUpload(r.Context(), p, in)
	write(w, r, http.StatusCreated, out, err)
}

func (s *Service) handleCompleteUpload(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.CompleteUpload(r.Context(), p, r.PathValue("reelId"))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleGetReel(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetReel(r.Context(), p, r.PathValue("reelId"))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleDeleteReel(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	noContent(w, r, s.DeleteReel(r.Context(), p, r.PathValue("reelId")))
}

// PUT {"liked": bool} — one idempotent endpoint for like and unlike.
func (s *Service) handleLike(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in struct {
		Liked *bool `json:"liked"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if in.Liked == nil {
		httpx.WriteError(w, r, validationError(map[string]string{"liked": "required"}))
		return
	}
	out, err := s.SetLike(r.Context(), p, r.PathValue("reelId"), *in.Liked)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleShare(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.Share(r.Context(), p, r.PathValue("reelId"))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleReport(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in ReportRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	noContent(w, r, s.Report(r.Context(), p, r.PathValue("reelId"), in))
}

func (s *Service) handleAppeal(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in AppealRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	noContent(w, r, s.Appeal(r.Context(), p, r.PathValue("reelId"), in))
}

func (s *Service) handleEvents(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in EventsRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if err := s.RecordEvents(r.Context(), p, in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusAccepted)
}

func (s *Service) handleGetCreator(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetCreator(r.Context(), p, r.PathValue("userId"))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleCreatorReels(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.CreatorReels(r.Context(), p, r.PathValue("userId"), r.URL.Query().Get("cursor"), limitParam(r))
	write(w, r, http.StatusOK, out, err)
}

// PUT {"following": bool} — one idempotent endpoint for follow and unfollow.
func (s *Service) handleFollow(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in struct {
		Following *bool `json:"following"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if in.Following == nil {
		httpx.WriteError(w, r, validationError(map[string]string{"following": "required"}))
		return
	}
	out, err := s.SetFollow(r.Context(), p, r.PathValue("userId"), *in.Following)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleUpdateMyCreator(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in UpdateCreatorRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.UpdateMyCreator(r.Context(), p, in)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleWebhook(w http.ResponseWriter, r *http.Request) {
	body, err := httpx.ReadRaw(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	noContent(w, r, s.HandleWebhook(r.Context(), r.PathValue("provider"), httpx.HeaderMap(r), body))
}

func (s *Service) handleQueue(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.Queue(r.Context(), p, r.URL.Query().Get("cursor"), limitParam(r))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleDecide(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in DecisionRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.Decide(r.Context(), p, r.PathValue("reelId"), in)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleAnalytics(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	days, _ := strconv.Atoi(r.URL.Query().Get("days"))
	out, err := s.GetAnalytics(r.Context(), p, days)
	write(w, r, http.StatusOK, out, err)
}
