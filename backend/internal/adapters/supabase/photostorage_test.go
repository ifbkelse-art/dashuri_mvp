package supabase

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestPhotoStorageSigning(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer svc-key" || r.Header.Get("apikey") != "svc-key" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		switch r.URL.Path {
		case "/storage/v1/object/upload/sign/profile-photos/u1/p1.jpg":
			_, _ = w.Write([]byte(`{"url":"/object/upload/sign/profile-photos/u1/p1.jpg?token=abc"}`))
		case "/storage/v1/object/sign/profile-photos":
			var in struct {
				ExpiresIn int      `json:"expiresIn"`
				Paths     []string `json:"paths"`
			}
			_ = json.NewDecoder(r.Body).Decode(&in)
			if in.ExpiresIn != 3600 || len(in.Paths) != 2 {
				t.Errorf("sign body %+v", in)
			}
			_, _ = w.Write([]byte(`[{"path":"u1/a.jpg","signedURL":"/object/sign/profile-photos/u1/a.jpg?token=r","error":null},
				{"path":"u1/missing.jpg","signedURL":null,"error":"Either the object does not exist or you do not have access to it"}]`))
		case "/storage/v1/object/list/profile-photos":
			var in struct {
				Prefix string `json:"prefix"`
			}
			_ = json.NewDecoder(r.Body).Decode(&in)
			if in.Prefix != "u1/" {
				t.Errorf("prefix %q", in.Prefix)
			}
			_, _ = w.Write([]byte(`[{"name":"a.jpg","id":"x1"},{"name":"sub","id":null}]`))
		case "/storage/v1/object/profile-photos":
			if r.Method != http.MethodDelete {
				t.Errorf("method %s", r.Method)
			}
			var in struct {
				Prefixes []string `json:"prefixes"`
			}
			_ = json.NewDecoder(r.Body).Decode(&in)
			if len(in.Prefixes) != 1 || in.Prefixes[0] != "u1/a.jpg" {
				t.Errorf("delete %v", in.Prefixes)
			}
			_, _ = w.Write([]byte(`[]`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()
	s := PhotoStorage{BaseURL: srv.URL + "/", APIKey: "svc-key", Bucket: "profile-photos", Client: srv.Client()}
	ctx := context.Background()
	u, err := s.SignUpload(ctx, "u1/p1.jpg")
	if err != nil || u != srv.URL+"/storage/v1/object/upload/sign/profile-photos/u1/p1.jpg?token=abc" {
		t.Fatalf("upload: %q %v", u, err)
	}
	m := s.SignRead(ctx, []string{"u1/a.jpg", "u1/missing.jpg"}, time.Hour)
	if len(m) != 1 || m["u1/a.jpg"] != srv.URL+"/storage/v1/object/sign/profile-photos/u1/a.jpg?token=r" {
		t.Fatalf("read: %v", m)
	}
	names, err := s.List(ctx, "u1/", 100)
	if err != nil || len(names) != 1 || names[0] != "u1/a.jpg" {
		t.Fatalf("list: %v %v", names, err)
	}
	if err := s.Delete(ctx, "u1/a.jpg"); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := (PhotoStorage{Bucket: "x"}).SignUpload(ctx, "p"); !errors.Is(err, ErrStorageNotConfigured) {
		t.Fatal(err)
	}
	bad := PhotoStorage{BaseURL: srv.URL, APIKey: "wrong", Bucket: "profile-photos", Client: srv.Client()}
	if _, err := bad.SignUpload(ctx, "u1/p1.jpg"); err == nil {
		t.Fatal("401 must fail")
	}
	if m := bad.SignRead(ctx, []string{"u1/a.jpg"}, time.Hour); len(m) != 0 {
		t.Fatal("failed signing must yield no urls")
	}
}
