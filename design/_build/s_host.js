// HOST EXPERIENCE
const F_HOST='Host';
const HSTEP = (step,total=6,title='') => `<div class="appbar"><div class="iconbtn">${I('arrow-left')}</div><div class="f1" style="padding:0 8px"><div class="steps">${Array.from({length:total},(_, i)=>`<i class="${i<step?'on':''}"></i>`).join('')}</div></div><div class="lbl ink3" style="width:44px;text-align:center">${step}/${total}</div></div>`;
const BOTTOM = (inner) => `<div style="position:absolute;bottom:0;left:0;right:0;padding:12px 20px 0;background:var(--bg)">${inner}${GB()}</div>`;
const HEAD_H = (title, right='') => `<div class="largetitle row between" style="padding-top:8px"><span class="d-m">${title}</span>${right}</div>`;
const ROWKV = (a,b,cls='') => `<div class="row between" style="height:46px"><span class="b-m ink3">${a}</span><span class="b-m num ${cls}" style="font-weight:700">${b}</span></div>`;

S({id:'H01',folder:F_HOST,name:'Host_Onboarding_Intro',title:'Host onboarding — introduction',
 desc:'Entry to the host application. Explains how hosting works in four honest points before any verification starts.',
 notes:['Women 18+ only at launch; ID verification required.','Facts only from confirmed rules: go online any time, no quotas; Beans per second; weekly withdrawals, ₹500 minimum.','"Start application" → H02.'],
 to:['H02']},
()=>SCR({light:true,body:`<div class="content" style="position:absolute;inset:0">
  ${ph('meera','',`position:absolute;top:0;left:0;right:0;height:360px`,390,360)}<div class="scrim-t" style="height:120px"></div>
  <div class="overlay-top" style="top:44px;padding:0 12px"><div class="iconbtn glass">${I('x')}</div></div>
  <div style="position:absolute;top:320px;left:0;right:0;bottom:0;background:var(--bg);border-radius:28px 28px 0 0;padding:28px 20px 0">
   <div class="over" style="color:var(--gold-d)">Host on Dashuri</div>
   <div class="d-m mt8">Your time, your terms.</div>
   <div class="col g16 mt24">${[
    ['toggle-right','Go online whenever you like','No schedules, no quotas. Accept or decline any call.'],
    [BEAN(22),'Earn Beans every second','Paid for every second you\'re on a call, at the rate you set.'],
    ['landmark','Withdraw weekly','To your own bank account or UPI ID. Minimum ₹500.'],
    ['shield-check','Safety first','End any call instantly. Report and block in one tap.']
   ].map(([ic,a,b])=>`<div class="row g14 ai-s" style="gap:14px"><div style="width:42px;height:42px;border-radius:14px;background:var(--gold-50);color:var(--gold-d);display:flex;align-items:center;justify-content:center;flex:none">${ic.startsWith('<')?ic:I(ic,'ic-s')}</div><div><div class="t-s">${a}</div><div class="b-m ink2">${b}</div></div></div>`).join('')}</div></div></div>`,
 overlay:BOTTOM(`<div class="btn pri full">Start application</div><div class="cap ink3 center mt8 mb8">Women 18+ · Government ID and selfie verification required</div>`),noGb:true}));

const KYCSTEPS = (cur) => [['Phone number','Verified'],['Aadhaar via DigiLocker','Confirms your identity and age'],['PAN','Needed for tax on payouts'],['Selfie check','A quick liveness video'],['Host agreement','Read and accept'],['Profile & rate','Photos, bio and your rate']]
 .map(([a,b],i)=>`<div class="row g14" style="gap:14px;padding:12px 0;${i?'border-top:1px solid var(--line-2)':''}"><div class="stepnum ${i<cur?'done':i===cur?'cur':''}">${i<cur?I('check','ic-xs'):i+1}</div><div class="f1"><div class="t-s" style="${i>cur?'color:var(--ink-3)':''}">${a}</div><div class="b-s ink3">${b}</div></div>${i===cur?`<span class="tag pri">Next</span>`:''}</div>`).join('');
S({id:'H02',folder:F_HOST,name:'Host_Verification_Steps',title:'Host verification — steps overview',
 desc:'Checklist of the verification and setup steps with progress. Users can leave and resume at any step.',
 notes:['Steps: phone, Aadhaar (DigiLocker or offline e-KYC), PAN, liveness, host agreement, profile & rate.','Completed steps show green checks; current step highlighted.','KYC vendor and exact data stored — PRO-REVIEW (D-12).'],
 flags:['D-12'],to:['H03']},
()=>SCR({body:`${APPBAR('')}<div class="content pad">
  <div class="d-m">Let's verify<br>it's really you</div>
  <div class="b-l ink2 mt8">Every host is verified. It keeps you and the community safe. Takes about 5 minutes.</div>
  <div class="card mt24" style="padding:4px 16px">${KYCSTEPS(1)}</div>
  <div class="row g8 mt16 ink3">${I('lock','ic-xs')}<span class="cap">Your documents are encrypted and never shown to customers.</span></div></div>`,
 overlay:BOTTOM(`<div class="btn pri full mb8">Continue</div>`),noGb:true}));

S({id:'H03',folder:F_HOST,name:'Host_ID_Verification',title:'ID verification — Aadhaar',
 desc:'Choose how to verify identity and age: DigiLocker (recommended) or Aadhaar offline e-KYC. Age 18+ is confirmed from the ID.',
 notes:['DigiLocker opens the consent flow in a secure web view.','Aadhaar number is never stored in full; only masked last 4 digits.','If ID age < 18 the application is closed (same pattern as A10).'],
 flags:['D-12'],to:['H04']},
()=>SCR({body:`${HSTEP(2)}<div class="content pad">
  <div class="d-m mt8">Verify with Aadhaar</div>
  <div class="b-l ink2 mt8">We'll confirm your name and date of birth. Your Aadhaar number is never shown to anyone.</div>
  <div class="col g12 mt24">
   <div class="card row g14" style="gap:14px;padding:18px;border:1.5px solid var(--primary);box-shadow:0 0 0 4px var(--b50)"><div style="width:48px;height:48px;border-radius:14px;background:#EAF1FB;color:#2C5AA0;display:flex;align-items:center;justify-content:center">${I('folder-lock','ic')}</div><div class="f1"><div class="row g8"><span class="t-s">DigiLocker</span><span class="tag ok" style="height:20px;font-size:10px">Recommended</span></div><div class="b-s ink3 mt4">Fastest. Share your Aadhaar securely in a few taps.</div></div><div class="radio on"></div></div>
   <div class="card row g14" style="gap:14px;padding:18px"><div style="width:48px;height:48px;border-radius:14px;background:var(--surface-2);display:flex;align-items:center;justify-content:center">${I('file-key-2','ic')}</div><div class="f1"><div class="t-s">Aadhaar offline e-KYC</div><div class="b-s ink3 mt4">Upload the XML file from the UIDAI website with your share code.</div></div><div class="radio"></div></div></div>
  <div class="banner info mt20">${I('info','ic-s')}<span>We use your ID only to confirm you're over 18 and to match your payouts. See how we handle your data.</span></div></div>`,
 overlay:BOTTOM(`<div class="btn pri full mb8">Continue with DigiLocker</div>`),noGb:true}));

