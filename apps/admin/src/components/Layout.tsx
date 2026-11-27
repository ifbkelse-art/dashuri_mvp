import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

export interface Counts {
  hosts: number | null;
  photos: number | null;
  reports: number | null;
}

const CountsCtx = createContext<{ counts: Counts; refresh: () => void; setPhotos: (n: number) => void }>({
  counts: { hosts: null, photos: null, reports: null },
  refresh: () => {},
  setPhotos: () => {},
});

export const useCounts = () => useContext(CountsCtx);

const OPEN_VERIFICATION = new Set(['submitted', 'under_review', 'info_required']);

export function Layout() {
  const { api, staff, has, signOut } = useAuth();
  const reviewer = has('moderator', 'admin');
  const finance = has('finance', 'admin');
  const isAdmin = has('admin');
  const [counts, setCounts] = useState<Counts>({ hosts: null, photos: null, reports: null });

  const refresh = useCallback(() => {
    if (!reviewer) return;
    // Counts are a convenience: a failure leaves the badge empty, never blocks
    // the page. The photo queue is NOT read here: opening it is an audited
    // view (photos.review_queue_viewed), so only the Photos page sets its count.
    void Promise.allSettled([api.verificationQueue(), api.hostApplications(), api.moderationQueue(), api.appeals()]).then(([v, h, m, a]) => {
      const ok = <T,>(r: PromiseSettledResult<T>) => (r.status === 'fulfilled' ? r.value : null);
      const ver = ok(v);
      const apps = ok(h);
      const mod = ok(m);
      const appeals = ok(a);
      setCounts((c) => ({
        ...c,
        hosts: ver && apps ? ver.items.filter((i) => OPEN_VERIFICATION.has(i.status)).length + apps.items.filter((a) => a.state === 'kyc_pending').length : null,
        reports: mod && appeals ? mod.items.length + appeals.items.length : null,
      }));
    });
  }, [api, reviewer]);

  // On load and after each decision only (no polling), so an idle console
  // makes no background requests.
  useEffect(() => {
    refresh();
  }, [refresh]);
  const setPhotos = useCallback((n: number) => setCounts((c) => ({ ...c, photos: n })), []);

  const badge = (n: number | null) => (n ? <span className="count">{n}</span> : null);

  return (
    <CountsCtx.Provider value={{ counts, refresh, setPhotos }}>
      <div className="shell">
        <aside className="side">
          <div className="brand">
            <div className="brand-mark" aria-hidden="true">
              D
            </div>
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <span className="brand-name">Dashuri</span>
              <span className="brand-sub">Admin</span>
            </div>
          </div>
          <nav className="nav" aria-label="Admin sections">
            <NavLink to="/" end>
              Overview
            </NavLink>
            {reviewer && <NavLink to="/hosts">Host applications {badge(counts.hosts)}</NavLink>}
            {reviewer && <NavLink to="/photos">Photo review {badge(counts.photos)}</NavLink>}
            {reviewer && <NavLink to="/reports">Reports &amp; appeals {badge(counts.reports)}</NavLink>}
            {reviewer && <NavLink to="/arrival-photos">Arrival photos</NavLink>}
            {reviewer && <NavLink to="/reels">Reels moderation</NavLink>}
            {(finance || reviewer) && <NavLink to="/gifts">Gifts</NavLink>}
            {finance && <NavLink to="/finance">Finance</NavLink>}
            {isAdmin && <NavLink to="/audit">Audit log</NavLink>}
          </nav>
          <div className="who">
            <strong>{staff?.display_name ?? 'Staff'}</strong>
            <span>{staff?.roles.filter((r) => r !== 'customer' && r !== 'host').join(' · ')}</span>
            <button type="button" className="btn btn-ghost" style={{ marginTop: 8, alignSelf: 'flex-start' }} onClick={() => void signOut()}>
              Sign out
            </button>
          </div>
        </aside>
        <main className="main" id="main">
          <Outlet />
        </main>
      </div>
    </CountsCtx.Provider>
  );
}
