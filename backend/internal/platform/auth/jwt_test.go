package auth

import (
	"context"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func sign(t *testing.T, secret string, c jwt.RegisteredClaims) string {
	t.Helper()
	s, err := jwt.NewWithClaims(jwt.SigningMethodHS256, c).SignedString([]byte(secret))
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func TestDevHS256Verification(t *testing.T) {
	v := &JWKSVerifier{Issuer: "http://localhost:54321/auth/v1", Audience: "authenticated", DevHS256Secret: "s3cret-s3cret-s3cret-s3cret-s3cret"}
	good := jwt.RegisteredClaims{
		Subject: "4b0f6c1e-1111-4222-8333-944455556666", Issuer: v.Issuer,
		Audience: jwt.ClaimStrings{"authenticated"}, ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
	}
	cases := []struct {
		name   string
		token  string
		wantOK bool
	}{
		{"valid", sign(t, v.DevHS256Secret, good), true},
		{"wrong secret", sign(t, "another-secret-another-secret-xx", good), false},
		{"expired", sign(t, v.DevHS256Secret, func() jwt.RegisteredClaims {
			c := good
			c.ExpiresAt = jwt.NewNumericDate(time.Now().Add(-time.Hour))
			return c
		}()), false},
		{"wrong audience", sign(t, v.DevHS256Secret, func() jwt.RegisteredClaims { c := good; c.Audience = jwt.ClaimStrings{"anon"}; return c }()), false},
		{"wrong issuer", sign(t, v.DevHS256Secret, func() jwt.RegisteredClaims { c := good; c.Issuer = "https://evil"; return c }()), false},
		{"no expiry", sign(t, v.DevHS256Secret, func() jwt.RegisteredClaims { c := good; c.ExpiresAt = nil; return c }()), false},
		{"garbage", "not-a-jwt", false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			sub, err := v.Verify(context.Background(), tc.token)
			if tc.wantOK && (err != nil || sub != good.Subject) {
				t.Fatalf("want ok, got sub=%q err=%v", sub, err)
			}
			if !tc.wantOK && err == nil {
				t.Fatalf("want error, got sub=%q", sub)
			}
		})
	}
}

func TestHS256RejectedWithoutDevSecret(t *testing.T) {
	v := &JWKSVerifier{JWKSURL: ""}
	if _, err := v.Verify(context.Background(), "x.y.z"); err == nil {
		t.Fatal("expected error with no verifier configured")
	}
}

func TestAlgNoneRejected(t *testing.T) {
	v := &JWKSVerifier{DevHS256Secret: "s3cret-s3cret-s3cret-s3cret-s3cret"}
	tok, _ := jwt.NewWithClaims(jwt.SigningMethodNone, jwt.RegisteredClaims{Subject: "x", ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour))}).SignedString(jwt.UnsafeAllowNoneSignatureType)
	if _, err := v.Verify(context.Background(), tok); err == nil {
		t.Fatal("alg=none must be rejected")
	}
}
