package r2

import (
	"net/http"
	"net/url"
	"strings"
	"testing"
	"time"
)

// Examples from the AWS S3 SigV4 documentation ("Authenticating Requests:
// Using Query Parameters" and "Using the Authorization Header", GET object).
var awsExample = Signer{
	AccessKeyID:     "AKIAIOSFODNN7EXAMPLE",
	SecretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
	Region:          "us-east-1",
	Service:         "s3",
}

var awsTime = time.Date(2013, 5, 24, 0, 0, 0, 0, time.UTC)

func TestPresignMatchesAWSExample(t *testing.T) {
	u, _ := url.Parse("https://examplebucket.s3.amazonaws.com/test.txt")
	got := awsExample.Presign(http.MethodGet, u, nil, 86400*time.Second, awsTime)
	const want = "X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404"
	if !strings.HasSuffix(got, want) {
		t.Fatalf("presigned URL\n got %s\nwant suffix %s", got, want)
	}
	if !strings.Contains(got, "X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request") {
		t.Fatalf("credential scope not encoded as AWS expects: %s", got)
	}
}

func TestSignRequestMatchesAWSExample(t *testing.T) {
	r, _ := http.NewRequest(http.MethodGet, "https://examplebucket.s3.amazonaws.com/test.txt", nil)
	r.Header.Set("Range", "bytes=0-9")
	awsExample.SignRequest(r, emptySHA256, awsTime)
	const want = "Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41"
	if got := r.Header.Get("Authorization"); !strings.HasSuffix(got, want) ||
		!strings.Contains(got, "SignedHeaders=host;range;x-amz-content-sha256;x-amz-date") {
		t.Fatalf("authorization\n got %s\nwant suffix %s", got, want)
	}
}

func TestPresignSignsDeclaredHeaders(t *testing.T) {
	u, _ := url.Parse("https://acct.r2.cloudflarestorage.com/media/reels/x/original")
	got := awsExample.Presign(http.MethodPut, u, map[string]string{"Content-Type": "video/mp4", "Content-Length": "123"}, time.Hour, awsTime)
	if !strings.Contains(got, "X-Amz-SignedHeaders=content-length%3Bcontent-type%3Bhost") {
		t.Fatalf("size and type must be signed: %s", got)
	}
	other := awsExample.Presign(http.MethodPut, u, map[string]string{"Content-Type": "video/mp4", "Content-Length": "124"}, time.Hour, awsTime)
	if got == other {
		t.Fatal("a different declared size must change the signature")
	}
}
