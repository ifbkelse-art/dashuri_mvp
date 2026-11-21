// VIDEO CALLING — customer + host
const F_CALL='Video_Calling';
const BG = (k, extra='') => `<div class="call-bg" style="background-image:url('${purl(k,390,844)}');${extra}"></div>`;
const CALLTOP = (name, sub, right='') => `<div class="overlay-top" style="top:44px;padding:8px 16px"><div class="row g12">${right}</div></div>`;
const CTRLS = (opts={}) => `<div class="glass" style="margin:0 16px;border-radius:32px;padding:14px 18px;display:flex;justify-content:space-between;align-items:center">
  <div class="cbtn ${opts.mic?'on':''}" style="width:52px;height:52px">${I(opts.mic?'mic-off':'mic','ic')}</div>
  <div class="cbtn" style="width:52px;height:52px">${I(opts.cam?'video-off':'video','ic')}</div>
  <div class="cbtn" style="width:52px;height:52px">${I('switch-camera','ic')}</div>
  <div class="cbtn" style="width:52px;height:52px">${I('flag','ic')}</div>
  <div class="cbtn end" style="width:60px;height:60px">${I('phone-off','ic')}</div></div>`;
const TIMERPILL = (t, extra='') => `<div class="glass row g8" style="height:36px;border-radius:18px;padding:0 14px;color:#fff"><i class="dot" style="background:#E0412F"></i><span class="t-s num" style="font-size:15px">${t}</span>${extra}</div>`;
const NAMEBLOCK = (k, sub) => `<div class="row g10" style="color:#fff">${av(k,40,null,'border:2px solid rgba(255,255,255,.6)')}<div><div class="t-s">${HOSTS[k]?HOSTS[k].name:'Arjun'}</div><div class="cap" style="opacity:.8">${sub}</div></div></div>`;

S({id:'V01',folder:F_CALL,name:'Pre_Call_Confirm',title:'Pre-call confirmation',
 desc:'Confirms rate and billing rules before an outgoing paid call. Shows the customer\'s own camera preview so they are camera-ready.',
 notes:['Requires ≥ 60 s of balance at the host\'s rate (else V06).','Copy states the billing rules: per second, starts when both videos connect, 30 s warning, auto-end at zero.','"Start video call" → V02.'],
 to:['V02','V06']},
()=>SCR({light:true,body:`<div class="content" style="position:absolute;inset:0">${ph('ananya','',`position:absolute;top:0;left:0;right:0;height:500px`,390,500)}</div>`,noGb:true,
 overlay:`<div class="dim"></div><div class="sheet"><div class="grab"></div>
  <div class="row g16"><div style="position:relative">${av('ananya',64,'on')}</div><div class="f1"><div class="over ink3">Video call</div><div class="t-l">Ananya, 24</div></div>
   <div class="ph" style="width:68px;height:92px;border-radius:16px;background-image:url('${purl('arjun',140,190)}');box-shadow:var(--sh2)"><span class="tag dark" style="position:absolute;bottom:6px;left:6px;height:18px;font-size:9px;padding:0 6px">You</span></div></div>
  <div class="card flat mt20" style="background:var(--surface-2);border:none;padding:4px 16px">
   ${[['Rate',`<span class="row g6">${DIA(16)}<b class="num">2,400</b> / min</span>`],['Approx. cost','<span class="num">≈ ₹53 / min</span>'],['Your balance',`<span class="row g6">${DIA(16)}<b class="num">12,480</b></span>`],['Talk time','<b class="num">about 5 min 12 s</b>']].map(([a,b],i)=>`<div class="row between" style="height:46px;${i?'border-top:1px solid var(--line)':''}"><span class="b-m ink2">${a}</span><span class="b-m">${b}</span></div>`).join('')}</div>
  <div class="col g8 mt16">${[['timer','Billed per second — only once you\'re both on video.'],['bell-ring','We\'ll warn you 30 seconds before your balance runs out.'],['shield-check','You can end the call or report at any time.']].map(([ic,t])=>`<div class="row g10 ai-s ink2">${I(ic,'ic-s','margin-top:1px;color:var(--primary)')}<span class="b-s">${t}</span></div>`).join('')}</div>
  <div class="btn pri full mt20">${I('video','ic-s')}Start video call</div>${GB()}</div>`}));

