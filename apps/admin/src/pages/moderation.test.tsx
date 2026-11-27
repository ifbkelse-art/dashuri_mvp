import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { ReelQueueItem, Role } from '../lib/types';

const auth = {
  staff: { user_id: 'mod-1', display_name: 'Meera', roles: ['customer', 'moderator'] as Role[] },
  api: {} as Record<string, ReturnType<typeof vi.fn>>,
  has: (...r: Role[]) => r.some((x) => auth.staff.roles.includes(x)),
};
vi.mock('../auth/AuthContext', () => ({ useAuth: () => ({ ...auth, status: 'ready', signOut: vi.fn() }) }));

import { AppRoutes } from '../App';
import { ApiError } from '../lib/api';
import { AuditLog } from './AuditLog';
import { ReelsModeration } from './ReelsModeration';

function item(status: string, source = 'automated'): ReelQueueItem {
  return {
    case_id: `case-${status}`,
    source,
    priority: 2,
    scores: { sexual: 0.42 },
    report_count: source === 'report' ? 3 : 0,
    appeal_statement: null,
    created_at: '2026-11-27T10:00:00Z',
    reel: {
      id: `reel-${status}`,
      creator: { user_id: 'h1', display_name: 'Riya' },
      caption: 'Morning chai',
      duration_ms: 20000,
      status,
      rejection_code: null,
      playback: { url: 'https://r2.example/p.mp4?sig', format: 'mp4', thumbnail_url: 'https://r2.example/t.jpg?sig', expires_at: '2026-11-27T10:15:00Z' },
      created_at: '2026-11-27T09:59:00Z',
    },
  };
}

function page(el: JSX.Element) {
  return render(<MemoryRouter>{el}</MemoryRouter>);
}

beforeEach(() => {
  auth.staff = { user_id: 'mod-1', display_name: 'Meera', roles: ['customer', 'moderator'] };
  auth.api = {
    reelsQueue: vi.fn(async () => ({ items: [item('in_review')], next_cursor: null })),
    decideReel: vi.fn(async () => ({ reel_id: 'reel-in_review', status: 'published' })),
    audit: vi.fn(async () => ({ items: [] })),
    userNames: vi.fn(async () => ({ items: [] })),
    // Layout badge counts for reviewers.
    verificationQueue: vi.fn(async () => ({ items: [] })),
    hostApplications: vi.fn(async () => ({ items: [] })),
    moderationQueue: vi.fn(async () => ({ items: [], next_cursor: null })),
    appeals: vi.fn(async () => ({ items: [] })),
  };
});

describe('Reels moderation', () => {
  it('approves with a neutral reason and removes the case from the queue', async () => {
    const user = userEvent.setup();
    page(<ReelsModeration />);
    expect(await screen.findByText('Riya')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Approve' }));
    await waitFor(() => expect(auth.api.decideReel).toHaveBeenCalledWith('reel-in_review', 'approve', 'meets_guidelines', undefined));
    expect(await screen.findByText('All caught up')).toBeInTheDocument();
  });

  it('rejects with the chosen policy reason and a staff note', async () => {
    const user = userEvent.setup();
    page(<ReelsModeration />);
    await screen.findByText('Riya');
    await user.selectOptions(screen.getByLabelText('Reason for reject / remove'), 'minor_safety');
    await user.type(screen.getByLabelText(/Note/), 'looks underage');
    await user.click(screen.getByRole('button', { name: 'Reject' }));
    await waitFor(() => expect(auth.api.decideReel).toHaveBeenCalledWith('reel-in_review', 'reject', 'minor_safety', 'looks underage'));
  });

  it('a reported live reel offers Remove, a removed one Restore', async () => {
    auth.api.reelsQueue = vi.fn(async () => ({ items: [item('published', 'report'), item('removed', 'appeal')], next_cursor: null }));
    page(<ReelsModeration />);
    expect(await screen.findByRole('button', { name: 'Remove' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Restore' })).toBeInTheDocument();
    expect(screen.getByText(/3 reports/)).toBeInTheDocument();
  });

  it('shows the server refusal for your own reel', async () => {
    const user = userEvent.setup();
    auth.api.decideReel = vi.fn(async () => {
      throw new ApiError(403, 'self_review', 'no');
    });
    page(<ReelsModeration />);
    await user.click(await screen.findByRole('button', { name: 'Approve' }));
    expect(await screen.findByText("You can't review your own account or content.")).toBeInTheDocument();
    expect(screen.getByText('Riya')).toBeInTheDocument();
  });
});

describe('Audit log', () => {
  it('lists entries and filters them', async () => {
    const user = userEvent.setup();
    auth.api.audit = vi.fn(async () => ({
      items: [
        { at: '2026-11-27T10:00:00Z', actor: 'a1', actor_name: 'Founder', action: 'gift.price_changed', target: 'rose', target_name: null, reason: 'launch' },
        { at: '2026-11-27T09:00:00Z', actor: 'm1', actor_name: 'Meera', action: 'photo.approved', target: 'p1', target_name: 'Riya', reason: null },
      ],
    }));
    page(<AuditLog />);
    expect(await screen.findByText('Founder')).toBeInTheDocument();
    expect(screen.getByText('Meera')).toBeInTheDocument();
    await user.type(screen.getByLabelText('Filter'), 'launch');
    expect(screen.queryByText('Meera')).not.toBeInTheDocument();
    expect(screen.getByText('Founder')).toBeInTheDocument();
  });

  it('asks the server for more when the limit changes', async () => {
    const user = userEvent.setup();
    page(<AuditLog />);
    await waitFor(() => expect(auth.api.audit).toHaveBeenCalledWith(50));
    await user.selectOptions(screen.getByLabelText('Show'), '200');
    await waitFor(() => expect(auth.api.audit).toHaveBeenCalledWith(200));
  });
});

describe('Navigation by role', () => {
  it('a moderator sees Reels moderation but not the Audit log', async () => {
    render(
      <MemoryRouter initialEntries={['/reels']}>
        <AppRoutes />
      </MemoryRouter>,
    );
    expect(await screen.findByRole('link', { name: 'Reels moderation' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Audit log' })).not.toBeInTheDocument();
  });

  it('only an admin can open the Audit log', async () => {
    render(
      <MemoryRouter initialEntries={['/audit']}>
        <AppRoutes />
      </MemoryRouter>,
    );
    expect(await screen.findByText(/doesn't have access to this section/)).toBeInTheDocument();
  });
});
