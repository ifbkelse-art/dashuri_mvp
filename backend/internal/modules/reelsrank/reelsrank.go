// Package reelsrank is the deterministic, explainable ranking for the
// Reels "For You" feed (EXPERIMENT). It is a pure library like keyset and
// economy: no I/O, no clock, no randomness. Given the same candidates,
// viewer and as-of time it always returns the same order, so cursor
// pagination over it is stable.
//
// Upgrade path: a learned model can replace Score behind the same
// Candidate/Ranked types without touching the feed module or the API.
package reelsrank

import (
	"encoding/base64"
	"errors"
	"math"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

// Candidate is one published video with the signals the ranker uses.
type Candidate struct {
	VideoID        string
	CreatorID      string
	PublishedAt    time.Time
	Language       string // ISO 639-1, may be empty
	Likes          int
	Views          int
	Completions    int
	Reports        int  // distinct reporters (published videos only)
	Following      bool // viewer follows the creator
	SeenByViewer   bool // viewer watched it before
	CreatorIsHost  bool // approved host
	HostOnline     bool // host is online now (contextual)
	CreatorLikedBy int  // how many of this creator's videos the viewer liked (relevance)
}

// Weights are the tunable coefficients. Defaults are documented in
// docs/reels/DASHURI_REELS_ARCHITECTURE.md §Feed.
type Weights struct {
	Following       float64
	FreshnessHalfH  float64 // half-life of the freshness term in hours
	Freshness       float64
	Language        float64
	Engagement      float64
	Completion      float64
	CreatorAffinity float64
	HostOnline      float64
	SeenPenalty     float64
	ReportPenalty   float64
}

// DefaultWeights are the MVP coefficients.
var DefaultWeights = Weights{
	Following:       1.0,
	FreshnessHalfH:  36,
	Freshness:       1.2,
	Language:        0.6,
	Engagement:      1.0,
	Completion:      0.8,
	CreatorAffinity: 0.3,
	HostOnline:      0.15,
	SeenPenalty:     1.5,
	ReportPenalty:   0.5,
}

// Viewer is what the ranker knows about the person scrolling.
type Viewer struct {
	Languages []string
}

// Breakdown explains a score term by term (admin/debug and tests).
type Breakdown struct {
	Following, Freshness, Language, Engagement, Completion, Affinity, HostOnline, Seen, Reports float64
}

// Total is the sum of the terms.
func (b Breakdown) Total() float64 {
	return b.Following + b.Freshness + b.Language + b.Engagement + b.Completion + b.Affinity + b.HostOnline - b.Seen - b.Reports
}

// Explain computes each term for one candidate.
func Explain(c Candidate, v Viewer, asOf time.Time, w Weights) Breakdown {
	var b Breakdown
	if c.Following {
		b.Following = w.Following
	}
	ageH := asOf.Sub(c.PublishedAt).Hours()
	if ageH < 0 {
		ageH = 0
	}
	if w.FreshnessHalfH > 0 {
		b.Freshness = w.Freshness * math.Pow(0.5, ageH/w.FreshnessHalfH)
	}
	if c.Language != "" {
		for _, l := range v.Languages {
			if strings.EqualFold(l, c.Language) {
				b.Language = w.Language
				break
			}
		}
	}
	// Smoothed like rate (Bayesian prior of 1 like per 20 views) so a video
	// with 1 view and 1 like does not outrank everything.
	b.Engagement = w.Engagement * (float64(c.Likes) + 1) / (float64(c.Views) + 20) * 5
	b.Completion = w.Completion * (float64(c.Completions) + 1) / (float64(c.Views) + 4)
	b.Affinity = w.CreatorAffinity * math.Min(float64(c.CreatorLikedBy), 3) / 3
	if c.CreatorIsHost && c.HostOnline {
		b.HostOnline = w.HostOnline
	}
	if c.SeenByViewer {
		b.Seen = w.SeenPenalty
	}
	b.Reports = w.ReportPenalty * math.Min(float64(c.Reports), 4)
	return b
}

// Score is the candidate's rank score, rounded to 1e-9 so the cursor
// round-trips exactly.
func Score(c Candidate, v Viewer, asOf time.Time, w Weights) float64 {
	return round9(Explain(c, v, asOf, w).Total())
}

func round9(x float64) float64 { return math.Round(x*1e9) / 1e9 }

// Ranked is a candidate with its score.
type Ranked struct {
	Candidate
	Score float64
}

// Rank orders candidates by score desc, then video id desc (total order).
// Pages are cut from this order (After); Diversify then spreads creators
// within a page. The cursor always comes from the undiversified page.
func Rank(cands []Candidate, v Viewer, asOf time.Time, w Weights) []Ranked {
	out := make([]Ranked, len(cands))
	for i, c := range cands {
		out[i] = Ranked{Candidate: c, Score: Score(c, v, asOf, w)}
	}
	sort.Slice(out, func(i, j int) bool { return Less(out[j], out[i]) })
	return out
}

// Less reports whether a sorts after b (a is "smaller").
func Less(a, b Ranked) bool {
	if a.Score != b.Score {
		return a.Score < b.Score
	}
	return a.VideoID < b.VideoID
}

// After returns the ranked items strictly after the cursor position
// (score, id) in the Rank order, at most limit.
func After(ranked []Ranked, c *Cursor, limit int) []Ranked {
	start := 0
	if c != nil {
		pos := Ranked{Candidate: Candidate{VideoID: c.LastID}, Score: c.LastScore}
		start = len(ranked)
		for i, r := range ranked {
			if Less(r, pos) {
				start = i
				break
			}
		}
	}
	end := start + limit
	if end > len(ranked) {
		end = len(ranked)
	}
	return ranked[start:end]
}

// Cursor is the For You pagination position. AsOf pins the candidate set
// and the freshness term for the whole scroll session.
type Cursor struct {
	AsOf      time.Time
	LastScore float64
	LastID    string
}

// ErrInvalidCursor is returned for tokens not produced by Encode.
var ErrInvalidCursor = errors.New("invalid feed cursor")

var uuidRE = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

// Encode returns the opaque token.
func (c Cursor) Encode() string {
	raw := "r1|" + c.AsOf.UTC().Format(time.RFC3339Nano) + "|" + strconv.FormatFloat(c.LastScore, 'g', -1, 64) + "|" + c.LastID
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

// DecodeCursor parses a token; empty means the first page (nil, nil).
func DecodeCursor(s string) (*Cursor, error) {
	if s == "" {
		return nil, nil
	}
	if len(s) > 200 {
		return nil, ErrInvalidCursor
	}
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return nil, ErrInvalidCursor
	}
	p := strings.Split(string(b), "|")
	if len(p) != 4 || p[0] != "r1" || !uuidRE.MatchString(p[3]) {
		return nil, ErrInvalidCursor
	}
	at, err := time.Parse(time.RFC3339Nano, p[1])
	if err != nil {
		return nil, ErrInvalidCursor
	}
	score, err := strconv.ParseFloat(p[2], 64)
	if err != nil || math.IsNaN(score) || math.IsInf(score, 0) {
		return nil, ErrInvalidCursor
	}
	return &Cursor{AsOf: at, LastScore: score, LastID: p[3]}, nil
}

// Diversify reorders a ranked page so the same creator does not appear in
// consecutive slots when an alternative exists within the page. It keeps
// the relative order otherwise (stable), so it is still deterministic.
func Diversify(page []Ranked) []Ranked {
	out := make([]Ranked, 0, len(page))
	rest := append([]Ranked(nil), page...)
	for len(rest) > 0 {
		pick := 0
		if n := len(out); n > 0 {
			for i, r := range rest {
				if r.CreatorID != out[n-1].CreatorID {
					pick = i
					break
				}
			}
		}
		out = append(out, rest[pick])
		rest = append(rest[:pick], rest[pick+1:]...)
	}
	return out
}
