// Response headers, written to dist/_headers by build.mjs. Netlify applies
// _headers for every deploy method (Git, CLI and drag-and-drop), so this is
// the single source; serve.mjs uses the same CSP locally.
export const csp =
  "default-src 'none'; style-src 'self' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src 'self' data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'";

export const headersFile = `/*
  Content-Security-Policy: ${csp}
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=()
  Strict-Transport-Security: max-age=31536000

/*.html
  Cache-Control: public, max-age=0, must-revalidate
`;
