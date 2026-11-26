import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { Avatar, ErrorBanner, PageHead, Pill, Skeleton, verificationTone } from '../components/ui';
import { formatDateTime, verificationLabels } from '../lib/format';
import type { VerificationStatus } from '../lib/types';
import { useLoad } from '../lib/useLoad';

type Tab = 'verified' | 'new';
type Filter = 'open' | 'approved' | 'rejected' | 'suspended' | 'all';

const OPEN: VerificationStatus[] = ['submitted', 'under_review', 'info_required'];
const FILTERS: [Filter, string][] = [
  ['open', 'Needs a decision'],
  ['approved', 'Verified'],
  ['rejected', 'Rejected'],
  ['suspended', 'Suspended or revoked'],
  ['all', 'All'],
];

export function Hosts() {
  const { api } = useAuth();
  const [params, setParams] = useSearchParams();
  const tab: Tab = params.get('tab') === 'new' ? 'new' : 'verified';
  const [filter, setFilter] = useState<Filter>('open');

  const verifications = useLoad(async () => {
    if (filter === 'open') {
      const r = await api.verificationQueue();
      return r.items.filter((i) => OPEN.includes(i.status));
    }
    if (filter === 'suspended') {
      const [s, r] = await Promise.all([api.verificationQueue('suspended'), api.verificationQueue('revoked')]);
      return [...s.items, ...r.items];
    }
    if (filter === 'all') {
      const all = await Promise.all(
        (['submitted', 'under_review', 'info_required', 'approved', 'rejected', 'suspended', 'revoked'] as VerificationStatus[]).map((s) =>
          api.verificationQueue(s),
        ),
      );
      return all.flatMap((r) => r.items);
    }
    return (await api.verificationQueue(filter)).items;
  }, [api, filter]);
  const applications = useLoad(() => api.hostApplications(), [api]);

  const setTab = (t: Tab) => setParams(t === 'new' ? { tab: 'new' } : {});
  const vCount = verifications.data && filter === 'open' ? verifications.data.length : undefined;

  return (
    <>
      <PageHead title="Host applications" lede="Oldest first. Open an application to review it and decide." />
      <div className="tabs" role="tablist" aria-label="Application type">
        <button type="button" role="tab" className="tab" aria-selected={tab === 'verified'} onClick={() => setTab('verified')}>
          Verified Host {vCount !== undefined && <span style={{ color: 'var(--brand)' }}>{vCount}</span>}
        </button>
        <button type="button" role="tab" className="tab" aria-selected={tab === 'new'} onClick={() => setTab('new')}>
          New hosts {applications.data && <span style={{ color: 'var(--brand)' }}>{applications.data.items.filter((a) => a.state === 'kyc_pending').length}</span>}
        </button>
      </div>

      {tab === 'verified' ? (
        <>
          <p className="small" style={{ margin: 0, color: 'var(--text-2)', maxWidth: 760, lineHeight: 1.5 }}>
            Verified Host: profile photos, a face video and ID evidence. Approval adds the badge and lets the host charge above 3,000 Diamonds/min, up to
            their level limit.
          </p>
          <div className="chips" role="group" aria-label="Filter by status">
            {FILTERS.map(([id, label]) => (
              <button key={id} type="button" className="chip" aria-pressed={filter === id} onClick={() => setFilter(id)}>
                {label}
              </button>
            ))}
          </div>
          <ErrorBanner error={verifications.error} onRetry={verifications.reload} />
          <div className="table-wrap">
            {verifications.loading && !verifications.data ? (
              <div style={{ padding: 20 }}>
                <Skeleton rows={4} />
              </div>
            ) : verifications.data && verifications.data.length === 0 ? (
              <p className="empty">Nothing with this status.</p>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th scope="col">Host</th>
                    <th scope="col">Level</th>
                    <th scope="col">Status</th>
                    <th scope="col">Submitted</th>
                    <th scope="col">
                      <span className="sr-only">Action</span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {verifications.data?.map((v) => (
                    <tr key={v.application_id}>
                      <td>
                        <div className="person">
                          <Avatar name={v.display_name} />
                          <strong>{v.display_name ?? 'Unnamed host'}</strong>
                        </div>
                      </td>
                      <td>Level {v.level}</td>
                      <td>
                        <Pill tone={verificationTone(v.status)}>{verificationLabels[v.status] ?? v.status}</Pill>
                      </td>
                      <td className="muted">{formatDateTime(v.submitted_at)}</td>
                      <td style={{ textAlign: 'right' }}>
                        <Link className="btn btn-outline" to={`/hosts/${v.host_id}/verification`}>
                          Review<span className="sr-only"> {v.display_name}</span>
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </>
      ) : (
        <>
          <p className="small" style={{ margin: 0, color: 'var(--text-2)', maxWidth: 760, lineHeight: 1.5 }}>
            New hosts: basic activation (age and ID check). You can decide once the applicant has started the ID check in the app. Approved hosts can take
            calls up to 3,000 Diamonds/min, within their level limit.
          </p>
          <ErrorBanner error={applications.error} onRetry={applications.reload} />
          <div className="table-wrap">
            {applications.loading && !applications.data ? (
              <div style={{ padding: 20 }}>
                <Skeleton rows={4} />
              </div>
            ) : applications.data && applications.data.items.length === 0 ? (
              <p className="empty">No new host applications.</p>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th scope="col">Applicant</th>
                    <th scope="col">City</th>
                    <th scope="col">Stage</th>
                    <th scope="col">Applied</th>
                    <th scope="col">
                      <span className="sr-only">Action</span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {applications.data?.items.map((a) => (
                    <tr key={a.user_id}>
                      <td>
                        <div className="person">
                          <Avatar name={a.display_name} />
                          <strong>{a.display_name ?? 'Unnamed'}</strong>
                        </div>
                      </td>
                      <td>{a.city ?? '—'}</td>
                      <td>
                        <Pill tone={a.state === 'kyc_pending' ? 'brand' : 'neutral'}>{a.state === 'kyc_pending' ? 'Ready to decide' : 'Waiting for ID check'}</Pill>
                      </td>
                      <td className="muted">{formatDateTime(a.applied_at)}</td>
                      <td style={{ textAlign: 'right' }}>
                        <Link className="btn btn-outline" to={`/hosts/${a.user_id}/activation`}>
                          Review<span className="sr-only"> {a.display_name}</span>
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </>
      )}
    </>
  );
}
