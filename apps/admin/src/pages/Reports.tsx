import { useEffect, useState } from 'react';
import { useAuth } from '../auth/AuthContext';
import { useCounts } from '../components/Layout';
import { Banner, ErrorBanner, PageHead, Pill, Skeleton } from '../components/ui';
import { describeError } from '../lib/api';
import { categoryLabels, formatDateTime, timeAgo } from '../lib/format';
import type { ModerationAction } from '../lib/types';
import { useLoad } from '../lib/useLoad';

const ACTIONS: { id: ModerationAction; label: string; danger?: boolean; effect: string }[] = [
  { id: 'dismiss', label: 'Dismiss', effect: 'Closes the report with no action.' },
  { id: 'warn', label: 'Warn', effect: 'Sends a warning. Repeated warnings count towards a suspension.' },
  { id: 'restrict_calls', label: 'Restrict calls', effect: 'Blocks new calls for this account. Chat and wallet still work.' },
  { id: 'suspend', label: 'Suspend', danger: true, effect: 'Ends any live call now and blocks the account. They can appeal.' },
  { id: 'ban', label: 'Ban', danger: true, effect: 'Ends any live call and closes the account. They can appeal.' },
  { id: 'escalate_legal', label: 'Escalate (legal)', danger: true, effect: 'Suspends and flags for legal follow-up (for example a minor at risk). Evidence is kept.' },
];

const SEVERE = new Set(['nudity', 'sexual_content', 'minor_safety']);

type Tab = 'reports' | 'appeals';

