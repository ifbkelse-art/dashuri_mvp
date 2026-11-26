package r2

import (
	"context"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// Store is a minimal S3-API object client for one R2 bucket (path-style:
// <endpoint>/<bucket>/<key>). Every call is signed with SigV4.
type Store struct {
	Endpoint string // https://<account_id>.r2.cloudflarestorage.com (or a local S3 fake)
	Bucket   string
	Signer   Signer
	HTTP     *http.Client
	Now      func() time.Time
}

// ErrNoSuchKey means the object does not exist.
var ErrNoSuchKey = errors.New("r2: no such key")

func (s *Store) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

func (s *Store) client() *http.Client {
	if s.HTTP != nil {
		return s.HTTP
	}
	return &http.Client{Timeout: 5 * time.Minute}
}

// ObjectURL is the unsigned path-style URL of key.
func (s *Store) ObjectURL(key string) *url.URL {
	u, _ := url.Parse(strings.TrimRight(s.Endpoint, "/"))
	u.Path = "/" + s.Bucket + "/" + key
	return u
}

// PresignPut lets a client PUT exactly size bytes of contentType to key.
func (s *Store) PresignPut(key, contentType string, size int64, ttl time.Duration) (string, map[string]string) {
	h := map[string]string{"Content-Type": contentType, "Content-Length": strconv.FormatInt(size, 10)}
	return s.Signer.Presign(http.MethodPut, s.ObjectURL(key), h, ttl, s.now()), h
}

// PresignGet returns a time-limited read URL for key.
func (s *Store) PresignGet(key string, ttl time.Duration) string {
	return s.Signer.Presign(http.MethodGet, s.ObjectURL(key), nil, ttl, s.now())
}

func (s *Store) do(ctx context.Context, method string, u *url.URL, body io.Reader, size int64, contentType string) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, method, u.String(), body)
	if err != nil {
		return nil, err
	}
	if body != nil {
		req.ContentLength = size
		req.Header.Set("Content-Type", contentType)
	}
	s.Signer.SignRequest(req, unsignedPayload, s.now())
	return s.client().Do(req)
}

func drain(r *http.Response) {
	_, _ = io.Copy(io.Discard, io.LimitReader(r.Body, 1<<16))
	_ = r.Body.Close()
}

func statusErr(op string, r *http.Response) error {
	b, _ := io.ReadAll(io.LimitReader(r.Body, 512))
	return fmt.Errorf("r2 %s: HTTP %d: %s", op, r.StatusCode, strings.TrimSpace(string(b)))
}

// Head returns the object's size and content type.
func (s *Store) Head(ctx context.Context, key string) (int64, string, error) {
	r, err := s.do(ctx, http.MethodHead, s.ObjectURL(key), nil, 0, "")
	if err != nil {
		return 0, "", err
	}
	defer drain(r)
	switch {
	case r.StatusCode == http.StatusNotFound:
		return 0, "", ErrNoSuchKey
	case r.StatusCode/100 != 2:
		return 0, "", fmt.Errorf("r2 head: HTTP %d", r.StatusCode)
	}
	return r.ContentLength, r.Header.Get("Content-Type"), nil
}

// Get copies at most maxBytes of key into w (error if larger).
func (s *Store) Get(ctx context.Context, key string, w io.Writer, maxBytes int64) (int64, error) {
	r, err := s.do(ctx, http.MethodGet, s.ObjectURL(key), nil, 0, "")
	if err != nil {
		return 0, err
	}
	defer drain(r)
	if r.StatusCode == http.StatusNotFound {
		return 0, ErrNoSuchKey
	}
	if r.StatusCode/100 != 2 {
		return 0, statusErr("get", r)
	}
	n, err := io.Copy(w, io.LimitReader(r.Body, maxBytes+1))
	if err == nil && n > maxBytes {
		return n, errTooLarge
	}
	return n, err
}

var errTooLarge = errors.New("r2: object larger than allowed")

// Put stores size bytes from body under key.
func (s *Store) Put(ctx context.Context, key string, body io.Reader, size int64, contentType string) error {
	r, err := s.do(ctx, http.MethodPut, s.ObjectURL(key), body, size, contentType)
	if err != nil {
		return err
	}
	defer drain(r)
	if r.StatusCode/100 != 2 {
		return statusErr("put", r)
	}
	return nil
}

// Delete removes key (absent keys are not an error, as in S3).
func (s *Store) Delete(ctx context.Context, key string) error {
	r, err := s.do(ctx, http.MethodDelete, s.ObjectURL(key), nil, 0, "")
	if err != nil {
		return err
	}
	defer drain(r)
	if r.StatusCode/100 != 2 && r.StatusCode != http.StatusNotFound {
		return statusErr("delete", r)
	}
	return nil
}

type listResult struct {
	Contents []struct {
		Key string `xml:"Key"`
	} `xml:"Contents"`
	IsTruncated           bool   `xml:"IsTruncated"`
	NextContinuationToken string `xml:"NextContinuationToken"`
}

// List returns every key under prefix (ListObjectsV2, paginated).
func (s *Store) List(ctx context.Context, prefix string) ([]string, error) {
	var keys []string
	token := ""
	for range 100 { // ≤ 100k keys; a reel has ~35
		u := s.ObjectURL("")
		u.Path = "/" + s.Bucket
		q := url.Values{"list-type": {"2"}, "prefix": {prefix}}
		if token != "" {
			q.Set("continuation-token", token)
		}
		u.RawQuery = canonicalQuery(q)
		r, err := s.do(ctx, http.MethodGet, u, nil, 0, "")
		if err != nil {
			return nil, err
		}
		if r.StatusCode/100 != 2 {
			err := statusErr("list", r)
			drain(r)
			return nil, err
		}
		var out listResult
		err = xml.NewDecoder(io.LimitReader(r.Body, 8<<20)).Decode(&out)
		drain(r)
		if err != nil {
			return nil, fmt.Errorf("r2 list: %w", err)
		}
		for _, c := range out.Contents {
			keys = append(keys, c.Key)
		}
		if !out.IsTruncated || out.NextContinuationToken == "" {
			return keys, nil
		}
		token = out.NextContinuationToken
	}
	return keys, errors.New("r2 list: too many keys")
}
