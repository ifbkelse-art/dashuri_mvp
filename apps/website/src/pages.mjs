// Marketing and contact pages. Only claims the app actually supports today;
// see README.md "Content rules" before adding any.

const i = {
  shield: '<path d="M12 3l8 3v6c0 4.5-3.4 8.3-8 9-4.6-.7-8-4.5-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  video: '<rect x="3" y="6" width="13" height="12" rx="2"/><path d="M16 10l5-3v10l-5-3"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/>',
  flag: '<path d="M5 21V4"/><path d="M5 4h11l-2 4 2 4H5"/>',
  lock: '<rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 018 0v3"/>',
  pin: '<path d="M12 21s-7-6.2-7-11a7 7 0 0114 0c0 4.8-7 11-7 11z"/><circle cx="12" cy="10" r="2.5"/>',
  chat: '<path d="M4 5h16v11H9l-5 4z"/>',
  id: '<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="12" r="2.5"/><path d="M14 10h4M14 14h4"/>',
  coin: '<circle cx="12" cy="12" r="8"/><path d="M9 12h6M12 9v6"/>',
  mic: '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0014 0M12 18v3"/>',
  phone: '<path d="M4 15c4 4 12 4 16 0l-2-3-3 1c-2-1-4-1-6 0l-3-1z"/>',
};
const icon = (name) => `<div class="icon"><svg viewBox="0 0 24 24" aria-hidden="true">${i[name]}</svg></div>`;
const card = (ic, title, text) => `<div class="card">${icon(ic)}<h3 class="h3">${title}</h3><p>${text}</p></div>`;

function download(site, label = 'Get Dashuri on Google Play') {
  return site.playStoreUrl
    ? `<a class="btn btn-primary" href="${site.playStoreUrl}" rel="noopener">${label}</a>`
    : `<span class="btn" aria-disabled="true">Coming soon to Google Play</span>`;
}

