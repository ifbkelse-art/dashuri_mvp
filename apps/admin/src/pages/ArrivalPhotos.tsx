import { useState } from 'react';
import { useAuth } from '../auth/AuthContext';
import { Banner, ErrorBanner, PageHead, Skeleton } from '../components/ui';
import { describeError } from '../lib/api';
import { formatDateTime } from '../lib/format';
import { useLoad } from '../lib/useLoad';

const REASONS = ['Nudity or sexual content', 'Not a real photo of the host', 'Contact details in the image', 'Minor in the photo', 'Other policy issue'];

/**
 * Arrival photos waiting for review (2026-11-26): optional selfies hosts
 * take when they go online. Approved photos show to customers only while
 * that online session lasts. Opening this queue is logged.
 */
export function ArrivalPhotos() {
  const { api } = useAuth();
  const queue = useLoad(() => api.arrivalQueue(), [api]);
  const [gone, setGone] = useState<Record<string, boolean>>({});
  const [busy, setBusy] = useState<string | null>(null);
  const [why, setWhy] = useState(REASONS[0]);
  const [error, setError] = useState<string | null>(null);

  const decide = async (id: string, decision: 'approve' | 'reject' | 'remove') => {
    setBusy(id);
    setError(null);
    try {
      await api.decideArrival(id, decision, decision === 'approve' ? undefined : why);
      setGone((g) => ({ ...g, [id]: true }));
    } catch (e) {
      setError(describeError(e));
    } finally {
      setBusy(null);
    }
  };
  const left = (queue.data?.items ?? []).filter((p) => !gone[p.photo_id]);
  return (
    <>
      <PageHead title="Arrival photos" lede="Recent selfies hosts took when going online. Not identity checks — approve only what follows the rules." />
      <ErrorBanner error={queue.error} onRetry={queue.reload} />
      {error && <Banner tone="error">{error}</Banner>}
      {queue.loading && !queue.data ? (
        <Skeleton rows={4} />
      ) : left.length === 0 ? (
        <section className="card" style={{ alignItems: 'center', textAlign: 'center' }}>
          <span className="serif" style={{ fontSize: 26 }}>All caught up</span>
          <button type="button" className="btn btn-ghost" onClick={() => void queue.reload()}>Check again</button>
        </section>
      ) : (
        <>
          <div className="field" style={{ maxWidth: 420 }}>
            <label htmlFor="arrival-why">Reason for reject / remove</label>
            <select id="arrival-why" value={why} onChange={(e) => setWhy(e.target.value)}>
              {REASONS.map((r) => <option key={r}>{r}</option>)}
            </select>
          </div>
          <div className="photo-grid">
            {left.map((p) => (
              <article key={p.photo_id} className="photo">
                <div className="photo-img">{p.photo_url ? <img src={p.photo_url} alt={`Arrival photo from ${p.host_name}`} /> : <span>Not available</span>}</div>
                <div className="photo-body">
                  <strong>{p.host_name || 'Host'}</strong>
                  <span className="small muted">
                    {formatDateTime(p.captured_at)} · {p.session_open ? 'still online' : 'session ended'}
                  </span>
                  <div className="two">
                    <button type="button" className="btn btn-primary" disabled={busy === p.photo_id || !p.session_open} onClick={() => void decide(p.photo_id, 'approve')}>Approve</button>
                    <button type="button" className="btn btn-danger-outline" disabled={busy === p.photo_id} onClick={() => void decide(p.photo_id, 'reject')}>Reject</button>
                  </div>
                </div>
              </article>
            ))}
          </div>
        </>
      )}
    </>
  );
}
