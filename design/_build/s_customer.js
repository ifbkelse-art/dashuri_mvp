// CUSTOMER — DISCOVERY & HOST PROFILES
const F_CUS='Customer';
const HOMEHEAD = (bal='12,480', dot=true) => `<div class="row between" style="padding:6px 20px 0 20px;height:52px">${WORD(30)}<div class="row g8">${BAL(bal)}<div class="iconbtn filled" style="width:40px;height:40px">${I('bell','ic-s')}${dot?'<i class="badge-dot" style="top:8px;right:9px"></i>':''}</div></div></div>`;
const LANGCHIPS = (on='All') => `<div class="row g8" style="padding:0 20px;overflow:hidden"><div class="chip" style="padding:0 11px">${I('sliders-horizontal','ic-s')}</div>${['All','Hindi','English','Tamil','Telugu','Bengali'].map(l=>`<div class="chip ${l===on?'on':''}">${l}</div>`).join('')}</div>`;

S({id:'C01',folder:F_CUS,name:'Home_Discover',title:'Home — Discover hosts',
 desc:'The customer home. A live grid of verified hosts who are online now, filterable by language. Each card shows status, name, age, languages and Diamond rate.',
 notes:['Balance pill (top right) opens Wallet; "+" opens Buy Diamonds.','Only Online hosts can be called; "In a call" hosts are shown dimmed with an amber status and sort after online hosts.','Grid updates in real time (Supabase Realtime presence). Pull to refresh.','Card tap → Host profile (C07). Long-press is not used.','Rates come from HostCard.ratePerMinute; never computed on device.'],
 to:['C03','C07','W01','C11']},
()=>SCR({body:`${HOMEHEAD()}<div class="content">
  <div class="pad mt8 mb16"><div class="b-m ink2">Good evening, Arjun</div><div class="d-s mt4">Who would you like to talk to?</div></div>
  ${LANGCHIPS()}
  <div class="section-h mt20"><span class="t row g8"><i class="dot on"></i>Online now <span class="ink3" style="font-weight:700">· 128</span></span><span class="a row g4">Recommended ${I('chevron-down','ic-xs')}</span></div>
  <div class="hgrid">${['ananya','meera','kavya','riya','priya','naina'].map(k=>HCARD(k)).join('')}</div>
 </div>`, nav:CNAV('discover')}));

S({id:'C02',folder:F_CUS,name:'Home_New_Customer_Free_Call',title:'Home — new customer with Free Call Card',
 desc:'First-session home for an eligible new customer on Android. The Free Call Card offers one free random minute with a host who opted in to free calls.',
 notes:['Card appears only for eligible accounts (one per phone and device) and is hidden on iOS.','Zero balance pill shows "0" with the add affordance.','Dismissible with ✕; re-accessible from Wallet until used. Expiry rules — D-05.'],
 flags:['D-05'],to:['C10','C07','W02']},
()=>SCR({body:`${HOMEHEAD('0',false)}<div class="content">
  <div class="pad mt8"><div class="whero" style="padding:20px;border-radius:24px">
   <div class="row between"><span class="tag" style="background:rgba(255,255,255,.16);color:#fff">${I('gift','ic-xs')}Welcome gift</span><span style="opacity:.6">${I('x','ic-s')}</span></div>
   <div class="d-m mt16" style="color:#fff">Your first minute<br>is <span class="it" style="color:#F0CF8A">on us</span></div>
   <div class="b-m mt8" style="opacity:.8;max-width:250px">Get matched with a host who's online now for a free one-minute video call.</div>
   <div class="row g12 mt20"><div class="btn white sm">${I('sparkles','ic-s')}Start free call</div><div class="row" style="margin-left:4px">${['naina','riya','aditi'].map((k,i)=>`<div style="margin-left:${i?-10:0}px">${av(k,32,null,'border:2px solid #761C3B')}</div>`).join('')}</div></div>
  </div></div>
  <div class="mt20">${LANGCHIPS()}</div>
  <div class="section-h mt20"><span class="t row g8"><i class="dot on"></i>Online now <span class="ink3" style="font-weight:700">· 128</span></span><span class="a row g4">Recommended ${I('chevron-down','ic-xs')}</span></div>
  <div class="hgrid">${['ananya','meera','kavya','riya'].map(k=>HCARD(k)).join('')}</div>
 </div>`, nav:CNAV('discover')}));