S({id:'V02',folder:F_CALL,name:'Outgoing_Call',title:'Outgoing call — ringing',
 desc:'Customer is calling a host. Own camera fills the screen (FaceTime pattern). Nothing is charged while ringing.',
 notes:['Host avatar pulses; "Ringing…" status.','Persistent reassurance: "Billing starts when you\'re both connected".','Ring timeout → V08 (no charge).','Controls: mute, camera off, flip, cancel.'],
 to:['V03','V08']},
()=>SCR({dark:true,body:`${BG('arjun','filter:brightness(.55)')}<div class="content col" style="align-items:center;position:relative;z-index:2">
  <div style="position:relative;width:180px;height:180px;margin-top:70px">${[180,148].map(s=>`<div class="pulse" style="width:${s}px;height:${s}px;left:${(180-s)/2}px;top:${(180-s)/2}px;border-color:rgba(255,255,255,.28)"></div>`).join('')}<div style="position:absolute;left:30px;top:30px">${av('ananya',120,null,'border:3px solid rgba(255,255,255,.8)')}</div></div>
  <div class="d-m mt24" style="color:#fff">Ananya</div><div class="b-l mt4" style="color:rgba(255,255,255,.8)">Ringing…</div>
  <div class="glass row g8 mt20" style="height:34px;border-radius:17px;padding:0 14px;color:#fff">${DIA(14)}<span class="lbl num">2,400 / min</span><span style="opacity:.5">·</span><span class="cap" style="opacity:.85">Billing starts when you're both connected</span></div>
  <div class="spacer"></div>
  <div class="row" style="gap:28px;margin-bottom:20px">${[['mic','Mute'],['video','Camera'],['switch-camera','Flip']].map(([ic,l])=>`<div class="col" style="align-items:center"><div class="cbtn">${I(ic)}</div><div class="clabel">${l}</div></div>`).join('')}</div>
  <div class="col" style="align-items:center;margin-bottom:14px"><div class="cbtn end">${I('phone-off','ic-l')}</div><div class="clabel">Cancel</div></div></div>`}));

S({id:'V03',folder:F_CALL,name:'Connecting',title:'Connecting',
 desc:'Host accepted; media is being negotiated. Host video fades in over a blurred frame. Billing has not started.',
 notes:['Spinner + "Connecting securely…".','Small self-view already live.','If media never connects → V14 (refund).'],
 to:['V04','V14']},
()=>SCR({dark:true,body:`${BG('ananya','filter:blur(14px) brightness(.6);transform:scale(1.1)')}<div class="content col" style="align-items:center;justify-content:center;position:relative;z-index:2">
  <div class="pip" style="top:8px;right:16px">${ph('arjun','',`width:100%;height:100%`,104,150)}</div>
  ${av('ananya',96,null,'border:3px solid rgba(255,255,255,.7)')}
  <div class="t-l mt20" style="color:#fff">Ananya</div>
  <div class="row g10 mt12" style="color:rgba(255,255,255,.85)"><div class="spinner"></div><span class="b-m">Connecting securely…</span></div>
  <div class="cap mt16" style="color:rgba(255,255,255,.6)">You haven't been charged yet</div></div>
  <div class="overlay-bottom" style="padding-bottom:30px">${CTRLS()}</div>`}));

