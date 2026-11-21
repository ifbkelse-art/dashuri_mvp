// Shared rendering helpers + sample content for the Dashuri visual handoff.
const PHOTO = {
  ananya:'1624610806209-82a4cbb4339a', meera:'1572943549994-ee6249cc7ba3', riya:'1746265329418-0a063de8cc7d',
  kavya:'1767607740661-05e668190cdc', priya:'1759840278381-bf7d5e332050', ishita:'1793024981458-3b3773613794',
  sneha:'1789500381106-ba13068a6520', tara:'1601583844062-7487c80b56b7', naina:'1747264464985-2bc2e20c739e',
  aditi:'1761125135357-99cbe52a6271', diya:'1630001603446-585f8a8d5527', zoya:'1536766768598-e09213fdcf22',
  sana:'1628620835051-8f40f48c928d',
  arjun:'1670110531916-41045e83cb0a', rohan:'1712425718137-491250cfde88', vikram:'1577933679437-f3171f9b963a',
  // extra host gallery photos (same people where available)
  priya2:'1759840278361-f1adc75529a1',
};
const purl = (k, w=400, h=533) => `https://images.unsplash.com/photo-${PHOTO[k]}?w=${w*2}&h=${h*2}&fit=crop&crop=faces&q=78`;
const ph = (k, cls='', style='', w=400, h=533) => `<div class="ph ${cls}" style="background-image:url('${purl(k,w,h)}');${style}"></div>`;
const av = (k, size=44, st=null, extra='') => `<div class="av" style="width:${size}px;height:${size}px;background-image:url('${purl(k,size*2>200?size*2:200,size*2>200?size*2:200)}');${extra}">${st?`<i class="sdot ${st==='on'?'':st}"></i>`:''}</div>`;

const HOSTS = {
  ananya:{name:'Ananya',age:24,city:'Pune',langs:['Hindi','English','Marathi'],rate:2400,st:'on'},
  meera:{name:'Meera',age:27,city:'Bengaluru',langs:['English','Kannada'],rate:3000,st:'on'},
  riya:{name:'Riya',age:25,city:'Kochi',langs:['Malayalam','English'],rate:1800,st:'on'},
  kavya:{name:'Kavya',age:26,city:'Hyderabad',langs:['Telugu','Hindi'],rate:4500,st:'on'},
  priya:{name:'Priya',age:29,city:'Jaipur',langs:['Hindi','English'],rate:1200,st:'busy'},
  ishita:{name:'Ishita',age:28,city:'Kolkata',langs:['Bengali','Hindi'],rate:2000,st:'on'},
  sneha:{name:'Sneha',age:31,city:'Nagpur',langs:['Marathi','Hindi'],rate:900,st:'on'},
  tara:{name:'Tara',age:26,city:'Mumbai',langs:['English','Hindi'],rate:6000,st:'busy'},
  naina:{name:'Naina',age:23,city:'Delhi',langs:['Hindi','Punjabi'],rate:3600,st:'on'},
  aditi:{name:'Aditi',age:25,city:'Chennai',langs:['Tamil','English'],rate:2200,st:'on'},
  diya:{name:'Diya',age:24,city:'Indore',langs:['Hindi','English'],rate:1500,st:'off'},
  zoya:{name:'Zoya',age:27,city:'Lucknow',langs:['Urdu','Hindi'],rate:2800,st:'on'},
  sana:{name:'Sana',age:26,city:'Goa',langs:['Konkani','English'],rate:2600,st:'off'},
};
const fmt = n => Number(n).toLocaleString('en-IN');
// Customer-facing ₹ hint: approximate, based on the "Popular" simulation pack (₹1,199 / 54,000 D). Labelled ≈.
const inr = d => Math.round(d * 1199 / 54000);
// Host earnings: S3 — 16,670 Diamonds spent = 10,000 Beans; 200 Beans = ₹1.
const beansPerMin = d => Math.round(d * 10000 / 16670);
const rupeesFromBeans = b => (b/200).toLocaleString('en-IN',{minimumFractionDigits:2,maximumFractionDigits:2});