function home(site) {
  return `
<section class="hero"><div class="wrap">
  <div>
    <p class="eyebrow">Video calls · 18+ · India</p>
    <h1 class="display">Real conversations, face to face.</h1>
    <p class="lead">Dashuri connects you with hosts for one-to-one video calls. You see the price per minute before you call, and you only pay for the time you talk.</p>
    <div class="actions">${download(site)}<a class="btn btn-ghost" href="/hosts/">Become a host</a></div>
  </div>
  <div class="call-card" role="img" aria-label="Illustration of a Dashuri video call screen">
    <div class="row"><span class="pill"><span class="dot"></span>Online</span><span class="pill">04:12</span></div>
    <div>
      <div class="avatar" aria-hidden="true">A</div>
      <div class="name">Ananya</div>
      <div class="meta">Hindi · English · Pune</div>
    </div>
    <div class="controls" aria-hidden="true">
      <span><svg viewBox="0 0 24 24">${i.mic}</svg></span>
      <span><svg viewBox="0 0 24 24">${i.video}</svg></span>
      <span class="end"><svg viewBox="0 0 24 24">${i.phone}</svg></span>
    </div>
  </div>
</div></section>

<section class="section" id="how"><div class="wrap">
  <div class="section-head"><p class="eyebrow">How it works</p><h2 class="h2">Three steps to a conversation</h2></div>
  <div class="grid grid-3">
    <div class="card"><div class="num">1</div><h3 class="h3">Sign in with your number</h3><p>Verify your mobile number and confirm you are 18 or older. One account per number.</p></div>
    <div class="card"><div class="num">2</div><h3 class="h3">Find a host</h3><p>Browse hosts by language and city, see who is online and check each host’s rate per minute.</p></div>
    <div class="card"><div class="num">3</div><h3 class="h3">Start a video call</h3><p>Calls use Diamonds, bought through Google Play. Billing is per minute, measured by our servers, and stops when the call ends.</p></div>
  </div>
</div></section>

<section class="section"><div class="wrap split">
  <div>
    <p class="eyebrow">Clear pricing</p>
    <h2 class="h2">You see the price before every call</h2>
    <p class="lead">No hidden charges and no subscriptions.</p>
  </div>
  <ul class="checks">
    <li>Each host shows their rate in Diamonds per minute before you call.</li>
    <li>Calls that never connect are not charged; reserved Diamonds come back automatically.</li>
    <li>Your wallet shows every purchase and every call.</li>
    <li>Diamonds are added only after Google Play confirms the payment.</li>
  </ul>
</div></section>

<section class="section"><div class="wrap">
  <div class="section-head"><p class="eyebrow">Safety</p><h2 class="h2">Built for adults, designed to be safe</h2><p class="muted">Safety tools are part of every call, not an afterthought.</p></div>
  <div class="grid grid-3">
    ${card('shield', 'Adults only', 'Everyone confirms they are 18 or older, and hosts are checked with ID before they can take calls.')}
    ${card('flag', 'Report and block', 'Report or block anyone during or after a call. Reports are reviewed by our team.')}
    ${card('lock', 'Your privacy', 'Calls are not recorded, and you choose who can message you.')}
  </div>
  <div class="actions"><a class="btn btn-ghost" href="/safety/">How we keep Dashuri safe</a></div>
</div></section>

<section class="section"><div class="wrap">
  <div class="section-head"><p class="eyebrow">Questions</p><h2 class="h2">Frequently asked</h2></div>
  <details class="faq"><summary>Who can use Dashuri?</summary><p>Adults aged 18 or older in India with a mobile number. Anyone under 18 is not allowed.</p></details>
  <details class="faq"><summary>What are Diamonds?</summary><p>Diamonds are the in-app currency for video calls. You buy them through Google Play. They have no cash value and can’t be transferred.</p></details>
  <details class="faq"><summary>How much does a call cost?</summary><p>Each host sets a rate in Diamonds per minute, and you see it before you call. You pay only for the time the call is connected.</p></details>
  <details class="faq"><summary>Are calls recorded?</summary><p>No. Dashuri does not record call audio or video. For safety, still frames from the first minutes of a call may be checked automatically. See the <a href="/privacy/">Privacy Policy</a>.</p></details>
  <details class="faq"><summary>How do I delete my account?</summary><p>In the app, go to Settings › Delete account. You can also ask by email. See <a href="/delete-account/">Delete your account</a>.</p></details>
</div></section>

<section class="section"><div class="wrap">
  <div class="band">
    <h2 class="h2">Start a real conversation.</h2>
    <p>Dashuri is coming to Google Play for adults in India.</p>
    <div class="actions actions-tight">${download(site)}</div>
  </div>
</div></section>`;
}

function hosts(site) {
  return `
<section class="hero"><div class="wrap">
  <div>
    <p class="eyebrow">For hosts</p>
    <h1 class="display">Host calls on your own schedule.</h1>
    <p class="lead">Go online when it suits you, set your own rate within your level’s limits, and earn Beans for every minute you talk.</p>
    <div class="actions">${download(site, 'Get the app to apply')}<a class="btn btn-ghost" href="/community-guidelines/">Read the guidelines</a></div>
  </div>
  <div class="card">
    <p class="eyebrow">What you need</p>
    <ul class="checks">
      <li>You are 18 or older and live in India.</li>
      <li>A government ID for a one-time identity check.</li>
      <li>A phone with a front camera and a steady internet connection.</li>
      <li>You agree to the <a href="/host-agreement/">Host Agreement</a> and <a href="/community-guidelines/">Community Guidelines</a>.</li>
    </ul>
  </div>
</div></section>

<section class="section"><div class="wrap">
  <div class="section-head"><p class="eyebrow">How hosting works</p><h2 class="h2">From application to your first call</h2></div>
  <div class="grid grid-2">
    ${card('id', 'Apply in the app', 'Fill in your host profile and complete the ID check. Our team reviews every application by hand.')}
    ${card('clock', 'Go online when you want', 'Switch to available whenever you are free. Callers see that you are online and can call you.')}
    ${card('coin', 'Set your rate', 'Choose your price per minute. The highest rate you can set grows as your level grows.')}
    ${card('video', 'Earn Beans', 'You earn Beans for the minutes you talk. Your earnings screen shows every call.')}
  </div>
</div></section>

<section class="section"><div class="wrap split">
  <div><p class="eyebrow">Withdrawals</p><h2 class="h2">Payouts open after launch</h2></div>
  <div>
    <p class="lead">Withdrawals to a bank account or UPI ID in your own name will open after Dashuri’s launch, once payouts are set up. We will announce the date in the app.</p>
    <p class="muted">Questions about hosting? Email <a href="mailto:${site.supportEmail}">${site.supportEmail}</a>.</p>
  </div>
</div></section>`;
}

