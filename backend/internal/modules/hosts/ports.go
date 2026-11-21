package hosts

import "context"

// KYCProvider is the identity-verification vendor (not chosen; Aadhaar
// offline e-KYC / DigiLocker + PAN + liveness). Raw documents stay with the
// vendor; Dashuri stores status, masked identifiers and verified DOB.
type KYCProvider interface {
	StartSession(ctx context.Context, hostID string) (sessionID, redirectURL string, err error)
	VerifyCallback(raw []byte, headers map[string]string) (KYCResult, error)
}

type KYCResult struct {
	SessionID   string
	HostID      string
	Approved    bool
	AgeVerified bool // must be 18+
	NameOnID    string
	FailureCode string
}