S({id:'C03',folder:F_CUS,name:'Discover_Filters',title:'Discovery filters (bottom sheet)',
 desc:'Filter and sort sheet opened from the filter chip. Filters stay free for everyone (language, rate). Result count updates live on the primary button.',
 notes:['Languages: multi-select chips.','Rate range slider spans the platform range 500–10,000 Diamonds/min.','"Show hosts in a call" includes busy hosts (not callable) for browsing.','Sort options beyond "Recommended" need confirmation — D-06.'],
 flags:['D-06'],to:['C01','C05']},
()=>SCR({body:`${HOMEHEAD()}<div class="content"><div class="pad mt8"><div class="d-s">Who would you like to talk to?</div></div><div class="mt16">${LANGCHIPS('Hindi')}</div><div class="hgrid mt20">${['ananya','meera','kavya','riya'].map(k=>HCARD(k)).join('')}</div></div>`, nav:CNAV('discover'),
 overlay:`<div class="dim"></div><div class="sheet" style="top:96px;padding-bottom:0;display:flex;flex-direction:column"><div class="grab"></div>
  <div class="row between"><span class="t-l">Filters</span><span class="lbl pri">Reset</span></div>
  <div class="t-s mt24">Languages</div>
  <div class="row wrap g8 mt12">${['Hindi','English','Tamil','Telugu','Bengali','Marathi','Kannada','Malayalam','Punjabi','Urdu'].map(l=>`<div class="chip sm ${['Hindi','English'].includes(l)?'pon':''}" style="height:34px;font-size:13px">${['Hindi','English'].includes(l)?I('check','ic-xs'):''}${l}</div>`).join('')}</div>
  <div class="row between mt24"><span class="t-s">Rate per minute</span><span class="b-m ink2 row g4">${DIA(14)}<b class="num" style="color:var(--ink)">1,000 – 4,000</b></span></div>
  <div style="position:relative;height:36px;margin-top:10px"><div style="position:absolute;left:0;right:0;top:16px;height:4px;border-radius:2px;background:var(--n100)"></div><div style="position:absolute;left:5%;right:63%;top:16px;height:4px;border-radius:2px;background:var(--primary)"></div>${[5,37].map(p=>`<div style="position:absolute;left:calc(${p}% - 13px);top:5px;width:26px;height:26px;border-radius:13px;background:#fff;border:2px solid var(--primary);box-shadow:var(--sh2)"></div>`).join('')}</div>
  <div class="row between cap ink3"><span class="num">500</span><span class="num">10,000</span></div>
  <div class="t-s mt24">Sort by</div>
  <div class="col mt8">${[['Recommended',1],['Rate: low to high',0],['Rate: high to low',0],['Recently online',0]].map(([l,on])=>`<div class="row between" style="height:44px"><span class="b-l" style="font-weight:600">${l}</span><div class="radio ${on?'on':''}"></div></div>`).join('')}</div>
  <div class="hr mt8"></div>
  <div class="row between" style="height:60px"><div><div class="t-s">Show hosts in a call</div><div class="b-s ink3">You can view them, but can't call until they're free</div></div><div class="switch"></div></div>
  <div class="spacer"></div><div class="btn pri full">Show 46 hosts</div>${GB()}</div>`}));

S({id:'C04',folder:F_CUS,name:'Discover_Empty_No_Hosts',title:'Discover — no hosts online (empty)',
 desc:'Empty state when no host is online. Hosts choose when to go online, so this is expected at off-peak times and must feel calm, not broken.',
 notes:['No scheduling or booking options (business rule: no scheduled bookings).','Refresh re-queries presence; the list also updates automatically.','Balance pill and navigation remain available.'],
 to:['C01']},
()=>SCR({body:`${HOMEHEAD()}<div class="content col">
  <div class="mt16">${LANGCHIPS()}</div>
  <div class="spacer"></div>
  <div class="empty"><div class="art">${I('moon-star','ic-xl')}</div>
   <div class="d-s">It's quiet right now</div>
   <div class="b-l ink2 mt8">No hosts are online at the moment. Hosts go online whenever they like — this page updates the second someone does.</div>
   <div class="btn neu sm mt24">${I('refresh-cw','ic-s')}Refresh</div></div>
  <div class="spacer"></div><div class="spacer"></div></div>`, nav:CNAV('discover')}));

