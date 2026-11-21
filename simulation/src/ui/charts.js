// Small dependency-free SVG chart helpers. Colors come from CSS tokens.
const NS = 'http://www.w3.org/2000/svg';
const el = (tag, attrs = {}, parent) => {
  const e = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  if (parent) parent.appendChild(e);
  return e;
};

function niceScale(min, max, ticks = 5) {
  if (min === max) {
    if (min === 0) return { min: 0, max: 1, step: 0.25, ticks: [0, 0.25, 0.5, 0.75, 1] };
    const pad = Math.abs(min) * 0.1;
    min -= pad;
    max += pad;
  }
  const span = max - min;
  const raw = span / ticks;
  const mag = Math.pow(10, Math.floor(Math.log10(raw)));
  const norm = raw / mag;
  const step = (norm < 1.5 ? 1 : norm < 3 ? 2 : norm < 7 ? 5 : 10) * mag;
  const lo = Math.floor(min / step) * step;
  const hi = Math.ceil(max / step) * step;
  const t = [];
  for (let v = lo; v <= hi + step / 2; v += step) t.push(Math.abs(v) < step / 1e6 ? 0 : v);
  return { min: lo, max: hi, step, ticks: t };
}

function tooltipFor(container) {
  let tip = container.querySelector('.chart-tip');
  if (!tip) {
    tip = document.createElement('div');
    tip.className = 'chart-tip';
    tip.hidden = true;
    container.appendChild(tip);
  }
  return tip;
}

function legend(container, series) {
  if (series.length < 2) return;
  const lg = document.createElement('div');
  lg.className = 'chart-legend';
  for (const s of series) {
    const item = document.createElement('span');
    item.className = 'chart-legend-item';
    const sw = document.createElement('i');
    sw.style.background = s.color;
    if (s.dashed) sw.className = 'dashed';
    item.append(sw, document.createTextNode(s.name));
    lg.appendChild(item);
  }
  container.appendChild(lg);
}

/**
 * Line chart. opts: { labels, series:[{name,color,values,dashed}], yFormat, height, zeroLine, band:{lo,hi,color} }
 */
