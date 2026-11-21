package chat

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
	mux.Handle("GET /v1/conversations", mw.User(s.handleListConversations))
	mux.Handle("POST /v1/conversations", mw.User(idempotency.Require(mw.Idempotency, s.handleStartConversation)))
	mux.Handle("GET /v1/conversations/{conversationId}/messages", mw.User(s.handleListMessages))
	mux.Handle("POST /v1/conversations/{conversationId}/messages", mw.User(idempotency.Require(mw.Idempotency, s.handleSendMessage)))
	mux.Handle("GET /v1/me/messaging-privacy", mw.User(s.handleGetMessagingPrivacy))
	mux.Handle("PUT /v1/me/messaging-privacy", mw.User(s.handleUpdateMessagingPrivacy))
}

func (s *Service) handleListConversations(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	page, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.ListConversations(r.Context(), p, page)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleStartConversation(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in StartConversationRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.StartConversation(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 201, out)
}

func (s *Service) handleListMessages(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	page, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.ListMessages(r.Context(), p, r.PathValue("conversationId"), page)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleSendMessage(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in SendMessageRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.SendMessage(r.Context(), p, r.PathValue("conversationId"), in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 201, out)
}

func (s *Service) handleGetMessagingPrivacy(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetMessagingPrivacy(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleUpdateMessagingPrivacy(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in MessagingPrivacy
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.UpdateMessagingPrivacy(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}
