package chat

import "dashuri/backend/internal/modules/keyset"

// Cursor is a keyset position (timestamp, id) for newest-first lists.
type Cursor = keyset.Cursor

// DecodeCursor parses a token; empty means first page.
func DecodeCursor(s string) (*Cursor, error) { return keyset.Decode(s) }
