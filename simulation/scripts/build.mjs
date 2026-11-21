// Bundles the engine + dashboard + business-model report into self-contained HTML files.
//   dist/dashuri-simulation.html  full document; open directly in a browser
//   dist/artifact.html            body-only version for the hosted artifact
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const repo = join(root, '..');
const MODULES = [
  'src/engine/assumptions.js',
  'src/engine/rng.js',
  'src/engine/finance.js',
  'src/engine/simulate.js',
  'src/engine/runs.js',
  'src/engine/export.js',
  'src/ui/charts.js',
  'src/ui/markdown.js',
  'src/ui/app.js',
];

function wrap(path) {
  const src = readFileSync(join(root, path), 'utf8');
  const exported = new Set();
  const out = src.split('\n').map((line) => {
    const imp = /^import\s*\{([^}]+)\}\s*from\s*['"][^'"]+['"];?\s*$/.exec(line);
    if (imp) return `const {${imp[1]}} = __M;`;
    const exList = /^export\s*\{([^}]+)\};?\s*$/.exec(line);
    if (exList) {
      exList[1].split(',').map((s) => s.trim()).filter(Boolean).forEach((n) => exported.add(n));
      return '';
    }
    const ex = /^export\s+(async\s+)?(function|const|let|class)\s+([A-Za-z0-9_$]+)/.exec(line);
    if (ex) {
      exported.add(ex[3]);
      return line.replace(/^export\s+/, '');
    }
    if (/^\s*import\s/.test(line)) throw new Error(`Unsupported import form in ${path}: ${line}`);
    return line;
  }).join('\n');
  const assign = exported.size ? `\nObject.assign(__M, { ${[...exported].join(', ')} });` : '';
  return `// ---- ${path} ----\n(function () {\n${out}${assign}\n})();\n`;
}

const reportFile = 'docs/business-model-report.md';
const report = readFileSync(join(repo, reportFile), 'utf8');
const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));
const build = { builtAt: new Date().toISOString().slice(0, 16).replace('T', ' ') + ' UTC', version: pkg.version, reportFile };
const safe = (s) => JSON.stringify(s).replace(/<\//g, '<\\/').replace(/<!--/g, '<\\!--');
const script = `<script>\n"use strict";\nwindow.__DASHURI_REPORT__ = ${safe(report)};\nwindow.__DASHURI_BUILD__ = ${safe(build)};\nconst __M = {};\n${MODULES.map(wrap).join('\n')}\n</script>`;
const template = readFileSync(join(root, 'src/ui/template.html'), 'utf8');

mkdirSync(join(root, 'dist'), { recursive: true });
const artifact = `${template}\n${script}\n`;
writeFileSync(join(root, 'dist/artifact.html'), artifact);
const headEnd = template.indexOf('</style>') + '</style>'.length;
const full = `<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n${template.slice(0, headEnd)}\n</head>\n<body>\n${template.slice(headEnd)}\n${script}\n</body>\n</html>\n`;
writeFileSync(join(root, 'dist/dashuri-simulation.html'), full);
console.log(`Built dist/dashuri-simulation.html (${(full.length / 1024).toFixed(0)} KB) and dist/artifact.html at ${build.builtAt}`);