S({id:'V04',folder:F_CALL,name:'Active_Call_Customer',title:'Active call — customer',
 desc:'Live 1-to-1 video. Host video full-bleed, self-view PiP, live timer and remaining talk time from server-reported billing. Controls float on frosted glass.',
 notes:['Timer and talk-time-left come from server billing events (never computed on device).','Safety indicator is visible during the automated check window (first 3 minutes) — wording/visibility D-09.','Tap anywhere hides/shows controls. PiP draggable to any corner.','Flag button = report: ends the call and keeps an evidence frame (V11).'],
 flags:['D-09'],to:['V05','V07','V09','V11']},
()=>SCR({dark:true,body:`${BG('ananya')}<div class="scrim-t" style="height:200px;z-index:1"></div><div class="scrim-b" style="height:260px;z-index:1"></div>
  <div class="overlay-top" style="top:44px;padding:8px 16px"><div class="row between">${NAMEBLOCK('ananya','Pune')}${TIMERPILL('02:14')}</div>
   <div class="row between mt12"><div class="glass row g6" style="height:30px;border-radius:15px;padding:0 12px;color:#fff">${DIA(14)}<span class="cap num">2,400/min · 2:58 left</span></div><div class="glass row g6" style="height:30px;border-radius:15px;padding:0 10px;color:#fff">${I('shield-check','ic-xs')}<span class="cap">Safety check on</span></div></div></div>
  <div class="pip" style="top:150px;right:16px">${ph('arjun','',`width:100%;height:100%`,104,150)}</div>
  <div class="overlay-bottom" style="padding-bottom:30px">${CTRLS()}</div>`}));

S({id:'V05',folder:F_CALL,name:'Low_Balance_Warning',title:'Low balance — 30-second warning',
 desc:'Shown 30 seconds before the balance runs out. A countdown banner with an in-call top-up; the call ends automatically at zero.',
 notes:['Amber banner slides from the top; countdown is server-driven.','"Top up" opens a compact package sheet without leaving the call (D-10).','At 0 the call ends → V10.'],
 flags:['D-10'],to:['V10','W03']},
()=>SCR({dark:true,body:`${BG('ananya')}<div class="scrim-b" style="height:260px;z-index:1"></div>
  <div class="overlay-top" style="top:44px;padding:8px 12px">
   <div style="background:rgba(255,248,236,.97);border-radius:22px;padding:14px 14px 14px 16px;display:flex;align-items:center;gap:12px;box-shadow:var(--sh3)">
    <div style="width:44px;height:44px;border-radius:22px;border:3px solid var(--warn);display:flex;align-items:center;justify-content:center;flex:none;color:#7A4A06" class="t-s num">28</div>
    <div class="f1"><div class="t-s" style="color:#3E2604">28 seconds of talk time left</div><div class="b-s" style="color:#7A4A06">Top up to keep talking with Ananya.</div></div>
    <div class="btn pri xs">Top up</div></div>
   <div class="row between mt12" style="padding:0 4px">${NAMEBLOCK('ananya','Pune')}${TIMERPILL('04:44')}</div></div>
  <div class="pip" style="top:200px;right:16px">${ph('arjun','',`width:100%;height:100%`,104,150)}</div>
  <div class="overlay-bottom" style="padding-bottom:30px">${CTRLS()}</div>`}));

S({id:'V06',folder:F_CALL,name:'Insufficient_Balance',title:'Insufficient balance (before call)',
 desc:'Blocks a call when the balance is below 60 seconds at the host\'s rate. Explains the gap and offers the most relevant packages inline.',
 notes:['Requirement text is exact: 60 s × host rate.','Three suggested packages, smallest that covers the gap pre-selected; "See all packages" → W02.','Purchase success returns straight to V01.'],
 to:['W02','W03','V01']},
()=>SCR({light:true,body:`<div class="content" style="position:absolute;inset:0">${ph('kavya','',`position:absolute;top:0;left:0;right:0;height:500px`,390,500)}</div>`,noGb:true,
 overlay:`<div class="dim"></div><div class="sheet"><div class="grab"></div>
  <div class="row g12">${av('kavya',52)}<div class="f1"><div class="t-l">Top up to call Kavya</div><div class="b-m ink2">Rate ${DIA(14)} <b class="num">4,500</b> / min</div></div></div>
  <div class="card flat mt20 row" style="background:var(--surface-2);border:none;padding:14px 16px">
   <div class="f1"><div class="cap ink3">YOU HAVE</div><div class="row g6 mt4">${DIA(16)}<span class="t-m num">1,150</span></div></div>
   <div style="width:1px;height:40px;background:var(--line)"></div>
   <div class="f1" style="padding-left:16px"><div class="cap ink3">NEEDED TO START</div><div class="row g6 mt4">${DIA(16)}<span class="t-m num">4,500</span></div></div></div>
  <div class="b-s ink3 mt8">You need at least 1 minute of balance to start a call.</div>
  <div class="col g10 mt16">${[['4,000','₹99',0],['12,500','₹299',1],['26,000','₹599',0]].map(([d,p,on])=>`<div class="pkg row between ${on?'sel':''}" style="flex-direction:row;align-items:center;padding:14px 16px">${on?'<span class="ribbon">Best fit</span>':''}<div class="row g10"><div class="radio ${on?'on':''}"></div>${DIA(20)}<span class="t-s num">${d}</span></div><span class="t-s num">${p}</span></div>`).join('')}</div>
  <div class="btn pri full mt20">Continue · ₹299</div><div class="btn txt full mt4">See all packages</div>${GB()}</div>`}));