S({id:'H04',folder:F_HOST,name:'Host_PAN',title:'PAN details',
 desc:'PAN is required for tax withholding on payouts. The name on PAN is matched to the Aadhaar name.',
 notes:['Auto-formats to AAAAA9999A; uppercase keyboard.','Name-match result shown inline (success state).','Mismatch → manual review state.'],
 flags:['D-17'],to:['H05']},
()=>SCR({body:`${HSTEP(3)}<div class="content pad">
  <div class="d-m mt8">Add your PAN</div>
  <div class="b-l ink2 mt8">Required by law for payouts. We match it to the name on your Aadhaar.</div>
  <div class="field mt32"><span class="flabel">PAN number</span><div class="input" style="letter-spacing:.12em">BKVPS4821K<span class="spacer"></span><span class="okc">${I('circle-check','ic-s')}</span></div></div>
  <div class="card flat row g12 mt16" style="padding:14px 16px;background:var(--ok-100);border:none">${I('user-check','ic-s','color:var(--ok)')}<div class="f1"><div class="t-s" style="color:#1D5E41">Name matched</div><div class="b-s" style="color:#2E6E50">ANANYA SHARMA · matches Aadhaar</div></div></div>
  <div class="field mt24"><span class="flabel">Date of birth (from Aadhaar)</span><div class="input" style="background:var(--surface-2);color:var(--ink-2)">14 / 04 / 2002<span class="spacer"></span>${I('lock','ic-xs')}</div></div></div>`,
 overlay:BOTTOM(`<div class="btn pri full mb8">Continue</div>`),noGb:true}));

S({id:'H05',folder:F_HOST,name:'Host_Liveness_Selfie',title:'Selfie liveness check',
 desc:'A short guided video selfie confirms a real, present person and is matched to the ID and profile photos.',
 notes:['Oval guide turns green when the face is detected.','Step prompts: look straight, turn left, turn right, blink.','Failure → retry with tips (lighting, glasses).'],
 to:['H06']},
()=>SCR({dark:true,body:`${BG('ananya','filter:brightness(.9)')}<div style="position:absolute;inset:0;z-index:1;background:radial-gradient(ellipse 128px 170px at 50% 42%,transparent 98%,rgba(17,14,13,.82) 100%)"></div>
  <svg style="position:absolute;left:0;top:0;z-index:2" width="390" height="844"><ellipse cx="195" cy="354" rx="130" ry="172" fill="none" stroke="#3DBE84" stroke-width="4" stroke-dasharray="560 260" stroke-linecap="round"/><ellipse cx="195" cy="354" rx="130" ry="172" fill="none" stroke="rgba(255,255,255,.3)" stroke-width="4" stroke-dasharray="4 10"/></svg>
  <div class="overlay-top" style="top:44px;padding:0 12px"><div class="row between"><div class="iconbtn glass">${I('x')}</div><span class="lbl" style="color:#fff">Step 4 of 6</span><div style="width:44px"></div></div></div>
  <div style="position:absolute;left:0;right:0;top:560px;z-index:3;color:#fff" class="center">
   <div class="row g8 jc">${['Look','Left','Right','Blink'].map((s,i)=>`<span class="tag" style="background:${i<1?'#2FA56F':i===1?'#fff':'rgba(255,255,255,.14)'};color:${i===1?'var(--ink)':'#fff'}">${i<1?I('check','ic-xs'):''}${s}</span>`).join('')}</div>
   <div class="d-m mt20">Slowly turn your<br>head to the left</div>
   <div class="b-m mt8" style="opacity:.75">Keep your face inside the oval</div></div>`}));

S({id:'H06',folder:F_HOST,name:'Host_Agreement',title:'Host agreement',
 desc:'Plain-language summary of the host agreement with the full text one tap away. Covers status, content rules, Beans terms, tax and data consent.',
 notes:['Beans terms reflect confirmed rules: 16,670 Diamonds spent = 10,000 Beans; 200 Beans = ₹1; 7-day hold; weekly withdrawals, ₹500 minimum; Beans never expire.','Legal wording requires professional review (D-12).','Accept requires scrolling to the end.'],
 flags:['D-12','D-17'],to:['H09']},
()=>SCR({body:`${HSTEP(5)}<div class="content pad">
  <div class="d-m mt8">Host agreement</div>
  <div class="b-m ink2 mt8">The key points, in plain words.</div>
  <div class="col g10 mt20">${[
   ['briefcase','Independent creator','You\'re not an employee. You choose when and whether to work.'],
   ['eye-off','Content rules','No nudity or sexual content. Calls are safety-checked; reports are investigated.'],
   [BEAN(18),'How Beans work','Every 16,670 Diamonds a customer spends with you = 10,000 Beans. 200 Beans = ₹1. Beans never expire.'],
   ['calendar-clock','Withdrawals','Beans become withdrawable 7 days after you earn them. Weekly payouts, minimum ₹500.'],
   ['receipt-indian-rupee','Tax','Tax may be deducted from payouts as required by law. PAN is mandatory.'],
   ['database','Your data','We process your ID and call data to verify you, pay you and keep calls safe.']
  ].map(([ic,a,b])=>`<div class="card flat row g12 ai-s" style="padding:14px"><div style="width:36px;height:36px;border-radius:12px;background:var(--surface-2);display:flex;align-items:center;justify-content:center;flex:none">${ic.startsWith('<')?ic:I(ic,'ic-s')}</div><div><div class="t-s" style="font-size:15px">${a}</div><div class="b-s ink2 mt4">${b}</div></div></div>`).join('')}</div></div>`,
 overlay:BOTTOM(`<div class="row g10 mb12"><div class="check on">${I('check','ic-xs')}</div><span class="b-s">I've read and accept the <u class="pri">full Host Agreement</u></span></div><div class="btn pri full mb8">Accept and continue</div>`),noGb:true}));

