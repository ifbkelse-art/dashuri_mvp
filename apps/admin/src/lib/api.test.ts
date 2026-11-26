import { describe, expect, it, vi } from 'vitest';
import { AdminApi, ApiError, describeError } from './api';

function fakeFetch(status: number, body: unknown) {
  return vi.fn(async (_url: string, _init?: RequestInit) => new Response(body === undefined ? '' : JSON.stringify(body), { status }));
}

describe('AdminApi', () => {
  it('sends the bearer token and no idempotency key on reads', async () => {
    const f = fakeFetch(200, { items: [] });
    const api = new AdminApi('https://api.test', async () => 'tok', f as unknown as typeof fetch);
    await api.hostApplications();
    const [url, init] = f.mock.calls[0];
    expect(url).toBe('https://api.test/v1/admin/host-applications?limit=100');
    const h = init!.headers as Record<string, string>;
    expect(h.Authorization).toBe('Bearer tok');
    expect(h['Idempotency-Key']).toBeUndefined();
  });

  it('adds a fresh Idempotency-Key to decisions that require one', async () => {
    const f = fakeFetch(200, {});
    const api = new AdminApi('https://api.test', async () => 'tok', f as unknown as typeof fetch);
    await api.verificationAction('h1', 'reject', 'blurry');
    await api.verificationAction('h1', 'reject', 'blurry');
    const k1 = (f.mock.calls[0][1]!.headers as Record<string, string>)['Idempotency-Key'];
    const k2 = (f.mock.calls[1][1]!.headers as Record<string, string>)['Idempotency-Key'];
    expect(k1).toMatch(/^[0-9a-f-]{36}$/);
    expect(k1).not.toBe(k2);
    expect(JSON.parse(f.mock.calls[0][1]!.body as string)).toEqual({ action: 'reject', reason: 'blurry' });
  });

  it('sends info_request only for request_info', async () => {
    const f = fakeFetch(200, {});
    const api = new AdminApi('https://api.test', async () => 'tok', f as unknown as typeof fetch);
    await api.verificationAction('h1', 'request_info', 'too dark', 'too dark');
    expect(JSON.parse(f.mock.calls[0][1]!.body as string)).toEqual({ action: 'request_info', reason: 'too dark', info_request: 'too dark' });
  });

  it('turns problem+json into ApiError with the rule or code', async () => {
    const api = new AdminApi('https://api.test', async () => 'tok', fakeFetch(403, { code: 'self_review', detail: 'no' }) as unknown as typeof fetch);
    await expect(api.verification('h1')).rejects.toMatchObject({ status: 403, code: 'self_review' });

    const rule = new AdminApi('https://api.test', async () => 'tok', fakeFetch(409, { code: 'business_rule', rule: 'invalid_transition' }) as unknown as typeof fetch);
    await expect(rule.verification('h1')).rejects.toMatchObject({ status: 409, code: 'invalid_transition' });

    const val = new AdminApi('https://api.test', async () => 'tok', fakeFetch(422, { code: 'validation_failed', errors: [{ field: 'reason', reason: 'required' }] }) as unknown as typeof fetch);
    const err = await val.verification('h1').catch((e) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err.fields).toEqual({ reason: 'required' });
    expect(describeError(err)).toContain('reason (required)');
  });

  it('reports network failures as status 0', async () => {
    const api = new AdminApi('https://api.test', async () => 'tok', (async () => {
      throw new TypeError('offline');
    }) as unknown as typeof fetch);
    const err = await api.me().catch((e) => e);
    expect(err).toMatchObject({ status: 0 });
    expect(describeError(err)).toMatch(/reach the server/);
  });

  it('skips the names call for an empty id list', async () => {
    const f = fakeFetch(200, { items: [] });
    const api = new AdminApi('https://api.test', async () => 'tok', f as unknown as typeof fetch);
    expect(await api.userNames([])).toEqual({ items: [] });
    expect(f).not.toHaveBeenCalled();
  });
});
