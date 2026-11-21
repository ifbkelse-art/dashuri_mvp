// Minimal Markdown renderer for the business-model report (headings, lists,
// tables, blockquotes, rules, emphasis, code, links). Escapes HTML first.
const escapeHtml = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

export function slugify(s) {
  return s.toLowerCase().replace(/<[^>]+>/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 80);
}

function inline(text) {
  let s = escapeHtml(text);
  const codes = [];
  s = s.replace(/`([^`]+)`/g, (_, c) => {
    codes.push(c);
    return `\u0000${codes.length - 1}\u0000`;
  });
  s = s.replace(/\[([^\]]+)\]\((https?:\/\/[^)\s]+|[^)\s]+)\)/g, (_, t, u) => {
    const ext = /^https?:/.test(u);
    return `<a href="${u}"${ext ? ' target="_blank" rel="noopener"' : ''}>${t}</a>`;
  });
  s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  s = s.replace(/(^|[^*\w])\*([^*\n]+)\*(?!\w)/g, '$1<em>$2</em>');
  // Evidence chips: make decision labels scannable.
  s = s.replace(/\[(FOUNDER-DRAFT|FOUNDER|RESEARCH|CLAUDE|ASSUMPTION|UNRESOLVED|PRO-REVIEW|VERIFIED-OFFICIAL)([^\]]*)\]/g, (m, tag, rest) => `<span class="chip chip-${tag.toLowerCase()}">${tag}${rest}</span>`);
  s = s.replace(/\bUNVERIFIED\b/g, '<span class="chip chip-unverified">UNVERIFIED</span>');
  s = s.replace(/\u0000(\d+)\u0000/g, (_, i) => `<code>${escapeHtml(codes[+i])}</code>`);
  return s;
}

function splitRow(line) {
  let l = line.trim();
  if (l.startsWith('|')) l = l.slice(1);
  if (l.endsWith('|')) l = l.slice(0, -1);
  const cells = [];
  let cur = '';
  let inCode = false;
  for (let i = 0; i < l.length; i++) {
    const ch = l[i];
    if (ch === '`') inCode = !inCode;
    if (ch === '\\' && l[i + 1] === '|') {
      cur += '|';
      i++;
      continue;
    }
    if (ch === '|' && !inCode) {
      cells.push(cur.trim());
      cur = '';
    } else cur += ch;
  }
  cells.push(cur.trim());
  return cells;
}

export function renderMarkdown(md) {
  const lines = md.replace(/\r/g, '').split('\n');
  const out = [];
  const toc = [];
  let i = 0;
  const listStack = [];
  const closeLists = (toIndent = -1) => {
    while (listStack.length && listStack[listStack.length - 1].indent > toIndent) {
      out.push(listStack.pop().ordered ? '</li></ol>' : '</li></ul>');
    }
  };
  let para = [];
  const flushPara = () => {
    if (para.length) {
      out.push(`<p>${inline(para.join(' '))}</p>`);
      para = [];
    }
  };
  while (i < lines.length) {
    const line = lines[i];
    const t = line.trim();
    if (!t) {
      flushPara();
      // keep lists open across blank lines only if next non-blank line is a list item or indented
      let j = i + 1;
      while (j < lines.length && !lines[j].trim()) j++;
      const nxt = lines[j] || '';
      if (!/^\s*([-*]|\d+\.)\s+/.test(nxt) && !/^\s{2,}\S/.test(nxt)) closeLists();
      i++;
      continue;
    }
    const h = /^(#{1,4})\s+(.*)$/.exec(t);
    if (h && !/^\s/.test(line)) {
      flushPara();
      closeLists();
      const level = h[1].length;
      const text = h[2];
      let id = slugify(text);
      if (toc.some((x) => x.id === id)) id += '-' + toc.length;
      toc.push({ level, text: text.replace(/[*`]/g, ''), id });
      out.push(`<h${level} id="${id}">${inline(text)}</h${level}>`);
      i++;
      continue;
    }
    if (/^-{3,}$/.test(t)) {
      flushPara();
      closeLists();
      out.push('<hr>');
      i++;
      continue;
    }
    if (t.startsWith('|') && i + 1 < lines.length && /^\|?\s*:?-{2,}/.test(lines[i + 1].trim())) {
      flushPara();
      closeLists();
      const head = splitRow(t);
      i += 2;
      const body = [];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        body.push(splitRow(lines[i]));
        i++;
      }
      out.push('<div class="table-wrap"><table><thead><tr>' + head.map((c) => `<th>${inline(c)}</th>`).join('') + '</tr></thead><tbody>' + body.map((r) => '<tr>' + r.map((c) => `<td>${inline(c)}</td>`).join('') + '</tr>').join('') + '</tbody></table></div>');
      continue;
    }
    if (t.startsWith('>')) {
      flushPara();
      closeLists();
      const q = [];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        q.push(lines[i].trim().replace(/^>\s?/, ''));
        i++;
      }
      out.push(`<blockquote>${renderMarkdown(q.join('\n')).html}</blockquote>`);
      continue;
    }
    const li = /^(\s*)([-*]|\d+\.)\s+(.*)$/.exec(line);
    if (li) {
      flushPara();
      const indent = li[1].length;
      const ordered = /\d/.test(li[2]);
      const top = listStack[listStack.length - 1];
      if (!top || indent > top.indent) {
        listStack.push({ indent, ordered });
        out.push(ordered ? '<ol><li>' : '<ul><li>');
      } else {
        closeLists(indent);
        const cur = listStack[listStack.length - 1];
        if (cur && cur.indent === indent) out.push('</li><li>');
        else {
          listStack.push({ indent, ordered });
          out.push(ordered ? '<ol><li>' : '<ul><li>');
        }
      }
      out.push(inline(li[3]));
      i++;
      continue;
    }
    if (listStack.length && /^\s{2,}\S/.test(line)) {
      out.push(' ' + inline(t));
      i++;
      continue;
    }
    closeLists();
    para.push(t);
    i++;
  }
  flushPara();
  closeLists();
  return { html: out.join('\n'), toc };
}