S({id:'H07',folder:F_HOST,name:'Host_Application_Review',title:'Application under review',
 desc:'Waiting state after submission. A simple timeline shows what\'s done and what\'s pending. The host is notified when approved.',
 notes:['No promised turnaround time (not decided).','Profile and rate can still be edited while waiting.','Approved → Host Home (H11) with a welcome sheet.'],
 to:['H11','H08']},
()=>SCR({body:`${APPBAR('',{left:'x'})}<div class="content pad col">
  <div class="row jc mt16"><div style="width:120px;height:120px;border-radius:60px;background:var(--gold-50);display:flex;align-items:center;justify-content:center;position:relative">${I('hourglass','ic-xl','color:var(--gold-d)')}<div style="position:absolute;inset:-12px;border-radius:50%;border:1px dashed var(--gold)"></div></div></div>
  <div class="d-m center mt32">You're almost there,<br>Ananya</div>
  <div class="b-l ink2 center mt8">We're reviewing your application. We'll notify you as soon as you can go online.</div>
  <div class="card mt32" style="padding:8px 18px">${[['Application submitted','Today, 4:12 PM','done'],['Identity & age verified','Aadhaar · PAN · Selfie','done'],['Profile review','Checking your photos and bio','cur'],['Ready to host','You can go online','']].map(([a,b,s],i)=>`<div class="row g14 ai-s" style="gap:14px;padding:10px 0"><div class="col" style="align-items:center"><div class="stepnum ${s}" style="width:24px;height:24px">${s==='done'?I('check','ic-xs'):s==='cur'?'<i class="dot" style="background:#fff;width:6px;height:6px"></i>':''}</div></div><div><div class="t-s" style="font-size:15px;${!s?'color:var(--ink-3)':''}">${a}</div><div class="b-s ink3">${b}</div></div></div>`).join('')}</div>
  <div class="spacer"></div><div class="btn neu full" style="margin-bottom:12px">Edit my profile</div></div>`}));

S({id:'H08',folder:F_HOST,name:'Host_Verification_Attention',title:'Verification needs attention',
 desc:'Recoverable failure state: one step needs to be redone (e.g. selfie did not match). Explains the reason and gives the exact fix.',
 notes:['Specific reason from the KYC result code.','Only the failed step is repeated.','Permanent rejections use a separate, final message (no retry).'],
 to:['H05']},
()=>SCR({body:`${APPBAR('',{left:'x'})}<div class="content pad col">
  <div class="empty mt24" style="padding:0"><div class="art" style="background:var(--warn-100);color:var(--warn)">${I('scan-face','ic-xl')}</div>
  <div class="d-m">Let's retake your selfie</div>
  <div class="b-l ink2 mt12">We couldn't clearly match your selfie to your ID photo. This usually happens in low light.</div></div>
  <div class="card mt24" style="padding:16px"><div class="t-s mb12">Tips for a good selfie</div>${[['sun','Face a window or bright light'],['glasses','Remove glasses and hats'],['smartphone','Hold the phone at eye level']].map(([ic,t])=>`<div class="row g12" style="height:40px">${I(ic,'ic-s','color:var(--primary)')}<span class="b-m">${t}</span></div>`).join('')}</div>
  <div class="spacer"></div><div class="btn pri full" style="margin-bottom:12px">Retake selfie</div></div>`}));

S({id:'H09',folder:F_HOST,name:'Host_Profile_Setup',title:'Host profile setup',
 desc:'Photos, display name, bio and languages. Photos are moderated and matched against the verified selfie.',
 notes:['Up to 6 photos; first is the cover used in Discover. Drag to reorder.','Bio 150 chars; phone numbers, links and handles are blocked.','Languages drive Discover filters.'],
 to:['H10']},
()=>SCR({body:`${HSTEP(6)}<div class="content pad">
  <div class="d-m mt4">Make your profile shine</div>
  <div style="display:grid;grid-template-columns:2fr 1fr;grid-template-rows:96px 96px;gap:8px;margin-top:20px">
   <div style="grid-row:span 2;border-radius:18px;overflow:hidden;position:relative">${ph('ananya','',`width:100%;height:100%`,240,200)}<span class="tag dark" style="position:absolute;left:8px;bottom:8px">Cover</span></div>
   <div style="border-radius:16px;overflow:hidden">${ph('ananya','',`width:100%;height:100%;background-position:50% 20%`,120,100)}</div>
   <div style="border-radius:16px;border:1.5px dashed var(--n300);display:flex;align-items:center;justify-content:center;color:var(--primary);background:var(--surface)">${I('plus','ic')}</div></div>
  <div class="field mt20"><span class="flabel">Display name</span><div class="input">Ananya</div></div>
  <div class="field mt16"><span class="flabel">About you</span><div class="input area" style="min-height:88px">Chai over coffee, old Bollywood songs and long conversations about travel. Let's talk about anything except work!<span class="caret"></span></div><span class="helper" style="text-align:right">118/150</span></div>
  <div class="flabel mt8" style="font-size:13px;font-weight:700;color:var(--ink-2)">Languages you speak</div>
  <div class="row wrap g8 mt8">${['Hindi','English','Marathi'].map(l=>`<div class="chip sm pon">${I('check','ic-xs')}${l}</div>`).join('')}<div class="chip sm">${I('plus','ic-xs')}Add</div></div></div>`,
 overlay:BOTTOM(`<div class="btn pri full mb8">Continue to rate</div>`),noGb:true}));

