package chat

import (
	"encoding/json"
	"net/http"

	"dashuri/backend/internal/modules/textfilter"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/idempotency"
	"dashuri/backend/internal/platform/routing"
)

// Routes registers this module's endpoints.
func Routes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	mux.Handle("GET /v1/conversations", mw.User(s.handleListConversations))
	mux.Handle("POST /v1/conversations", mw.User(idempotency.Require(mw.Idempotency, s.handleStartConversation)))
	mux.Handle("GET /v1/conversations/{conversationId}/messages", mw.User(s.handleListMessages))
	mux.Handle("POST /v1/conversations/{conversationId}/messages", mw.User(idempotency.Require(mw.Idempotency, s.handleSendMessage)))
	mux.Handle("POST /v1/conversations/{conversationId}/read", mw.User(s.handleMarkRead))
	mux.Handle("GET /v1/me/messaging-privacy", mw.User(s.handleGetMessagingPrivacy))
	mux.Handle("PUT /v1/me/messaging-privacy", mw.User(s.handleUpdateMessagingPrivacy))
}

// rejectedProblem adds the top-level `reason` the contract requires for
// message_rejected (CH05).
type rejectedProblem struct {
	httpx.Problem
	Reason string `json:"reason"`
}

func writeError(w http.ResponseWriter, r *http.Request, err error) {
	if e := apperr.As(err); e != nil && e.Kind == apperr.KindBusinessRule && e.Code == "message_rejected" {
		p := rejectedProblem{
			Problem: httpx.Problem{
				Type:   "https://docs.dashuri.invalid/problems/message_rejected",
				Title:  http.StatusText(http.StatusConflict),
				Status: http.StatusConflict, Code: "business_rule", Rule: e.Code, Detail: e.Detail,
				Errors:    []httpx.FieldError{{Field: "body", Reason: textfilter.ReasonContactDetails}},
				RequestID: httpx.RequestID(r.Context()),
			},
			Reason: textfilter.ReasonContactDetails,
		}
		w.Header().Set("Content-Type", "application/problem+json")
		w.WriteHeader(http.StatusConflict)
		_ = json.NewEncoder(w).Encode(p)
		return
	}
	httpx.WriteError(w, r, err)
}

func write[T any](w http.ResponseWriter, r *http.Request, status int, out T, err error) {
	if err != nil {
		writeError(w, r, err)
		return
	}
	httpx.WriteJSON(w, status, out)
}

func principal(r *http.Request) auth.Principal {
	p, _ := auth.FromContext(r.Context())
	return p
}

func (s *Service) handleListConversations(w http.ResponseWriter, r *http.Request) {
	page, err := parsePage(r)
	if err != nil {
		writeError(w, r, err)
		return
	}
	out, err := s.ListConversations(r.Context(), principal(r), page)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleStartConversation(w http.ResponseWriter, r *http.Request) {
	var in StartConversationRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	out, err := s.StartConversation(r.Context(), principal(r), in)
	write(w, r, http.StatusCreated, out, err)
}

func (s *Service) handleListMessages(w http.ResponseWriter, r *http.Request) {
	page, err := parsePage(r)
	if err != nil {
		writeError(w, r, err)
		return
	}
	out, err := s.ListMessages(r.Context(), principal(r), r.PathValue("conversationId"), page)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleSendMessage(w http.ResponseWriter, r *http.Request) {
	var in SendMessageRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	out, err := s.SendMessage(r.Context(), principal(r), r.PathValue("conversationId"), in)
	write(w, r, http.StatusCreated, out, err)
}

func (s *Service) handleMarkRead(w http.ResponseWriter, r *http.Request) {
	if err := s.MarkRead(r.Context(), principal(r), r.PathValue("conversationId")); err != nil {
		writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleGetMessagingPrivacy(w http.ResponseWriter, r *http.Request) {
	out, err := s.GetMessagingPrivacy(r.Context(), principal(r))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleUpdateMessagingPrivacy(w http.ResponseWriter, r *http.Request) {
	var in MessagingPrivacy
	if err := httpx.DecodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	out, err := s.UpdateMessagingPrivacy(r.Context(), principal(r), in)
	write(w, r, http.StatusOK, out, err)
}
