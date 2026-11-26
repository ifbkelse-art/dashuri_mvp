import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { useCounts } from '../components/Layout';
import { ErrorBanner, PageHead, Skeleton } from '../components/ui';
import { formatDateTime, humanizeAction } from '../lib/format';
import { useLoad } from '../lib/useLoad';

function greeting(d = new Date()): string {
  const h = Number(d.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', hour: 'numeric', hour12: false }));
  return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
}

export function Overview() {
  const { api, has } = useAuth();
  const { counts } = useCounts();
  const reviewer = has('moderator', 'admin');
  const finance = has('finance', 'admin');
  const isAdmin = has('admin');
  const audit = useLoad(() => (isAdmin ? api.audit(12) : Promise.resolve({ items: [] })), [api, isAdmin]);

  const stat = (to: string, label: string, value: number | null, hint: string) => (
    <Link to={to} className="stat">
      <span className="label">{label}</span>
      <span className="value">{value ?? '—'}</span>
      <span className="hint">{hint}</span>
    </Link>
  );

  return (
    <>
      <PageHead title={greeting()} lede="What needs a decision. Counts update when you open a page or decide something." />
      {reviewer && (
        <section aria-label="Queues" className="grid-stats">
          {stat('/hosts', 'Host applications waiting', counts.hosts, 'Verified Host and new hosts')}
          {stat('/photos', 'Photos to review', counts.photos, counts.photos === null ? 'Open the queue to see new photos' : 'Hidden from customers until approved')}
          {stat('/reports', 'Open reports and appeals', counts.reports, 'Highest severity first')}
        </section>
      )}
      <div className="row">
        {finance && (
          <section className="card col-2">
            <h2>Finance</h2>
            <p style={{ margin: 0 }}>
              Reconciliation, ledger adjustments and payouts. <Link to="/finance">Open Finance</Link>
            </p>
          </section>
        )}
        {isAdmin && (
          <section className="card col-3">
            <h2>Recent decisions (audit log)</h2>
            {audit.loading && !audit.data ? (
              <Skeleton rows={4} />
            ) : audit.error ? (
              <ErrorBanner error={audit.error} onRetry={audit.reload} />
            ) : audit.data && audit.data.items.length === 0 ? (
              <p className="muted" style={{ margin: 0 }}>
                Nothing recorded yet.
              </p>
            ) : (
              <ul className="list">
                {audit.data?.items.map((e, i) => (
                  <li key={i} style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                    <span>
                      <strong>{e.actor_name ?? e.actor}</strong> · {humanizeAction(e.action)}
                      {e.target_name ? (
                        <>
                          {' '}
                          · <strong>{e.target_name}</strong>
                        </>
                      ) : null}
                    </span>
                    <span className="muted">
                      {formatDateTime(e.at)}
                      {e.reason ? ` · reason: ${e.reason}` : ''}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </section>
        )}
      </div>
    </>
  );
}