export function lineChart(container, opts) {
  container.innerHTML = '';
  container.classList.add('chart');
  const W = Math.max(300, Math.round(container.clientWidth || 640));
  const H = opts.height || 240;
  const m = { t: 12, r: 16, b: 28, l: 64 };
  const all = opts.series.flatMap((s) => s.values).concat(opts.band ? [...opts.band.lo, ...opts.band.hi] : []).filter(Number.isFinite);
  let lo = Math.min(...all, opts.zeroLine !== false ? 0 : Infinity);
  let hi = Math.max(...all, opts.zeroLine !== false ? 0 : -Infinity);
  const sc = niceScale(lo, hi);
  const n = opts.labels.length;
  const x = (i) => m.l + (n === 1 ? (W - m.l - m.r) / 2 : (i * (W - m.l - m.r)) / (n - 1));
  const y = (v) => m.t + ((sc.max - v) * (H - m.t - m.b)) / (sc.max - sc.min || 1);
  const svg = el('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': opts.title || 'line chart' });
  for (const t of sc.ticks) {
    el('line', { x1: m.l, x2: W - m.r, y1: y(t), y2: y(t), class: t === 0 ? 'axis-zero' : 'grid' }, svg);
    const tx = el('text', { x: m.l - 8, y: y(t) + 4, 'text-anchor': 'end', class: 'tick' }, svg);
    tx.textContent = opts.yFormat ? opts.yFormat(t) : t;
  }
  const every = Math.ceil(n / 8);
  opts.labels.forEach((l, i) => {
    if (i % every && i !== n - 1) return;
    const tx = el('text', { x: x(i), y: H - 8, 'text-anchor': 'middle', class: 'tick' }, svg);
    tx.textContent = l;
  });
  if (opts.band) {
    const pts = opts.band.hi.map((v, i) => `${x(i)},${y(v)}`).concat(opts.band.lo.map((v, i) => `${x(i)},${y(v)}`).reverse());
    el('polygon', { points: pts.join(' '), fill: opts.band.color, opacity: 0.14 }, svg);
  }
  for (const s of opts.series) {
    const d = s.values.map((v, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join('');
    el('path', { d, fill: 'none', stroke: s.color, 'stroke-width': 2, 'stroke-linejoin': 'round', 'stroke-dasharray': s.dashed ? '5 4' : 'none', 'vector-effect': 'non-scaling-stroke' }, svg);
    if (n <= 12) s.values.forEach((v, i) => el('circle', { cx: x(i), cy: y(v), r: 3.5, fill: s.color, stroke: 'var(--surface)', 'stroke-width': 2, 'vector-effect': 'non-scaling-stroke' }, svg));
  }
  const cross = el('line', { y1: m.t, y2: H - m.b, class: 'crosshair', visibility: 'hidden' }, svg);
  const wrap = document.createElement('div');
  wrap.className = 'chart-plot';
  wrap.appendChild(svg);
  container.appendChild(wrap);
  legend(container, opts.series);
  const tip = tooltipFor(wrap);
  const hit = el('rect', { x: m.l, y: m.t, width: W - m.l - m.r, height: H - m.t - m.b, fill: 'transparent' }, svg);
  const move = (ev) => {
    const r = svg.getBoundingClientRect();
    const px = ((ev.clientX - r.left) / r.width) * W;
    const i = Math.max(0, Math.min(n - 1, Math.round(((px - m.l) / (W - m.l - m.r)) * (n - 1))));
    cross.setAttribute('x1', x(i));
    cross.setAttribute('x2', x(i));
    cross.setAttribute('visibility', 'visible');
    tip.hidden = false;
    tip.innerHTML = `<b>${opts.labels[i]}</b>` + opts.series.map((s) => `<div><i style="background:${s.color}"></i>${s.name}<span>${opts.yFormat ? opts.yFormat(s.values[i]) : s.values[i]}</span></div>`).join('');
    const left = (x(i) / W) * r.width;
    tip.style.left = Math.min(r.width - tip.offsetWidth - 4, Math.max(4, left + 12)) + 'px';
    tip.style.top = '8px';
  };
  hit.addEventListener('pointermove', move);
  hit.addEventListener('pointerleave', () => {
    tip.hidden = true;
    cross.setAttribute('visibility', 'hidden');
  });
}

/**
 * Grouped or stacked vertical bar chart.
 * opts: { labels, series:[{name,color,values}], stacked, yFormat, height }
 */
export function barChart(container, opts) {
  container.innerHTML = '';
  container.classList.add('chart');
  const W = Math.max(300, Math.round(container.clientWidth || 640));
  const H = opts.height || 240;
  const m = { t: 12, r: 16, b: 28, l: 64 };
  const n = opts.labels.length;
  let vals;
  if (opts.stacked) {
    vals = [];
    for (let i = 0; i < n; i++) {
      let pos = 0;
      let neg = 0;
      for (const s of opts.series) {
        const v = s.values[i] || 0;
        if (v >= 0) pos += v;
        else neg += v;
      }
      vals.push(pos, neg);
    }
  } else vals = opts.series.flatMap((s) => s.values);
  const sc = niceScale(Math.min(0, ...vals), Math.max(0, ...vals));
  const y = (v) => m.t + ((sc.max - v) * (H - m.t - m.b)) / (sc.max - sc.min || 1);
  const band = (W - m.l - m.r) / n;
  const svg = el('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': opts.title || 'bar chart' });
  for (const t of sc.ticks) {
    el('line', { x1: m.l, x2: W - m.r, y1: y(t), y2: y(t), class: t === 0 ? 'axis-zero' : 'grid' }, svg);
    const tx = el('text', { x: m.l - 8, y: y(t) + 4, 'text-anchor': 'end', class: 'tick' }, svg);
    tx.textContent = opts.yFormat ? opts.yFormat(t) : t;
  }
  const groups = [];
  opts.labels.forEach((l, i) => {
    const tx = el('text', { x: m.l + band * i + band / 2, y: H - 8, 'text-anchor': 'middle', class: 'tick' }, svg);
    tx.textContent = l;
    const g = el('g', {}, svg);
    groups.push(g);
    const inner = band * 0.7;
    const x0 = m.l + band * i + (band - inner) / 2;
    if (opts.stacked) {
      let pos = 0;
      let neg = 0;
      for (const s of opts.series) {
        const v = s.values[i] || 0;
        const from = v >= 0 ? pos : neg;
        const to = from + v;
        if (v >= 0) pos = to;
        else neg = to;
        const yy = Math.min(y(from), y(to));
        const h = Math.max(0, Math.abs(y(to) - y(from)) - 1);
        el('rect', { x: x0, y: yy, width: inner, height: h, fill: s.color, rx: 2 }, g);
      }
    } else {
      const k = opts.series.length;
      const bw = Math.max(2, inner / k - 2);
      opts.series.forEach((s, j) => {
        const v = s.values[i] || 0;
        const yy = Math.min(y(0), y(v));
        el('rect', { x: x0 + j * (bw + 2), y: yy, width: bw, height: Math.max(1, Math.abs(y(v) - y(0))), fill: s.color, rx: 3 }, g);
      });
    }
    const hit = el('rect', { x: m.l + band * i, y: m.t, width: band, height: H - m.t - m.b, fill: 'transparent' }, g);
    hit.addEventListener('pointerenter', () => {
      const tip = tooltipFor(wrap);
      tip.hidden = false;
      tip.innerHTML = `<b>${l}</b>` + opts.series.map((s) => `<div><i style="background:${s.color}"></i>${s.name}<span>${opts.yFormat ? opts.yFormat(s.values[i]) : s.values[i]}</span></div>`).join('');
      const r = svg.getBoundingClientRect();
      const left = ((m.l + band * (i + 1)) / W) * r.width;
      tip.style.left = Math.min(r.width - tip.offsetWidth - 4, Math.max(4, left + 4)) + 'px';
      tip.style.top = '8px';
      g.classList.add('hover');
    });
    hit.addEventListener('pointerleave', () => {
      tooltipFor(wrap).hidden = true;
      g.classList.remove('hover');
    });
  });
  const wrap = document.createElement('div');
  wrap.className = 'chart-plot';
  wrap.appendChild(svg);
  container.appendChild(wrap);
  legend(container, opts.series);
}