S({id:'H10',folder:F_HOST,name:'Host_Set_Rate',title:'Set your rate',
 desc:'Hosts choose their Diamond rate within platform limits (500–10,000 D/min) and their level\'s limit. Live preview of Beans earned per minute.',
 notes:['Stepper ± 100; slider for coarse changes.','Upper bound = level limit (ladder unresolved — D-16). Platform range 500–10,000.','Earnings preview: rate × 10,000 ÷ 16,670 Beans/min; ₹ at 200 Beans = ₹1.','Changes apply from the next call, never during a call.'],
 flags:['D-16'],to:['H07','H11']},
()=>SCR({body:`${APPBAR('Your rate')}<div class="content pad">
  <div class="b-l ink2 center mt8">Customers pay this rate in Diamonds for every second you're on a call.</div>
  <div class="row jc g16 mt32"><div class="iconbtn filled" style="width:52px;height:52px">${I('minus')}</div>
   <div class="center"><div class="row g8 jc">${DIA(30)}<span class="num" style="font-size:52px;font-weight:800;letter-spacing:-.03em;line-height:1">2,400</span></div><div class="lbl ink3 mt8">DIAMONDS / MINUTE</div></div>
   <div class="iconbtn filled" style="width:52px;height:52px">${I('plus')}</div></div>
  <div style="position:relative;height:36px;margin-top:28px"><div style="position:absolute;left:0;right:0;top:16px;height:6px;border-radius:3px;background:var(--n100)"></div><div style="position:absolute;left:0;width:36%;top:16px;height:6px;border-radius:3px;background:var(--n200)"></div><div style="position:absolute;left:0;width:18.9%;top:16px;height:6px;border-radius:3px;background:var(--primary)"></div><div style="position:absolute;left:calc(18.9% - 14px);top:5px;width:28px;height:28px;border-radius:14px;background:#fff;border:2px solid var(--primary);box-shadow:var(--sh2)"></div><div style="position:absolute;left:36%;top:10px;width:2px;height:18px;background:var(--n400)"></div></div>
  <div class="row between cap ink3"><span>500</span><span style="margin-left:60px">Your limit 4,000</span><span>10,000</span></div>
  <div class="hhero mt24" style="padding:18px 20px"><div class="cap" style="color:#E9C98C;letter-spacing:.12em">YOU EARN</div>
   <div class="row between mt8"><div class="row g8">${BEAN(24)}<span class="num" style="font-size:28px;font-weight:800">1,440</span><span class="b-m" style="opacity:.7">Beans / min</span></div><span class="t-s num" style="color:#E9C98C">≈ ₹7.20</span></div>
   <div class="b-s mt8" style="opacity:.7">≈ ₹432 for every hour on calls</div></div>
  <div class="banner info mt16">${I('trending-up','ic-s')}<span>Your level sets your maximum rate. Level up to unlock higher rates.</span></div></div>`,
 overlay:BOTTOM(`<div class="cap ink3 center mb8">Changes apply from your next call.</div><div class="btn pri full mb8">Save rate</div>`),noGb:true}));

const HHEAD = (on) => `<div class="row between" style="padding:6px 20px 0;height:56px"><div class="row g10">${av('ananya',40,on?'on':'off')}<div><div class="cap ink3">Good evening</div><div class="t-s">Ananya</div></div></div><div class="row g8"><div class="balpill" style="padding:0 12px 0 8px">${BEAN(18)}<span>2,10,750</span></div><div class="iconbtn filled" style="width:40px;height:40px">${I('bell','ic-s')}</div></div></div>`;
const TODAY = `<div class="row g12">${[['Today',`<span class="row g4">${BEAN(16)}69,106</span>`,'≈ ₹345.53'],['Calls','6','48 min on calls'],['Online','2h 14m','since 6:30 PM']].map(([a,b,c])=>`<div class="card f1" style="padding:14px 12px"><div class="cap ink3">${a.toUpperCase()}</div><div class="t-m num mt4" style="font-size:17px">${b}</div><div class="cap ink3 mt4" style="font-weight:600">${c}</div></div>`).join('')}</div>`;
S({id:'H11',folder:F_HOST,name:'Host_Home_Offline',title:'Host home — offline',
 desc:'Host dashboard while offline. A single dominant action — Go online — plus today\'s earnings and quick links. Optimised for one-handed, glanceable use.',
 notes:['Go online requires camera + mic permission (A15 if denied).','Offline means invisible in Discover and no incoming calls.','Beans pill → Earnings (H14).'],
 to:['H12','H14','H13']},
()=>SCR({body:`${HHEAD(false)}<div class="content pad">
  <div class="card mt12" style="padding:24px 20px;text-align:center">
   <div class="row jc"><div style="width:84px;height:84px;border-radius:42px;background:var(--surface-2);display:flex;align-items:center;justify-content:center;color:var(--ink-3)">${I('moon','ic-l')}</div></div>
   <div class="t-l mt16">You're offline</div><div class="b-m ink2 mt4">Customers can't see or call you.</div>
   <div class="btn ok full mt20" style="height:56px;border-radius:28px;font-size:17px"><i class="dot" style="background:#fff;box-shadow:0 0 0 4px rgba(255,255,255,.3)"></i>Go online</div>
   <div class="row jc g8 mt12 b-s ink3">${I('gift','ic-xs')}Free Call Card calls: <b style="color:var(--ink)">On</b></div></div>
  <div class="section-h mt24" style="padding:0"><span class="t">Today</span><span class="a">Earnings</span></div>${TODAY}
  <div class="list mt16">${[['user-round-pen','Edit profile & photos'],['gem','Change my rate','2,400 / min'],['sliders-horizontal','Availability settings']].map(([ic,a,b])=>`<div class="li"><div class="lic">${I(ic,'ic-s')}</div><div class="lt"><div class="a">${a}</div></div>${b?`<span class="b-s ink3 num">${b}</span>`:''}${I('chevron-right','ic-s chev')}</div>`).join('')}</div></div>`, nav:HNAV('home')}));

S({id:'H12',folder:F_HOST,name:'Host_Home_Online',title:'Host home — online, waiting for calls',
 desc:'Online state. A calm, living "waiting" visual tells the host she is visible and ready; incoming calls take over the screen (V16).',
 notes:['Green identity for "online" across the host app.','Free call counter: completed free minutes today / 20 cap.','Go offline is always one tap.','Keeps the screen awake setting is off by default; calls arrive as full-screen notifications.'],
 to:['V16','H11','H13']},
()=>SCR({body:`${HHEAD(true)}<div class="content pad">
  <div class="mt12" style="border-radius:24px;padding:24px 20px;text-align:center;background:linear-gradient(180deg,#E6F4EC 0%,#F4FAF6 100%);border:1px solid #CFE9DB">
   <div style="position:relative;width:120px;height:120px;margin:0 auto">${[120,96].map(s=>`<div style="position:absolute;left:${(120-s)/2}px;top:${(120-s)/2}px;width:${s}px;height:${s}px;border-radius:50%;border:1.5px solid rgba(46,139,98,${s===120?.18:.3})"></div>`).join('')}<div style="position:absolute;left:24px;top:24px">${av('ananya',72,null,'border:3px solid #fff;box-shadow:var(--sh2)')}</div></div>
   <div class="t-l mt12" style="color:#1D5E41">You're online</div><div class="b-m mt4" style="color:#2E6E50">Waiting for calls · visible in Discover</div>
   <div class="row g8 jc mt16"><span class="tag ok" style="background:#fff">${DIA(13)}<span class="num">2,400 / min</span></span><span class="tag ok" style="background:#fff">${I('gift','ic-xs')}Free calls 7/20</span></div>
   <div class="btn neu full mt20">Go offline</div></div>
  <div class="section-h mt24" style="padding:0"><span class="t">Today</span><span class="a">Earnings</span></div>${TODAY}
  <div class="card mt16 row g12" style="padding:14px 16px">${av('arjun',40)}<div class="f1"><div class="t-s" style="font-size:15px">Last call · Arjun</div><div class="b-s ink3">12 min 40 s · 8:58 PM</div></div><span class="row g4 t-s num okc">+18,236 ${BEAN(14)}</span></div></div>`, nav:HNAV('home')}));

