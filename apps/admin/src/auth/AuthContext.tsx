import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import { AdminApi, ApiError, describeError } from '../lib/api';
import type { Role, StaffMe } from '../lib/types';

type Status = 'loading' | 'signed_out' | 'checking' | 'ready';

interface AuthState {
  status: Status;
  staff: StaffMe | null;
  /** Shown on the sign-in screen (e.g. "not a staff account"). */
  notice: string | null;
  api: AdminApi;
  sendCode: (phone: string) => Promise<void>;
  verifyCode: (phone: string, code: string) => Promise<void>;
  signOut: () => Promise<void>;
  has: (...roles: Role[]) => boolean;
}

const Ctx = createContext<AuthState | null>(null);

export function useAuth(): AuthState {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAuth outside AuthProvider');
  return v;
}

/** E.164 for an Indian mobile: digits only, 10 digits → +91, else as typed. */
export function toE164(raw: string): string {
  const d = raw.replace(/\D/g, '');
  if (d.length === 10) return `+91${d}`;
  if (d.length === 12 && d.startsWith('91')) return `+${d}`;
  return `+${d}`;
}

export function AuthProvider({ supabase, apiBaseUrl, children }: { supabase: SupabaseClient; apiBaseUrl: string; children: ReactNode }) {
  const [status, setStatus] = useState<Status>('loading');
  const [staff, setStaff] = useState<StaffMe | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const tokenRef = useRef<string | null>(null);

  const api = useMemo(
    () =>
      new AdminApi(apiBaseUrl, async () => {
        const { data } = await supabase.auth.getSession();
        return data.session?.access_token ?? tokenRef.current;
      }),
    [supabase, apiBaseUrl],
  );

  const checkStaff = useCallback(async () => {
    setStatus('checking');
    try {
      const me = await api.me();
      setStaff(me);
      setNotice(null);
      setStatus('ready');
    } catch (e) {
      // Not staff (403) or the session is unusable: sign out completely so
      // a customer or host token never lingers in the console.
      const msg =
        e instanceof ApiError && e.status === 403
          ? 'This account is not a staff account. Only admin, moderator and finance accounts can use the console.'
          : describeError(e);
      setStaff(null);
      setNotice(msg);
      await supabase.auth.signOut();
      setStatus('signed_out');
    }
  }, [api, supabase]);

  useEffect(() => {
    let alive = true;
    supabase.auth.getSession().then(({ data }) => {
      if (!alive) return;
      tokenRef.current = data.session?.access_token ?? null;
      if (data.session) void checkStaff();
      else setStatus('signed_out');
    });
    const { data: sub } = supabase.auth.onAuthStateChange((event, session) => {
      tokenRef.current = session?.access_token ?? null;
      if (event === 'SIGNED_OUT') {
        setStaff(null);
        setStatus('signed_out');
      }
    });
    return () => {
      alive = false;
      sub.subscription.unsubscribe();
    };
  }, [supabase, checkStaff]);

  const sendCode = useCallback(
    async (phone: string) => {
      const { error } = await supabase.auth.signInWithOtp({ phone: toE164(phone), options: { shouldCreateUser: false } });
      if (error) throw new Error(error.message);
    },
    [supabase],
  );

  const verifyCode = useCallback(
    async (phone: string, code: string) => {
      const { data, error } = await supabase.auth.verifyOtp({ phone: toE164(phone), token: code, type: 'sms' });
      if (error) throw new Error(error.message);
      tokenRef.current = data.session?.access_token ?? null;
      await checkStaff();
    },
    [supabase, checkStaff],
  );

  const signOut = useCallback(async () => {
    await supabase.auth.signOut();
    setStaff(null);
    setNotice(null);
    setStatus('signed_out');
  }, [supabase]);

  const has = useCallback((...roles: Role[]) => !!staff && roles.some((r) => staff.roles.includes(r)), [staff]);

  const value = useMemo(
    () => ({ status, staff, notice, api, sendCode, verifyCode, signOut, has }),
    [status, staff, notice, api, sendCode, verifyCode, signOut, has],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}