/** Horizontal tornado chart. rows: [{label, lo, hi, loLabel, hiLabel}], base value. */
export function tornadoChart(container, { rows, base, format, loColor, hiColor }) {
  container.innerHTML = '';
  container.classList.add('chart');
  const rowH = 30;
  const W = Math.max(300, Math.round(container.clientWidth || 640));
  const m = { t: 24, r: 16, b: 20, l: Math.min(230, Math.round(W * 0.42)) };
  const H = m.t + m.b + rows.length * rowH;
  const vals = rows.flatMap((r) => [r.lo, r.hi]).concat(base);
  const sc = niceScale(Math.min(...vals), Math.max(...vals), 4);
  const x = (v) => m.l + ((v - sc.min) * (W - m.l - m.r)) / (sc.max - sc.min || 1);
  const svg = el('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': 'tornado chart' });
  for (const t of sc.ticks) {
    el('line', { x1: x(t), x2: x(t), y1: m.t - 6, y2: H - m.b, class: t === 0 ? 'axis-zero' : 'grid' }, svg);
    const tx = el('text', { x: x(t), y: m.t - 10, 'text-anchor': 'middle', class: 'tick' }, svg);
    tx.textContent = format(t);
  }
  el('line', { x1: x(base), x2: x(base), y1: m.t - 6, y2: H - m.b, class: 'baseline-mark' }, svg);
  rows.forEach((r, i) => {
    const yy = m.t + i * rowH + 6;
    const lab = el('text', { x: m.l - 10, y: yy + 12, 'text-anchor': 'end', class: 'row-label' }, svg);
    lab.textContent = r.label;
    const drawBar = (v, color, text) => {
      const x0 = Math.min(x(base), x(v));
      const w = Math.max(1, Math.abs(x(v) - x(base)));
      const rect = el('rect', { x: x0, y: yy, width: w, height: 16, fill: color, rx: 3 }, svg);
      const t = el('title', {}, rect);
      t.textContent = `${r.label}: ${text} → ${format(v)}`;
    };
    drawBar(r.lo, loColor, r.loLabel);
    drawBar(r.hi, hiColor, r.hiLabel);
  });
  container.appendChild(svg);
  const lg = document.createElement('div');
  lg.className = 'chart-legend';
  lg.innerHTML = `<span class="chart-legend-item"><i style="background:${loColor}"></i>Low setting</span><span class="chart-legend-item"><i style="background:${hiColor}"></i>High setting</span><span class="chart-legend-item"><i class="base-swatch"></i>Scenario result ${format(base)}</span>`;
  container.appendChild(lg);
}

/** Histogram of values into bins. */
export function histogram(container, { values, bins = 8, color, format }) {
  if (!values.length) {
    container.innerHTML = '<p class="muted">No active hosts.</p>';
    return;
  }
  const max = Math.max(...values, 1);
  const step = niceScale(0, max, bins).step;
  const nb = Math.max(1, Math.ceil((max + 1e-9) / step));
  const counts = new Array(nb).fill(0);
  for (const v of values) counts[Math.min(nb - 1, Math.floor(v / step))] += 1;
  const labels = counts.map((_, i) => `${format(i * step)}–${format((i + 1) * step)}`);
  barChart(container, { labels, series: [{ name: 'Hosts', color, values: counts }], yFormat: (v) => Math.round(v), height: 220 });
}
