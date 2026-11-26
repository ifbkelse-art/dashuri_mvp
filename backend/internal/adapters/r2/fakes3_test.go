package r2

import (
	"encoding/xml"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

// fakeS3 is an in-memory S3/R2 bucket that checks signatures the way R2
// does: presigned URLs are re-signed from the request actually received
// (so a different Content-Length or Content-Type fails), and signed calls
// must carry an Authorization header for the right key id.
type fakeS3 struct {
	t       *testing.T
	signer  Signer
	bucket  string
	mu      sync.Mutex
	objects map[string]fakeObject
	srv     *httptest.Server
}

type fakeObject struct {
	body        []byte
	contentType string
}

func newFakeS3(t *testing.T, signer Signer, bucket string) *fakeS3 {
	f := &fakeS3{t: t, signer: signer, bucket: bucket, objects: map[string]fakeObject{}}
	f.srv = httptest.NewServer(http.HandlerFunc(f.serve))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fakeS3) keys() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := make([]string, 0, len(f.objects))
	for k := range f.objects {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func (f *fakeS3) get(key string) (fakeObject, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	o, ok := f.objects[key]
	return o, ok
}

func (f *fakeS3) put(key string, body []byte, ct string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.objects[key] = fakeObject{body: body, contentType: ct}
}

// verifyPresigned recomputes the signature from what was received.
func (f *fakeS3) verifyPresigned(r *http.Request) bool {
	q := r.URL.Query()
	at, err := time.Parse(amzDateFormat, q.Get("X-Amz-Date"))
	if err != nil {
		return false
	}
	exp, _ := strconv.Atoi(q.Get("X-Amz-Expires"))
	if time.Now().After(at.Add(time.Duration(exp) * time.Second)) {
		return false // expired
	}
	h := map[string]string{}
	for _, name := range strings.Split(q.Get("X-Amz-SignedHeaders"), ";") {
		switch name {
		case "host":
		case "content-length":
			h["Content-Length"] = strconv.FormatInt(r.ContentLength, 10)
		default:
			h[name] = r.Header.Get(name)
		}
	}
	u := &url.URL{Scheme: "http", Host: r.Host, Path: r.URL.Path}
	want := f.signer.Presign(r.Method, u, h, time.Duration(exp)*time.Second, at)
	wu, _ := url.Parse(want)
	return wu.Query().Get("X-Amz-Signature") == q.Get("X-Amz-Signature")
}

func (f *fakeS3) serve(w http.ResponseWriter, r *http.Request) {
	presigned := r.URL.Query().Get("X-Amz-Signature") != ""
	switch {
	case presigned && !f.verifyPresigned(r):
		http.Error(w, "SignatureDoesNotMatch", http.StatusForbidden)
		return
	case !presigned && !strings.Contains(r.Header.Get("Authorization"), "Credential="+f.signer.AccessKeyID+"/"):
		http.Error(w, "AccessDenied", http.StatusForbidden)
		return
	}
	path := strings.TrimPrefix(r.URL.Path, "/"+f.bucket)
	key := strings.TrimPrefix(path, "/")
	switch {
	case r.Method == http.MethodGet && key == "" && r.URL.Query().Get("list-type") == "2":
		prefix := r.URL.Query().Get("prefix")
		type content struct {
			Key string `xml:"Key"`
		}
		var res struct {
			XMLName  xml.Name  `xml:"ListBucketResult"`
			Contents []content `xml:"Contents"`
		}
		for _, k := range f.keys() {
			if strings.HasPrefix(k, prefix) {
				res.Contents = append(res.Contents, content{Key: k})
			}
		}
		_ = xml.NewEncoder(w).Encode(res)
	case r.Method == http.MethodPut:
		b, _ := io.ReadAll(r.Body)
		f.put(key, b, r.Header.Get("Content-Type"))
	case r.Method == http.MethodGet || r.Method == http.MethodHead:
		o, ok := f.get(key)
		if !ok {
			http.Error(w, "NoSuchKey", http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", o.contentType)
		w.Header().Set("Content-Length", strconv.Itoa(len(o.body)))
		if r.Method == http.MethodGet {
			_, _ = w.Write(o.body)
		}
	case r.Method == http.MethodDelete:
		f.mu.Lock()
		delete(f.objects, key)
		f.mu.Unlock()
		w.WriteHeader(http.StatusNoContent)
	default:
		http.Error(w, "unsupported", http.StatusMethodNotAllowed)
	}
}
