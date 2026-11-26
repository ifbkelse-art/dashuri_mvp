import { render, screen, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import type { SupabaseClient } from '@supabase/supabase-js';
import { AuthProvider, useAuth } from './AuthContext';

function fakeSupabase(session: { access_token: string } | null) {
  return {
    auth: {
      getSession: vi.fn(async () => ({ data: { session } })),
      onAuthStateChange: vi.fn(() => ({ data: { subscription: { unsubscribe: vi.fn() } } })),
      signOut: vi.fn(async () => ({ error: null })),
      signInWithOtp: vi.fn(async () => ({ error: null })),
      verifyOtp: vi.fn(),
    },
  };
}

function Probe() {
  const { status, staff, notice } = useAuth();
  return (
    <div>
      <span data-testid="status">{status}</span>
      <span data-testid="staff">{staff?.roles.join(',') ?? ''}</span>
      <span data-testid="notice">{notice ?? ''}</span>
    </div>
  );
}

describe('AuthProvider', () => {
  it('lets a staff account in', async () => {
    const sb = fakeSupabase({ access_token: 't' });
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ user_id: 'u', display_name: 'F', roles: ['customer', 'admin'] }), { status: 200 })));
    render(
      <AuthProvider supabase={sb as unknown as SupabaseClient} apiBaseUrl="https://api.test">
        <Probe />
      </AuthProvider>,
    );
    await waitFor(() => expect(screen.getByTestId('status')).toHaveTextContent('ready'));
    expect(screen.getByTestId('staff')).toHaveTextContent('customer,admin');
    vi.unstubAllGlobals();
  });

  it('signs out a non-staff account and explains why', async () => {
    const sb = fakeSupabase({ access_token: 't' });
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ code: 'role_required' }), { status: 403 })));
    render(
      <AuthProvider supabase={sb as unknown as SupabaseClient} apiBaseUrl="https://api.test">
        <Probe />
      </AuthProvider>,
    );
    await waitFor(() => expect(screen.getByTestId('status')).toHaveTextContent('signed_out'));
    expect(screen.getByTestId('notice')).toHaveTextContent('not a staff account');
    expect(sb.auth.signOut).toHaveBeenCalled();
    vi.unstubAllGlobals();
  });

  it('starts signed out without a session', async () => {
    render(
      <AuthProvider supabase={fakeSupabase(null) as unknown as SupabaseClient} apiBaseUrl="https://api.test">
        <Probe />
      </AuthProvider>,
    );
    await waitFor(() => expect(screen.getByTestId('status')).toHaveTextContent('signed_out'));
  });
});
