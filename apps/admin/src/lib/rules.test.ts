import { describe, expect, it } from 'vitest';
import { toE164 } from '../auth/AuthContext';
import { ageOn } from '../pages/HostActivation';
import { priceLimit, verificationActions } from './format';

describe('price limits (500 min, level × 1,000 max, above 3,000 only when verified)', () => {
  it.each([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])('level %i', (level) => {
    expect(priceLimit(level, true)).toBe(level * 1000);
    expect(priceLimit(level, false)).toBe(Math.min(level * 1000, 3000));
  });
});

describe('verification actions mirror the backend state machine', () => {
  it('approve is only possible from under review', () => {
    for (const [status, actions] of Object.entries(verificationActions)) {
      expect(actions.includes('approve')).toBe(status === 'under_review');
    }
  });
  it('a verified host can be suspended or revoked; a suspended one reinstated', () => {
    expect(verificationActions.verified).toEqual(['suspend', 'revoke']);
    expect(verificationActions.suspended).toContain('reinstate');
  });
});

describe('phone numbers', () => {
  it('adds +91 to a 10-digit Indian number', () => {
    expect(toE164('99999 99997')).toBe('+919999999997');
    expect(toE164('919999999997')).toBe('+919999999997');
  });
});

describe('age from the ID', () => {
  const today = new Date(2026, 10, 24); // 24 Nov 2026
  it('counts whole years and respects birthdays', () => {
    expect(ageOn('2008-11-24', today)).toBe(18);
    expect(ageOn('2008-11-25', today)).toBe(17);
    expect(Number.isNaN(ageOn('', today))).toBe(true);
  });
});
