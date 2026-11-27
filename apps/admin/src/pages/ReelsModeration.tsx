import { useState } from 'react';
import { useAuth } from '../auth/AuthContext';
import { Banner, ErrorBanner, PageHead, Pill, Skeleton } from '../components/ui';
import { describeError } from '../lib/api';
import { formatDateTime } from '../lib/format';
import type { ReelDecision, ReelQueueItem } from '../lib/types';
import { useLoad } from '../lib/useLoad';

/** Reason codes the app explains to creators in plain language. */
export const REEL_REASONS: { code: string; label: string }[] = [
  { code: 'sexual_content', label: 'Nudity or sexual content' },
  { code: 'graphic_or_offensive', label: 'Graphic or offensive' },
  { code: 'minor_safety', label: 'May show someone under 18' },
  { code: 'privacy', label: "Shares someone's private information" },
  { code: 'copyright', label: 'Copyright (takedown)' },
];

const SOURCE: Record<string, string> = {
  automated: 'Automated check',
  report: 'Reported',
  appeal: 'Appeal',
};

/**
 * Reels moderation queue (EXPERIMENT, empty while Reels is off). Nothing is
 * published without a decision: uncertain automated checks, first reels,
 * reports and appeals all land here. Video links are short-lived (15 min).
 * The server refuses decisions on your own reel (self_review).
 */
export function ReelsModeration() {
  const { api } = useAuth();
  const queue = useLoad(() => api.reelsQueue(), [api]);
  const [gone, setGone] = useState<Record<string, boolean>>({});
  const [busy, setBusy] = useState<string | null>(null);
  const [reason, setReason] = useState(REEL_REASONS[0].code);
  const [note, setNote] = useState('');
  const [error, setError] = useState<string | null>(null);

  const decide = async (item: ReelQueueItem, decision: ReelDecision) => {
    setBusy(item.reel.id);
    setError(null);
    try {
      const keep = decision === 'approve' || decision === 'restore';
      await api.decideReel(item.reel.id, decision, keep ? 'meets_guidelines' : reason, note.trim() || undefined);
      setGone((g) => ({ ...g, [item.case_id]: true }));
      setNote('');
    } catch (e) {
      setError(describeError(e));
    } finally {
      setBusy(null);
    }
  };

  const left = (queue.data?.items ?? []).filter((i) => !gone[i.case_id]);
  return (
    <>
      <PageHead title="Reels moderation" lede="Nothing goes live without a decision. Video links expire after 15 minutes; reload the queue if one stops playing." />
      <ErrorBanner error={queue.error} onRetry={queue.reload} />
      {error && <Banner tone="error">{error}</Banner>}
      {queue.loading && !queue.data ? (
        <Skeleton rows={4} />
      ) : left.length === 0 ? (
        <section className="card" style={{ alignItems: 'center', textAlign: 'center' }}>
          <span className="serif" style={{ fontSize: 26 }}>All caught up</span>
          <span className="small muted">Reels is switched off on this server until R2 is configured; the queue stays empty until then.</span>
          <button type="button" className="btn btn-ghost" onClick={() => void queue.reload()}>Check again</button>
        </section>
      ) : (
        <>
          <div className="two" style={{ maxWidth: 760 }}>
            <div className="field">
              <label htmlFor="reel-reason">Reason for reject / remove</label>
              <select id="reel-reason" value={reason} onChange={(e) => setReason(e.target.value)}>
                {REEL_REASONS.map((r) => <option key={r.code} value={r.code}>{r.label}</option>)}
              </select>
            </div>
            <div className="field">
              <label htmlFor="reel-note">Note (optional, staff only)</label>
              <input id="reel-note" maxLength={2000} value={note} onChange={(e) => setNote(e.target.value)} />
            </div>
          </div>
          <div className="photo-grid">
            {left.map((i) => {
              const live = i.reel.status === 'published';
              const removed = i.reel.status === 'removed' || i.reel.status === 'rejected';
              return (
                <article key={i.case_id} className="photo">
                  <div className="photo-img">
                    {i.reel.playback ? (
                      <video src={i.reel.playback.url} poster={i.reel.playback.thumbnail_url} controls muted playsInline preload="none" aria-label={`Reel by ${i.reel.creator.display_name}`} />
                    ) : (
                      <span>Video not available</span>
                    )}
                  </div>
                  <div className="photo-body">
                    <strong>{i.reel.creator.display_name || 'Creator'}</strong>
                    <span className="small muted">
                      {SOURCE[i.source] ?? i.source} · {formatDateTime(i.created_at)}
                      {i.report_count > 0 ? ` · ${i.report_count} report${i.report_count === 1 ? '' : 's'}` : ''}
                    </span>
                    <Pill tone={live ? 'ok' : removed ? 'danger' : 'warn'}>{i.reel.status.replace(/_/g, ' ')}</Pill>
                    {i.reel.caption && <span className="small">“{i.reel.caption}”</span>}
                    {i.appeal_statement && <span className="small">Appeal: {i.appeal_statement}</span>}
                    {i.scores && Object.keys(i.scores).length > 0 && (
                      <span className="small muted">
                        {Object.entries(i.scores).map(([k, v]) => `${k.replace(/_/g, ' ')} ${v.toFixed(2)}`).join(' · ')}
                      </span>
                    )}
                    <div className="two">
                      {removed ? (
                        <button type="button" className="btn btn-primary" disabled={busy === i.reel.id} onClick={() => void decide(i, 'restore')}>Restore</button>
                      ) : (
                        <button type="button" className="btn btn-primary" disabled={busy === i.reel.id || live} onClick={() => void decide(i, 'approve')}>Approve</button>
                      )}
                      <button type="button" className="btn btn-danger-outline" disabled={busy === i.reel.id || removed} onClick={() => void decide(i, live ? 'remove' : 'reject')}>
                        {live ? 'Remove' : 'Reject'}
                      </button>
                    </div>
                  </div>
                </article>
              );
            })}
          </div>
          {queue.data?.next_cursor && <span className="small muted">More cases are waiting; decide these first, then check again.</span>}
        </>
      )}
    </>
  );
}
