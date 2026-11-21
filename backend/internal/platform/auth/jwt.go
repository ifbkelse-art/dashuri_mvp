package auth

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/MicahParks/keyfunc/v3"
	"github.com/golang-jwt/jwt/v5"
)

// JWKSVerifier verifies Supabase access tokens signed with the project's
// asymmetric signing keys (ES256 or RS256), fetched from the JWKS endpoint
// and refreshed in the background. It checks signature, `iss`, `aud`,
// `exp`/`nbf` (30 s leeway) and returns `sub`.
//
// DevHS256Secret allows the legacy shared-secret (HS256) tokens issued by a
// local `supabase start` stack. It must stay empty outside development; the
// config loader refuses it in staging and production.
type JWKSVerifier struct {
	JWKSURL        string
	Issuer         string
	Audience       string
	DevHS256Secret string

	once    sync.Once
	kf      keyfunc.Keyfunc
	initErr error
}

var errNoVerifier = errors.New("auth: no JWKS URL or development secret configured")

func (v *JWKSVerifier) init(ctx context.Context) {
	v.once.Do(func() {
		if v.JWKSURL == "" {
			if v.DevHS256Secret == "" {
				v.initErr = errNoVerifier
			}
			return
		}
		// Background refresh uses its own context; it lives for the process.
		kf, err := keyfunc.NewDefaultCtx(context.WithoutCancel(ctx), []string{v.JWKSURL})
		if err != nil {
			v.initErr = fmt.Errorf("auth: load JWKS: %w", err)
			return
		}
		v.kf = kf
	})
}

// Verify implements TokenVerifier.
func (v *JWKSVerifier) Verify(ctx context.Context, raw string) (string, error) {
	v.init(ctx)
	if v.initErr != nil {
		return "", v.initErr
	}
	methods := []string{"ES256", "RS256"}
	if v.DevHS256Secret != "" {
		methods = append(methods, "HS256")
	}
	opts := []jwt.ParserOption{
		jwt.WithValidMethods(methods),
		jwt.WithLeeway(30 * time.Second),
		jwt.WithExpirationRequired(),
	}
	if v.Issuer != "" {
		opts = append(opts, jwt.WithIssuer(v.Issuer))
	}
	if v.Audience != "" {
		opts = append(opts, jwt.WithAudience(v.Audience))
	}
	tok, err := jwt.ParseWithClaims(raw, &jwt.RegisteredClaims{}, func(t *jwt.Token) (any, error) {
		if t.Method.Alg() == "HS256" {
			return []byte(v.DevHS256Secret), nil
		}
		if v.kf == nil {
			return nil, errors.New("auth: asymmetric token but no JWKS configured")
		}
		return v.kf.Keyfunc(t)
	}, opts...)
	if err != nil {
		return "", err
	}
	claims, ok := tok.Claims.(*jwt.RegisteredClaims)
	if !ok || claims.Subject == "" {
		return "", errors.New("auth: token has no subject")
	}
	return claims.Subject, nil
}
