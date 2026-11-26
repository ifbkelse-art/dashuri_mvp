import { useState, type FormEvent } from 'react';
import { useAuth } from '../auth/AuthContext';
import { Banner, ErrorBanner, PageHead, Pill, Skeleton } from '../components/ui';
import { describeError } from '../lib/api';
import { formatDateTime, formatNumber, formatRupeesFromPaise } from '../lib/format';
import { useLoad } from '../lib/useLoad';

const BUCKETS: { kind: string; label: string; currency: 'DIAMOND' | 'BEAN' }[] = [
  { kind: 'diamond_promotional', label: 'Promotional Diamonds', currency: 'DIAMOND' },
  { kind: 'diamond_purchased', label: 'Purchased Diamonds', currency: 'DIAMOND' },
  { kind: 'bean_held', label: 'Beans on hold', currency: 'BEAN' },
  { kind: 'bean_available', label: 'Beans available', currency: 'BEAN' },
];

export function Finance() {
  const { api } = useAuth();
  const recon = useLoad(() => api.reconciliation(), [api]);
  const adjustments = useLoad(() => api.adjustments('all'), [api]);
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [userId, setUserId] = useState('');
  const [bucket, setBucket] = useState(BUCKETS[0].kind);
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');

  const decide = async (id: string, approve: boolean) => {
    setBusy(id);
    setMsg(null);
    try {
      if (approve) await api.approveAdjustment(id);
      else await api.rejectAdjustment(id);
      setMsg({ ok: true, text: approve ? 'Approved and posted to the ledger.' : 'Rejected. Nothing was posted.' });
      await Promise.all([adjustments.reload(), recon.reload()]);
    } catch (e) {
      setMsg({ ok: false, text: describeError(e) });
    } finally {
      setBusy(null);
    }
  };

  const propose = async (e: FormEvent) => {
    e.preventDefault();
    setMsg(null);
    const n = Number(amount);
    if (!/^[0-9a-f-]{36}$/i.test(userId.trim())) return setMsg({ ok: false, text: 'Enter the user id (a UUID) of the account to adjust.' });
    if (!Number.isInteger(n) || n === 0) return setMsg({ ok: false, text: 'Amount must be a whole number, positive to add or negative to remove.' });
    if (!reason.trim()) return setMsg({ ok: false, text: 'Please write a reason.' });
    const b = BUCKETS.find((x) => x.kind === bucket)!;
    setBusy('propose');
    try {
      await api.proposeAdjustment(`user:${userId.trim()}:${b.kind}`, b.currency, n, reason.trim());
      setMsg({ ok: true, text: 'Proposed. A second finance or admin user must approve it before anything is posted.' });
      setShowForm(false);
      setUserId('');
      setAmount('');
      setReason('');
      await adjustments.reload();
    } catch (err) {
      setMsg({ ok: false, text: describeError(err) });
    } finally {
      setBusy(null);
    }
  };

  const r = recon.data;
  return (
    <>
      <PageHead title="Finance" lede="Read-only books, plus corrections that need two different people." />
      {msg && <Banner tone={msg.ok ? 'ok' : 'error'}>{msg.text}</Banner>}
      <section className="card">
        <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
          <h2>Reconciliation</h2>
          {r && (r.discrepancies === 0 ? <Pill tone="ok">Books balance · 0 discrepancies</Pill> : <Pill tone="danger">{r.discrepancies} discrepancies</Pill>)}
        </div>
        <ErrorBanner error={recon.error} onRetry={recon.reload} />
        {recon.loading && !r ? (
          <Skeleton rows={2} />
        ) : r ? (
          <>
            <div className="grid-stats">
              <div className="card" style={{ background: 'var(--muted-surface)', border: 0 }}>
                <span className="small muted">Purchased Diamonds held</span>
                <strong style={{ fontSize: 26 }}>{formatNumber(r.customer_diamond_liability)}</strong>
                <span className="small muted">owed to customers (real money)</span>
              </div>
              <div className="card" style={{ background: 'var(--muted-surface)', border: 0 }}>
                <span className="small muted">Promotional Diamonds held</span>
                <strong style={{ fontSize: 26 }}>{formatNumber(r.promotional_diamond_liability ?? 0)}</strong>
                <span className="small muted">free grants, expire after 30 days</span>
              </div>
              <div className="card" style={{ background: 'var(--muted-surface)', border: 0 }}>
                <span className="small muted">Host Beans owed</span>
                <strong style={{ fontSize: 26 }}>{formatNumber(r.host_bean_liability)}</strong>
                <span className="small muted">≈ {formatRupeesFromPaise(r.host_bean_liability_paise ?? 0)}</span>
              </div>
            </div>
            <span className="small muted">As of {formatDateTime(r.as_of)}</span>
          </>
        ) : null}
      </section>

      <section className="card">
        <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
          <h2>Ledger adjustments</h2>
          <button type="button" className="btn btn-outline" onClick={() => setShowForm((v) => !v)} aria-expanded={showForm}>
            {showForm ? 'Close' : 'Propose adjustment'}
          </button>
        </div>
        <p className="small" style={{ margin: 0, color: 'var(--text-2)', lineHeight: 1.5 }}>
          For corrections and test grants. The person who proposes can't approve, and nobody can adjust their own account.
        </p>
        {showForm && (
          <form onSubmit={propose} className="card" style={{ background: 'var(--muted-surface)', border: 0 }} noValidate>
            <div className="field">
              <label htmlFor="adj-user">User id</label>
              <input id="adj-user" value={userId} onChange={(e) => setUserId(e.target.value)} placeholder="e.g. 819f3b87-…" autoComplete="off" />
            </div>
            <div className="field">
              <label htmlFor="adj-bucket">Wallet</label>
              <select id="adj-bucket" value={bucket} onChange={(e) => setBucket(e.target.value)}>
                {BUCKETS.map((b) => (
                  <option key={b.kind} value={b.kind}>
                    {b.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="field">
              <label htmlFor="adj-amount">Amount (negative to remove)</label>
              <input id="adj-amount" inputMode="numeric" value={amount} onChange={(e) => setAmount(e.target.value)} />
            </div>
            <div className="field">
              <label htmlFor="adj-reason">Reason</label>
              <textarea id="adj-reason" rows={2} maxLength={2000} value={reason} onChange={(e) => setReason(e.target.value)} />
            </div>
            <button type="submit" className="btn btn-primary" style={{ alignSelf: 'flex-start' }} disabled={busy === 'propose'}>
              {busy === 'propose' ? 'Saving…' : 'Propose'}
            </button>
          </form>
        )}
        <ErrorBanner error={adjustments.error} onRetry={adjustments.reload} />
        {adjustments.loading && !adjustments.data ? (
          <Skeleton rows={3} />
        ) : adjustments.data?.items.length === 0 ? (
          <p className="muted" style={{ margin: 0 }}>
            No adjustments yet.
          </p>
        ) : (
          adjustments.data?.items
            .slice()
            .reverse()
            .map((j) => (
              <div key={j.proposal_id} style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 12, padding: 14, border: '1px solid var(--line-soft)', borderRadius: 14 }}>
                <span style={{ flex: 1, minWidth: 220, display: 'flex', flexDirection: 'column', gap: 2 }}>
                  <strong>
                    {j.amount > 0 ? '+' : '−'}
                    {formatNumber(Math.abs(j.amount))} {j.currency === 'DIAMOND' ? 'Diamonds' : 'Beans'} · {j.owner_display_name ?? 'Unknown user'}
                  </strong>
                  <span className="small muted">
                    {j.reason} · proposed by {j.proposed_by_me ? 'you' : j.proposed_by_name ?? 'staff'} · {formatDateTime(j.created_at)}
                  </span>
                </span>
                {j.status === 'awaiting_second_approval' ? (
                  j.proposed_by_me ? (
                    <Pill tone="warn">Waiting for a second approver</Pill>
                  ) : (
                    <div style={{ display: 'flex', gap: 8 }}>
                      <button type="button" className="btn btn-primary" disabled={busy === j.proposal_id} onClick={() => void decide(j.proposal_id, true)}>
                        Approve
                      </button>
                      <button type="button" className="btn btn-danger-outline" disabled={busy === j.proposal_id} onClick={() => void decide(j.proposal_id, false)}>
                        Reject
                      </button>
                    </div>
                  )
                ) : (
                  <Pill tone={j.status === 'posted' ? 'ok' : 'neutral'}>{j.status === 'posted' ? 'Posted' : 'Rejected'}</Pill>
                )}
              </div>
            ))
        )}
      </section>

      <section className="card">
        <h2>Host payouts</h2>
        <Banner tone="info">
          Payouts are switched off until a payout provider accepts Dashuri. Withdrawal requests are recorded; payout cycles will appear here for a finance approver
          once payouts are on.
        </Banner>
      </section>
    </>
  );
}