S({id:'V07',folder:F_CALL,name:'Network_Interrupted',title:'Network interrupted — billing paused',
 desc:'Shown when the connection drops mid-call. The frame freezes and blurs, billing pauses (server-detected) and resumes automatically on recovery.',
 notes:['"Billing is paused" is shown only when the server confirms the pause.','Timer freezes; reconnect spinner.','If not recovered → call ends; unbilled time credited automatically (V09 shows the credit line).','Threshold for pausing is a technical assumption (D-13).'],
 flags:['D-13'],to:['V04','V09']},
()=>SCR({dark:true,body:`${BG('ananya','filter:blur(10px) brightness(.45) saturate(.6);transform:scale(1.08)')}
  <div class="overlay-top" style="top:44px;padding:8px 16px"><div class="row between">${NAMEBLOCK('ananya','Pune')}<div class="glass row g8" style="height:36px;border-radius:18px;padding:0 14px;color:#fff">${I('pause','ic-xs')}<span class="t-s num" style="font-size:15px">03:41</span></div></div></div>
  <div class="content col jc" style="align-items:center;position:relative;z-index:2;color:#fff">
   <div style="width:76px;height:76px;border-radius:38px;background:rgba(255,255,255,.12);display:flex;align-items:center;justify-content:center">${I('wifi-off','ic-l')}</div>
   <div class="t-l mt20">Connection lost</div>
   <div class="row g8 mt8" style="opacity:.85"><div class="spinner" style="width:16px;height:16px;border-width:2px"></div><span class="b-m">Trying to reconnect…</span></div>
   <div class="glass row g8 mt24" style="border-radius:16px;padding:12px 16px;max-width:300px">${I('circle-pause','ic-s','color:#7FD8AE')}<span class="b-s">Billing is paused. You won't be charged while you're disconnected.</span></div></div>
  <div class="pip" style="top:110px;right:16px;opacity:.6">${ph('arjun','',`width:100%;height:100%`,104,150)}</div>
  <div class="overlay-bottom" style="padding-bottom:30px">${CTRLS()}</div>`}));

S({id:'V08',folder:F_CALL,name:'Call_Not_Answered',title:'Host unavailable / declined',
 desc:'The host declined, missed the call or became unavailable. The customer is reassured nothing was charged and guided back to available hosts.',
 notes:['Neutral copy — never says "declined" to avoid pressure on hosts.','Suggested online hosts with similar languages.','No queue or callback booking.'],
 to:['C01','C07']},
()=>SCR({body:`${APPBAR('',{left:'x'})}<div class="content pad col" style="align-items:center">
  <div style="margin-top:24px;position:relative">${av('ananya',104,null,'filter:grayscale(.3)')}<div style="position:absolute;right:-4px;bottom:-4px;width:40px;height:40px;border-radius:20px;background:var(--surface);display:flex;align-items:center;justify-content:center;box-shadow:var(--sh2);color:var(--ink-2)">${I('phone-missed','ic-s')}</div></div>
  <div class="d-m center mt24">Ananya couldn't<br>take your call</div>
  <div class="row g8 mt12 tag ok" style="height:30px;padding:0 12px">${I('circle-check','ic-xs')}You haven't been charged</div>
  <div class="b-m ink2 center mt16">Hosts are free to accept calls when they can. These hosts are online now:</div>
  <div class="row g12 mt20" style="width:100%">${['meera','aditi'].map(k=>`<div class="f1">${HCARD(k,{h:210})}</div>`).join('')}</div>
  <div class="spacer"></div><div class="btn neu full" style="margin-bottom:12px">Back to Discover</div></div>`}));