// ---------- Icons ----------
const I = (name, cls='ic', style='') => `<i data-lucide="${name}" class="${cls}" style="${style}"></i>`;
const DIA = (s=18) => `<svg class="cur" width="${s}" height="${s}" viewBox="0 0 24 24"><defs><linearGradient id="gDia" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#EA8DAA"/><stop offset=".5" stop-color="#A83E61"/><stop offset="1" stop-color="#5E1630"/></linearGradient></defs><path d="M6.6 3.2h10.8l4.3 5.4L12 21.2 2.3 8.6z" fill="url(#gDia)"/><path d="M2.3 8.6h19.4M7.8 8.6 12 21.2l4.2-12.6M7.8 8.6 10 3.2M16.2 8.6 14 3.2M7.8 8.6 12 3.4l4.2 5.2" stroke="rgba(255,255,255,.6)" stroke-width=".85" fill="none" stroke-linejoin="round"/></svg>`;
const BEAN = (s=18) => `<svg class="cur" width="${s}" height="${s}" viewBox="0 0 24 24"><defs><linearGradient id="gBean" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F3D695"/><stop offset=".55" stop-color="#C99B47"/><stop offset="1" stop-color="#8A6326"/></linearGradient></defs><ellipse cx="12" cy="12" rx="7.6" ry="9.6" transform="rotate(38 12 12)" fill="url(#gBean)"/><path d="M15.6 6.2c-2.6 1.6-2.4 4.6-3.8 6.6-1.2 1.8-2.9 2.6-4.6 3" stroke="rgba(255,255,255,.75)" stroke-width="1.4" stroke-linecap="round" fill="none"/></svg>`;
const LOGO = (s=56, bg='var(--primary)', fg='#fff') => `<div style="width:${s}px;height:${s}px;border-radius:${s*0.3}px;background:${bg};display:flex;align-items:center;justify-content:center;position:relative;flex:none"><span style="font-family:var(--serif);font-size:${s*0.74}px;line-height:1;color:${fg};margin-top:${s*0.06}px;margin-left:-${s*0.02}px">D</span><svg style="position:absolute;top:${s*0.2}px;right:${s*0.2}px" width="${s*0.18}" height="${s*0.18}" viewBox="0 0 10 10"><path d="M5 0C5.4 3.6 6.4 4.6 10 5 6.4 5.4 5.4 6.4 5 10 4.6 6.4 3.6 5.4 0 5 3.6 4.6 4.6 3.6 5 0z" fill="#E9C98C"/></svg></div>`;
const WORD = (size=28, color='var(--ink)') => `<span style="font-family:var(--serif);font-size:${size}px;line-height:1;color:${color};letter-spacing:-.01em">Dashuri</span>`;

// ---------- Device chrome ----------
const SB = (light=false) => `<div class="statusbar ${light?'light':''}"><span class="num">9:41</span><span class="sb-ic">
<svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor"><rect x="0" y="8" width="3" height="4" rx=".8"/><rect x="4.5" y="5.5" width="3" height="6.5" rx=".8"/><rect x="9" y="3" width="3" height="9" rx=".8"/><rect x="13.5" y="0" width="3" height="12" rx=".8"/></svg>
<svg width="16" height="12" viewBox="0 0 16 12" fill="currentColor"><path d="M8 2.2c2.4 0 4.6.9 6.3 2.5l1.2-1.3C13.5 1.5 10.9.4 8 .4S2.5 1.5.5 3.4l1.2 1.3C3.4 3.1 5.6 2.2 8 2.2zm0 3.6c1.4 0 2.7.5 3.7 1.4l1.2-1.3C11.6 4.7 9.9 4 8 4s-3.6.7-4.9 1.9l1.2 1.3c1-.9 2.3-1.4 3.7-1.4zM8 9.4c-.6 0-1.1.2-1.5.6L8 11.6 9.5 10c-.4-.4-.9-.6-1.5-.6z"/></svg>
<svg width="26" height="12" viewBox="0 0 26 12"><rect x=".5" y=".5" width="22" height="11" rx="3.2" fill="none" stroke="currentColor" opacity=".4"/><rect x="2" y="2" width="16" height="8" rx="1.8" fill="currentColor"/><rect x="23.6" y="4" width="1.8" height="4" rx=".8" fill="currentColor" opacity=".45"/></svg>
</span></div>`;
const GB = (light=false) => `<div class="gesture ${light?'light':''}"><i></i></div>`;