S({id:'C05',folder:F_CUS,name:'Discover_No_Filter_Results',title:'Discover — no results for filters',
 desc:'Empty state when filters exclude every online host. Shows the active filters as removable chips and a one-tap reset.',
 notes:['Active filter chips each have an ✕.','"Clear all filters" restores the default grid.','Count of all online hosts is shown to encourage widening the search.'],
 to:['C01','C03']},
()=>SCR({body:`${HOMEHEAD()}<div class="content col">
  <div class="row g8 mt16" style="padding:0 20px"><div class="chip on" style="padding:0 11px">${I('sliders-horizontal','ic-s')}<span>2</span></div><div class="chip pon">Punjabi ${I('x','ic-xs')}</div><div class="chip pon row g4">${DIA(14)} Under 1,000 ${I('x','ic-xs')}</div></div>
  <div class="spacer"></div>
  <div class="empty"><div class="art">${I('search-x','ic-xl')}</div>
   <div class="d-s">No hosts match</div>
   <div class="b-l ink2 mt8">Nobody online fits these filters right now. 128 other hosts are online.</div>
   <div class="btn pri sm mt24">Clear all filters</div></div>
  <div class="spacer"></div><div class="spacer"></div></div>`, nav:CNAV('discover')}));

S({id:'C06',folder:F_CUS,name:'Discover_Loading',title:'Discover — loading skeleton',
 desc:'Skeleton state while the first page of hosts loads. Mirrors the real card geometry to avoid layout shift.',
 notes:['Shimmer animation, 1.2 s loop.','Header and balance render immediately from cache.','Errors replace the grid with an inline retry banner.'],
 to:['C01']},
()=>SCR({body:`${HOMEHEAD()}<div class="content">
  <div class="pad mt8 mb16"><div class="b-m ink2">Good evening, Arjun</div><div class="d-s mt4">Who would you like to talk to?</div></div>
  <div class="row g8" style="padding:0 20px">${[44,56,72,62,58].map(w=>`<div class="sk" style="width:${w}px;height:36px;border-radius:18px"></div>`).join('')}</div>
  <div class="section-h mt20"><div class="sk" style="width:120px;height:18px"></div><div class="sk" style="width:90px;height:14px"></div></div>
  <div class="hgrid">${Array.from({length:6},()=>`<div style="height:236px;border-radius:20px;background:var(--n100);position:relative;overflow:hidden"><div class="sk" style="position:absolute;left:12px;bottom:46px;width:90px;height:16px;background:var(--n200)"></div><div class="sk" style="position:absolute;left:12px;bottom:26px;width:70px;height:12px;background:var(--n200)"></div><div class="sk" style="position:absolute;left:12px;top:12px;width:62px;height:22px;border-radius:12px;background:var(--n200)"></div></div>`).join('')}</div>
 </div>`, nav:CNAV('discover')}));

const BIO={ananya:"Chai over coffee, old Bollywood songs and long conversations about travel. Let's talk about anything except work!",
 priya:"Jaipur girl, textile designer by day. Ask me about block prints, street food and the best sunsets in Rajasthan.",
 diya:"Literature student and amateur baker. I love hearing about the places people grew up in."};
const PROFILE = (k, state) => { const h=HOSTS[k];
  const st = state==='on'?`<span class="tag ok"><i class="dot on" style="box-shadow:none;width:7px;height:7px"></i>Online now</span>`:state==='busy'?`<span class="tag warn"><i class="dot busy" style="box-shadow:none;width:7px;height:7px"></i>In a call</span>`:`<span class="tag"><i class="dot off" style="width:7px;height:7px"></i>Offline · last seen 2h ago</span>`;
  const cta = state==='on'?`<div class="btn pri f1">${I('video','ic-s')}Video call</div>`:state==='busy'?`<div class="btn dis f1">${I('phone-off','ic-s')}In a call — try again soon</div>`:`<div class="btn dis f1">Not available right now</div>`;
  return SCR({light:true,body:`<div class="content" style="position:absolute;inset:0">
   ${ph(k,'',`position:absolute;top:0;left:0;right:0;height:500px;${state==='off'?'filter:saturate(.55)':''}`,390,500)}<div class="scrim-t" style="height:140px"></div>
   <div class="overlay-top" style="top:44px"><div class="row between" style="padding:0 12px"><div class="iconbtn glass">${I('arrow-left')}</div><div class="row g8"><div class="iconbtn glass">${I('ellipsis-vertical')}</div></div></div>
    <div class="row g4" style="padding:8px 24px 0">${[1,0,0,0].map(o=>`<i style="flex:1;height:3px;border-radius:2px;background:#fff;opacity:${o?1:.4}"></i>`).join('')}</div></div>
   <div style="position:absolute;top:420px;left:0;right:0;bottom:0;background:var(--bg);border-radius:28px 28px 0 0;padding:22px 20px 0">
    <div class="row between ai-s"><div><div class="row g8"><span class="d-m">${h.name}, ${h.age}</span><span class="pri">${I('badge-check','ic',`fill:var(--b100)`)}</span></div><div class="row g6 ink2 b-m mt4">${I('map-pin','ic-xs')}${h.city}</div></div>${st}</div>
    <div class="row g8 mt16 wrap">${h.langs.map(l=>`<span class="chip sm">${I('languages','ic-xs')}${l}</span>`).join('')}</div>
    <div class="t-s mt16">About</div>
    <div class="b-m ink2 mt4">${BIO[k]||BIO.ananya}</div>
    <div class="card flat mt16" style="padding:14px 16px;background:var(--surface)"><div class="row between"><div class="row g6">${DIA(20)}<span class="t-m num">${fmt(h.rate)}</span><span class="b-m ink3">Diamonds / min</span></div><span class="b-m ink2 num">≈ ₹${inr(h.rate)}/min</span></div>${state==='on'?`<div class="hr mt12"></div><div class="row g6 cap ink3 mt12">${I('wallet','ic-xs')}Your balance ${fmt(12480)} · about 5 min of talk time</div>`:''}</div>
   </div>
   <div class="overlay-bottom" style="background:linear-gradient(0deg,var(--bg) 70%,rgba(252,250,247,0));padding:18px 20px 0">
    <div class="row g12"><div class="iconbtn filled" style="width:52px;height:52px">${I('message-circle')}</div>${cta}</div>${GB()}</div>
  </div>`, noGb:true}); };

