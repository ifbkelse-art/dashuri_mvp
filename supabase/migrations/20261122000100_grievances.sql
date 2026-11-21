-- Grievances (D-22, IT Rules grievance officer): a user can file a complaint
-- that is not about another user. Stored as a report with category 'other'
-- and no target, so it reaches the same moderation queue.
alter table safety.reports alter column target_user_id drop not null;
alter table safety.reports add constraint reports_target_or_grievance
  check (target_user_id is not null or (category = 'other' and call_id is null and details is not null));
