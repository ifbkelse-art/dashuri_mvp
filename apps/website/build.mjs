// Builds the static site into dist/. No dependencies: `node build.mjs`.
import { mkdirSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { site } from './src/site.mjs';
import { legalPages } from './src/legal.mjs';
import { pages } from './src/pages.mjs';

const root = dirname(fileURLToPath(import.meta.url));
const out = join(root, 'dist');

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

export const logo = `<svg viewBox="0 0 64 64" aria-hidden="true"><rect width="64" height="64" rx="19" fill="#761C3B"/><text x="29" y="47" text-anchor="middle" font-family="Instrument Serif, Times New Roman, serif" font-size="44" fill="#fff">D</text><path d="M46 12l1.6 4.4L52 18l-4.4 1.6L46 24l-1.6-4.4L40 18l4.4-1.6z" fill="#E9C98C"/></svg>`;

const nav = [
  ['/', 'Home'],
  ['/hosts/', 'Become a host'],
  ['/safety/', 'Safety'],
  ['/legal/', 'Legal'],
  ['/contact/', 'Contact'],
];

function header(path) {
  const links = nav
    .map(([href, label]) => `<a href="${href}"${href === path ? ' aria-current="page"' : ''}>${label}</a>`)
    .join('');
  return `<a class="skip" href="#main">Skip to content</a>
<header class="site-header"><div class="wrap">
  <a class="brand" href="/" aria-label="${site.name} home">${logo}<span>${site.name}</span></a>
  <nav class="nav" aria-label="Main">${links}</nav>
</div></header>`;
}

function footer() {
  const legal = legalPages.map((p) => `<li><a href="/${p.slug}/">${esc(p.title)}</a></li>`).join('');
  const operator = ` · Operated by ${val('operatorName', 'legal name of the operator')}`;
  return `<footer class="site-footer"><div class="wrap">
  <div>
    <a class="brand" href="/" aria-label="${site.name} home">${logo}<span>${site.name}</span></a>
    <p class="muted">${esc(site.tagline)} For adults 18+ in India.</p>
    <p><a href="mailto:${site.supportEmail}">${site.supportEmail}</a> · <a href="/grievance/">Grievance Officer</a></p>
  </div>
  <div><h2>Dashuri</h2><ul>${nav.slice(1).map(([h, l]) => `<li><a href="${h}">${l}</a></li>`).join('')}</ul></div>
  <div><h2>Policies</h2><ul>${legal}</ul></div>
  <p class="fine">© 2026 ${site.name}${operator}. Dashuri is only for adults aged 18 or older.</p>
</div></footer>`;
}

function layout({ path, title, description, body }) {
  const fullTitle = path === '/' ? `${site.name} · ${site.tagline}` : `${title} · ${site.name}`;
  const canonical = site.origin ? `<link rel="canonical" href="${site.origin}${path}">` : '';
  return `<!doctype html>
<html lang="en-IN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(fullTitle)}</title>
<meta name="description" content="${esc(description)}">
<meta property="og:title" content="${esc(fullTitle)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:type" content="website">
<meta name="theme-color" content="#761C3B">
${canonical}
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Instrument+Serif&family=Manrope:wght@400;600;700&display=swap">
<link rel="stylesheet" href="/styles.css">
</head>
<body>
${header(path)}
<main id="main">
${body}
</main>
${footer()}
</body>
</html>
`;
}

// A company detail not yet filled in renders as a visible marker, so a
// preview shows the gap; `check.mjs --production` refuses to ship it.
const val = (key, label) => (site[key] ? esc(site[key]) : `<mark data-missing>[${label}]</mark>`);

function fill(html) {
  const map = {
    '{operator}': val('operatorName', 'legal name of the operator'),
    '{address}': val('registeredAddress', 'registered address'),
    '{city}': val('jurisdictionCity', 'city for courts'),
    '{phone}': val('supportPhone', 'customer care phone'),
    '{officer}': val('grievanceOfficer', 'Grievance Officer name'),
    '{email}': site.supportEmail,
    '{gemail}': site.grievanceEmail,
    '{version}': site.policyVersion,
    '{effective}': site.effectiveDate,
  };
  return html.replace(/\{[a-z]+\}/g, (k) => map[k] ?? k);
}

function legalBody(p) {
  const sections = p.sections.map(([h, html]) => `<h2>${esc(h)}</h2>\n${fill(html)}`).join('\n');
  return `<article class="doc"><div class="wrap">
  <p class="eyebrow">Policy</p>
  <h1>${esc(p.title)}</h1>
  <p class="updated">Version ${site.policyVersion} · Effective ${site.effectiveDate}</p>
  ${sections}
</div></article>`;
}

function legalIndex() {
  const items = legalPages
    .map((p) => `<a href="/${p.slug}/"><strong>${esc(p.title)}</strong><span>${esc(p.summary)}</span></a>`)
    .join('');
  return `<section class="doc"><div class="wrap">
  <p class="eyebrow">Legal</p>
  <h1>Policies</h1>
  <p class="updated">Version ${site.policyVersion} · Effective ${site.effectiveDate}</p>
  <div class="doc-list">${items}</div>
  <h2>Company information</h2>
  <p>${fill('{operator}<br>{address}<br>Customer care: {phone} · <a href="mailto:{email}">{email}</a><br>Grievance Officer: {officer} · <a href="mailto:{gemail}">{gemail}</a>')}</p>
</div></section>`;
}

function write(path, html) {
  const file = path === '/404' ? join(out, '404.html') : join(out, path, 'index.html');
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, html);
}

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

for (const p of pages(site)) write(p.path, layout(p));
write('/legal/', layout({ path: '/legal/', title: 'Policies', description: 'Dashuri terms, privacy, safety and account policies.', body: legalIndex() }));
for (const p of legalPages) {
  write(`/${p.slug}/`, layout({ path: `/${p.slug}/`, title: p.title, description: p.summary, body: legalBody(p) }));
}

writeFileSync(join(out, 'styles.css'), readFileSync(join(root, 'src/styles.css')));
writeFileSync(join(out, 'favicon.svg'), logo.replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" '));
writeFileSync(join(out, 'robots.txt'), 'User-agent: *\nAllow: /\n');

console.log(`Built ${legalPages.length + pages(site).length + 1} pages into dist/`);
