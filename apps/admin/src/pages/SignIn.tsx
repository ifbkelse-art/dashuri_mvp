import { useState, type FormEvent } from 'react';
import { useAuth } from '../auth/AuthContext';
import { Banner } from '../components/ui';

export function SignIn() {
  const { sendCode, verifyCode, notice, status } = useAuth();
  const [step, setStep] = useState<'phone' | 'code'>('phone');
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submitPhone = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    if (phone.replace(/\D/g, '').length < 10) {
      setError('Enter your 10-digit mobile number.');
      return;
    }
    setBusy(true);
    try {
      await sendCode(phone);
      setStep('code');
    } catch (err) {
      setError(err instanceof Error ? err.message : "Couldn't send the code.");
    } finally {
      setBusy(false);
    }
  };

  const submitCode = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    if (!/^\d{6}$/.test(code)) {
      setError('Enter the 6-digit code.');
      return;
    }
    setBusy(true);
    try {
      await verifyCode(phone, code);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'That code did not work.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <main className="signin">
      <div className="signin-box">
        <div className="brand" style={{ padding: 0 }}>
          <div className="brand-mark" style={{ width: 44, height: 44, fontSize: 28, borderRadius: 12 }} aria-hidden="true">
            D
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span className="brand-name" style={{ fontSize: 28 }}>
              Dashuri
            </span>
            <span className="brand-sub">Admin console</span>
          </div>
        </div>
        <section className="card" style={{ padding: 32, gap: 20 }}>
          <div>
            <h1 className="serif" style={{ fontSize: 36, lineHeight: 1.1 }}>
              Staff sign in
            </h1>
            <p className="lede" style={{ lineHeight: 1.5 }}>
              Sign in with your staff phone number. Only admin, moderator and finance accounts can open the console.
            </p>
          </div>
          {notice && <Banner tone="warn">{notice}</Banner>}
          {error && <Banner tone="error">{error}</Banner>}
          {step === 'phone' ? (
            <form onSubmit={submitPhone} style={{ display: 'flex', flexDirection: 'column', gap: 16 }} noValidate>
              <label htmlFor="phone" style={{ fontSize: 14, fontWeight: 600 }}>
                Mobile number
              </label>
              <div className="phone">
                <span style={{ fontWeight: 600, color: 'var(--text-2)' }}>+91</span>
                <input
                  id="phone"
                  type="tel"
                  inputMode="numeric"
                  autoComplete="tel-national"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="10-digit number"
                  autoFocus
                />
              </div>
              <button type="submit" className="btn btn-primary" style={{ height: 52 }} disabled={busy || status === 'checking'}>
                {busy ? 'Sending…' : 'Send code'}
              </button>
            </form>
          ) : (
            <form onSubmit={submitCode} style={{ display: 'flex', flexDirection: 'column', gap: 16 }} noValidate>
              <label htmlFor="code" style={{ fontSize: 14, fontWeight: 600 }}>
                6-digit code sent to +91 {phone}
              </label>
              <input
                id="code"
                className="phone"
                style={{ fontSize: 20, letterSpacing: '0.3em', padding: '0 14px' }}
                inputMode="numeric"
                autoComplete="one-time-code"
                maxLength={6}
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                autoFocus
              />
              <button type="submit" className="btn btn-primary" style={{ height: 52 }} disabled={busy || status === 'checking'}>
                {busy || status === 'checking' ? 'Checking…' : 'Verify and sign in'}
              </button>
              <button
                type="button"
                className="btn btn-ghost"
                style={{ alignSelf: 'flex-start' }}
                onClick={() => {
                  setStep('phone');
                  setCode('');
                  setError(null);
                }}
              >
                Use a different number
              </button>
            </form>
          )}
        </section>
        <p className="small muted" style={{ lineHeight: 1.5, margin: 0 }}>
          Staff roles are granted only in the database, never here. The server checks your role again on every action, and every decision is written to the
          audit log.
        </p>
      </div>
    </main>
  );
}
