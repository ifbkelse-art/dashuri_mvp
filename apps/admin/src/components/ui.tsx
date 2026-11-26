import type { ReactNode } from 'react';
import { describeError } from '../lib/api';

export function PageHead({ title, lede, aside }: { title: string; lede?: string; aside?: ReactNode }) {
  return (
    <header className="page-head">
      <div>
        <h1>{title}</h1>
        {lede && <p className="lede">{lede}</p>}
      </div>
      {aside}
    </header>
  );
}

export function Banner({ tone, children }: { tone: 'ok' | 'error' | 'info' | 'warn'; children: ReactNode }) {
  return (
    <div className={`banner ${tone}`} role={tone === 'error' ? 'alert' : 'status'}>
      {children}
    </div>
  );
}

export function ErrorBanner({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  if (!error) return null;
  return (
    <Banner tone="error">
      <span style={{ flex: 1 }}>{describeError(error)}</span>
      {onRetry && (
        <button type="button" className="btn btn-danger-outline" onClick={onRetry}>
          Try again
        </button>
      )}
    </Banner>
  );
}

export function Skeleton({ rows = 3 }: { rows?: number }) {
  return (
    <div aria-busy="true" aria-label="Loading" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="skeleton" style={{ width: `${90 - i * 12}%` }} />
      ))}
    </div>
  );
}

export function Avatar({ name, large }: { name: string | null | undefined; large?: boolean }) {
  return (
    <span className={`avatar${large ? ' lg' : ''}`} aria-hidden="true">
      {(name ?? '?').trim().charAt(0).toUpperCase() || '?'}
    </span>
  );
}

export function Pill({ tone, children }: { tone: 'brand' | 'warn' | 'ok' | 'info' | 'neutral' | 'danger' | 'high'; children: ReactNode }) {
  return <span className={`pill ${tone}`}>{children}</span>;
}

export function verificationTone(status: string): 'brand' | 'warn' | 'ok' | 'info' | 'neutral' | 'danger' {
  switch (status) {
    case 'submitted':
      return 'brand';
    case 'under_review':
    case 'info_required':
      return 'warn';
    case 'approved':
    case 'verified':
      return 'info';
    case 'suspended':
    case 'revoked':
      return 'danger';
    default:
      return 'neutral';
  }
}
