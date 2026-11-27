-- Purchase price records (finance audit, 2026-11-27).
--
-- commerce.purchases kept only the Diamonds credited, not what the customer
-- paid. Package prices are still provisional, so after a price change an old
-- purchase could not be reconciled or refunded against its real price.
--
-- Additive only. New credits snapshot the catalogue price of the package in
-- the same transaction as the ledger entry. Rows credited before this
-- migration keep price_paise null (unknown), never a guessed value.
--   * Google Play: the catalogue INR price the server sold the pack at. Play
--     reports the buyer's local amount only in its order reports, so this is
--     the list price, not a settlement figure.
--   * Cashfree: the order's amount_paise (what the gateway charged).

alter table commerce.purchases
  add column price_paise bigint check (price_paise > 0),
  add column price_source text check (price_source in ('catalogue', 'gateway_order'));

alter table commerce.purchases
  add constraint purchases_price_source_with_price
  check ((price_paise is null) = (price_source is null));

comment on column commerce.purchases.price_paise is
  'Price snapshot at credit time (INR paise). Null for rows credited before 2026-11-27.';
comment on column commerce.purchases.price_source is
  'catalogue = package list price at credit time (Play); gateway_order = Cashfree order amount.';
