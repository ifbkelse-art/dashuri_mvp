import { useEffect, useState } from 'react';
import { useAuth } from '../auth/AuthContext';
import { useCounts } from '../components/Layout';
import { Banner, ErrorBanner, PageHead, Skeleton } from '../components/ui';
import { describeError } from '../lib/api';
import { formatDateTime } from '../lib/format';
import { useLoad } from '../lib/useLoad';

const REASONS = ['Face not clearly visible', 'Contact details in the image', 'Nudity or sexual content', 'Not the account owner', 'Low quality'];

export function Photos() {
  const { api } = useAuth();
  const { setPhotos } = useCounts();
  const photos = useLoad(async () => {
    const page = await api.pendingPhotos();
    const names = await api.userNames([...new Set(page.items.map((p) => p.user_id))]);
    const byId = Object.fromEntries(names.items.map((n) => [n.user_id, n.display_name]));
    return page.items.map((p) => ({ ...p, name: byId[p.user_id] ?? 'Unknown user' }));
  }, [api]);
  const [gone, setGone] = useState<Record<string, boolean>>({});
  const [choosing, setChoosing] = useState<string | null>(null);
  const [why, setWhy] = useState(REASONS[0]);
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const decide = async (id: string, decision: 'approve' | 'reject') => {
    setBusy(id);
    setError(null);
    try {
      await api.decidePhoto(id, decision, decision === 'reject' ? why : undefined);
      setGone((g) => ({ ...g, [id]: true }));
      setChoosing(null);
    } catch (e) {
      setError(describeError(e));
    } finally {
      setBusy(null);
    }
  };

  const left = (photos.data ?? []).filter((p) => !gone[p.photo_id]);
  useEffect(() => {
    if (photos.data) setPhotos(left.length);
  }, [photos.data, left.length, setPhotos]);

  return (
    <>
      <PageHead
        title="Photo review"
        lede="New profile photos stay hidden from customers until approved. Oldest first."
        aside={photos.data && <span className="small" style={{ fontWeight: 600, color: 'var(--text-2)' }}>{left.length} waiting</span>}
      />
      <ErrorBanner error={photos.error} onRetry={photos.reload} />
      {error && <Banner tone="error">{error}</Banner>}
      {photos.loading && !photos.data ? (
        <Skeleton rows={4} />
      ) : photos.data && left.length === 0 ? (
        <section className="card" style={{ alignItems: 'center', textAlign: 'center', padding: '48px 24px' }}>
          <span className="serif" style={{ fontSize: 30 }}>
            All caught up
          </span>
          <span className="muted">No photos waiting. New ones appear here automatically.</span>
          <button type="button" className="btn btn-ghost" onClick={() => void photos.reload()}>
            Check again
          </button>
        </section>
      ) : (
        <div className="photo-grid">
          {left.map((p) => (
            <article key={p.photo_id} className="photo">
              <div className="photo-img">{p.read_url ? <img src={p.read_url} alt={`Pending photo from ${p.name}`} /> : <span>Upload not finished</span>}</div>
              <div className="photo-body">
                <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                  <strong>{p.name}</strong>
                  <span className="small muted">{formatDateTime(p.created_at)}</span>
                </div>
                {choosing === p.photo_id ? (
                  <div className="field">
                    <label htmlFor={`why-${p.photo_id}`} style={{ fontSize: 13 }}>
                      Reason shown to the user
                    </label>
                    <select id={`why-${p.photo_id}`} value={why} onChange={(e) => setWhy(e.target.value)}>
                      {REASONS.map((r) => (
                        <option key={r}>{r}</option>
                      ))}
                    </select>
                    <div className="two">
                      <button type="button" className="btn btn-danger" disabled={busy === p.photo_id} onClick={() => void decide(p.photo_id, 'reject')}>
                        Confirm reject
                      </button>
                      <button type="button" className="btn btn-ghost" onClick={() => setChoosing(null)}>
                        Cancel
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="two">
                    <button type="button" className="btn btn-primary" disabled={busy === p.photo_id || !p.read_url} onClick={() => void decide(p.photo_id, 'approve')}>
                      Approve
                    </button>
                    <button type="button" className="btn btn-danger-outline" disabled={busy === p.photo_id} onClick={() => setChoosing(p.photo_id)}>
                      Reject
                    </button>
                  </div>
                )}
              </div>
            </article>
          ))}
        </div>
      )}
      <p className="small muted" style={{ margin: 0 }}>
        Image previews use links that expire in minutes. Decisions are logged.
      </p>
    </>
  );
}
