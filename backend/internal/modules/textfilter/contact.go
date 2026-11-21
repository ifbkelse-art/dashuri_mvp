// Package textfilter screens user-written text (chat messages, display
// names, bios) for contact details: phone numbers, UPI IDs, email addresses
// and links. Sharing them moves payment and contact off the platform, which
// is a revenue and safety risk (security-architecture.md, CH05).
//
// It is a pure library (like economy and ledger): accounts and chat import
// it; it imports nothing from other modules.
package textfilter

import (
	"regexp"
	"strings"
	"unicode"
)

// Kind names the kind of contact detail found.
type Kind string

const (
	None  Kind = ""
	Phone Kind = "phone"
	Email Kind = "email"
	UPI   Kind = "upi"
	Link  Kind = "link"
)

// ReasonContactDetails is the problem `reason` clients map to copy.
const ReasonContactDetails = "contact_details"

var (
	emailRE = regexp.MustCompile(`[a-z0-9._%+\-]+@[a-z0-9\-]+(\.[a-z0-9\-]+)*\.[a-z]{2,}`)
	// UPI virtual payment addresses: handle@psp, where the PSP part has no dot
	// (okaxis, ybl, paytm, upi, ...).
	upiRE = regexp.MustCompile(`[a-z0-9._\-]{2,}@[a-z]{2,}`)
	// Spelled-out emails: "name at gmail dot com".
	spelledEmailRE = regexp.MustCompile(`[a-z0-9._\-]+\s*(\(at\)|\[at\]|\sat\s)\s*[a-z0-9\-]+\s*(\.|\(dot\)|\[dot\]|\sdot\s)\s*[a-z]{2,}`)
	schemeRE       = regexp.MustCompile(`(https?|ftp)\s*:\s*/\s*/|www\s*\.`)
	shortLinkRE    = regexp.MustCompile(`\b(t\.me|wa\.me|bit\.ly|tinyurl\.com|goo\.gl|instagram\.com|snapchat\.com|telegram\.me|chat\.whatsapp\.com)\b`)
	domainRE       = regexp.MustCompile(`\b[a-z0-9][a-z0-9\-]{0,62}\s?\.\s?(com|in|net|org|io|me|app|co|xyz|link|ly|gg|info|biz|online|site|shop|live|club|tv|to|cc|us|uk)\b`)
)

// Find reports the first kind of contact detail in s, or None.
func Find(s string) Kind {
	n := normalize(s)
	switch {
	case emailRE.MatchString(n) || spelledEmailRE.MatchString(n):
		return Email
	case upiRE.MatchString(n):
		return UPI
	case schemeRE.MatchString(n) || shortLinkRE.MatchString(n) || domainRE.MatchString(n):
		return Link
	case hasPhoneNumber(n):
		return Phone
	}
	return None
}

// ContainsContactDetails is Find(s) != None.
func ContainsContactDetails(s string) bool { return Find(s) != None }

// normalize lowercases, maps every Unicode decimal digit to ASCII, maps
// fullwidth ASCII to ASCII and drops zero-width and other format characters
// that are used to slip past filters.
func normalize(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	for _, r := range s {
		switch {
		case r >= 0xFF01 && r <= 0xFF5E: // fullwidth forms
			r -= 0xFEE0
		case unicode.Is(unicode.Cf, r): // zero-width joiners, BOM, ...
			continue
		}
		if r > unicode.MaxASCII && unicode.IsDigit(r) {
			if d, ok := digitValue(r); ok {
				r = rune('0' + d)
			}
		}
		b.WriteRune(unicode.ToLower(r))
	}
	return b.String()
}

// digitValue returns the value of a Unicode Nd digit. Every Nd range in the
// Unicode tables starts at a zero and runs in blocks of ten.
func digitValue(r rune) (int, bool) {
	for _, rg := range unicode.Nd.R16 {
		if r >= rune(rg.Lo) && r <= rune(rg.Hi) {
			return int(r-rune(rg.Lo)) % 10, true
		}
	}
	for _, rg := range unicode.Nd.R32 {
		if r >= rune(rg.Lo) && r <= rune(rg.Hi) {
			return int(r-rune(rg.Lo)) % 10, true
		}
	}
	return 0, false
}

// phone separators that may appear between digits of one number.
func isPhoneSeparator(r rune) bool {
	return r == ' ' || r == '-' || r == '.' || r == '(' || r == ')' || r == '/' || r == '_' || r == '\t'
}

// hasPhoneNumber finds a run of digits (separators allowed) with at least 10
// digits, or at least 8 digits after a leading "+". This catches Indian
// mobile numbers in any spacing ("98765 43210", "+91-98765-43210").
func hasPhoneNumber(s string) bool {
	rs := []rune(s)
	for i := 0; i < len(rs); i++ {
		if rs[i] != '+' && !isASCIIDigit(rs[i]) {
			continue
		}
		plus := rs[i] == '+'
		j := i
		if plus {
			j++
		}
		digits := 0
		for j < len(rs) {
			r := rs[j]
			if isASCIIDigit(r) {
				digits++
			} else if !isPhoneSeparator(r) || (r == ' ' && j+1 < len(rs) && rs[j+1] == ' ') {
				// Anything else, or a double space, ends the number.
				break
			}
			j++
		}
		if digits >= 10 || (plus && digits >= 8) {
			return true
		}
		if j > i {
			i = j - 1 // continue after this run
		}
	}
	return false
}

func isASCIIDigit(r rune) bool { return r >= '0' && r <= '9' }