export function Reports() {
  const { api } = useAuth();
  const { refresh: refreshCounts } = useCounts();
  const [tab, setTab] = useState<Tab>('reports');
  const reports = useLoad(async () => {
    const page = await api.moderationQueue();
    const names = await api.userNames([...new Set(page.items.map((r) => r.target_user_id).filter(Boolean))]);
    const byId = Object.fromEntries(names.items.map((n) => [n.user_id, n.display_name]));
    return page.items.map((r) => ({ ...r, targetName: byId[r.target_user_id] ?? 'Unknown user' }));
  }, [api]);
  const appeals = useLoad(() => api.appeals('open'), [api]);
  const [sel, setSel] = useState<string | null>(null);
  const [act, setAct] = useState<string | null>(null);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [gone, setGone] = useState<Record<string, boolean>>({});

  const reportItems = (reports.data ?? []).filter((r) => !gone[r.report_id]);
  const appealItems = (appeals.data?.items ?? []).filter((a) => !gone[a.appeal_id]);
  const ids = tab === 'reports' ? reportItems.map((r) => r.report_id) : appealItems.map((a) => a.appeal_id);

  useEffect(() => {
    if (!sel || !ids.includes(sel)) setSel(ids[0] ?? null);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, ids.join(',')]);

  const report = tab === 'reports' ? reportItems.find((r) => r.report_id === sel) : undefined;
  const appeal = tab === 'appeals' ? appealItems.find((a) => a.appeal_id === sel) : undefined;

  const choose = (t: Tab) => {
    setTab(t);
    setAct(null);
    setReason('');
    setMsg(null);
  };

  const confirm = async () => {
    if (!act || !sel) return;
    if (!reason.trim()) {
      setMsg({ ok: false, text: 'Please write a reason first.' });
      return;
    }
    setBusy(true);
    setMsg(null);
    try {
      if (tab === 'reports') await api.decideReport(sel, act as ModerationAction, reason.trim());
      else await api.decideAppeal(sel, act as 'upheld' | 'overturned', reason.trim());
      setGone((g) => ({ ...g, [sel]: true }));
      setMsg({ ok: true, text: 'Decision recorded.' });
      setAct(null);
      setReason('');
      refreshCounts();
    } catch (e) {
      setMsg({ ok: false, text: describeError(e) });
    } finally {
      setBusy(false);
    }
  };

  const decisionButtons =
    tab === 'reports'
      ? ACTIONS
      : [
          { id: 'upheld', label: 'Keep decision', effect: 'Keeps the original decision. The user is told the appeal was reviewed.' },
          { id: 'overturned', label: 'Overturn', effect: 'Reverses the original decision and restores the account.' },
        ];
  const effect = decisionButtons.find((b) => b.id === act)?.effect;
  const current = tab === 'reports' ? reports : appeals;

  return (
    <>
      <PageHead title="Reports & appeals" lede="Highest severity first. Automated nudity flags from the first 3 minutes of calls appear with reports." />
      <div className="tabs" role="tablist" aria-label="Queue">
        <button type="button" role="tab" className="tab" aria-selected={tab === 'reports'} onClick={() => choose('reports')}>
          Reports &amp; flags ({reportItems.length})
        </button>
        <button type="button" role="tab" className="tab" aria-selected={tab === 'appeals'} onClick={() => choose('appeals')}>
          Appeals ({appealItems.length})
        </button>
      </div>
      <ErrorBanner error={current.error} onRetry={current.reload} />
      {msg && <Banner tone={msg.ok ? 'ok' : 'error'}>{msg.text}</Banner>}
      {current.loading && !current.data ? (
        <Skeleton rows={4} />
      ) : (
        <div className="row">
          <ul className="col-2" style={{ listStyle: 'none', margin: 0, padding: 0, gap: 10 }}>
            {ids.length === 0 && <li className="card empty">Queue is empty.</li>}
            {tab === 'reports'
              ? reportItems.map((r) => (
                  <li key={r.report_id}>
                    <button type="button" className="case" aria-pressed={sel === r.report_id} onClick={() => { setSel(r.report_id); setAct(null); }}>
                      <span className="case-top">
                        <Pill tone={SEVERE.has(r.category) ? 'high' : 'warn'}>{SEVERE.has(r.category) ? 'High' : 'Normal'}</Pill>
                        <span className="small muted">{timeAgo(r.created_at)}</span>
                      </span>
                      <strong>{categoryLabels[r.category] ?? r.category}</strong>
                      <span className="small" style={{ color: 'var(--text-2)' }}>About {r.targetName}</span>
                    </button>
                  </li>
                ))
              : appealItems.map((a) => (
                  <li key={a.appeal_id}>
                    <button type="button" className="case" aria-pressed={sel === a.appeal_id} onClick={() => { setSel(a.appeal_id); setAct(null); }}>
                      <span className="case-top">
                        <Pill tone="warn">Appeal</Pill>
                        <span className="small muted">{timeAgo(a.created_at)}</span>
                      </span>
                      <strong>Against: {a.enforcement.action.replace(/_/g, ' ')}</strong>
                      <span className="small" style={{ color: 'var(--text-2)' }}>From {a.display_name ?? 'Unknown user'}</span>
                    </button>
                  </li>
                ))}
          </ul>
          <section className="card col-3">
            {report || appeal ? (
              <>
                <div>
                  <h2 style={{ fontSize: 22 }}>{report ? categoryLabels[report.category] ?? report.category : `Appeal from ${appeal?.display_name ?? 'user'}`}</h2>
                  <span className="small muted">{formatDateTime(report?.created_at ?? appeal?.created_at)}</span>
                </div>
                <dl className="dl">
                  {report && (
                    <>
                      <dt>About</dt>
                      <dd>{report.targetName}</dd>
                      <dt>Evidence</dt>
                      <dd>{report.evidence_count ? `${report.evidence_count} item(s) on file` : 'None attached'}</dd>
                      <dt>Reporter said</dt>
                      <dd style={{ lineHeight: 1.5 }}>{report.details || '—'}</dd>
                    </>
                  )}
                  {appeal && (
                    <>
                      <dt>Original action</dt>
                      <dd>
                        {appeal.enforcement.action.replace(/_/g, ' ')} · {formatDateTime(appeal.enforcement.created_at)}
                      </dd>
                      <dt>Original reason</dt>
                      <dd>{appeal.enforcement.reason}</dd>
                      <dt>Their appeal</dt>
                      <dd style={{ lineHeight: 1.5 }}>"{appeal.statement}"</dd>
                    </>
                  )}
                </dl>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  <strong className="small">Decision</strong>
                  <div className="choices" role="group" aria-label="Decision">
                    {decisionButtons.map((b) => (
                      <button key={b.id} type="button" className={`choice${'danger' in b && b.danger ? ' danger' : ''}`} aria-pressed={act === b.id} onClick={() => setAct(b.id)}>
                        {b.label}
                      </button>
                    ))}
                  </div>
                  {act && (
                    <div className="field">
                      <label htmlFor="why">Reason (required, saved to the audit log)</label>
                      <textarea id="why" rows={3} maxLength={2000} value={reason} onChange={(e) => setReason(e.target.value)} />
                      {effect && <span className="small" style={{ color: 'var(--text-2)' }}>{effect}</span>}
                      <button type="button" className="btn btn-primary" style={{ alignSelf: 'flex-start' }} disabled={busy} onClick={() => void confirm()}>
                        {busy ? 'Saving…' : 'Confirm decision'}
                      </button>
                    </div>
                  )}
                </div>
              </>
            ) : (
              <p className="empty">Pick an item from the queue.</p>
            )}
          </section>
        </div>
      )}
    </>
  );
}
