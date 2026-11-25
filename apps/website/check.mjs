// Checks the built site in dist/. Exits non-zero on any problem.
import { readdirSync, readFileSync, statSync, existsSync } from 'node:fs';
import { join, relative, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { legalPages } from './src/legal.mjs';
import { site, required } from './src/site.mjs';

const dist = join(dirname(fileURLToPath(import.meta.url)), 'dist');
const problems = [];
const files = [];
(function walk(d) {
  for (const n of readdirSync(d)) {
    const p = join(d, n);
    statSync(p).isDirectory() ? walk(p) : files.push(p);
  }
})(dist);
const html = files.filter((f) => f.endsWith('.html'));

// Pages Google Play asks for must exist.
for (const slug of ['privacy', 'terms', 'child-safety', 'delete-account']) {
  if (!existsSync(join(dist, slug, 'index.html'))) problems.push(`missing required page /${slug}/`);
}

for (const f of html) {
  const rel = '/' + relative(dist, f);
  const s = readFileSync(f, 'utf8');
  if (!/<title>[^<]+<\/title>/.test(s)) problems.push(`${rel}: no <title>`);
  if (!s.includes('name="viewport"')) problems.push(`${rel}: no viewport meta`);
  if (/\sstyle="/.test(s)) problems.push(`${rel}: inline style attribute (blocked by the CSP)`);
  if (/<script/i.test(s)) problems.push(`${rel}: script tag (the CSP allows none)`);
  if (/\{[a-z]+\}/.test(s)) problems.push(`${rel}: unfilled placeholder`);
  if (/example\.com|lorem ipsum|TODO/i.test(s)) problems.push(`${rel}: placeholder text`);
  if (/(sk_live|sk_test|service_role|sb_secret|AIza[0-9A-Za-z_-]{20,}|-----BEGIN)/.test(s)) problems.push(`${rel}: looks like a secret`);
  // Internal links must resolve to a built page.
  for (const [, href] of s.matchAll(/href="(\/[^"#?]*)/g)) {
    const target = href.endsWith('/') ? join(dist, href, 'index.html') : join(dist, href);
    if (!existsSync(target)) problems.push(`${rel}: broken link ${href}`);
  }
}

// Company details the law requires (see src/site.mjs). Missing ones render
// as <mark data-missing>; a production build must have none.
const production = process.argv.includes('--production');
const missing = required.filter((k) => !site[k]);
if (missing.length) {
  const msg = `company details not filled in src/site.mjs: ${missing.join(', ')}`;
  if (production) problems.push(msg);
  else console.warn(`! ${msg} (preview only; a --production build fails)`);
}
for (const f of html) {
  const s = readFileSync(f, 'utf8');
  if (production && s.includes('data-missing')) problems.push(`/${relative(dist, f)}: unfilled company detail`);
  if (/pending legal review|\bdraft\b/i.test(s)) problems.push(`/${relative(dist, f)}: still marked as a draft`);
}
for (const p of legalPages) {
  if (!existsSync(join(dist, p.slug, 'index.html'))) problems.push(`missing policy page /${p.slug}/`);
}

if (problems.length) {
  console.error(problems.map((p) => `✗ ${p}`).join('\n'));
  process.exit(1);
}
console.log(`✓ ${html.length} pages checked: links, titles, company details, CSP-safe markup, no secrets.`);