S({id:'H13',folder:F_HOST,name:'Host_Availability',title:'Availability & free calls',
 desc:'Controls for being online and for opting in to Free Call Card calls, with the confirmed compensation and daily cap.',
 notes:['Free calls: 2,000 Beans (₹10) per completed free minute; max 20 per day; opt-in only.','Who can message me: Everyone / People I\'ve called.','No quotas, schedules or penalties anywhere in copy.'],
 to:['H12']},
()=>SCR({body:`${APPBAR('Availability')}<div class="content pad">
  <div class="list"><div class="li noic" style="padding:18px 16px"><div class="lt"><div class="a" style="font-size:16px">Online</div><div class="b">Customers can see you and call you</div></div><div class="switch okon"></div></div></div>
  <div class="grp-lbl mt24">Free Call Card</div>
  <div class="list"><div class="li noic" style="padding:16px"><div class="lt"><div class="a">Accept free calls</div><div class="b">One-minute calls with new customers</div></div><div class="switch on"></div></div>
   <div class="li noic" style="padding:16px;display:block"><div class="row between"><span class="b-m ink2">You earn per completed free minute</span><span class="row g4 t-s num">${BEAN(14)}2,000 <span class="b-s ink3">(₹10)</span></span></div>
    <div class="row between mt12"><span class="b-m ink2">Today</span><span class="t-s num">7 of 20</span></div><div class="prog mt8"><i style="width:35%;background:var(--gold)"></i></div>
    <div class="cap ink3 mt8" style="font-weight:600">Free calls are matched randomly among hosts who opted in. Up to 20 per day.</div></div></div>
  <div class="grp-lbl mt24">Messages</div>
  <div class="list"><div class="li noic"><div class="lt"><div class="a">Who can message me</div><div class="b">People I've called</div></div>${I('chevron-right','ic-s chev')}</div></div>
  <div class="banner pri mt20">${I('heart-handshake','ic-s')}<span>You're always free to decline any call or end it at any time. There are no quotas or penalties.</span></div></div>`}));

const BARS = [42,68,35,80,56,92,61];
S({id:'H14',folder:F_HOST,name:'Host_Earnings',title:'Earnings dashboard — Beans balance',
 desc:'Earnings home: total Beans with withdrawable vs on-hold split, weekly chart, and source breakdown. Leads directly into withdrawal.',
 notes:['Withdrawable = Beans older than 7 days. On hold shows release schedule.','₹ values at 200 Beans = ₹1 (server-calculated).','Chart: last 7 days, tap a bar for the day detail.','Withdraw disabled with explanation until withdrawals are enabled (H21).'],
 to:['H16','H15','H19','H21']},
()=>SCR({body:`${HEAD_H('Earnings',`<div class="iconbtn filled" style="width:40px;height:40px">${I('circle-help','ic-s')}</div>`)}<div class="content pad">
  <div class="hhero"><div class="row between"><span class="cap" style="color:#E9C98C;letter-spacing:.12em">BEANS BALANCE</span><span class="cap" style="opacity:.6">Never expire</span></div>
   <div class="row g10 mt12">${BEAN(34)}<span class="num" style="font-size:42px;font-weight:800;letter-spacing:-.03em;line-height:1">2,10,750</span></div>
   <div class="b-m mt8" style="opacity:.75">≈ ₹1,053.75</div>
   <div class="row mt20" style="background:rgba(255,255,255,.07);border-radius:16px;padding:12px 14px">
    <div class="f1"><div class="cap" style="opacity:.6">WITHDRAWABLE</div><div class="t-s num mt4">₹621.50</div><div class="cap num" style="opacity:.6">1,24,300 Beans</div></div>
    <div style="width:1px;background:rgba(255,255,255,.12)"></div>
    <div class="f1" style="padding-left:14px"><div class="cap" style="opacity:.6">ON HOLD · 7 DAYS</div><div class="t-s num mt4">₹432.25</div><div class="cap num" style="opacity:.6">86,450 Beans</div></div></div>
   <div class="btn full mt16" style="background:#E9C98C;color:#2A1D0F">Withdraw ₹621.50</div></div>
  <div class="card mt16" style="padding:16px"><div class="row between"><span class="t-s">This week</span><span class="b-s ink3 num">4,48,920 Beans</span></div>
   <div class="row ai-s mt16" style="height:110px;align-items:flex-end;gap:12px">${BARS.map((h,i)=>`<div class="col f1" style="align-items:center;gap:6px"><div style="width:100%;height:${h}px;border-radius:8px;background:${i===5?'var(--gold)':'var(--gold-100)'}"></div><span class="cap ${i===5?'':'ink3'}">${'MTWTFSS'[i]}</span></div>`).join('')}</div></div>
  <div class="list mt16">${[[I('video','ic-s'),'Paid calls','38 calls this week','4,20,920'],[I('gift','ic-s'),'Free Call Card minutes','14 completed','28,000']].map(([ic,a,b,c])=>`<div class="li"><div class="lic">${ic}</div><div class="lt"><div class="a">${a}</div><div class="b">${b}</div></div><span class="row g4 t-s num">${c}${BEAN(14)}</span></div>`).join('')}</div></div>`, nav:HNAV('earnings')}));

