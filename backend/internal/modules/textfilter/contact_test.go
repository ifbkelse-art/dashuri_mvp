package textfilter

import "testing"

func TestFindContactDetails(t *testing.T) {
	cases := []struct {
		in   string
		want Kind
	}{
		// Clean text.
		{"Hi! How was your day?", None},
		{"I have 2 cats and 1 dog", None},
		{"Call me at 5 pm, ok?", None},
		{"I paid 100000 Beans last week", None},
		{"Pune is 150 km from Mumbai", None},
		{"rating 4.5 out of 5", None},
		{"नमस्ते, आप कैसे हैं?", None},
		{"see you @ 7", None},
		{"The year 2026 was great", None},
		{"", None},

		// Phone numbers.
		{"my number 9876543210", Phone},
		{"98765 43210", Phone},
		{"+91 98765-43210", Phone},
		{"+91-98765-43210 call", Phone},
		{"(987) 654.3210", Phone},
		{"9 8 7 6 5 4 3 2 1 0", Phone},
		{"+44 20 7946 0958", Phone},
		{"९८७६५४३२१०", Phone},  // Devanagari digits
		{"９８７６５４３２１０", Phone}, // fullwidth digits
		{"98765\u200b43210", Phone}, // zero-width space

		// Emails.
		{"write to priya.s@gmail.com", Email},
		{"PRIYA@Example.CO.IN", Email},
		{"priya at gmail dot com", Email},
		{"priya(at)gmail(dot)com", Email},

		// UPI.
		{"pay me on priya@okaxis", UPI},
		{"9876543210@ybl", UPI},
		{"upi: rahul.k@paytm", UPI},

		// Links.
		{"https://example.org/x", Link},
		{"visit www.example.org", Link},
		{"find me on t.me/priya", Link},
		{"wa.me/919876543210", Link},
		{"my site is priya.in", Link},
		{"check example . com", Link},
		{"h t t p s://x", None}, // too obfuscated; documented limitation
	}
	for _, c := range cases {
		if got := Find(c.in); got != c.want {
			t.Errorf("Find(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestContainsContactDetails(t *testing.T) {
	if !ContainsContactDetails("ping 9876543210") {
		t.Fatal("phone not detected")
	}
	if ContainsContactDetails("hello there") {
		t.Fatal("false positive")
	}
}

func TestDigitValue(t *testing.T) {
	for r, want := range map[rune]int{'0': 0, '9': 9, '०': 0, '७': 7, '٣': 3, '𝟘': 0, '𝟡': 9, '𝟬': 0} {
		got, ok := digitValue(r)
		if !ok || got != want {
			t.Errorf("digitValue(%q) = %d,%v want %d", r, got, ok, want)
		}
	}
}