const SUMROW = (a,b,cls='') => `<div class="row between" style="height:44px"><span class="b-m ink2">${a}</span><span class="b-m ${cls}" style="font-weight:700">${b}</span></div>`;
S({id:'V09',folder:F_CALL,name:'Call_Summary_Customer',title:'Call ended — summary (customer)',
 desc:'Post-call summary with server-final duration and Diamonds charged (rounded once in the customer\'s favour), remaining balance, rating and quick actions.',
 notes:['All figures from CallSession.billedSeconds / diamondsCharged.','Credited interruption time appears as a green line item when applicable.','Rating scale and use — D-11. "Report" opens V11.','"Message" opens chat only if permitted.'],
 flags:['D-11'],to:['C01','CH02','V11']},
()=>SCR({body:`${APPBAR('',{left:'x'})}<div class="content pad col" style="align-items:center">
  ${av('ananya',88)}
  <div class="over ink3 mt16">Call ended</div><div class="d-m mt4">3:05 with Ananya</div>
  <div class="card mt20" style="width:100%;padding:4px 16px">
   ${SUMROW('Billed time','3 min 05 s')}<div class="hr"></div>
   ${SUMROW('Rate',`<span class="row g4">${DIA(14)}2,400 / min</span>`)}<div class="hr"></div>
   ${SUMROW('Connection pause credited','– 0 min 08 s','okc')}<div class="hr"></div>
   <div class="row between" style="height:52px"><span class="t-s">Diamonds used</span><span class="row g6 t-m num">${DIA(18)}7,400</span></div></div>
  <div class="row between mt12" style="width:100%;padding:0 4px"><span class="b-s ink3">Balance remaining</span><span class="b-s row g4" style="font-weight:800">${DIA(13)}<span class="num">5,080</span></span></div>
  <div class="t-s mt24">How was your call?</div>
  <div class="row g12 mt12">${[1,1,1,1,0].map(f=>I('star','ic-l',`color:${f?'var(--gold)':'var(--n300)'};fill:${f?'var(--gold)':'none'}`)).join('')}</div>
  <div class="spacer"></div>
  <div class="row g12" style="width:100%"><div class="btn neu f1">${I('message-circle','ic-s')}Message</div><div class="btn pri f1">Done</div></div>
  <div class="btn txt full mt4 errc" style="color:var(--err);margin-bottom:4px">${I('flag','ic-xs')}Report a problem</div></div>`}));

S({id:'V10',folder:F_CALL,name:'Call_Ended_Balance_Zero',title:'Call ended — balance ran out',
 desc:'Variant of the summary when the call ended automatically at zero balance. Leads with a calm explanation and the top-up path.',
 notes:['Banner explains auto-end; no blame.','Primary action: Top up → W02; secondary: Done.','Re-calling the same host requires ≥ 60 s balance again.'],
 to:['W02','C01']},
()=>SCR({body:`${APPBAR('',{left:'x'})}<div class="content pad col" style="align-items:center">
  ${av('ananya',88)}
  <div class="over ink3 mt16">Call ended</div><div class="d-m mt4">5:12 with Ananya</div>
  <div class="banner warn mt20" style="width:100%">${I('hourglass','ic-s')}<span>Your balance ran out, so the call ended automatically. You were warned 30 seconds before.</span></div>
  <div class="card mt16" style="width:100%;padding:4px 16px">
   ${SUMROW('Billed time','5 min 12 s')}<div class="hr"></div>
   ${SUMROW('Rate',`<span class="row g4">${DIA(14)}2,400 / min</span>`)}<div class="hr"></div>
   <div class="row between" style="height:52px"><span class="t-s">Diamonds used</span><span class="row g6 t-m num">${DIA(18)}12,480</span></div></div>
  <div class="row between mt12" style="width:100%;padding:0 4px"><span class="b-s ink3">Balance remaining</span><span class="b-s row g4" style="font-weight:800">${DIA(13)}<span class="num">0</span></span></div>
  <div class="spacer"></div>
  <div class="btn pri full">${I('plus','ic-s')}Top up Diamonds</div><div class="btn txt full mt4" style="margin-bottom:4px">Done</div></div>`}));

