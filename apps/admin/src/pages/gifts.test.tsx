import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { AdminGift, Role } from '../lib/types';

const auth = {
  staff: { user_id: 'staff-1', display_name: 'Founder', roles: ['customer', 'admin'] as Role[] },
  api: {} as Record<string, ReturnType<typeof vi.fn>>,
  has: (...r: Role[]) => r.some((x) => auth.staff.roles.includes(x)),
};
vi.mock('../auth/AuthContext', () => ({ useAuth: () => ({ ...auth, status: 'ready', signOut: vi.fn() }) }));

import { ArrivalPhotos } from './ArrivalPhotos';
import { Gifts } from './Gifts';

const rose: AdminGift = {
  id: 'rose', name: 'Rose', description: '', emoji: '🌹', icon_asset: 'gift/rose', animation_asset: 'celebration/rose',
  animation_duration_ms: 5000, sound_asset: null, tier: 'common', sort_order: 10, diamond_price: 1500, active: true,
  available_from: null, available_until: null, earning_rule: 'standard_conversion', retired_at: null,
  created_at: '2026-11-26T00:00:00Z', updated_at: '2026-11-26T00:00:00Z',
};

beforeEach(() => {
  auth.staff = { user_id: 'staff-1', display_name: 'Founder', roles: ['customer', 'admin'] };
  auth.api = {
    gifts: vi.fn(async () => ({ items: [rose] })),
    giftPerformance: vi.fn(async () => ({ days: 30, items: [{ gift_id: 'rose', gift_name: 'Rose', count: 4, diamond_value: 6000, host_beans: 3596, unique_senders: 2, unique_hosts: 1 }] })),
    giftTransactions: vi.fn(async () => ({ items: [], next_cursor: null })),
    changeGiftPrice: vi.fn(async () => ({ ...rose, diamond_price: 2000 })),
    updateGift: vi.fn(async () => ({ ...rose, active: false })),
    giftPriceHistory: vi.fn(async () => ({ items: [] })),
    arrivalQueue: vi.fn(async () => ({ items: [{ photo_id: 'p1', host_user_id: 'h1', host_name: 'Meera', status: 'pending_review', captured_at: '2026-11-26T10:00:00Z', session_open: true, photo_url: 'https://x/p1.jpg' }] })),
    decideArrival: vi.fn(async () => ({})),
  };
});

const page = (el: JSX.Element) => render(<MemoryRouter>{el}</MemoryRouter>);

describe('Gifts', () => {
  it('lists the catalogue with performance', async () => {
    page(<Gifts />);
    expect(await screen.findByText('🌹 Rose')).toBeInTheDocument();
    expect(screen.getByText('1,500')).toBeInTheDocument();
    expect(screen.getByText('4 · 6,000 D')).toBeInTheDocument();
  });

  it('a price change needs a reason and calls the audited endpoint', async () => {
    const user = userEvent.setup();
    page(<Gifts />);
    await user.click(await screen.findByRole('button', { name: 'Change price' }));
    const price = screen.getByLabelText('New price');
    await user.clear(price);
    await user.type(price, '2000');
    await user.click(screen.getByRole('button', { name: 'Save price' }));
    expect(auth.api.changeGiftPrice).not.toHaveBeenCalled();
    expect(screen.getByText(/whole price between 1 and/)).toBeInTheDocument();
    await user.type(screen.getByLabelText('Reason (logged)'), 'Festival pricing');
    await user.click(screen.getByRole('button', { name: 'Save price' }));
    await waitFor(() => expect(auth.api.changeGiftPrice).toHaveBeenCalledWith('rose', 2000, 'Festival pricing'));
  });

  it('finance can read but not edit', async () => {
    auth.staff = { user_id: 'f1', display_name: 'Fin', roles: ['customer', 'finance'] };
    page(<Gifts />);
    expect(await screen.findByText('🌹 Rose')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Change price' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'New gift' })).not.toBeInTheDocument();
  });
});

describe('Arrival photos', () => {
  it('approves a pending photo', async () => {
    const user = userEvent.setup();
    page(<ArrivalPhotos />);
    expect(await screen.findByText('Meera')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Approve' }));
    await waitFor(() => expect(auth.api.decideArrival).toHaveBeenCalledWith('p1', 'approve', undefined));
    expect(await screen.findByText('All caught up')).toBeInTheDocument();
  });
});
