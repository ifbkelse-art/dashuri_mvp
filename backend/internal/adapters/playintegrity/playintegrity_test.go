package playintegrity

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"strconv"
	"testing"
	"time"

	"dashuri/backend/internal/modules/freecall"
)

func payload(now time.Time) Payload {
	var p Payload
	p.RequestDetails.RequestPackageName = "app.dashuri"
	p.RequestDetails.TimestampMillis = strconv.FormatInt(now.Add(-time.Minute).UnixMilli(), 10)
	p.RequestDetails.RequestHash = "devhash"
	p.AppIntegrity.AppRecognitionVerdict = "PLAY_RECOGNIZED"
	p.DeviceIntegrity.DeviceRecognitionVerdict = []string{"MEETS_DEVICE_INTEGRITY"}
	return p
}

func TestEvaluate(t *testing.T) {
	now := time.Now()
	v, err := Evaluate(payload(now), "app.dashuri", now)
	if err != nil || v.DeviceBinding != "devhash" {
		t.Fatalf("%+v %v", v, err)
	}
	bad := map[string]func(*Payload){
		"package": func(p *Payload) { p.RequestDetails.RequestPackageName = "evil" },
		"app":     func(p *Payload) { p.AppIntegrity.AppRecognitionVerdict = "UNRECOGNIZED_VERSION" },
		"device":  func(p *Payload) { p.DeviceIntegrity.DeviceRecognitionVerdict = []string{"MEETS_BASIC_INTEGRITY"} },
		"stale": func(p *Payload) {
			p.RequestDetails.TimestampMillis = strconv.FormatInt(now.Add(-time.Hour).UnixMilli(), 10)
		},
		"binding": func(p *Payload) { p.RequestDetails.RequestHash = "" },
	}
	for name, mut := range bad {
		p := payload(now)
		mut(&p)
		if _, err := Evaluate(p, "app.dashuri", now); !errors.Is(err, freecall.ErrIntegrityFailed) {
			t.Errorf("%s: want ErrIntegrityFailed, got %v", name, err)
		}
	}
}

func TestParseServiceAccount(t *testing.T) {
	k, _ := rsa.GenerateKey(rand.Reader, 2048)
	der, _ := x509.MarshalPKCS8PrivateKey(k)
	raw, _ := json.Marshal(map[string]string{
		"client_email": "sa@example.iam.gserviceaccount.com",
		"private_key":  string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})),
	})
	sa, err := parseServiceAccount(raw)
	if err != nil || sa.key == nil || sa.TokenURI == "" {
		t.Fatalf("%v", err)
	}
	if v, err := New("", "app", nil); v != nil || err != nil {
		t.Fatal("missing credentials must disable the verifier")
	}
}
