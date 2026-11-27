import { useMemo, useState } from 'react';
import { useAuth } from '../auth/AuthContext';
import { ErrorBanner, PageHead, Skeleton } from '../components/ui';
import { formatDateTime, humanizeAction } from '../lib/format';
import { useLoad } from '../lib/useLoad';

const LIMITS = [50, 100, 200];

/**
 * Audit log (admin only, server-enforced): who did what, to whom, why.
 * Read-only; entries are append-only in the database.
 */
export function AuditLog() {
  const { api } = useAuth();
  const [limit, setLimit] = useState(50);
  const [query, setQuery] = useState('');
  const audit = useLoad(() => api.audit(limit), [api, limit]);
  const rows = useMemo(() => {
    const q = query.trim().toLowerCase();
    const items = audit.data?.items ?? [];
    if (!q) return items;
    return items.filter((a) =>
      [a.action, a.actor, a.actor_name, a.target, a.target_name, a.reason].some((v) => (v ?? '').toLowerCase().includes(q)),
    );
  }, [audit.data, query]);

  return (
    <>
      <PageHead title="Audit log" lede="Every staff action, newest first. Entries cannot be edited or deleted." />
      <div className="two" style={{ maxWidth: 640 }}>
        <div className="field">
          <label htmlFor="audit-q">Filter</label>
          <input id="audit-q" placeholder="Action, name, id or reason" value={query} onChange={(e) => setQuery(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="audit-limit">Show</label>
          <select id="audit-limit" value={limit} onChange={(e) => setLimit(Number(e.target.value))}>
            {LIMITS.map((n) => <option key={n} value={n}>Latest {n}</option>)}
          </select>
        </div>
      </div>
      <ErrorBanner error={audit.error} onRetry={audit.reload} />
      {audit.loading && !audit.data ? (
        <Skeleton rows={6} />
      ) : rows.length === 0 ? (
        <section className="card"><span className="muted">{query ? 'No entries match.' : 'No staff actions yet.'}</span></section>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>When</th><th>Who</th><th>Action</th><th>Target</th><th>Reason</th></tr>
            </thead>
            <tbody>
              {rows.map((a, i) => (
                <tr key={`${a.at}-${i}`}>
                  <td style={{ whiteSpace: 'nowrap' }}>{formatDateTime(a.at)}</td>
                  <td>{a.actor_name ?? a.actor}</td>
                  <td>{humanizeAction(a.action)}</td>
                  <td>{a.target_name ?? a.target ?? '—'}</td>
                  <td>{a.reason ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