S({id:'H15',folder:F_HOST,name:'Host_Beans_Conversion',title:'Beans → ₹ conversion explainer',
 desc:'Transparent explanation of how Diamonds become Beans and Beans become rupees, with a calculator for any Bean amount.',
 notes:['Exact confirmed formula: 16,670 Diamonds spent = 10,000 Beans; 200 Beans = ₹1.','Calculator is display-only; payouts are server-calculated.','No Beans → Diamonds conversion (not a confirmed rule).'],
 to:['H14','H16']},
()=>SCR({body:`${APPBAR('How Beans work')}<div class="content pad">
  <div class="card" style="padding:20px">
   <div class="row between" style="align-items:center">
    <div class="col center" style="align-items:center;width:90px"><div style="width:56px;height:56px;border-radius:18px;background:var(--b50);display:flex;align-items:center;justify-content:center">${DIA(30)}</div><div class="t-s num mt8">16,670</div><div class="cap ink3">Diamonds spent</div></div>
    ${I('arrow-right','ic-s','color:var(--n400)')}
    <div class="col center" style="align-items:center;width:90px"><div style="width:56px;height:56px;border-radius:18px;background:var(--gold-50);display:flex;align-items:center;justify-content:center">${BEAN(30)}</div><div class="t-s num mt8">10,000</div><div class="cap ink3">Beans earned</div></div>
    ${I('arrow-right','ic-s','color:var(--n400)')}
    <div class="col center" style="align-items:center;width:70px"><div style="width:56px;height:56px;border-radius:18px;background:var(--ok-100);color:var(--ok);display:flex;align-items:center;justify-content:center;font-size:24px;font-weight:800">₹</div><div class="t-s num mt8">₹50</div><div class="cap ink3">Paid to you</div></div></div>
   <div class="hr mt20"></div><div class="row jc g8 mt16"><span class="tag gold">${BEAN(13)}200 Beans = ₹1</span></div></div>
  <div class="t-s mt24 mb8">Calculator</div>
  <div class="card" style="padding:16px"><div class="flabel" style="font-size:13px;font-weight:700;color:var(--ink-2)">Beans</div>
   <div class="input focus mt8" style="font-size:22px;font-weight:800">${BEAN(22)}<span class="num">1,24,300</span><span class="caret"></span></div>
   <div class="row jc mt12">${I('arrow-down','ic-s','color:var(--n400)')}</div>
   <div class="row between mt8" style="background:var(--ok-100);border-radius:14px;padding:14px 16px"><span class="b-m" style="color:#1D5E41;font-weight:700">You'd receive</span><span class="num" style="font-size:24px;font-weight:800;color:#1D5E41">₹621.50</span></div>
   <div class="cap ink3 mt8" style="font-weight:600">Before any tax deducted at source.</div></div>
  <div class="card flat mt16" style="padding:14px 16px"><div class="row between"><span class="b-m ink2">At your rate (2,400 / min)</span><span class="t-s num">1,440 Beans / min</span></div></div></div>`}));

S({id:'H16',folder:F_HOST,name:'Host_Withdraw',title:'Withdraw Beans',
 desc:'Withdrawal form: amount (defaults to the full withdrawable balance), destination in the host\'s own name, and when it will be paid.',
 notes:['Minimum ₹500 (1,00,000 Beans); max = withdrawable balance.','Destination must match the KYC name (bank or UPI).','Paid in the next weekly cycle; payout weekday — D-18.','TDS display — D-17.'],
 flags:['D-17','D-18'],to:['H17','H20','H25']},
()=>SCR({body:`${APPBAR('Withdraw')}<div class="content pad">
  <div class="center mt8"><div class="cap ink3">AMOUNT</div><div class="num mt8" style="font-size:52px;font-weight:800;letter-spacing:-.03em;line-height:1">₹621.50</div><div class="row g6 jc b-m ink3 mt8">${BEAN(16)}<span class="num">1,24,300 Beans</span></div></div>
  <div class="row g8 jc mt20">${['₹500','₹600','Max'].map((c,i)=>`<div class="chip ${i===2?'on':''}">${c}</div>`).join('')}</div>
  <div class="cap ink3 center mt8">Available ₹621.50 · Minimum ₹500</div>
  <div class="grp-lbl mt32">Pay to</div>
  <div class="list"><div class="li"><div class="lic" style="background:#EEF3FF;color:#2C5AA0">${I('at-sign','ic-s')}</div><div class="lt"><div class="a">ananya.sharma@okaxis</div><div class="b row g4">${I('badge-check','ic-xs','color:var(--ok)')}UPI · Ananya Sharma</div></div><span class="lbl pri">Change</span></div></div>
  <div class="card flat mt16" style="padding:4px 16px">${ROWKV('Paid in','Next weekly payout')}<div class="hr"></div>${ROWKV('Expected','Mon, 23 Nov')}<div class="hr"></div>${ROWKV('Tax (TDS)','Shown on payout slip')}</div></div>`,
 overlay:BOTTOM(`<div class="btn pri full mb8">Withdraw ₹621.50</div>`),noGb:true}));

S({id:'H17',folder:F_HOST,name:'Host_Withdraw_Confirm',title:'Withdrawal — confirm',
 desc:'Final confirmation sheet summarising Beans, rupee amount, destination and timing before the request is placed.',
 notes:['Requires device authentication (biometric / screen lock) on confirm.','Request is irreversible once processing starts; can be cancelled while "Requested".'],
 flags:['D-17'],to:['H18']},
()=>SCR({body:`${APPBAR('Withdraw')}<div class="content pad"><div class="center mt8"><div class="num mt16" style="font-size:52px;font-weight:800;letter-spacing:-.03em">₹621.50</div></div></div>`,noGb:true,
 overlay:`<div class="dim"></div><div class="sheet"><div class="grab"></div>
  <div class="t-l">Confirm withdrawal</div>
  <div class="card flat mt16" style="padding:4px 16px;background:var(--surface-2);border:none">
   ${ROWKV('Beans',`<span class="row g4">${BEAN(14)}1,24,300</span>`)}<div class="hr"></div>${ROWKV('Amount','₹621.50')}<div class="hr"></div>${ROWKV('To','UPI · ananya.sharma@okaxis')}<div class="hr"></div>${ROWKV('Expected','Mon, 23 Nov')}</div>
  <div class="b-s ink3 mt12">Tax deducted at source (if any) will be shown on your payout slip. Payouts flagged for review are held until checks are complete.</div>
  <div class="btn pri full mt20">${I('fingerprint','ic-s')}Confirm withdrawal</div><div class="btn txt full mt4" style="color:var(--ink)">Cancel</div>${GB()}</div>`}));

