import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { AdminVerificationDetail, Role } from '../lib/types';

// A fake staff session: pages read useAuth() for the API client and roles.
const auth = {
  staff: { user_id: 'staff-1', display_name: 'Founder', roles: ['customer', 'admin'] as Role[] },
  api: {} as Record<string, ReturnType<typeof vi.fn>>,
  has: (...r: Role[]) => r.some((x) => auth.staff.roles.includes(x)),
};
vi.mock('../auth/AuthContext', () => ({ useAuth: () => ({ ...auth, status: 'ready', signOut: vi.fn() }) }));

import { AppRoutes } from '../App';
import { HostReview } from './HostReview';

function detail(status: AdminVerificationDetail['status']): AdminVerificationDetail {
  return {
    host_id: 'h1',
    status,
    level: 5,
    rate_per_minute: 3000,
    application: {
      id: 'a1',
      status,
      submitted_at: '2026-11-22T12:32:00Z',
      resubmitted_at: null,
      reviewer_id: null,
      review_started_at: null,
      info_request: null,
      decided_by: null,
      decided_at: null,
      decision_reason: null,
    },
    evidence: [{ id: 'e1', kind: 'face_video', submitted: true, uploaded_at: '2026-11-22T12:31:00Z' }],
    history: [],
  };
}

function review(hostId = 'h1') {
  return render(
    <MemoryRouter initialEntries={[`/hosts/${hostId}/verification`]}>
      <Routes>
        <Route path="/hosts/:hostId/verification" element={<HostReview />} />
      </Routes>
    </MemoryRouter>,
  );
}

beforeEach(() => {
  auth.staff = { user_id: 'staff-1', display_name: 'Founder', roles: ['customer', 'admin'] };
  auth.api = {
    verification: vi.fn(async () => detail('submitted')),
    profile: vi.fn(async () => ({ user_id: 'h1', display_name: 'Rita', bio: 'Music', languages: ['Hindi'], photo_urls: [] })),
    userNames: vi.fn(async () => ({ items: [] })),
    verificationAction: vi.fn(async () => detail('rejected')),
    evidenceAccess: vi.fn(),
  };
});

describe('Host review', () => {
  it('offers only the actions the status allows', async () => {
    review();
    expect(await screen.findByRole('heading', { name: 'Rita' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Start review' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Reject' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Approve' })).not.toBeInTheDocument();
    expect(screen.getByText('5,000 / min')).toBeInTheDocument(); // limit if approved at level 5
  });

  it('shows Approve once under review', async () => {
    auth.api.verification = vi.fn(async () => detail('under_review'));
    review();
    expect(await screen.findByRole('button', { name: 'Approve' })).toBeInTheDocument();
  });

  it('requires a reason before rejecting, then sends it', async () => {
    const user = userEvent.setup();
    review();
    await user.click(await screen.findByRole('button', { name: 'Reject' }));
    await user.click(screen.getByRole('button', { name: 'Confirm: Reject' }));
    expect(screen.getByText('Please write a reason first.')).toBeInTheDocument();
    expect(auth.api.verificationAction).not.toHaveBeenCalled();

    await user.type(screen.getByLabelText(/Reason shown to the host/), 'Face not visible');
    await user.click(screen.getByRole('button', { name: 'Confirm: Reject' }));
    await waitFor(() => expect(auth.api.verificationAction).toHaveBeenCalledWith('h1', 'reject', 'Face not visible', undefined));
    expect(await screen.findByText(/Rejected\. The host has been told why/)).toBeInTheDocument();
  });

  it('blocks reviewing your own account', async () => {
    auth.staff = { user_id: 'h1', display_name: 'Rita', roles: ['host', 'admin'] };
    review('h1');
    expect(await screen.findByText(/This is your own account/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Reject' })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Open (5-min link)' })).toBeDisabled();
  });
});

describe('Role-based sections', () => {
  it('a finance-only account sees Finance but not the review queues', async () => {
    auth.staff = { user_id: 'f1', display_name: 'Asha', roles: ['customer', 'finance'] };
    auth.api = {
      reconciliation: vi.fn(async () => ({ as_of: '2026-11-24T00:00:00Z', customer_diamond_liability: 0, host_bean_liability: 0, discrepancies: 0 })),
      adjustments: vi.fn(async () => ({ items: [] })),
    };
    render(
      <MemoryRouter initialEntries={['/hosts']}>
        <AppRoutes />
      </MemoryRouter>,
    );
    expect(await screen.findByRole('link', { name: 'Finance' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /Host applications/ })).not.toBeInTheDocument();
    expect(screen.getByText(/doesn't have access to this section/)).toBeInTheDocument();
  });
});
