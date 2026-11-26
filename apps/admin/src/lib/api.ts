import type {
  AdminGift,
  AdminGiftTransaction,
  ArrivalQueueItem,
  CreateGiftInput,
  GiftPerformance,
  GiftPriceChange,
  AdjustmentItem,
  AdminVerificationDetail,
  AppealItem,
  AuditItem,
  EvidenceAccess,
  HostApplication,
  Items,
  ModerationAction,
  ModerationCase,
  Page,
  PendingPhoto,
  PublicProfile,
  ReconciliationReport,
  StaffMe,
  UserName,
  VerificationAction,
  VerificationQueueItem,
  VerificationStatus,
} from './types';

/** A problem+json error from the API, or a network failure (status 0). */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly fields: Record<string, string> = {},
  ) {
    super(message);
  }
}

type TokenSource = () => Promise<string | null>;
type Fetch = typeof fetch;

function idempotencyKey(): string {
  return crypto.randomUUID();
}

/** Plain-language message for an API error, for banners and toasts. */
export function describeError(e: unknown): string {
  if (!(e instanceof ApiError)) return 'Something went wrong. Please try again.';
  if (e.status === 0) return "Can't reach the server. Check your connection and try again.";
  if (e.status === 401) return 'Your session has ended. Please sign in again.';
  if (e.code === 'role_required') return "Your account doesn't have permission for this.";
  if (e.code === 'self_review') return "You can't review your own account.";
  if (e.code === 'conflict_of_interest') return "You can't act on your own proposal or account.";
  const fields = Object.entries(e.fields);
  if (fields.length) return 'Please check: ' + fields.map(([f, r]) => `${f.replace(/_/g, ' ')} (${r.replace(/_/g, ' ')})`).join(', ');
  return e.message || 'Request failed.';
}

export class AdminApi {
  constructor(
    private readonly baseUrl: string,
    private readonly token: TokenSource,
    private readonly http: Fetch = (...a) => fetch(...a),
  ) {}