S({id:'C07',folder:F_CUS,name:'Host_Profile_Online',title:'Host profile — online',
 desc:'Full host profile. Photo gallery, verification, status, city, languages, bio and the rate in Diamonds with an approximate rupee hint. Primary action starts a call.',
 notes:['Swipe photos horizontally; progress segments at top.','Rate shows Diamonds/min and "≈ ₹/min" labelled approximate (rupee basis — D-07).','Talk-time hint = balance ÷ rate, from the server wallet summary.','Message button respects the host\'s messaging permission (CH04).','⋮ menu: Report, Block (V11).'],
 flags:['D-07'],to:['V01','V06','CH02','V11']},
()=>PROFILE('ananya','on'));

S({id:'C08',folder:F_CUS,name:'Host_Profile_Busy',title:'Host profile — in a call (unavailable)',
 desc:'The host is on another call. Calling is disabled; the profile stays browsable. Status updates live and the button enables when the host is free.',
 notes:['Amber status "In a call".','Disabled call button with explanatory label (no queue, no booking).','Real-time: the CTA switches to enabled as soon as presence changes.'],
 to:['C07']},
()=>PROFILE('priya','busy'));

S({id:'C09',folder:F_CUS,name:'Host_Profile_Offline',title:'Host profile — offline (unavailable)',
 desc:'The host is offline. Customers can only call hosts who are online, so the call action is disabled and the photo is slightly desaturated.',
 notes:['Shows "last seen" relative time (privacy setting may hide it — D-08).','No scheduling or booking options.','Message button still available if permitted.'],
 flags:['D-08'],to:['CH02']},
()=>PROFILE('diya','off'));

S({id:'C10',folder:F_CUS,name:'Free_Call_Matching',title:'Free Call Card — matching',
 desc:'Random matching for the one free minute. Matches among hosts who are online, not busy and opted in to free calls.',
 notes:['Dark immersive canvas consistent with call screens.','Rotating avatars of opted-in hosts (blurred until matched).','Cancel returns to Home and keeps the card unused.','Android only.'],
 to:['V03','C02']},
()=>SCR({dark:true,bg:'radial-gradient(80% 50% at 50% 40%,#5E1630 0%,#2B0A17 55%,#110E0D 100%)',body:`<div class="content col" style="align-items:center">
  <div class="row between" style="width:100%;padding:8px 20px"><span class="tag" style="background:rgba(255,255,255,.12);color:#F0CF8A">${I('gift','ic-xs')}Free Call Card</span><span class="lbl" style="opacity:.7">1 min free</span></div>
  <div style="position:relative;width:300px;height:300px;margin-top:70px">
   ${[300,236,172].map((s,i)=>`<div class="pulse" style="width:${s}px;height:${s}px;left:${(300-s)/2}px;top:${(300-s)/2}px;opacity:${.5+i*.2}"></div>`).join('')}
   <div style="position:absolute;left:96px;top:96px;width:108px;height:108px;border-radius:54px;background:rgba(255,255,255,.08);display:flex;align-items:center;justify-content:center">${LOGO(64,'#fff','var(--b700)')}</div>
   ${[['naina',8,120],['riya',230,70],['aditi',200,236],['meera',30,232],['ishita',122,-6]].map(([k,x,y])=>`<div style="position:absolute;left:${x}px;top:${y}px;filter:blur(2.5px)">${av(k,52,null,'border:2px solid rgba(255,255,255,.4)')}</div>`).join('')}
  </div>
  <div class="d-m center mt40" style="color:#fff">Finding someone<br>for you…</div>
  <div class="b-m center mt12" style="color:rgba(255,255,255,.7);padding:0 40px">We're matching you with a host who's online now. Your free minute starts when you're both connected.</div>
  <div class="spacer"></div>
  <div class="btn full" style="width:calc(100% - 40px);background:rgba(255,255,255,.12);color:#fff;margin-bottom:12px">Cancel</div></div>`}));

