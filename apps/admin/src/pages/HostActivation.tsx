import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { useCounts } from '../components/Layout';
import { Avatar, Banner, ErrorBanner, Pill, Skeleton } from '../components/ui';
import { describeError } from '../lib/api';
import { formatDateTime } from '../lib/format';
import { useLoad } from '../lib/useLoad';

/** Age on a date in whole years (the server re-checks 18+ authoritatively). */
export function ageOn(dob: string, today = new Date()): number {
  const [y, m, d] = dob.split('-').map(Number);
  if (!y || !m || !d) return NaN;
  let age = today.getFullYear() - y;
  if (today.getMonth() + 1 < m || (today.getMonth() + 1 === m && today.getDate() < d)) age--;
  return age;
}

export function HostActivation() {
  const { userId = '' } = useParams();
  const { api, staff } = useAuth();
  const { refresh: refreshCounts } = useCounts();
  const apps = useLoad(() => api.hostApplications(), [api]);
  const app = apps.data?.items.find((a) => a.user_id === userId);
  const profile = useLoad(() => api.profile(userId).catch(() => null), [api, userId]);

  const [pick, setPick] = useState<'approve' | 'reject' | null>(null);
  const [dob, setDob] = useState('');
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; text: string } | null>(null);
  const self = staff?.user_id === userId;

  useEffect(() => {
    if (app?.declared_date_of_birth && !dob) setDob(app.declared_date_of_birth);
  }, [app, dob]);

  const confirm = async () => {
    if (!pick) return;
    if (!reason.trim()) {
      setResult({ ok: false, text: 'Please write a reason first.' });
      return;
    }
    if (pick === 'approve') {
      const age = ageOn(dob);
      if (Number.isNaN(age)) {
        setResult({ ok: false, text: 'Enter the date of birth shown on the ID.' });
        return;
      }
      if (age < 18) {
        setResult({ ok: false, text: 'The ID shows the applicant is under 18. Hosts must be 18 or older; reject instead.' });
        return;
      }
    }
    setBusy(true);
    setResult(null);
    try {
      await api.kycDecision(userId, pick, reason.trim(), pick === 'approve' ? dob : undefined);
      setResult({
        ok: true,
        text: pick === 'approve' ? 'Approved. The host role is active and they can go online, up to 3,000 Diamonds/min within their level.' : 'Rejected. The applicant has been told.',
      });
      setPick(null);
      refreshCounts();
    } catch (e) {
      setResult({ ok: false, text: describeError(e) });
    } finally {
      setBusy(false);
    }
  };

  const decided = result?.ok;
  const name = app?.display_name ?? profile.data?.display_name ?? 'Applicant';

  return (
    <>
      <Link to="/hosts?tab=new" className="small" style={{ fontWeight: 600, textDecoration: 'none', alignSelf: 'flex-start', minHeight: 44, display: 'inline-flex', alignItems: 'center' }}>
        ← New host applications
      </Link>
      <ErrorBanner error={apps.error} onRetry={apps.reload} />
      {apps.loading && !apps.data ? (
        <Skeleton rows={5} />
      ) : !app && !decided ? (
        <Banner tone="info">This application is no longer waiting. It may already have been decided.</Banner>
      ) : (
        <>
          <header style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 16 }}>
            <Avatar name={name} large />
            <div style={{ flex: 1, minWidth: 220 }}>
              <h1 className="serif" style={{ fontSize: 40, lineHeight: 1.05 }}>
                {name}
              </h1>
              <span className="muted small">New host · applied {formatDateTime(app?.applied_at)}</span>
            </div>
            {app && <Pill tone={app.state === 'kyc_pending' ? 'brand' : 'neutral'}>{app.state === 'kyc_pending' ? 'Ready to decide' : 'Waiting for ID check'}</Pill>}
          </header>
          {result && <Banner tone={result.ok ? 'ok' : 'error'}>{result.text}</Banner>}
          {self && <Banner tone="warn">This is your own account. Another staff member must decide.</Banner>}
          {!decided && (
            <div className="row">
              <section className="card col-3">
                <h2>Applicant</h2>
                <dl className="dl">
                  <dt>City</dt>
                  <dd>{app?.city ?? '—'}</dd>
                  <dt>Date of birth (declared)</dt>
                  <dd>{app?.declared_date_of_birth ?? 'Not given'}</dd>
                  <dt>Bio</dt>
                  <dd>{profile.data?.bio || '—'}</dd>
                  <dt>Languages</dt>
                  <dd>{profile.data?.languages.join(' · ') || '—'}</dd>
                </dl>
                <p className="small" style={{ margin: 0, color: 'var(--text-2)', lineHeight: 1.5 }}>
                  Check the applicant's ID outside the console (no ID vendor is connected yet), then confirm the date of birth from the ID below. The server
                  refuses anyone under 18.
                </p>
              </section>
              <section className="card col-2">
                <h2>Decision</h2>
                {self ? (
                  <p className="muted" style={{ margin: 0 }}>
                    You can't decide your own application.
                  </p>
                ) : app?.state === 'applied' ? (
                  <Banner tone="info">
                    Waiting for the applicant to start the ID check in the app. You can approve or reject once they have.
                  </Banner>
                ) : (
                  <>
                    <div className="two" role="group" aria-label="Decision">
                      <button type="button" className="choice primary" aria-pressed={pick === 'approve'} onClick={() => setPick('approve')}>
                        Approve
                      </button>
                      <button type="button" className="choice danger" aria-pressed={pick === 'reject'} onClick={() => setPick('reject')}>
                        Reject
                      </button>
                    </div>
                    {pick === 'approve' && (
                      <div className="field">
                        <label htmlFor="dob">Date of birth on the ID</label>
                        <input id="dob" type="date" value={dob} onChange={(e) => setDob(e.target.value)} max={new Date().toISOString().slice(0, 10)} />
                      </div>
                    )}
                    {pick && (
                      <div className="field">
                        <label htmlFor="reason">{pick === 'approve' ? 'Reason (recorded)' : 'Reason shown to the applicant'}</label>
                        <textarea
                          id="reason"
                          rows={3}
                          maxLength={500}
                          value={reason}
                          onChange={(e) => setReason(e.target.value)}
                          placeholder={pick === 'approve' ? 'e.g. Aadhaar checked, name and age match' : 'e.g. The ID photo is unreadable'}
                        />
                        <button type="button" className={`btn ${pick === 'reject' ? 'btn-danger' : 'btn-primary'}`} disabled={busy} onClick={() => void confirm()}>
                          {busy ? 'Saving…' : pick === 'approve' ? 'Confirm: Approve' : 'Confirm: Reject'}
                        </button>
                        <span className="small muted">Recorded in the audit log with your name, the time and this reason.</span>
                      </div>
                    )}
                  </>
                )}
              </section>
            </div>
          )}
        </>
      )}
    </>
  );
}
