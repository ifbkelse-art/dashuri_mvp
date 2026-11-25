// Local preview of dist/ (http://localhost:5174). Mirrors Netlify's clean
// URLs, 404 page and headers closely enough for checking layout.
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { join, extname, normalize, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const dist = join(dirname(fileURLToPath(import.meta.url)), 'dist');
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.svg': 'image/svg+xml', '.txt': 'text/plain' };
const csp = "default-src 'none'; style-src 'self' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src 'self' data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'";
const port = Number(process.env.PORT) || 5174;

createServer(async (req, res) => {
  const path = normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname)).replace(/^(\.\.[/\\])+/, '');
  let file = join(dist, path);
  try {
    if ((await stat(file)).isDirectory()) file = join(file, 'index.html');
  } catch {
    file = null;
  }
  let status = 200;
  let body;
  try {
    body = await readFile(file);
  } catch {
    status = 404;
    file = join(dist, '404.html');
    body = await readFile(file);
  }
  res.writeHead(status, { 'Content-Type': types[extname(file)] || 'application/octet-stream', 'Content-Security-Policy': csp });
  res.end(body);
}).listen(port, () => console.log(`Dashuri website on http://localhost:${port}`));