S({id:'C11',folder:F_CUS,name:'Notifications',title:'Notifications inbox',
 desc:'In-app notifications: purchases, messages, safety outcomes and account notices. Grouped by day; unread items carry a burgundy dot.',
 notes:['Tapping routes to the related screen (transaction, chat, report outcome).','Never used for marketing at MVP.','Empty state mirrors chat empty state.'],
 to:['W09','CH02']},
()=>SCR({body:`${APPBAR('Notifications',{right:`<div class="iconbtn">${I('check-check')}</div>`})}<div class="content">
  ${[['Today',[
    ['gem','pri','Diamonds added','54,000 Diamonds were added to your wallet.','2m',1],
    ['message-circle','','Meera sent you a message','"It was lovely talking to you! 😊"','1h',1],
    ['shield-check','ok','Your report was reviewed','Thanks for helping keep Dashuri safe. We\'ve taken action.','4h',0]]],
   ['Yesterday',[
    ['video','','Call summary','12 min 40 s with Ananya · 30,400 Diamonds','Yesterday',0],
    ['receipt','','Payment failed','Your ₹599 payment didn\'t go through. No money was taken.','Yesterday',0]]]
  ].map(([d,items])=>`<div class="grp-lbl" style="padding:12px 24px 8px">${d}</div><div class="col">${items.map(([ic,c,a,b,t,u])=>`<div class="row g12 ai-s" style="padding:12px 20px;${u?'background:var(--b50)':''}"><div style="width:40px;height:40px;border-radius:14px;flex:none;display:flex;align-items:center;justify-content:center;background:${c==='pri'?'var(--b100)':c==='ok'?'var(--ok-100)':'var(--surface-2)'};color:${c==='pri'?'var(--primary)':c==='ok'?'var(--ok)':'var(--ink)'}">${I(ic,'ic-s')}</div><div class="f1"><div class="row between"><span class="t-s" style="font-size:15px">${a}</span><span class="cap ink3">${t}</span></div><div class="b-m ink2 mt4">${b}</div></div>${u?'<i class="dot" style="background:var(--primary);margin-top:6px"></i>':''}</div>`).join('')}</div>`).join('')}
 </div>`}));

S({id:'C12',folder:F_CUS,name:'Host_Profile_Actions',title:'Host profile — more actions sheet',
 desc:'Overflow sheet from the ⋮ button on a host profile: report or block. Destructive actions are separated and coloured.',
 notes:['Report → V11 (reason picker). Block → confirm dialog (V13).','Blocking hides the host everywhere and stops messages both ways.'],
 to:['V11','V13']},
()=>SCR({light:true,body:`<div class="content" style="position:absolute;inset:0">${ph('ananya','',`position:absolute;top:0;left:0;right:0;height:500px`,390,500)}<div style="position:absolute;top:440px;left:0;right:0;bottom:0;background:var(--bg);border-radius:28px 28px 0 0"></div></div>`,noGb:true,
 overlay:`<div class="dim"></div><div class="sheet"><div class="grab"></div>
  <div class="row g12 mb16">${av('ananya',44)}<div><div class="t-s">Ananya, 24</div><div class="b-s ink3">Pune · Verified host</div></div></div>
<div class="list plain" style="border:none;background:var(--surface-2)">
   <div class="li"><div class="lic err">${I('flag','ic-s')}</div><div class="lt"><div class="a errc">Report Ananya</div><div class="b">Tell us what happened. It's anonymous.</div></div></div>
   <div class="li"><div class="lic err">${I('ban','ic-s')}</div><div class="lt"><div class="a errc">Block Ananya</div><div class="b">You won't see or hear from each other.</div></div></div></div>
  <div class="btn neu full mt16">Cancel</div>${GB()}</div>`}));
