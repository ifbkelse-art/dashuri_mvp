// Package playintegrity implements freecall.IntegrityVerifier with the
// Google Play Integrity API (decodeIntegrityToken), authenticated with the
// service account in GOOGLE_APPLICATION_CREDENTIALS (OAuth 2.0 JWT bearer
// grant, scope playintegrity). Standard library only.
//
// Device binding: the app sets the Play Integrity requestHash (standard
// request) or nonce (classic request) to a value it derives from the device
// (base64url(SHA-256(ANDROID_ID))). That field is integrity-protected and
// the verdict proves it came from our unmodified app on a genuine device, so
// the server binds the Free Call Card to its hash.
package playintegrity

import (
	"context"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"dashuri/backend/internal/modules/freecall"
)

const (
	scope       = "https://www.googleapis.com/auth/playintegrity"
	apiBase     = "https://playintegrity.googleapis.com/v1/"
	maxTokenAge = 10 * time.Minute
)

// Verifier decodes integrity tokens for one Android package.
type Verifier struct {
	PackageName string
	APIBase     string // defaults to the Google endpoint (tests use httptest)
	HTTP        *http.Client
	Now         func() time.Time

	creds serviceAccount
	mu    sync.Mutex
	tok   string
	exp   time.Time
}

type serviceAccount struct {
	ClientEmail string `json:"client_email"`
	PrivateKey  string `json:"private_key"`
	TokenURI    string `json:"token_uri"`
	key         *rsa.PrivateKey
}

var _ freecall.IntegrityVerifier = (*Verifier)(nil)

// New returns a verifier, or nil when the credentials file or package name
// is missing (the service then answers 503 integrity_not_configured).
func New(credentialsFile, packageName string, hc *http.Client) (freecall.IntegrityVerifier, error) {
	if credentialsFile == "" || packageName == "" {
		return nil, nil
	}
	raw, err := os.ReadFile(credentialsFile)
	if err != nil {
		return nil, fmt.Errorf("playintegrity: read credentials: %w", err)
	}
	sa, err := parseServiceAccount(raw)
	if err != nil {
		return nil, err
	}
	return &Verifier{PackageName: packageName, HTTP: hc, creds: sa}, nil
}

func parseServiceAccount(raw []byte) (serviceAccount, error) {
	var sa serviceAccount
	if err := json.Unmarshal(raw, &sa); err != nil {
		return sa, fmt.Errorf("playintegrity: credentials json: %w", err)
	}
	block, _ := pem.Decode([]byte(sa.PrivateKey))
	if block == nil || sa.ClientEmail == "" {
		return sa, errors.New("playintegrity: credentials missing client_email or private_key")
	}
	k, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		if k1, err1 := x509.ParsePKCS1PrivateKey(block.Bytes); err1 == nil {
			k = k1
		} else {
			return sa, fmt.Errorf("playintegrity: private key: %w", err)
		}
	}
	rk, ok := k.(*rsa.PrivateKey)
	if !ok {
		return sa, errors.New("playintegrity: private key is not RSA")
	}
	sa.key = rk
	if sa.TokenURI == "" {
		sa.TokenURI = "https://oauth2.googleapis.com/token"
	}
	return sa, nil
}

func (v *Verifier) now() time.Time {
	if v.Now != nil {
		return v.Now()
	}
	return time.Now()
}

func (v *Verifier) client() *http.Client {
	if v.HTTP != nil {
		return v.HTTP
	}
	return http.DefaultClient
}

// accessToken returns a cached OAuth access token (JWT bearer grant).
func (v *Verifier) accessToken(ctx context.Context) (string, error) {
	v.mu.Lock()
	defer v.mu.Unlock()
	now := v.now()
	if v.tok != "" && now.Before(v.exp.Add(-time.Minute)) {
		return v.tok, nil
	}
	b64 := base64.RawURLEncoding
	hdr := b64.EncodeToString([]byte(`{"alg":"RS256","typ":"JWT"}`))
	claims, _ := json.Marshal(map[string]any{
		"iss": v.creds.ClientEmail, "scope": scope, "aud": v.creds.TokenURI,
		"iat": now.Unix(), "exp": now.Add(time.Hour).Unix(),
	})
	signing := hdr + "." + b64.EncodeToString(claims)
	sum := sha256.Sum256([]byte(signing))
	sig, err := rsa.SignPKCS1v15(nil, v.creds.key, crypto.SHA256, sum[:])
	if err != nil {
		return "", err
	}
	form := url.Values{"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"}, "assertion": {signing + "." + b64.EncodeToString(sig)}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, v.creds.TokenURI, strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	res, err := v.client().Do(req)
	if err != nil {
		return "", fmt.Errorf("playintegrity: token: %w", err)
	}
	defer res.Body.Close()
	var out struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int64  `json:"expires_in"`
	}
	if err := json.NewDecoder(io.LimitReader(res.Body, 64<<10)).Decode(&out); err != nil || res.StatusCode != 200 || out.AccessToken == "" {
		return "", fmt.Errorf("playintegrity: token status %d", res.StatusCode)
	}
	v.tok, v.exp = out.AccessToken, now.Add(time.Duration(out.ExpiresIn)*time.Second)
	return v.tok, nil
}

