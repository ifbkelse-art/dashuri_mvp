// Deterministic seeded random numbers. Same seed + same inputs => same outputs.

export function createRng(seed) {
  // mulberry32
  let a = (seed >>> 0) || 1;
  const next = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const normal = () => {
    let u = 0;
    let v = 0;
    while (u === 0) u = next();
    while (v === 0) v = next();
    return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
  };
  const binomial = (n, p) => {
    n = Math.max(0, Math.round(n));
    if (n === 0 || p <= 0) return 0;
    if (p >= 1) return n;
    if (n < 60) {
      let k = 0;
      for (let i = 0; i < n; i++) if (next() < p) k++;
      return k;
    }
    const mean = n * p;
    const sd = Math.sqrt(n * p * (1 - p));
    return Math.min(n, Math.max(0, Math.round(mean + sd * normal())));
  };
  const poisson = (lambda) => {
    if (lambda <= 0) return 0;
    if (lambda > 30) return Math.max(0, Math.round(lambda + Math.sqrt(lambda) * normal()));
    const L = Math.exp(-lambda);
    let k = 0;
    let p = 1;
    do {
      k++;
      p *= next();
    } while (p > L);
    return k - 1;
  };
  const pick = (weights) => {
    const total = weights.reduce((s, w) => s + w, 0);
    let r = next() * total;
    for (let i = 0; i < weights.length; i++) {
      r -= weights[i];
      if (r < 0) return i;
    }
    return weights.length - 1;
  };
  return { next, normal, binomial, poisson, pick };
}