S({id:'H18',folder:F_HOST,name:'Host_Withdraw_Requested',title:'Withdrawal requested (success)',
 desc:'Success state after a withdrawal request. Sets the expectation of the weekly cycle and shows status tracking.',
 notes:['Status flow: Requested → Processing → Paid (or Under review / Failed → returned).','Notification on each status change.'],
 to:['H19','H14']},
()=>SCR({body:`<div class="content pad col" style="align-items:center">
  <div class="empty mt40" style="padding:0"><div class="art" style="background:var(--ok-100);color:var(--ok)">${I('circle-check-big','ic-xl')}</div>
  <div class="over okc">Withdrawal requested</div><div class="num mt8" style="font-size:44px;font-weight:800;letter-spacing:-.03em">₹621.50</div>
  <div class="b-l ink2 mt8">We'll send it to <b style="color:var(--ink)">ananya.sharma@okaxis</b> in the next weekly payout.</div></div>
  <div class="card mt24" style="width:100%;padding:8px 18px">${[['Requested','Today, 9:14 PM','done'],['Processing','Weekly payout run','cur'],['Paid','Expected Mon, 23 Nov','']].map(([a,b,s])=>`<div class="row g14" style="gap:14px;padding:10px 0"><div class="stepnum ${s}" style="width:24px;height:24px">${s==='done'?I('check','ic-xs'):''}</div><div><div class="t-s" style="font-size:15px;${!s?'color:var(--ink-3)':''}">${a}</div><div class="b-s ink3">${b}</div></div></div>`).join('')}</div>
  <div class="spacer"></div><div class="btn pri full">Done</div><div class="btn txt full mt4" style="margin-bottom:4px">View payout history</div></div>`}));

S({id:'H19',folder:F_HOST,name:'Host_Payout_History',title:'Payout history',
 desc:'All withdrawals with clear statuses. Failed payouts are returned to the Beans balance automatically.',
 notes:['Statuses: Requested, Processing, Paid, Under review, Failed (returned).','Row → payout slip with UTR reference and tax lines.'],
 flags:['D-17'],to:['H14']},
()=>SCR({body:`${APPBAR('Payouts')}<div class="content pad">
  <div class="card flat row" style="padding:14px 16px"><div class="f1"><div class="cap ink3">PAID OUT · 2026</div><div class="t-m num mt4">₹4,812.00</div></div><div class="f1" style="border-left:1px solid var(--line);padding-left:16px"><div class="cap ink3">IN PROGRESS</div><div class="t-m num mt4">₹621.50</div></div></div>
  <div class="list mt16">${[
   ['Processing','warn','₹621.50','Requested 19 Nov · UPI','clock-3'],
   ['Paid','ok','₹1,240.00','16 Nov · UTR 6132 8841 0921','circle-check'],
   ['Under review','info','₹980.00','9 Nov · We\'ll update you soon','shield-question'],
   ['Paid','ok','₹1,512.00','2 Nov · UTR 6128 1201 7735','circle-check'],
   ['Failed · returned','err','₹540.00','26 Oct · Beans returned to balance','circle-x'],
   ['Paid','ok','₹1,080.00','19 Oct · UTR 6119 4410 2208','circle-check']
  ].map(([s,c,a,b,ic])=>`<div class="li"><div class="lic" style="background:var(--${c}-100);color:var(--${c})">${I(ic,'ic-s')}</div><div class="lt"><div class="a num">${a}</div><div class="b">${b}</div></div><span class="tag ${c}">${s}</span></div>`).join('')}</div></div>`}));

S({id:'H20',folder:F_HOST,name:'Host_Payout_Method',title:'Payout method',
 desc:'Add or change where payouts go: a UPI ID or bank account in the host\'s own name. Names are matched to KYC before use.',
 notes:['One active method at a time.','Verification via a ₹1 penny-drop / UPI name lookup (provider dependent — D-19).','Mismatch → blocked with explanation.'],
 flags:['D-19'],to:['H16']},
()=>SCR({body:`${APPBAR('Payout method')}<div class="content pad">
  <div class="seg"><div class="on">UPI ID</div><div>Bank account</div></div>
  <div class="field mt24"><span class="flabel">UPI ID</span><div class="input focus">ananya.sharma@okaxis<span class="caret"></span></div></div>
  <div class="card flat row g12 mt12" style="padding:14px 16px;background:var(--ok-100);border:none">${I('user-check','ic-s','color:var(--ok)')}<div class="f1"><div class="t-s" style="color:#1D5E41">Verified · ANANYA SHARMA</div><div class="b-s" style="color:#2E6E50">Matches your verified ID</div></div></div>
  <div class="banner warn mt20">${I('triangle-alert','ic-s')}<span>Payouts can only go to an account in your own name. We can't pay to family or friends' accounts.</span></div></div>`,
 overlay:BOTTOM(`<div class="btn pri full mb8">Save payout method</div>`),noGb:true}));

S({id:'H21',folder:F_HOST,name:'Host_Withdrawals_Unavailable',title:'Withdrawals not yet available',
 desc:'Pre-launch state: withdrawals are enabled only after incorporation, legal/tax advice and payout onboarding. Beans keep accruing and never expire.',
 notes:['Shown in place of the Withdraw button on H14 and as this full-screen explainer.','Copy must not promise a date.','Matches founder rule R3-7.'],
 to:['H14']},
()=>SCR({body:`${APPBAR('')}<div class="content pad col" style="align-items:center">
  <div class="empty mt24" style="padding:0"><div class="art" style="background:var(--gold-50);color:var(--gold-d)">${I('landmark','ic-xl')}</div>
  <div class="d-m">Withdrawals are coming soon</div>
  <div class="b-l ink2 mt12">We're finishing the setup needed to pay hosts safely and legally. Your Beans are safe and never expire.</div></div>
  <div class="hhero mt24" style="width:100%;padding:18px 20px"><div class="row between"><span class="cap" style="color:#E9C98C">YOUR BEANS</span><span class="cap" style="opacity:.6">≈ ₹1,053.75</span></div><div class="row g8 mt8">${BEAN(24)}<span class="num" style="font-size:30px;font-weight:800">2,10,750</span></div></div>
  <div class="card flat mt16 row g12" style="width:100%;padding:14px 16px">${I('bell-ring','ic-s','color:var(--primary)')}<span class="b-m f1">We'll notify you the moment withdrawals open.</span></div>
  <div class="spacer"></div><div class="btn neu full" style="margin-bottom:12px">Add payout method now</div></div>`}));

