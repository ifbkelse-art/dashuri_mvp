package r2

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"maps"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"
)

// AWS Signature Version 4 for the S3 API, which R2 implements
// (https://developers.cloudflare.com/r2/api/s3/). Written here instead of
// pulling in the AWS SDK: we need presigned PUT/GET and a handful of
// signed object calls, nothing more. Verified against the examples in the
// AWS S3 SigV4 documentation (sigv4_test.go).

const (
	algorithm       = "AWS4-HMAC-SHA256"
	unsignedPayload = "UNSIGNED-PAYLOAD"
	emptySHA256     = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
	amzDateFormat   = "20060102T150405Z"
)

// Signer holds the credentials. Region is "auto" for R2.
type Signer struct {
	AccessKeyID     string
	SecretAccessKey string
	Region          string
	Service         string // "s3"
}

func (s Signer) scope(t time.Time) string {
	return t.Format("20060102") + "/" + s.Region + "/" + s.Service + "/aws4_request"
}

func hmacSHA256(key []byte, data string) []byte {
	m := hmac.New(sha256.New, key)
	m.Write([]byte(data))
	return m.Sum(nil)
}

func (s Signer) signature(t time.Time, stringToSign string) string {
	k := hmacSHA256([]byte("AWS4"+s.SecretAccessKey), t.Format("20060102"))
	k = hmacSHA256(k, s.Region)
	k = hmacSHA256(k, s.Service)
	k = hmacSHA256(k, "aws4_request")
	return hex.EncodeToString(hmacSHA256(k, stringToSign))
}

// uriEncode is RFC 3986 encoding as SigV4 requires (space → %20, '~' kept).
func uriEncode(s string, keepSlash bool) string {
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		c := s[i]
		switch {
		case 'A' <= c && c <= 'Z', 'a' <= c && c <= 'z', '0' <= c && c <= '9', c == '-', c == '_', c == '.', c == '~':
			b.WriteByte(c)
		case c == '/' && keepSlash:
			b.WriteByte(c)
		default:
			b.WriteString("%" + strings.ToUpper(hex.EncodeToString([]byte{c})))
		}
	}
	return b.String()
}

func canonicalQuery(q url.Values) string {
	keys := make([]string, 0, len(q))
	for k := range q {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	var parts []string
	for _, k := range keys {
		vs := append([]string(nil), q[k]...)
		sort.Strings(vs)
		for _, v := range vs {
			parts = append(parts, uriEncode(k, false)+"="+uriEncode(v, false))
		}
	}
	return strings.Join(parts, "&")
}

// canonicalHeaders returns the canonical header block and the signed list.
func canonicalHeaders(h map[string]string) (string, string) {
	names := make([]string, 0, len(h))
	lower := map[string]string{}
	for k, v := range h {
		lk := strings.ToLower(k)
		names = append(names, lk)
		lower[lk] = strings.Join(strings.Fields(v), " ")
	}
	sort.Strings(names)
	var b strings.Builder
	for _, n := range names {
		b.WriteString(n + ":" + lower[n] + "\n")
	}
	return b.String(), strings.Join(names, ";")
}

func sha256Hex(b []byte) string {
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}

// Presign returns a URL valid for expires that performs method on u when
// the client sends exactly the given extra headers (host is always signed).
func (s Signer) Presign(method string, u *url.URL, headers map[string]string, expires time.Duration, now time.Time) string {
	t := now.UTC()
	h := map[string]string{"host": u.Host}
	maps.Copy(h, headers)
	ch, signed := canonicalHeaders(h)
	q := u.Query()
	q.Set("X-Amz-Algorithm", algorithm)
	q.Set("X-Amz-Credential", s.AccessKeyID+"/"+s.scope(t))
	q.Set("X-Amz-Date", t.Format(amzDateFormat))
	q.Set("X-Amz-Expires", strconv.Itoa(int(expires.Seconds())))
	q.Set("X-Amz-SignedHeaders", signed)
	cq := canonicalQuery(q)
	creq := strings.Join([]string{method, uriEncode(u.Path, true), cq, ch, signed, unsignedPayload}, "\n")
	sts := strings.Join([]string{algorithm, t.Format(amzDateFormat), s.scope(t), sha256Hex([]byte(creq))}, "\n")
	out := *u
	out.RawQuery = cq + "&X-Amz-Signature=" + s.signature(t, sts)
	return out.String()
}

// SignRequest adds x-amz-date, x-amz-content-sha256 and Authorization.
// payloadHash is the hex SHA-256 of the body (or unsignedPayload).
func (s Signer) SignRequest(r *http.Request, payloadHash string, now time.Time) {
	t := now.UTC()
	r.Header.Set("X-Amz-Date", t.Format(amzDateFormat))
	r.Header.Set("X-Amz-Content-Sha256", payloadHash)
	h := map[string]string{"host": r.URL.Host}
	for k, vs := range r.Header {
		lk := strings.ToLower(k)
		if lk == "x-amz-date" || lk == "x-amz-content-sha256" || lk == "range" || lk == "content-type" || strings.HasPrefix(lk, "x-amz-meta-") {
			h[lk] = strings.Join(vs, ",")
		}
	}
	ch, signed := canonicalHeaders(h)
	creq := strings.Join([]string{r.Method, uriEncode(r.URL.Path, true), canonicalQuery(r.URL.Query()), ch, signed, payloadHash}, "\n")
	sts := strings.Join([]string{algorithm, t.Format(amzDateFormat), s.scope(t), sha256Hex([]byte(creq))}, "\n")
	r.Header.Set("Authorization", algorithm+" Credential="+s.AccessKeyID+"/"+s.scope(t)+
		", SignedHeaders="+signed+", Signature="+s.signature(t, sts))
}