// Payload is the decoded tokenPayloadExternal (fields used).
type Payload struct {
	RequestDetails struct {
		RequestPackageName string `json:"requestPackageName"`
		TimestampMillis    string `json:"timestampMillis"`
		Nonce              string `json:"nonce"`
		RequestHash        string `json:"requestHash"`
	} `json:"requestDetails"`
	AppIntegrity struct {
		AppRecognitionVerdict string `json:"appRecognitionVerdict"`
		PackageName           string `json:"packageName"`
	} `json:"appIntegrity"`
	DeviceIntegrity struct {
		DeviceRecognitionVerdict []string `json:"deviceRecognitionVerdict"`
	} `json:"deviceIntegrity"`
}

// Evaluate applies Dashuri's acceptance rules to a decoded payload.
func Evaluate(p Payload, packageName string, now time.Time) (freecall.IntegrityVerdict, error) {
	fail := func(why string) (freecall.IntegrityVerdict, error) {
		return freecall.IntegrityVerdict{}, fmt.Errorf("%w: %s", freecall.ErrIntegrityFailed, why)
	}
	if p.RequestDetails.RequestPackageName != packageName {
		return fail("package mismatch")
	}
	if p.AppIntegrity.AppRecognitionVerdict != "PLAY_RECOGNIZED" {
		return fail("app not recognised")
	}
	if !slices.Contains(p.DeviceIntegrity.DeviceRecognitionVerdict, "MEETS_DEVICE_INTEGRITY") {
		return fail("device integrity not met")
	}
	ms, err := strconv.ParseInt(p.RequestDetails.TimestampMillis, 10, 64)
	if err != nil {
		return fail("no timestamp")
	}
	if age := now.Sub(time.UnixMilli(ms)); age > maxTokenAge || age < -time.Minute {
		return fail("stale token")
	}
	binding := p.RequestDetails.RequestHash
	if binding == "" {
		binding = p.RequestDetails.Nonce
	}
	if binding == "" {
		return fail("no device binding")
	}
	return freecall.IntegrityVerdict{DeviceBinding: binding}, nil
}

// Verify decodes the token with Google and evaluates the verdict.
func (v *Verifier) Verify(ctx context.Context, token string) (freecall.IntegrityVerdict, error) {
	at, err := v.accessToken(ctx)
	if err != nil {
		return freecall.IntegrityVerdict{}, err
	}
	base := v.APIBase
	if base == "" {
		base = apiBase
	}
	body, _ := json.Marshal(map[string]string{"integrity_token": token})
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, base+url.PathEscape(v.PackageName)+":decodeIntegrityToken", strings.NewReader(string(body)))
	if err != nil {
		return freecall.IntegrityVerdict{}, err
	}
	req.Header.Set("Authorization", "Bearer "+at)
	req.Header.Set("Content-Type", "application/json")
	res, err := v.client().Do(req)
	if err != nil {
		return freecall.IntegrityVerdict{}, fmt.Errorf("playintegrity: decode: %w", err)
	}
	defer res.Body.Close()
	if res.StatusCode == http.StatusBadRequest {
		return freecall.IntegrityVerdict{}, fmt.Errorf("%w: token rejected", freecall.ErrIntegrityFailed)
	}
	if res.StatusCode != 200 {
		return freecall.IntegrityVerdict{}, fmt.Errorf("playintegrity: decode status %d", res.StatusCode)
	}
	var out struct {
		TokenPayloadExternal Payload `json:"tokenPayloadExternal"`
	}
	if err := json.NewDecoder(io.LimitReader(res.Body, 256<<10)).Decode(&out); err != nil {
		return freecall.IntegrityVerdict{}, fmt.Errorf("playintegrity: decode body: %w", err)
	}
	return Evaluate(out.TokenPayloadExternal, v.PackageName, v.now())
}
