package reelsrank

import (
	"fmt"
	"testing"
	"time"
)

var asOf = time.Date(2026, 11, 22, 12, 0, 0, 0, time.UTC)

func id(n int) string { return fmt.Sprintf("00000000-0000-4000-8000-%012d", n) }

func cand(n int, ageH float64) Candidate {
	return Candidate{VideoID: id(n), CreatorID: id(1000 + n), PublishedAt: asOf.Add(-time.Duration(ageH * float64(time.Hour)))}
}

func TestFresherRanksHigherAllElseEqual(t *testing.T) {
	r := Rank([]Candidate{cand(1, 48), cand(2, 1)}, Viewer{}, asOf, DefaultWeights)
	if r[0].VideoID != id(2) {
		t.Fatalf("fresh video should lead, got %s", r[0].VideoID)
	}
}

func TestFollowingLanguageAndSeenTerms(t *testing.T) {
	a, b := cand(1, 10), cand(2, 10)
	a.Following = true
	if Score(a, Viewer{}, asOf, DefaultWeights) <= Score(b, Viewer{}, asOf, DefaultWeights) {
		t.Fatal("following should add score")
	}
	b.Language = "hi"
	if Score(b, Viewer{Languages: []string{"HI"}}, asOf, DefaultWeights) <= Score(b, Viewer{}, asOf, DefaultWeights) {
		t.Fatal("language match should add score")
	}
	seen := cand(3, 10)
	seen.SeenByViewer = true
	if Score(seen, Viewer{}, asOf, DefaultWeights) >= Score(cand(4, 10), Viewer{}, asOf, DefaultWeights) {
		t.Fatal("seen should be demoted")
	}
}

func TestEngagementIsSmoothed(t *testing.T) {
	tiny, big := cand(1, 5), cand(2, 5)
	tiny.Views, tiny.Likes = 1, 1
	big.Views, big.Likes = 400, 120
	if Score(tiny, Viewer{}, asOf, DefaultWeights) >= Score(big, Viewer{}, asOf, DefaultWeights) {
		t.Fatal("1 like on 1 view must not beat 120 likes on 400 views")
	}
}

func TestReportsPenaltyIsCapped(t *testing.T) {
	a, b := cand(1, 5), cand(2, 5)
	a.Reports, b.Reports = 4, 100
	if Score(a, Viewer{}, asOf, DefaultWeights) != Score(b, Viewer{}, asOf, DefaultWeights) {
		t.Fatal("report penalty should cap at 4 reporters")
	}
}

func TestDeterministicTotalOrder(t *testing.T) {
	var cs []Candidate
	for i := 1; i <= 50; i++ {
		cs = append(cs, cand(i, 10)) // identical scores → ordered by id desc
	}
	r1 := Rank(cs, Viewer{}, asOf, DefaultWeights)
	rev := make([]Candidate, len(cs))
	for i := range cs {
		rev[i] = cs[len(cs)-1-i]
	}
	r2 := Rank(rev, Viewer{}, asOf, DefaultWeights)
	for i := range r1 {
		if r1[i].VideoID != r2[i].VideoID {
			t.Fatalf("order depends on input order at %d", i)
		}
	}
	if r1[0].VideoID != id(50) {
		t.Fatalf("tie-break should be id desc, got %s", r1[0].VideoID)
	}
}

func TestPaginationCoversAllWithoutDuplicates(t *testing.T) {
	var cs []Candidate
	for i := 1; i <= 47; i++ {
		c := cand(i, float64(i%9))
		c.Likes, c.Views = i%5, 10+i
		cs = append(cs, c)
	}
	ranked := Rank(cs, Viewer{}, asOf, DefaultWeights)
	seen := map[string]bool{}
	var cur *Cursor
	pages := 0
	for {
		page := After(ranked, cur, 10)
		if len(page) == 0 {
			break
		}
		pages++
		for _, p := range page {
			if seen[p.VideoID] {
				t.Fatalf("duplicate %s", p.VideoID)
			}
			seen[p.VideoID] = true
		}
		last := page[len(page)-1]
		tok := Cursor{AsOf: asOf, LastScore: last.Score, LastID: last.VideoID}.Encode()
		var err error
		if cur, err = DecodeCursor(tok); err != nil {
			t.Fatal(err)
		}
	}
	if len(seen) != 47 || pages != 5 {
		t.Fatalf("got %d items in %d pages", len(seen), pages)
	}
}

func TestCursorRoundTripAndRejects(t *testing.T) {
	c := Cursor{AsOf: asOf, LastScore: 1.234567891, LastID: id(7)}
	got, err := DecodeCursor(c.Encode())
	if err != nil || got.LastScore != c.LastScore || got.LastID != c.LastID || !got.AsOf.Equal(asOf) {
		t.Fatalf("round trip: %+v %v", got, err)
	}
	for _, bad := range []string{"x", "cjF8MjAyNnxhYmM", Cursor{AsOf: asOf, LastID: "not-a-uuid"}.Encode()} {
		if _, err := DecodeCursor(bad); err == nil {
			t.Fatalf("accepted %q", bad)
		}
	}
	if c, err := DecodeCursor(""); c != nil || err != nil {
		t.Fatal("empty cursor is the first page")
	}
}

func TestDiversifySpreadsCreators(t *testing.T) {
	a1, a2, b1 := cand(1, 1), cand(2, 1), cand(3, 1)
	a2.CreatorID = a1.CreatorID
	page := []Ranked{{Candidate: a1}, {Candidate: a2}, {Candidate: b1}}
	out := Diversify(page)
	if out[0].VideoID != a1.VideoID || out[1].VideoID != b1.VideoID || out[2].VideoID != a2.VideoID {
		t.Fatalf("got %v %v %v", out[0].VideoID, out[1].VideoID, out[2].VideoID)
	}
	if len(Diversify(nil)) != 0 {
		t.Fatal("empty page")
	}
}
