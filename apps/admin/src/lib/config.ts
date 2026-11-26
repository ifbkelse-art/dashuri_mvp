/** Public build-time settings (VITE_*). Never put a secret here: the browser sees them. */
export interface AdminConfig {
  apiBaseUrl: string;
  supabaseUrl: string;
  supabaseKey: string;
}

export function readConfig(env: Record<string, string | undefined> = import.meta.env): AdminConfig {
  const cfg = {
    apiBaseUrl: (env.VITE_API_BASE_URL ?? '').replace(/\/+$/, ''),
    supabaseUrl: env.VITE_SUPABASE_URL ?? '',
    supabaseKey: env.VITE_SUPABASE_PUBLISHABLE_KEY ?? '',
  };
  return cfg;
}

export function missingConfig(cfg: AdminConfig): string[] {
  const missing: string[] = [];
  if (!cfg.apiBaseUrl) missing.push('VITE_API_BASE_URL');
  if (!cfg.supabaseUrl) missing.push('VITE_SUPABASE_URL');
  if (!cfg.supabaseKey) missing.push('VITE_SUPABASE_PUBLISHABLE_KEY');
  return missing;
}
