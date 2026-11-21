package googleplay

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/MicahParks/keyfunc/v3"
	"github.com/golang-jwt/jwt/v5"

	"dashuri/backend/internal/modules/purchases"
)

// GoogleJWKSURL publishes the keys Google signs OIDC tokens with.
const GoogleJWKSURL = "https://www.googleapis.com/oauth2/v3/certs"

// PushVerifier verifies the OIDC token Pub/Sub attaches to push requests:
// RS256 signature from Google's JWKS, issuer accounts.google.com, audience
// = PLAY_RTDN_AUDIENCE, email = PLAY_RTDN_SERVICE_ACCOUNT, email_verified.
type PushVerifier struct {
	Audience string
	Email    string
	JWKSURL  string // default GoogleJWKSURL
	// Keyfunc overrides the JWKS lookup (tests).
	Keyfunc jwt.Keyfunc

	once    sync.Once
	kf      jwt.Keyfunc
	initErr error
}

var _ purchases.PushAuthenticator = (*PushVerifier)(nil)

type pushClaims struct {
	Email         string `json:"email"`
	EmailVerified bool   `json:"email_verified"`
	jwt.RegisteredClaims
}

// ErrPushUnauthenticated is returned for any token problem.
var ErrPushUnauthenticated = errors.New("googleplay: push token rejected")

func (v *PushVerifier) init(ctx context.Context) {
	v.once.Do(func() {
		if v.Keyfunc != nil {
			v.kf = v.Keyfunc
			return
		}
		u := v.JWKSURL
		if u == "" {
			u = GoogleJWKSURL
		}
		k, err := keyfunc.NewDefaultCtx(context.WithoutCancel(ctx), []string{u})
		if err != nil {
			v.initErr = fmt.Errorf("googleplay: load Google JWKS: %w", err)
			return
		}
		v.kf = k.Keyfunc
	})
}

// VerifyPush implements purchases.PushAuthenticator.
func (v *PushVerifier) VerifyPush(ctx context.Context, authorization string) error {
	if v.Audience == "" || v.Email == "" {
		return errors.New("googleplay: push verifier not configured")
	}
	raw, ok := strings.CutPrefix(authorization, "Bearer ")
	if !ok || raw == "" {
		return ErrPushUnauthenticated
	}
	v.init(ctx)
	if v.initErr != nil {
		return v.initErr
	}
	var c pushClaims
	_, err := jwt.ParseWithClaims(raw, &c, v.kf,
		jwt.WithValidMethods([]string{"RS256"}),
		jwt.WithAudience(v.Audience),
		jwt.WithExpirationRequired(),
		jwt.WithLeeway(30*time.Second))
	if err != nil {
		return fmt.Errorf("%w: %v", ErrPushUnauthenticated, err)
	}
	if c.Issuer != "https://accounts.google.com" && c.Issuer != "accounts.google.com" {
		return fmt.Errorf("%w: issuer", ErrPushUnauthenticated)
	}
	if !c.EmailVerified || !strings.EqualFold(c.Email, v.Email) {
		return fmt.Errorf("%w: service account", ErrPushUnauthenticated)
	}
	return nil
}
