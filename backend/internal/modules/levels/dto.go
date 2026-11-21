package levels

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

// LevelProgress: XP = 8 × eligible Diamonds purchased + eligible Beans earned; one shared level per account.
type LevelProgress struct {
	Level          int    `json:"level"`
	LifetimeXp     int64  `json:"lifetime_xp"`
	CurrentLevelXp int64  `json:"current_level_xp"`
	NextLevelXp    *int64 `json:"next_level_xp,omitempty"`
}