  private async request<T>(method: string, path: string, body?: unknown, idempotent = false): Promise<T> {
    const headers: Record<string, string> = { Accept: 'application/json' };
    const token = await this.token();
    if (token) headers.Authorization = `Bearer ${token}`;
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (idempotent) headers['Idempotency-Key'] = idempotencyKey();
    let res: Response;
    try {
      res = await this.http(this.baseUrl + path, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
      });
    } catch {
      throw new ApiError(0, 'network', 'Network error');
    }
    const text = await res.text();
    const json = text ? safeJson(text) : null;
    if (!res.ok) {
      const p = (json ?? {}) as { code?: string; rule?: string; title?: string; detail?: string; errors?: { field: string; reason: string }[] };
      const fields: Record<string, string> = {};
      for (const f of p.errors ?? []) fields[f.field] = f.reason;
      throw new ApiError(res.status, p.rule ?? p.code ?? String(res.status), p.detail ?? p.title ?? `HTTP ${res.status}`, fields);
    }
    return json as T;
  }

  // Staff identity.
  me = () => this.request<StaffMe>('GET', '/v1/admin/me');
  userNames = (ids: string[]) =>
    ids.length === 0
      ? Promise.resolve<Items<UserName>>({ items: [] })
      : this.request<Items<UserName>>('GET', `/v1/admin/users?ids=${ids.map(encodeURIComponent).join(',')}`);

  // Public profile (same endpoint the app uses): name, bio, approved photos.
  profile = (userId: string) => this.request<PublicProfile>('GET', `/v1/profiles/${encodeURIComponent(userId)}`);

  // Verified Host review.
  verificationQueue = (status?: VerificationStatus) =>
    this.request<Items<VerificationQueueItem>>('GET', `/v1/admin/host-verifications?limit=100${status ? `&status=${status}` : ''}`);
  verification = (hostId: string) =>
    this.request<AdminVerificationDetail>('GET', `/v1/admin/hosts/${encodeURIComponent(hostId)}/verification`);
  verificationAction = (hostId: string, action: VerificationAction, reason: string, infoRequest?: string) =>
    this.request<AdminVerificationDetail>(
      'POST',
      `/v1/admin/hosts/${encodeURIComponent(hostId)}/verification/actions`,
      { action, reason, ...(infoRequest ? { info_request: infoRequest } : {}) },
      true,
    );
  evidenceAccess = (hostId: string, evidenceId: string) =>
    this.request<EvidenceAccess>(
      'POST',
      `/v1/admin/hosts/${encodeURIComponent(hostId)}/verification/evidence/${encodeURIComponent(evidenceId)}/access`,
    );

  // Basic host activation.
  hostApplications = () => this.request<Items<HostApplication>>('GET', '/v1/admin/host-applications?limit=100');
  kycDecision = (userId: string, decision: 'approve' | 'reject', reason: string, dateOfBirth?: string) =>
    this.request<unknown>('POST', `/v1/admin/hosts/${encodeURIComponent(userId)}/kyc-decision`, {
      decision,
      reason,
      ...(dateOfBirth ? { date_of_birth: dateOfBirth } : {}),
    });

  // Photos.
  pendingPhotos = () => this.request<Page<PendingPhoto>>('GET', '/v1/admin/photos/pending?limit=50');
  decidePhoto = (photoId: string, decision: 'approve' | 'reject', reason?: string) =>
    this.request<unknown>('POST', `/v1/admin/photos/${encodeURIComponent(photoId)}/decision`, {
      decision,
      reason: reason ?? null,
    });

  // Reports and appeals.
  moderationQueue = () => this.request<Page<ModerationCase>>('GET', '/v1/admin/moderation/queue?limit=50');
  decideReport = (reportId: string, action: ModerationAction, reason: string) =>
    this.request<unknown>('POST', `/v1/admin/reports/${encodeURIComponent(reportId)}/decisions`, { action, reason }, true);
  appeals = (status: 'open' | 'all' = 'open') => this.request<Items<AppealItem>>('GET', `/v1/admin/appeals?status=${status}&limit=100`);
  decideAppeal = (appealId: string, outcome: 'upheld' | 'overturned', reason: string) =>
    this.request<unknown>('POST', `/v1/admin/appeals/${encodeURIComponent(appealId)}/decisions`, { outcome, reason }, true);

  // Finance.
  reconciliation = () => this.request<ReconciliationReport>('GET', '/v1/admin/ledger/reconciliation');
  adjustments = (status: 'awaiting_second_approval' | 'all' = 'awaiting_second_approval') =>
    this.request<Items<AdjustmentItem>>('GET', `/v1/admin/ledger/adjustments?status=${status}&limit=100`);
  proposeAdjustment = (account: string, currency: 'DIAMOND' | 'BEAN', amount: number, reason: string) =>
    this.request<unknown>('POST', '/v1/admin/ledger/adjustments', { account, currency, amount, reason }, true);
  approveAdjustment = (id: string) =>
    this.request<unknown>('POST', `/v1/admin/ledger/adjustments/${encodeURIComponent(id)}/approve`, undefined, true);
  rejectAdjustment = (id: string) =>
    this.request<unknown>('POST', `/v1/admin/ledger/adjustments/${encodeURIComponent(id)}/reject`, undefined, true);

  // Virtual gifts (2026-11-26). Prices change only through changeGiftPrice
  // (admin role; reason required; audited).
  gifts = () => this.request<Items<AdminGift>>('GET', '/v1/admin/gifts');
  createGift = (input: CreateGiftInput) => this.request<AdminGift>('POST', '/v1/admin/gifts', input, true);
  updateGift = (id: string, patch: Partial<Omit<AdminGift, 'id' | 'diamond_price'>> & { retire?: boolean; clear_schedule?: boolean }) =>
    this.request<AdminGift>('PATCH', `/v1/admin/gifts/${encodeURIComponent(id)}`, patch);
  changeGiftPrice = (id: string, diamondPrice: number, reason: string) =>
    this.request<AdminGift>('POST', `/v1/admin/gifts/${encodeURIComponent(id)}/price`, { diamond_price: diamondPrice, reason }, true);
  giftPriceHistory = (id: string) => this.request<Items<GiftPriceChange>>('GET', `/v1/admin/gifts/${encodeURIComponent(id)}/price-history`);
  giftPerformance = (days = 30) => this.request<Items<GiftPerformance> & { days: number }>('GET', `/v1/admin/gifts/performance?days=${days}`);
  giftTransactions = (opts: { userId?: string; flagged?: boolean } = {}) =>
    this.request<Page<AdminGiftTransaction>>(
      'GET',
      `/v1/admin/gifts/transactions?limit=50${opts.userId ? `&user_id=${encodeURIComponent(opts.userId)}` : ''}${opts.flagged ? '&flagged=true' : ''}`,
    );

  // Arrival photos (2026-11-26). Opening the queue is an audited view.
  arrivalQueue = () => this.request<Items<ArrivalQueueItem>>('GET', '/v1/admin/arrival-photos?limit=50');
  decideArrival = (photoId: string, decision: 'approve' | 'reject' | 'remove', reason?: string) =>
    this.request<ArrivalQueueItem>('POST', `/v1/admin/arrival-photos/${encodeURIComponent(photoId)}/decision`, { decision, reason: reason ?? '' }, true);

  // Audit.
  audit = (limit = 30) => this.request<Items<AuditItem>>('GET', `/v1/admin/audit?limit=${limit}`);
}

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}