S({id:'V11',folder:F_CALL,name:'Report_User',title:'Report — choose a reason',
 desc:'Report flow used from calls, profiles and chats. Reporting during a call ends the call immediately and keeps an evidence frame for review.',
 notes:['Single-select reasons; "Appears to be under 18" and "Nudity" are prioritised for review.','Optional details (max 500 chars).','"Also block" pre-checked.','Submitting from a call ends it; billing stops at that moment.'],
 to:['V12']},
()=>SCR({body:`${APPBAR('Report Ananya',{left:'x'})}<div class="content pad">
  <div class="banner pri">${I('info','ic-s')}<span>Reporting during a call ends it immediately. A still frame is kept privately for our safety team.</span></div>
  <div class="t-s mt20 mb8">What happened?</div>
  <div class="list plain">${[['Nudity or sexual content',1],['Appears to be under 18',0],['Harassment, threats or hate',0],['Asked to pay or talk outside Dashuri',0],['Scam or fake profile',0],['Something else',0]].map(([l,on])=>`<div class="li noic" style="min-height:52px"><span class="lt" style="font-size:15px;font-weight:600">${l}</span><div class="radio ${on?'on':''}"></div></div>`).join('')}</div>
  <div class="input area mt16" style="min-height:84px"><span class="ph-t">Add details (optional)</span></div>
  <div class="row g12 mt16"><div class="check on">${I('check','ic-xs')}</div><span class="b-m">Also block Ananya</span></div>
  <div style="position:absolute;bottom:12px;left:20px;right:20px"><div class="btn dan full">Submit report</div></div></div>`}));

S({id:'V12',folder:F_CALL,name:'Report_Submitted',title:'Report submitted',
 desc:'Confirmation after a report. Sets expectations about review and confirms the block.',
 notes:['Outcome is delivered later as a notification (C11).','Links to Safety Centre (S07).'],
 to:['C01','S07']},
()=>SCR({body:`<div class="content col jc" style="align-items:center">
  <div class="empty"><div class="art" style="background:var(--ok-100);color:var(--ok)">${I('shield-check','ic-xl')}</div>
  <div class="d-m">Thanks for telling us</div>
  <div class="b-l ink2 mt12">Our safety team will review this report. We'll let you know when action has been taken.</div>
  <div class="card flat row g12 mt24" style="padding:12px 16px;text-align:left">${av('ananya',36,null,'filter:grayscale(1)')}<span class="b-m f1">Ananya is blocked</span><span class="tag">Blocked</span></div></div>
  <div style="position:absolute;bottom:20px;left:20px;right:20px" class="col g8"><div class="btn pri full">Done</div><div class="btn txt full">Visit Safety Centre</div></div></div>`}));

S({id:'V13',folder:F_CALL,name:'Block_Confirm',title:'Block — confirmation dialog',
 desc:'Confirmation dialog before blocking. Explains consequences in plain language.',
 notes:['Destructive action uses danger red.','Undo available from Blocked users (S06).'],
 to:['S06']},
()=>SCR({light:true,body:`<div class="content" style="position:absolute;inset:0">${ph('ananya','',`position:absolute;top:0;left:0;right:0;height:500px`,390,500)}<div style="position:absolute;top:420px;left:0;right:0;bottom:0;background:var(--bg);border-radius:28px 28px 0 0"></div></div>`,
 overlay:`<div class="dim"></div><div class="dialog center"><div class="row jc">${av('ananya',64)}</div>
  <div class="t-l mt16">Block Ananya?</div>
  <div class="b-m ink2 mt8">You won't see each other on Dashuri, and neither of you can call or message the other. They won't be notified.</div>
  <div class="btn dan full mt24">Block</div><div class="btn txt full mt4" style="color:var(--ink)">Cancel</div></div>`}));

