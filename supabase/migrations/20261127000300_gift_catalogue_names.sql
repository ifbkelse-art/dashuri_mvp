-- Gift catalogue: recognisable names (founder decision, 2026-11-27).
--
-- The five top gifts had generic names ("Luxury Gift", "Royal Gift", ...).
-- They are renamed to real items, and "Teddy" becomes "Teddy Bear".
-- IDs, Diamond prices, tiers, sort order and the earning rule are NOT
-- changed, so no gifts.price_changes row is needed and past
-- gifts.transactions (which snapshot name/emoji/animation) stay as they were.
-- Rose, Watch, Gold Ring and Diamond Ring are unchanged.

update gifts.catalogue as c set
  name            = v.name,
  description     = v.description,
  emoji           = v.emoji,
  icon_asset      = v.icon_asset,
  animation_asset = v.animation_asset
from (values
  ('teddy',        'Teddy Bear', 'A soft, cuddly teddy bear',     '🧸', 'gift/teddy',      'celebration/teddy'),
  ('luxury_gift',  'Sports Car', 'A gleaming red sports car',     '🏎️', 'gift/sports_car', 'celebration/sports_car'),
  ('royal_gift',   'Crown',      'A jewelled golden crown',       '👑', 'gift/crown',      'celebration/crown'),
  ('premium_gift', 'Yacht',      'A private yacht at sunset',     '🛥️', 'gift/yacht',      'celebration/yacht'),
  ('super_gift',   'Rocket',     'A rocket launching to the stars', '🚀', 'gift/rocket',   'celebration/rocket'),
  ('elite_gift',   'Castle',     'A fairy-tale castle',           '🏰', 'gift/castle',     'celebration/castle')
) as v(id, name, description, emoji, icon_asset, animation_asset)
where c.id = v.id;
