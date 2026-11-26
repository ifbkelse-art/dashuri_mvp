import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { createClient } from '@supabase/supabase-js';
import { App } from './App';
import { AuthProvider } from './auth/AuthContext';
import { missingConfig, readConfig } from './lib/config';
import './styles.css';

const root = createRoot(document.getElementById('root')!);
const cfg = readConfig();
const missing = missingConfig(cfg);

if (missing.length) {
  root.render(
    <main className="signin">
      <div className="signin-box">
        <div className="banner error" role="alert">
          The console is not configured. Missing: {missing.join(', ')}. Copy .env.example to .env.local and fill it in.
        </div>
      </div>
    </main>,
  );
} else {
  // The session lives in this browser's local storage; signing out clears it.
  const supabase = createClient(cfg.supabaseUrl, cfg.supabaseKey, {
    auth: { persistSession: true, autoRefreshToken: true, storageKey: 'dashuri-admin-auth' },
  });
  root.render(
    <StrictMode>
      <AuthProvider supabase={supabase} apiBaseUrl={cfg.apiBaseUrl}>
        <App />
      </AuthProvider>
    </StrictMode>,
  );
}
