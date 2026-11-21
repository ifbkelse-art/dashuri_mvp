// Package logging configures structured JSON logs for Cloud Logging.
//
// Never log: tokens, phone numbers, dates of birth, KYC documents, bank or
// UPI details, message bodies, video frames, purchase tokens.
package logging

import (
	"log/slog"
	"os"
)

func New(env string) *slog.Logger {
	level := slog.LevelInfo
	if env == "development" {
		level = slog.LevelDebug
	}
	h := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: level,
		ReplaceAttr: func(_ []string, a slog.Attr) slog.Attr {
			// Cloud Logging reads "severity" and "message".
			switch a.Key {
			case slog.LevelKey:
				a.Key = "severity"
			case slog.MessageKey:
				a.Key = "message"
			}
			return a
		},
	})
	return slog.New(h)
}
