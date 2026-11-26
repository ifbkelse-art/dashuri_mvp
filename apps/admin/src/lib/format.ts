const IST = 'Asia/Kolkata';

export function formatDateTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleString('en-IN', { timeZone: IST, day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' });
}

export function timeAgo(iso: string, now: Date = new Date()): string {
  const s = Math.max(0, Math.round((now.getTime() - new Date(iso).getTime()) / 1000));
  if (s < 60) return 'just now';
  const m = Math.round(s / 60);
  if (m < 60) return `${m} min ago`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h} h ago`;
  const days = Math.round(h / 24);
  return days === 1 ? 'yesterday' : `${days} days ago`;
}

export function formatNumber(n: number): string {
  return new Intl.NumberFormat('en-IN').format(n);
}

export function formatRupeesFromPaise(paise: number): string {
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 }).format(paise / 100);
}

/** "host.kyc_approved" → "Host kyc approved" for the audit list. */
export function humanizeAction(action: string): string {
  const s = action.replace(/[._]/g, ' ').trim();
  return s.charAt(0).toUpperCase() + s.slice(1);
}

/** Levels are 1..10; a host may charge 500..level×1,000, and above 3,000 only when Verified. */
export function priceLimit(level: number, verified: boolean): number {
  const max = Math.max(1, Math.min(10, level)) * 1000;
  return verified ? max : Math.min(max, 3000);
}

export const verificationLabels: Record<string, string> = {
  not_applied: 'Not applied',
  submitted: 'Submitted',
  under_review: 'Under review',
  info_required: 'Info requested',
  approved: 'Verified Host',
  verified: 'Verified Host',
  rejected: 'Rejected',
  suspended: 'Suspended',
  revoked: 'Revoked',
};

export const categoryLabels: Record<string, string> = {
  nudity: 'Nudity',
  sexual_content: 'Sexual content',
  minor_safety: 'Minor safety',
  harassment: 'Harassment',
  spam_or_scam: 'Spam or scam',
  fake_profile: 'Fake profile',
  other: 'Other',
};

export const evidenceLabels: Record<string, string> = {
  face_video: 'Face verification video',
  id_document_front: 'ID document (front)',
  id_document_back: 'ID document (back)',
};

/** Staff actions allowed from a host's verification status (mirrors backend adminTransitions). */
export const verificationActions: Record<string, ('start_review' | 'request_info' | 'approve' | 'reject' | 'suspend' | 'reinstate' | 'revoke')[]> = {
  submitted: ['start_review', 'request_info', 'reject'],
  under_review: ['approve', 'request_info', 'reject'],
  info_required: ['reject'],
  verified: ['suspend', 'revoke'],
  suspended: ['reinstate', 'revoke'],
};

export const reasonRequired = new Set(['reject', 'suspend', 'reinstate', 'revoke']);
