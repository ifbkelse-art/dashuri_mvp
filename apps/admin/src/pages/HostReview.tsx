import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { useCounts } from '../components/Layout';
import { Avatar, Banner, ErrorBanner, Pill, Skeleton, verificationTone } from '../components/ui';
import { describeError } from '../lib/api';
import { evidenceLabels, formatDateTime, formatNumber, humanizeAction, priceLimit, reasonRequired, verificationActions, verificationLabels } from '../lib/format';
import type { EvidenceAccess, VerificationAction } from '../lib/types';
import { useLoad } from '../lib/useLoad';

const ACTION_COPY: Record<VerificationAction, { label: string; kind: 'primary' | 'danger' | 'plain'; reason: string; hint: string; done: string }> = {
  start_review: { label: 'Start review', kind: 'plain', reason: 'Note (optional)', hint: 'Anything for other reviewers', done: 'Marked under review. Other staff see that it is being handled.' },
  request_info: { label: 'Request info', kind: 'plain', reason: 'What should the host send again? (shown to the host)', hint: 'e.g. The face video is too dark. Please record again in good light.', done: 'Request sent. The host sees your message in the app and can resubmit.' },
  approve: { label: 'Approve', kind: 'primary', reason: 'Reason (recorded)', hint: 'e.g. Face video matches the ID and photos', done: 'Approved. The Verified Host badge is live and the host can raise their rate up to their level limit.' },
  reject: { label: 'Reject', kind: 'danger', reason: 'Reason shown to the host (required)', hint: 'e.g. Face not visible in the video', done: 'Rejected. The host has been told why and can apply again.' },
  suspend: { label: 'Suspend', kind: 'danger', reason: 'Why suspend? (required)', hint: 'e.g. Under investigation for a report', done: 'Suspended. The rate was capped at 3,000/min (or the level limit) and the host was notified.' },
  reinstate: { label: 'Reinstate', kind: 'plain', reason: 'Why reinstate? (required)', hint: 'e.g. Investigation closed, no violation', done: 'Reinstated. The badge is back; the host can raise their rate again.' },
  revoke: { label: 'Revoke', kind: 'danger', reason: 'Why revoke? (required)', hint: 'e.g. The evidence belongs to someone else', done: 'Verification revoked. Badge removed, rate capped, host notified.' },
};