S({id:'H22',folder:F_HOST,name:'Host_Call_History',title:'Calls — host call history',
 desc:'The host Calls tab: completed, free and missed calls with Beans earned per call.',
 notes:['Missed/declined rows have no penalty language.','Row → call detail with report option (within a time window — D-20).'],
 flags:['D-20'],to:['V18']},
()=>SCR({body:`${HEAD_H('Calls')}<div class="content">
  <div class="pad"><div class="seg"><div class="on">All</div><div>Paid</div><div>Free</div><div>Missed</div></div></div>
  <div class="grp-lbl" style="padding:20px 24px 8px">Today</div>
  <div class="col">${[['arjun','Arjun','12 min 40 s · 8:58 PM','+18,236','video'],['rohan','Rohan','Free minute · 8:20 PM','+2,000','gift'],['vikram','Vikram','Missed · 7:51 PM','','phone-missed'],['rohan','Rohan','8 min 05 s · 7:02 PM','+11,637','video'],['vikram','Vikram','4 min 30 s · 6:41 PM','+6,479','video']].map(([k,n,b,c,ic])=>`<div class="row g12" style="padding:12px 20px">${av(k,48)}<div class="f1"><div class="t-s">${n}</div><div class="b-s ink3 row g4">${I(ic,'ic-xs')}${b}</div></div>${c?`<span class="row g4 t-s num okc">${c}${BEAN(14)}</span>`:'<span class="b-s ink3">—</span>'}</div>`).join('')}</div>
  <div class="grp-lbl" style="padding:16px 24px 8px">Yesterday</div>
  <div class="row g12" style="padding:12px 20px">${av('arjun',48)}<div class="f1"><div class="t-s">Arjun</div><div class="b-s ink3 row g4">${I('video','ic-xs')}6 min 12 s · 10:15 PM</div></div><span class="row g4 t-s num okc">+8,926${BEAN(14)}</span></div></div>`, nav:HNAV('calls')}));

S({id:'H23',folder:F_HOST,name:'Host_Profile_Tab',title:'Host profile tab',
 desc:'Host\'s own profile hub: public profile preview, rate, verification badge, level, and links into settings.',
 notes:['"Preview as customer" opens the C07 layout read-only.','Level shown as number only; names and thresholds unresolved (D-16).'],
 flags:['D-16'],to:['H09','H10','H24']},
()=>SCR({body:`<div class="content">
  <div style="position:relative;height:250px">${ph('ananya','',`position:absolute;inset:0`,390,250)}<div class="scrim-b" style="height:100%"></div>
   <div class="row between" style="position:absolute;top:8px;left:12px;right:12px"><div></div><div class="iconbtn glass">${I('settings')}</div></div>
   <div style="position:absolute;left:20px;bottom:18px;color:#fff"><div class="row g8"><span class="d-m">Ananya, 24</span>${I('badge-check','ic')}</div><div class="b-m" style="opacity:.85">Pune · Verified host · Level 4</div></div></div>
  <div class="pad mt16"><div class="row g12">${[['Rate',`<span class="row g4">${DIA(15)}2,400</span>`],['Calls','214'],['Hours','61h']].map(([a,b])=>`<div class="card f1" style="padding:12px;text-align:center"><div class="cap ink3">${a.toUpperCase()}</div><div class="t-s num mt4 row jc">${b}</div></div>`).join('')}</div>
  <div class="btn neu full mt16">${I('eye','ic-s')}Preview as customer</div>
  <div class="list mt16">${[['images','Photos & bio'],['gem','My rate'],['languages','Languages'],['landmark','Payout method'],['sliders-horizontal','Availability & free calls']].map(([ic,a])=>`<div class="li"><div class="lic">${I(ic,'ic-s')}</div><div class="lt"><div class="a">${a}</div></div>${I('chevron-right','ic-s chev')}</div>`).join('')}</div></div></div>`, nav:HNAV('profile'), light:true}));

S({id:'H24',folder:F_HOST,name:'Host_Settings',title:'Host settings',
 desc:'Settings for hosts. Same structure as customer settings with host-only sections (payouts, tax, host agreement).',
 notes:['Shared rows reuse customer components (S03).','Delete account warns about unpaid Beans (D-21).'],
 flags:['D-21'],to:['S04','S05','S06','S07','S08','S09']},
()=>SCR({body:`${APPBAR('Settings')}<div class="content pad">
  ${[['Hosting',[['sliders-horizontal','Availability & free calls'],['landmark','Payout method','UPI'],['file-text','Tax details','PAN ••••821K']]],
     ['Privacy & safety',[['message-square-lock','Who can message me','People I\'ve called'],['ban','Blocked users','2'],['shield-check','Safety Centre']]],
     ['App',[['bell','Notifications'],['life-buoy','Help & support'],['scale','Legal & host agreement']]]]
   .map(([g,rows])=>`<div class="grp-lbl mt16">${g}</div><div class="list">${rows.map(([ic,a,b])=>`<div class="li"><div class="lic">${I(ic,'ic-s')}</div><div class="lt"><div class="a">${a}</div></div>${b?`<span class="b-s ink3">${b}</span>`:''}${I('chevron-right','ic-s chev')}</div>`).join('')}</div>`).join('')}
  <div class="list mt16"><div class="li"><div class="lic">${I('log-out','ic-s')}</div><div class="lt"><div class="a">Log out</div></div></div><div class="li"><div class="lic err">${I('trash-2','ic-s')}</div><div class="lt"><div class="a errc">Delete account</div></div></div></div></div>`}));

S({id:'H25',folder:F_HOST,name:'Host_Withdraw_Below_Minimum',title:'Withdraw — below minimum (error state)',
 desc:'Withdrawal attempted with less than ₹500 withdrawable. Explains the minimum and when on-hold Beans will release.',
 notes:['Primary button disabled.','Shows the next release date from the 7-day hold schedule.'],
 to:['H14']},
()=>SCR({body:`${APPBAR('Withdraw')}<div class="content pad">
  <div class="center mt8"><div class="cap ink3">AVAILABLE TO WITHDRAW</div><div class="num mt8" style="font-size:52px;font-weight:800;letter-spacing:-.03em;line-height:1;color:var(--ink-3)">₹432.25</div><div class="row g6 jc b-m ink3 mt8">${BEAN(16)}<span class="num">86,450 Beans</span></div></div>
  <div class="banner warn mt24">${I('info','ic-s')}<div><div style="font-weight:800">Minimum withdrawal is ₹500</div><div class="mt4" style="font-weight:600">You need ₹67.75 more (13,550 Beans). On-hold Beans worth ₹210.40 become withdrawable on Sat, 21 Nov.</div></div></div>
  <div class="card mt16" style="padding:16px"><div class="row between"><span class="b-m ink2">Progress to ₹500</span><span class="t-s num">86%</span></div><div class="prog mt12" style="height:8px;border-radius:4px"><i style="width:86%;background:var(--gold)"></i></div></div></div>`,
 overlay:BOTTOM(`<div class="btn dis full mb8">Withdraw</div>`),noGb:true}));