const CNAV = (on) => `<div class="bnav-wrap"><div class="bnav">${[
  ['discover','compass','Discover'],['chats','message-circle','Chats',3],['wallet','gem','Wallet'],['profile','circle-user-round','Profile']
].map(([k,ic,l,b])=>`<div class="it2 ${on===k?'on':''}">${I(ic,'ic',on===k?'stroke-width:2.1':'')}${b?`<span class="nb">${b}</span>`:''}<span>${l}</span></div>`).join('')}</div>${GB()}</div>`;
const HNAV = (on) => `<div class="bnav-wrap"><div class="bnav">${[
  ['home','layout-dashboard','Home'],['calls','video','Calls'],['earnings','coins','Earnings'],['chats','message-circle','Chats',2],['profile','circle-user-round','Profile']
].map(([k,ic,l,b])=>`<div class="it2 ${on===k?'on':''}">${I(ic,'ic',on===k?'stroke-width:2.1':'')}${b?`<span class="nb">${b}</span>`:''}<span>${l}</span></div>`).join('')}</div>${GB()}</div>`;

// Screen shell
function SCR({body, nav='', dark=false, light=false, bg='', noSb=false, noGb=false, overlay=''}){
  return `<div class="screen ${dark?'dark':''}" style="${bg?`background:${bg}`:''}">${noSb?'':SB(light||dark)}${body}${nav}${(!nav && !noGb)?GB(light||dark):''}${overlay}</div>`;
}
const APPBAR = (title='', {left='arrow-left', right='', left2='', align=''}={}) => `<div class="appbar">${left?`<div class="iconbtn">${I(left)}</div>`:'<div style="width:44px"></div>'}<div class="ttl ${align}">${title}</div>${right||'<div style="width:44px"></div>'}</div>`;

// Host card for grids
const HCARD = (k, opts={}) => { const h=HOSTS[k]; const st=opts.st||h.st;
  return `<div class="hcard ${st==='busy'?'busy':''}" style="${opts.h?`height:${opts.h}px`:''}">${ph(k,'',`position:absolute;inset:0`,200,280)}<div class="scrim-b"></div>
  <div class="top">${st==='on'?`<span class="pill-status"><i class="dot on" style="box-shadow:none"></i>Online</span>`:st==='busy'?`<span class="pill-status"><i class="dot busy" style="box-shadow:none"></i>In a call</span>`:`<span class="pill-status"><i class="dot off"></i>Offline</span>`}${opts.verified!==false?`<span class="pill-status" style="padding:0 6px">${I('badge-check','ic-xs')}</span>`:''}</div>
  <div class="bot"><div class="nm">${h.name}, ${h.age}</div><div class="meta">${h.langs.slice(0,2).join(' · ')}</div><div class="rate">${DIA(14)}<span class="num">${fmt(h.rate)}</span><span style="opacity:.75;font-weight:700">/min</span></div></div></div>`; };

const BAL = (n='12,480') => `<div class="balpill">${DIA(18)}<span>${n}</span><span class="plus">${I('plus','ic-xs')}</span></div>`;

// Registry
const REG = [];
function S(meta, fn){ REG.push({...meta, html:fn}); }
