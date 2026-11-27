// Wire types for the staff endpoints (api/openapi/dashuri.v1.yaml).

export type Role = 'customer' | 'host' | 'moderator' | 'admin' | 'finance';

export interface StaffMe {
  user_id: string;
  display_name: string | null;
  roles: Role[];
}

export interface Items<T> {
  items: T[];
}

export interface Page<T> extends Items<T> {
  next_cursor: string | null;
}

export type VerificationStatus =
  | 'not_applied'
  | 'submitted'
  | 'under_review'
  | 'info_required'
  | 'approved'
  | 'verified'
  | 'rejected'
  | 'suspended'
  | 'revoked';

export interface VerificationQueueItem {
  application_id: string;
  host_id: string;
  display_name: string | null;
  status: VerificationStatus;
  submitted_at: string;
  level: number;
}

export interface EvidenceItem {
  id: string;
  kind: 'face_video' | 'id_document_front' | 'id_document_back';
  submitted: boolean;
  uploaded_at: string | null;
}

export interface HistoryEvent {
  at: string;
  actor: string;
  action: string;
  details: Record<string, unknown>;
}

export interface AdminVerificationDetail {
  host_id: string;
  status: VerificationStatus;
  level: number;
  rate_per_minute: number;
  application: {
    id: string;
    status: string;
    submitted_at: string;
    resubmitted_at: string | null;
    reviewer_id: string | null;
    review_started_at: string | null;
    info_request: string | null;
    decided_by: string | null;
    decided_at: string | null;
    decision_reason: string | null;
  } | null;
  evidence: EvidenceItem[];
  history: HistoryEvent[];
}

export type VerificationAction =
  | 'start_review'
  | 'request_info'
  | 'approve'
  | 'reject'
  | 'suspend'
  | 'reinstate'
  | 'revoke';

export interface EvidenceAccess {
  url: string;
  expires_at: string;
}

export interface HostApplication {
  user_id: string;
  display_name: string | null;
  city: string | null;
  state: 'applied' | 'kyc_pending';
  kyc_state: string;
  declared_date_of_birth: string | null;
  applied_at: string;
}

export interface PendingPhoto {
  photo_id: string;
  user_id: string;
  read_url: string | null;
  created_at: string;
}

export interface ModerationCase {
  report_id: string;
  status: string;
  category: string;
  target_user_id: string;
  created_at: string;
  evidence_count: number;
  details: string | null;
}

export type ModerationAction = 'dismiss' | 'warn' | 'restrict_calls' | 'suspend' | 'ban' | 'escalate_legal';

export interface AppealItem {
  appeal_id: string;
  user_id: string;
  display_name: string | null;
  statement: string;
  status: 'open' | 'upheld' | 'overturned';
  created_at: string;
  enforcement: { action: string; reason: string; created_at: string };
}

export interface ReconciliationReport {
  as_of: string;
  customer_diamond_liability: number;
  host_bean_liability: number;
  discrepancies: number;
  promotional_diamond_liability?: number;
  host_bean_liability_paise?: number;
  unbalanced_entries?: number;
}

export interface AdjustmentItem {
  proposal_id: string;
  owner_user_id: string | null;
  owner_display_name: string | null;
  account_kind: string;
  currency: 'DIAMOND' | 'BEAN' | 'INR_PAISE';
  amount: number;
  reason: string;
  proposed_by: string;
  proposed_by_name: string | null;
  status: 'awaiting_second_approval' | 'posted' | 'rejected';
  created_at: string;
  proposed_by_me: boolean;
}

export interface AuditItem {
  at: string;
  actor: string;
  actor_name: string | null;
  action: string;
  target: string | null;
  target_name: string | null;
  reason: string | null;
}

export interface UserName {
  user_id: string;
  display_name: string;
}

export interface PublicProfile {
  user_id: string;
  display_name: string;
  bio: string | null;
  languages: string[];
  photo_urls: string[];
}

// ---------------------------------------------------------------- virtual gifts (2026-11-26)

export type GiftTier = 'common' | 'rare' | 'epic' | 'legendary' | 'mythic';

export interface AdminGift {
  id: string;
  name: string;
  description: string;
  emoji: string;
  icon_asset: string;
  animation_asset: string;
  animation_duration_ms: number;
  sound_asset: string | null;
  tier: GiftTier;
  sort_order: number;
  diamond_price: number;
  active: boolean;
  available_from: string | null;
  available_until: string | null;
  earning_rule: string;
  retired_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface GiftPriceChange {
  old_price: number | null;
  new_price: number;
  changed_by: string;
  reason: string;
  changed_at: string;
}

export interface GiftPerformance {
  gift_id: string;
  gift_name: string;
  count: number;
  diamond_value: number;
  host_beans: number;
  unique_senders: number;
  unique_hosts: number;
}

export interface AdminGiftTransaction {
  gift_transaction_id: string;
  gift_id: string;
  gift_name: string;
  emoji: string;
  diamond_value: number;
  sender: { user_id: string; display_name: string };
  recipient: { user_id: string; display_name: string };
  call_id: string;
  sent_at: string;
  from_promotional: number;
  from_purchased: number;
  host_beans: number;
  rule_set_version: string;
  ledger_entry_id: string;
  risk_flags: string[];
}

export interface CreateGiftInput {
  id: string;
  name: string;
  description: string;
  emoji: string;
  icon_asset: string;
  animation_asset: string;
  tier: GiftTier;
  sort_order: number;
  diamond_price: number;
  active: boolean;
  reason: string;
}

export interface ArrivalQueueItem {
  photo_id: string;
  host_user_id: string;
  host_name: string;
  status: string;
  captured_at: string | null;
  session_open: boolean;
  photo_url: string | null;
}

/** Reels moderation queue entry (GET /v1/admin/reels/queue). */
export interface ReelQueueItem {
  case_id: string;
  source: string; // automated | report | appeal
  priority: number;
  scores: Record<string, number> | null;
  report_count: number;
  appeal_statement: string | null;
  created_at: string;
  reel: {
    id: string;
    creator: { user_id: string; display_name: string };
    caption: string;
    duration_ms: number | null;
    status: string;
    rejection_code: string | null;
    playback: { url: string; format: string; thumbnail_url: string; expires_at: string } | null;
    created_at: string;
  };
}

export type ReelDecision = 'approve' | 'reject' | 'remove' | 'restore';