function safety(site) {
  return `
<section class="hero"><div class="wrap">
  <div>
    <p class="eyebrow">Safety</p>
    <h1 class="display">Safe conversations, by design.</h1>
    <p class="lead">Dashuri is for adults only. These are the tools and rules that protect every call.</p>
  </div>
</div></section>

<section class="section"><div class="wrap">
  <div class="grid grid-3">
    ${card('shield', 'Adults only', 'Everyone confirms their date of birth. Under-18 declarations are refused, and hosts are checked with ID.')}
    ${card('video', 'Automatic safety checks', 'During the first minutes of a call, still frames may be checked automatically for nudity. A flagged call can be ended.')}
    ${card('flag', 'Report and block', 'Report someone during or after a call, or block them so they can’t find or contact you again.')}
    ${card('chat', 'Protected messages', 'You can limit messages to people you have called, and sharing phone numbers or social handles is not allowed.')}
    ${card('pin', 'Coarse location only', 'Showing your city is optional. If you use your location, it is used once to find the nearest city and never stored.')}
    ${card('lock', 'No recordings', 'Calls are not recorded. We keep call records like time and length because billing depends on them.')}
  </div>
</div></section>

<section class="section"><div class="wrap split">
  <div><p class="eyebrow">Child safety</p><h2 class="h2">Zero tolerance for child abuse</h2></div>
  <div>
    <p class="lead">Dashuri prohibits any child sexual abuse material and any contact with minors. Accounts that break this rule are removed and reported to the authorities.</p>
    <p class="muted">Read our <a href="/child-safety/">Child Safety Standards</a>. To report a concern, use “Appears to be under 18” in the app or email <a href="mailto:${site.supportEmail}">${site.supportEmail}</a>.</p>
  </div>
</div></section>`;
}

function contact(site) {
  return `
<section class="doc"><div class="wrap">
  <p class="eyebrow">Contact</p>
  <h1>Get in touch</h1>
  <p class="lead">We read every message.</p>
  <div class="doc-list">
    <a href="mailto:${site.supportEmail}"><strong>Support</strong><span>${site.supportEmail}: account, calls, Diamonds and hosting questions.</span></a>
    <a href="/grievance/"><strong>Complaints</strong><span>Raise a grievance under India’s IT Rules, 2021.</span></a>
    <a href="/child-safety/"><strong>Child safety</strong><span>Report a concern about a minor.</span></a>
    <a href="/delete-account/"><strong>Delete your account</strong><span>Steps with or without the app.</span></a>
  </div>
  <p class="muted spaced">In the app you can also use Settings › Help &amp; support.</p>
</div></section>`;
}

function notFound() {
  return `
<section class="doc"><div class="wrap">
  <p class="eyebrow">404</p>
  <h1>Page not found</h1>
  <p class="lead">The page you were looking for doesn’t exist.</p>
  <div class="actions"><a class="btn btn-primary" href="/">Go to the home page</a></div>
</div></section>`;
}

export function pages(site) {
  return [
    { path: '/', title: 'Home', description: 'One-to-one video calls with hosts, for adults in India. See the price before you call; pay only for the minutes you talk.', body: home(site) },
    { path: '/hosts/', title: 'Become a host', description: 'Host video calls on Dashuri on your own schedule and earn Beans for every minute.', body: hosts(site) },
    { path: '/safety/', title: 'Safety', description: 'How Dashuri keeps calls safe: adults only, ID-checked hosts, reporting, blocking and automatic safety checks.', body: safety(site) },
    { path: '/contact/', title: 'Contact', description: 'Contact Dashuri support, raise a complaint or report a safety concern.', body: contact(site) },
    { path: '/404', title: 'Page not found', description: 'Page not found.', body: notFound() },
  ];
}