S({id:'V14',folder:F_CALL,name:'Call_Failed_Refunded',title:'Call failed to connect — refunded',
 desc:'When video never connects for both sides, nothing is billed and any reserved Diamonds are returned automatically.',
 notes:['Server-detected only; no customer claim form.','Retry starts a fresh pre-call check.'],
 to:['V01','C01']},
()=>SCR({body:`${APPBAR('',{left:'x'})}<div class="content col jc" style="align-items:center">
  <div class="empty"><div class="art" style="background:var(--surface-2);color:var(--ink-2)">${I('unplug','ic-xl')}</div>
  <div class="d-m">The call couldn't connect</div>
  <div class="b-l ink2 mt12">Something went wrong before you were both on video. You haven't been charged.</div>
  <div class="tag ok mt16" style="height:30px;padding:0 12px">${I('rotate-ccw','ic-xs')}All Diamonds returned</div></div>
  <div style="position:absolute;bottom:20px;left:20px;right:20px" class="col g8"><div class="btn pri full">Try again</div><div class="btn txt full">Back to Discover</div></div></div>`}));

S({id:'V15',folder:F_CALL,name:'Free_Call_Active',title:'Free call — active (customer)',
 desc:'The one-minute free call. A countdown ring replaces the billing pill; nothing is charged.',
 notes:['Gold "Free minute" chip; countdown ring around the timer.','At 0:00 the call ends with a prompt to buy Diamonds to continue with this host.'],
 to:['W02','C07']},
()=>SCR({dark:true,body:`${BG('naina')}<div class="scrim-t" style="height:200px;z-index:1"></div><div class="scrim-b" style="height:260px;z-index:1"></div>
  <div class="overlay-top" style="top:44px;padding:8px 16px"><div class="row between">${NAMEBLOCK('naina','Delhi')}
   <div class="glass row g8" style="height:40px;border-radius:20px;padding:0 6px 0 14px;color:#fff"><span class="cap" style="color:#F0CF8A">FREE MINUTE</span><div style="width:30px;height:30px;border-radius:15px;background:conic-gradient(#F0CF8A 0 70%,rgba(255,255,255,.2) 70% 100%);display:flex;align-items:center;justify-content:center"><div style="width:24px;height:24px;border-radius:12px;background:#2a1c1f;display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:800" class="num">42</div></div></div></div></div>
  <div class="pip" style="top:110px;right:16px">${ph('arjun','',`width:100%;height:100%`,104,150)}</div>
  <div class="overlay-bottom" style="padding-bottom:30px">${CTRLS()}</div>`}));

// ---------------- HOST SIDE ----------------
S({id:'V16',folder:F_CALL,name:'Incoming_Call_Host',title:'Incoming call — host',
 desc:'Full-screen incoming call for an online host. Shows who is calling and what the host earns per minute. The host is always free to decline, without penalty.',
 notes:['Shown as a full-screen intent/notification when the app is backgrounded.','Earnings hint in Beans/min from the host\'s current rate (server value).','Decline has no penalty (business rule). Ring timeout returns the host to Online.','Customer\'s photo is optional; falls back to initials.'],
 to:['V17','H12']},
()=>SCR({dark:true,body:`${BG('arjun','filter:blur(18px) brightness(.45);transform:scale(1.15)')}<div class="content col" style="align-items:center;position:relative;z-index:2">
  <div class="over mt24" style="color:rgba(255,255,255,.7)">Incoming video call</div>
  <div style="position:relative;width:180px;height:180px;margin-top:40px">${[180,148].map(s=>`<div class="pulse" style="width:${s}px;height:${s}px;left:${(180-s)/2}px;top:${(180-s)/2}px;border-color:rgba(255,255,255,.25)"></div>`).join('')}<div style="position:absolute;left:30px;top:30px">${av('arjun',120,null,'border:3px solid rgba(255,255,255,.8)')}</div></div>
  <div class="d-m mt24" style="color:#fff">Arjun</div><div class="b-m mt4" style="color:rgba(255,255,255,.75)">Mumbai · Hindi, English</div>
  <div class="glass row g8 mt20" style="height:36px;border-radius:18px;padding:0 14px;color:#fff">${BEAN(16)}<span class="lbl num">≈ 1,440 Beans / min</span><span style="opacity:.5">·</span><span class="cap" style="opacity:.85">≈ ₹7.20 / min</span></div>
  <div class="spacer"></div>
  <div class="row" style="gap:96px;margin-bottom:24px">
   <div class="col" style="align-items:center"><div class="cbtn end">${I('phone-off','ic-l')}</div><div class="clabel">Decline</div></div>
   <div class="col" style="align-items:center"><div class="cbtn acc">${I('video','ic-l')}</div><div class="clabel">Accept</div></div></div></div>`}));