export function HostReview() {
  const { hostId = '' } = useParams();
  const { api, staff } = useAuth();
  const { refresh: refreshCounts } = useCounts();
  const detail = useLoad(() => api.verification(hostId), [api, hostId]);
  const profile = useLoad(() => api.profile(hostId).catch(() => null), [api, hostId]);
  const names = useLoad(async () => {
    const ids = new Set<string>();
    for (const h of detail.data?.history ?? []) if (/^[0-9a-f-]{36}$/i.test(h.actor)) ids.add(h.actor);
    const r = await api.userNames([...ids]);
    return Object.fromEntries(r.items.map((n) => [n.user_id, n.display_name]));
  }, [api, detail.data]);

  const [pick, setPick] = useState<VerificationAction | null>(null);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; text: string } | null>(null);
  const [links, setLinks] = useState<Record<string, EvidenceAccess>>({});
  const [linkError, setLinkError] = useState<string | null>(null);

  const d = detail.data;
  const name = profile.data?.display_name ?? 'Host';
  const self = staff?.user_id === hostId;
  const actions = d ? verificationActions[d.status] ?? [] : [];
  const verified = d?.status === 'verified';
  const copy = pick ? ACTION_COPY[pick] : null;
  const needsReason = pick ? reasonRequired.has(pick) || pick === 'request_info' : false;

  const confirm = async () => {
    if (!pick || !copy) return;
    if (needsReason && !reason.trim()) {
      setResult({ ok: false, text: 'Please write a reason first.' });
      return;
    }
    setBusy(true);
    setResult(null);
    try {
      const text = reason.trim();
      await api.verificationAction(hostId, pick, text, pick === 'request_info' ? text : undefined);
      setResult({ ok: true, text: copy.done });
      setPick(null);
      setReason('');
      await detail.reload();
      refreshCounts();
    } catch (e) {
      setResult({ ok: false, text: describeError(e) });
    } finally {
      setBusy(false);
    }
  };

  const openEvidence = async (id: string) => {
    setLinkError(null);
    try {
      const a = await api.evidenceAccess(hostId, id);
      setLinks((l) => ({ ...l, [id]: a }));
      window.open(a.url, '_blank', 'noopener,noreferrer');
    } catch (e) {
      setLinkError(describeError(e));
    }
  };

  return (
    <>
      <Link to="/hosts" className="small" style={{ fontWeight: 600, textDecoration: 'none', alignSelf: 'flex-start', minHeight: 44, display: 'inline-flex', alignItems: 'center' }}>
        ← All applications
      </Link>
      <ErrorBanner error={detail.error} onRetry={detail.reload} />
      {detail.loading && !d ? (
        <Skeleton rows={6} />
      ) : d ? (
        <>
          <header style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 16 }}>
            <Avatar name={name} large />
            <div style={{ flex: 1, minWidth: 220 }}>
              <h1 className="serif" style={{ fontSize: 40, lineHeight: 1.05 }}>
                {name}
              </h1>
              <span className="muted small">
                Verified Host application{d.application ? ` · submitted ${formatDateTime(d.application.submitted_at)}` : ''}
              </span>
            </div>
            <Pill tone={verificationTone(d.status)}>{verificationLabels[d.status] ?? d.status}</Pill>
          </header>
          {result && <Banner tone={result.ok ? 'ok' : 'error'}>{result.text}</Banner>}
          {self && <Banner tone="warn">This is your own account. You can't review it; another staff member must.</Banner>}
          <div className="row">
            <div className="col-3">
              <section className="card">
                <h2>Public profile</h2>
                {profile.data?.photo_urls.length ? (
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 10 }}>
                    {profile.data.photo_urls.map((u, i) => (
                      <img key={u} src={u} alt={`${name}, public photo ${i + 1}`} style={{ width: '100%', aspectRatio: '3 / 4', objectFit: 'cover', borderRadius: 12 }} />
                    ))}
                  </div>
                ) : (
                  <p className="muted" style={{ margin: 0 }}>
                    No approved public photos yet.
                  </p>
                )}
                <dl className="dl">
                  <dt>Bio</dt>
                  <dd>{profile.data?.bio || '—'}</dd>
                  <dt>Languages</dt>
                  <dd>{profile.data?.languages.join(' · ') || '—'}</dd>
                </dl>
              </section>
              <section className="card">
                <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'space-between', gap: 8, alignItems: 'center' }}>
                  <h2>Private evidence</h2>
                  <Pill tone="neutral">Staff only · every view is logged</Pill>
                </div>
                <p className="small" style={{ margin: 0, color: 'var(--text-2)', lineHeight: 1.5 }}>
                  Never shown to customers. Each Open creates a link that works for 5 minutes and is written to the audit log. Evidence is deleted after the
                  decision under the retention policy.
                </p>
                {linkError && <Banner tone="error">{linkError}</Banner>}
                {d.evidence.length === 0 ? (
                  <p className="muted" style={{ margin: 0 }}>
                    No evidence on file.
                  </p>
                ) : (
                  d.evidence.map((e) => (
                    <div key={e.id} style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 12, padding: 14, border: '1px solid var(--line-soft)', borderRadius: 14 }}>
                      <span style={{ flex: 1, minWidth: 180, display: 'flex', flexDirection: 'column', gap: 2 }}>
                        <strong>{evidenceLabels[e.kind] ?? e.kind}</strong>
                        <span className="small muted">{e.uploaded_at ? `Uploaded ${formatDateTime(e.uploaded_at)}` : 'Not uploaded'}</span>
                      </span>
                      {links[e.id] ? (
                        <a className="small" href={links[e.id].url} target="_blank" rel="noopener noreferrer" style={{ fontWeight: 700 }}>
                          Open again (expires {formatDateTime(links[e.id].expires_at)})
                        </a>
                      ) : (
                        <button type="button" className="btn btn-outline" disabled={!e.uploaded_at || self} onClick={() => void openEvidence(e.id)}>
                          Open (5-min link)
                        </button>
                      )}
                    </div>
                  ))
                )}
              </section>
              <section className="card">
                <h2>History</h2>
                {d.history.length === 0 ? (
                  <p className="muted" style={{ margin: 0 }}>
                    No history yet.
                  </p>
                ) : (
                  <ol className="list">
                    {d.history.map((h, i) => (
                      <li key={i} style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                        <span>
                          <strong>{names.data?.[h.actor] ?? (h.actor === hostId ? name : h.actor.startsWith('system') ? 'System' : 'Staff')}</strong> ·{' '}
                          {humanizeAction(h.action)}
                          {typeof h.details.reason === 'string' && h.details.reason ? ` · "${h.details.reason}"` : ''}
                        </span>
                        <span className="muted">{formatDateTime(h.at)}</span>
                      </li>
                    ))}
                  </ol>
                )}
              </section>
            </div>
            <div className="col-2">
              <section className="card">
                <h2>Pricing</h2>
                <dl className="dl" style={{ gridTemplateColumns: '1fr max-content' }}>
                  <dt>Level</dt>
                  <dd>
                    <strong>{d.level}</strong>
                  </dd>
                  <dt>Current rate</dt>
                  <dd>
                    <strong>{formatNumber(d.rate_per_minute)} / min</strong>
                  </dd>
                  <dt>Limit {verified ? 'now (verified)' : 'now (not verified)'}</dt>
                  <dd>
                    <strong>{formatNumber(priceLimit(d.level, verified))} / min</strong>
                  </dd>
                  {!verified && (
                    <>
                      <dt>Limit if approved</dt>
                      <dd>
                        <strong>{formatNumber(priceLimit(d.level, true))} / min</strong>
                      </dd>
                    </>
                  )}
                </dl>
                <p className="small" style={{ margin: 0, color: 'var(--text-2)', lineHeight: 1.5 }}>
                  Approving keeps the current rate; the host raises it themselves. Suspending or revoking caps the rate at once. Calls already in progress keep
                  their price.
                </p>
              </section>
              <section className="card">
                <h2>Decision</h2>
                {d.application?.info_request && d.status === 'info_required' && (
                  <Banner tone="info">Waiting for the host. You asked: "{d.application.info_request}"</Banner>
                )}
                {actions.length === 0 || self ? (
                  <p className="muted" style={{ margin: 0 }}>
                    {self ? "You can't act on your own account." : 'No decision is available in this status.'}
                  </p>
                ) : (
                  <>
                    <div className="choices" role="group" aria-label="Decision">
                      {actions.map((a) => (
                        <button
                          key={a}
                          type="button"
                          className={`choice ${ACTION_COPY[a].kind === 'primary' ? 'primary' : ACTION_COPY[a].kind === 'danger' ? 'danger' : ''}`}
                          aria-pressed={pick === a}
                          onClick={() => {
                            setPick(a);
                            setResult(null);
                          }}
                        >
                          {ACTION_COPY[a].label}
                        </button>
                      ))}
                    </div>
                    {d.status === 'submitted' && (
                      <p className="small muted" style={{ margin: 0 }}>
                        Start the review first to be able to approve.
                      </p>
                    )}
                    {copy && (
                      <div className="field">
                        <label htmlFor="reason">{copy.reason}</label>
                        <textarea id="reason" rows={3} maxLength={1000} placeholder={copy.hint} value={reason} onChange={(e) => setReason(e.target.value)} />
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
                          <button type="button" className={`btn ${copy.kind === 'danger' ? 'btn-danger' : 'btn-primary'}`} disabled={busy} onClick={() => void confirm()}>
                            {busy ? 'Saving…' : `Confirm: ${copy.label}`}
                          </button>
                          <button type="button" className="btn btn-ghost" disabled={busy} onClick={() => setPick(null)}>
                            Cancel
                          </button>
                        </div>
                        <span className="small muted">Recorded in the audit log with your name, the time and this reason.</span>
                      </div>
                    )}
                  </>
                )}
              </section>
            </div>
          </div>
        </>
      ) : null}
    </>
  );
}
