import type { ReactNode } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './auth/AuthContext';
import { Layout } from './components/Layout';
import { Banner, Skeleton } from './components/ui';
import type { Role } from './lib/types';
import { ArrivalPhotos } from './pages/ArrivalPhotos';
import { AuditLog } from './pages/AuditLog';
import { ReelsModeration } from './pages/ReelsModeration';
import { Finance } from './pages/Finance';
import { Gifts } from './pages/Gifts';
import { HostActivation } from './pages/HostActivation';
import { HostReview } from './pages/HostReview';
import { Hosts } from './pages/Hosts';
import { Overview } from './pages/Overview';
import { Photos } from './pages/Photos';
import { Reports } from './pages/Reports';
import { SignIn } from './pages/SignIn';

/** Hides a section from staff without the role. The server enforces it again. */
function Guard({ roles, children }: { roles: Role[]; children: ReactNode }) {
  const { has } = useAuth();
  if (!has(...roles)) {
    return <Banner tone="warn">Your account doesn't have access to this section.</Banner>;
  }
  return <>{children}</>;
}

export function AppRoutes() {
  const { status } = useAuth();
  if (status === 'loading' || status === 'checking') {
    return (
      <main className="signin">
        <div className="signin-box">
          <Skeleton rows={3} />
        </div>
      </main>
    );
  }
  if (status === 'signed_out') return <SignIn />;
  const reviewers: Role[] = ['moderator', 'admin'];
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Overview />} />
        <Route path="hosts" element={<Guard roles={reviewers}><Hosts /></Guard>} />
        <Route path="hosts/:hostId/verification" element={<Guard roles={reviewers}><HostReview /></Guard>} />
        <Route path="hosts/:userId/activation" element={<Guard roles={reviewers}><HostActivation /></Guard>} />
        <Route path="photos" element={<Guard roles={reviewers}><Photos /></Guard>} />
        <Route path="reports" element={<Guard roles={reviewers}><Reports /></Guard>} />
        <Route path="finance" element={<Guard roles={['finance', 'admin']}><Finance /></Guard>} />
        <Route path="arrival-photos" element={<Guard roles={reviewers}><ArrivalPhotos /></Guard>} />
        <Route path="gifts" element={<Guard roles={['admin', 'finance', 'moderator']}><Gifts /></Guard>} />
        <Route path="reels" element={<Guard roles={reviewers}><ReelsModeration /></Guard>} />
        <Route path="audit" element={<Guard roles={['admin']}><AuditLog /></Guard>} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}

export function App() {
  return (
    <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
      <AppRoutes />
    </BrowserRouter>
  );
}