S({id:'V17',folder:F_CALL,name:'Active_Call_Host',title:'Active call — host',
 desc:'Host in-call view, optimised for earning and safety: a live Beans counter, one-tap report/end, and the same control bar as customers.',
 notes:['Beans counter updates from server billing ticks.','Report is one tap and ends the call immediately.','Host can end the call any time with no penalty.','Customer camera may be off — shows avatar card (state).'],
 to:['V18','V11']},
()=>SCR({dark:true,body:`${BG('arjun')}<div class="scrim-t" style="height:200px;z-index:1"></div><div class="scrim-b" style="height:260px;z-index:1"></div>
  <div class="overlay-top" style="top:44px;padding:8px 16px"><div class="row between"><div class="row g10" style="color:#fff">${av('arjun',40,null,'border:2px solid rgba(255,255,255,.6)')}<div><div class="t-s">Arjun</div><div class="cap" style="opacity:.8">Customer</div></div></div>${TIMERPILL('07:26')}</div>
   <div class="row mt12"><div class="glass row g6" style="height:32px;border-radius:16px;padding:0 12px;color:#fff">${BEAN(16)}<span class="lbl num">10,702 Beans this call</span></div></div></div>
  <div class="pip" style="top:150px;right:16px">${ph('ananya','',`width:100%;height:100%`,104,150)}</div>
  <div class="overlay-bottom" style="padding-bottom:30px">${CTRLS()}</div>`}));

S({id:'V18',folder:F_CALL,name:'Call_Summary_Host',title:'Call ended — summary (host)',
 desc:'Host post-call summary: duration, Beans earned and when they become withdrawable (7-day hold). Quick path back online.',
 notes:['Beans from server: Diamonds × 10,000 ÷ 16,670 (no early rounding).','"Withdrawable from" date = earned date + 7 days.','Primary: "Stay online" returns to the Online dashboard.'],
 to:['H12','V11']},
()=>SCR({body:`${APPBAR('',{left:'x'})}<div class="content pad col" style="align-items:center">
  ${av('arjun',80)}
  <div class="over ink3 mt16">Call with Arjun ended</div><div class="d-m mt4">12:40</div>
  <div class="hhero mt20" style="width:100%;text-align:center;padding:24px">
   <div class="cap" style="color:#E9C98C;letter-spacing:.12em">YOU EARNED</div>
   <div class="row g8 jc mt8">${BEAN(30)}<span class="num" style="font-size:40px;font-weight:800;letter-spacing:-.02em">18,236</span></div>
   <div class="b-m mt4" style="opacity:.75">Beans · ≈ ₹91.18</div></div>
  <div class="card mt16" style="width:100%;padding:4px 16px">
   ${SUMROW('Billed time','12 min 40 s')}<div class="hr"></div>
   ${SUMROW('Your rate',`<span class="row g4">${DIA(14)}2,400 / min</span>`)}<div class="hr"></div>
   ${SUMROW('Withdrawable from','Thu, 26 Nov')}</div>
  <div class="spacer"></div>
  <div class="btn ok full"><i class="dot" style="background:#fff;box-shadow:none"></i>Stay online</div>
  <div class="row g12 mt8" style="width:100%;margin-bottom:4px"><div class="btn txt f1" style="color:var(--ink)">Go offline</div><div class="btn txt f1" style="color:var(--err)">${I('flag','ic-xs')}Report</div></div></div>`}));
