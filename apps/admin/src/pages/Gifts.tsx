import { useState } from 'react';
import { useAuth } from '../auth/AuthContext';
import { Banner, ErrorBanner, PageHead, Pill, Skeleton } from '../components/ui';
import { describeError } from '../lib/api';
import { formatDateTime } from '../lib/format';
import type { AdminGift, GiftPriceChange, GiftTier } from '../lib/types';
import { useLoad } from '../lib/useLoad';

const TIERS: GiftTier[] = ['common', 'rare', 'epic', 'legendary', 'mythic'];
const n = (v: number) => v.toLocaleString('en-IN');

/**
 * Virtual gift catalogue (2026-11-26). Admins create gifts, edit metadata,
 * enable/disable, reorder, schedule and retire them, and change prices with a
 * reason (audited; completed gifts keep the price they were charged). Finance
 * and moderators can read the catalogue, performance and flagged gifts.
 */
export function Gifts() {
  const { api, has } = useAuth();
  const admin = has('admin');
  const gifts = useLoad(() => api.gifts(), [api]);
  const perf = useLoad(() => api.giftPerformance(30), [api]);
  const flagged = useLoad(() => api.giftTransactions({ flagged: true }), [api]);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [pricing, setPricing] = useState<{ id: string; price: string; reason: string } | null>(null);
  const [history, setHistory] = useState<{ id: string; items: GiftPriceChange[] } | null>(null);
  const [creating, setCreating] = useState(false);

  const run = async (id: string, f: () => Promise<unknown>, done: string) => {
    setBusy(id);
    setError(null);
    setOk(null);
    try {
      await f();
      setOk(done);
      await gifts.reload();
    } catch (e) {
      setError(describeError(e));
    } finally {
      setBusy(null);
    }
  };

  const toggle = (g: AdminGift) => run(g.id, () => api.updateGift(g.id, { active: !g.active }), `${g.name} ${g.active ? 'disabled' : 'enabled'}.`);
  const move = (g: AdminGift, delta: number) => run(g.id, () => api.updateGift(g.id, { sort_order: g.sort_order + delta }), `${g.name} moved.`);
  const retire = (g: AdminGift) => {
    if (!window.confirm(`Retire ${g.name}? It can never be sold again. Past gifts are unaffected.`)) return;
    void run(g.id, () => api.updateGift(g.id, { retire: true }), `${g.name} retired.`);
  };
  const savePrice = () => {
    if (!pricing) return;
    const price = Number(pricing.price);
    if (!Number.isInteger(price) || price < 1 || price > 1_000_000 || pricing.reason.trim().length < 3) {
      setError('Enter a whole price between 1 and 10,00,000 Diamonds and a reason.');
      return;
    }
    void run(pricing.id, () => api.changeGiftPrice(pricing.id, price, pricing.reason.trim()), 'Price changed. It applies to gifts sent from now on.').then(() => setPricing(null));
  };
  const showHistory = async (id: string) => {
    try {
      const h = await api.giftPriceHistory(id);
      setHistory({ id, items: h.items });
    } catch (e) {
      setError(describeError(e));
    }
  };

  const perfById = Object.fromEntries((perf.data?.items ?? []).map((p) => [p.gift_id, p]));

  return (
    <>
      <PageHead
        title="Gifts"
        lede="Gift catalogue, prices and performance. Price changes need a reason, are logged, and never change gifts already sent."
        aside={admin && <button type="button" className="btn btn-primary" onClick={() => setCreating((v) => !v)}>{creating ? 'Close' : 'New gift'}</button>}
      />
      <Banner tone="info">
        Host earnings from gifts use the economy rule set in force (the same conversion as calls). There is no gift-specific
        commission; changing the conversion is a founder decision, not a setting here.
      </Banner>
      {error && <Banner tone="error">{error}</Banner>}
      {ok && <Banner tone="ok">{ok}</Banner>}
      {creating && admin && <CreateGift onDone={async (msg) => { setCreating(false); setOk(msg); await gifts.reload(); }} onError={setError} />}
      <ErrorBanner error={gifts.error} onRetry={gifts.reload} />
      {gifts.loading && !gifts.data ? (
        <Skeleton rows={5} />
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Gift</th>
                <th>Price (Diamonds)</th>
                <th>Tier</th>
                <th>Status</th>
                <th>Sent (30 days)</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {(gifts.data?.items ?? []).map((g) => {
                const p = perfById[g.id];
                return (
                  <tr key={g.id}>
                    <td>
                      <strong>{g.emoji} {g.name}</strong>
                      <div className="small muted">{g.id} · order {g.sort_order}</div>
                    </td>
                    <td>
                      {pricing?.id === g.id ? (
                        <div className="field">
                          <label htmlFor={`price-${g.id}`}>New price</label>
                          <input id={`price-${g.id}`} inputMode="numeric" value={pricing.price} onChange={(e) => setPricing({ ...pricing, price: e.target.value })} />
                          <label htmlFor={`reason-${g.id}`}>Reason (logged)</label>
                          <input id={`reason-${g.id}`} value={pricing.reason} onChange={(e) => setPricing({ ...pricing, reason: e.target.value })} />
                          <div className="two">
                            <button type="button" className="btn btn-primary" disabled={busy === g.id} onClick={savePrice}>Save price</button>
                            <button type="button" className="btn btn-ghost" onClick={() => setPricing(null)}>Cancel</button>
                          </div>
                        </div>
                      ) : (
                        <>
                          {n(g.diamond_price)}
                          <div>
                            <button type="button" className="btn btn-ghost" onClick={() => void showHistory(g.id)}>History</button>
                          </div>
                        </>
                      )}
                    </td>
                    <td>{g.tier}</td>
                    <td>
                      {g.retired_at ? <Pill tone="neutral">Retired</Pill> : g.active ? <Pill tone="ok">Active</Pill> : <Pill tone="warn">Disabled</Pill>}
                      {(g.available_from || g.available_until) && (
                        <div className="small muted">
                          {g.available_from ? `from ${formatDateTime(g.available_from)}` : ''} {g.available_until ? `until ${formatDateTime(g.available_until)}` : ''}
                        </div>
                      )}
                    </td>
                    <td>
                      {p ? `${n(p.count)} · ${n(p.diamond_value)} D` : '—'}
                      {p && p.count > 0 && <div className="small muted">{n(p.unique_senders)} senders · {n(p.unique_hosts)} hosts</div>}
                    </td>
                    <td>
                      {admin && !g.retired_at ? (
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                          <button type="button" className="btn btn-ghost" disabled={busy === g.id} onClick={() => void toggle(g)}>{g.active ? 'Disable' : 'Enable'}</button>
                          <button type="button" className="btn btn-ghost" disabled={busy === g.id} onClick={() => setPricing({ id: g.id, price: String(g.diamond_price), reason: '' })}>Change price</button>
                          <button type="button" className="btn btn-ghost" aria-label={`Move ${g.name} up`} disabled={busy === g.id} onClick={() => void move(g, -15)}>↑</button>
                          <button type="button" className="btn btn-ghost" aria-label={`Move ${g.name} down`} disabled={busy === g.id} onClick={() => void move(g, 15)}>↓</button>
                          <button type="button" className="btn btn-danger-outline" disabled={busy === g.id} onClick={() => retire(g)}>Retire</button>
                        </div>
                      ) : (
                        <span className="small muted">{admin ? '—' : 'Read only'}</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
      {history && (
        <section className="card">
          <h2>Price history · {history.id}</h2>
          {history.items.map((h, i) => (
            <div key={i} className="small">
              {formatDateTime(h.changed_at)} — {h.old_price === null ? 'created at' : `${n(h.old_price)} →`} {n(h.new_price)} by {h.changed_by}: {h.reason}
            </div>
          ))}
          <button type="button" className="btn btn-ghost" onClick={() => setHistory(null)}>Close</button>
        </section>
      )}
      <section className="card">
        <h2>Flagged gifts</h2>
        <p className="small muted" style={{ margin: 0 }}>
          Review signals only (high value, new account, repeat pair volume, promotional Diamonds). Nothing here blocks a gift by itself.
        </p>
        <ErrorBanner error={flagged.error} onRetry={flagged.reload} />
        {(flagged.data?.items ?? []).length === 0 ? (
          <span className="muted">No flagged gifts.</span>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr><th>When</th><th>Gift</th><th>From → to</th><th>Diamonds</th><th>Flags</th></tr>
              </thead>
              <tbody>
                {flagged.data!.items.map((t) => (
                  <tr key={t.gift_transaction_id}>
                    <td>{formatDateTime(t.sent_at)}</td>
                    <td>{t.emoji} {t.gift_name}</td>
                    <td>{t.sender.display_name || t.sender.user_id} → {t.recipient.display_name || t.recipient.user_id}</td>
                    <td>{n(t.diamond_value)}</td>
                    <td>{t.risk_flags.map((f) => <Pill key={f} tone="warn">{f.replace(/_/g, ' ')}</Pill>)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  );
}

function CreateGift({ onDone, onError }: { onDone: (msg: string) => void; onError: (e: string) => void }) {
  const { api } = useAuth();
  const [f, setF] = useState({ id: '', name: '', emoji: '🎁', description: '', tier: 'common' as GiftTier, price: '', sort: '100', reason: '' });
  const [busy, setBusy] = useState(false);
  const save = async () => {
    setBusy(true);
    try {
      await api.createGift({
        id: f.id.trim(),
        name: f.name.trim(),
        emoji: f.emoji.trim(),
        description: f.description.trim(),
        icon_asset: `gift/${f.id.trim()}`,
        animation_asset: `celebration/${f.id.trim()}`,
        tier: f.tier,
        sort_order: Number(f.sort) || 0,
        diamond_price: Number(f.price),
        active: false,
        reason: f.reason.trim(),
      });
      onDone(`${f.name} created (disabled — enable it when ready).`);
    } catch (e) {
      onError(describeError(e));
    } finally {
      setBusy(false);
    }
  };
  const field = (key: keyof typeof f, label: string, hint?: string) => (
    <div className="field">
      <label htmlFor={`new-${key}`}>{label}</label>
      <input id={`new-${key}`} value={f[key]} onChange={(e) => setF({ ...f, [key]: e.target.value })} />
      {hint && <span className="small muted">{hint}</span>}
    </div>
  );
  return (
    <section className="card">
      <h2>New gift</h2>
      {field('id', 'Gift id', 'Lowercase letters, digits and _ (stable; cannot change)')}
      {field('name', 'Name')}
      {field('emoji', 'Emoji (chat line)')}
      {field('description', 'Description')}
      <div className="field">
        <label htmlFor="new-tier">Tier</label>
        <select id="new-tier" value={f.tier} onChange={(e) => setF({ ...f, tier: e.target.value as GiftTier })}>
          {TIERS.map((t) => <option key={t}>{t}</option>)}
        </select>
      </div>
      {field('price', 'Diamond price')}
      {field('sort', 'Sort order')}
      {field('reason', 'Reason (logged)')}
      <button type="button" className="btn btn-primary" disabled={busy} onClick={() => void save()}>Create (disabled)</button>
    </section>
  );
}
