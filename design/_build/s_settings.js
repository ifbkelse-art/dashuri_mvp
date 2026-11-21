// SETTINGS, PROFILE & ACCOUNT (customer; host reuses with H24)
const F_SET='Customer';
const ROWS = (rows) => `<div class="list">${rows.map(([ic,a,b,cls])=>`<div class="li"><div class="lic ${cls||''}">${I(ic,'ic-s')}</div><div class="lt"><div class="a ${cls==='err'?'errc':''}">${a}</div></div>${b?`<span class="b-s ink3">${b}</span>`:''}${cls==='err'?'':I('chevron-right','ic-s chev')}</div>`).join('')}</div>`;

S({id:'S01',folder:F_SET,name:'Customer_Profile',title:'Customer profile (Profile tab)',
 desc:'The customer\'s own profile hub with identity, level, wallet shortcut and account links.',
 notes:['Level is a single shared level per account (XP from Diamonds purchased). Names/thresholds unresolved — D-16.','Wallet card → W01.','Phone shown masked.'],
 flags:['D-16'],to:['S02','W01','S03']},
()=>SCR({body:`<div class="content">
  <div class="row between" style="padding:8px 20px"><span class="d-m">Profile</span><div class="iconbtn filled" style="width:40px;height:40px">${I('settings','ic-s')}</div></div>
  <div class="pad mt8"><div class="card row g16" style="padding:18px">${av('arjun',72)}<div class="f1"><div class="t-l">Arjun</div><div class="b-s ink3">+91 98204 •••35</div><div class="row g6 mt8"><span class="tag pri">${I("sparkles","ic-xs")}Level 2</span></div></div></div>
   <div class="card mt12" style="padding:16px"><div class="row between"><span class="t-s">Level 2</span><span class="b-s ink3 num">68% to Level 3</span></div><div class="prog mt12" style="height:8px;border-radius:4px"><i style="width:68%"></i></div><div class="cap ink3 mt8" style="font-weight:600">Earn XP when you buy Diamonds.</div></div>
   <div class="whero mt12 row between" style="padding:16px 18px;border-radius:20px"><div><div class="cap" style="opacity:.7">DIAMONDS</div><div class="row g6 mt4">${DIA(20)}<span class="t-m num">12,480</span></div></div><div class="btn white xs">${I('plus','ic-xs')}Buy</div></div>
   <div class="mt16">${ROWS([['user-round-pen','Edit profile'],['bell','Notifications'],['lock','Privacy & safety'],['life-buoy','Help & support'],['scale','Legal']])}</div></div></div>`, nav:CNAV('profile')}));

S({id:'S02',folder:F_SET,name:'Edit_Profile',title:'Edit profile',
 desc:'Edit display name and photo. Identity fields (phone, date of birth) are read-only; gender is private.',
 notes:['Save enabled only when something changes.','Photo changes go through moderation; old photo stays until approved.'],
 to:['S01']},
()=>SCR({body:`${APPBAR('Edit profile',{right:`<div class="btn txt" style="height:44px;font-size:15px">Save</div>`})}<div class="content pad">
  <div class="col mt8" style="align-items:center"><div style="position:relative">${av('arjun',104)}<div style="position:absolute;right:-2px;bottom:2px;width:36px;height:36px;border-radius:18px;background:var(--primary);color:#fff;display:flex;align-items:center;justify-content:center;border:3px solid var(--bg)">${I('camera','ic-xs')}</div></div></div>
  <div class="field mt24"><span class="flabel">Display name</span><div class="input focus">Arjun<span class="caret"></span></div></div>
  <div class="field mt16"><span class="flabel">Gender · private</span><div class="input">Man<span class="spacer"></span>${I('chevron-down','ic-s','color:var(--n400)')}</div></div>
  <div class="field mt16"><span class="flabel">Mobile number</span><div class="input" style="background:var(--surface-2);color:var(--ink-2)">+91 98204 17735<span class="spacer"></span><span class="tag ok">${I('check','ic-xs')}Verified</span></div></div>
  <div class="field mt16"><span class="flabel">Date of birth</span><div class="input" style="background:var(--surface-2);color:var(--ink-2)">14 April 1998<span class="spacer"></span>${I('lock','ic-xs')}</div><span class="helper">Contact support to correct your date of birth.</span></div></div>`}));

S({id:'S03',folder:F_SET,name:'Settings',title:'Settings (customer)',
 desc:'Grouped settings list. Destructive actions are isolated at the bottom.',
 notes:['Groups: Account, Privacy & safety, App, Danger zone.','"Become a host" entry appears for eligible accounts (D-04).'],
 flags:['D-04'],to:['S02','S04','S05','S06','S07','S08','S09']},
()=>SCR({body:`${APPBAR('Settings')}<div class="content pad">
  <div class="grp-lbl mt8">Account</div>${ROWS([['user-round-pen','Edit profile'],['phone','Phone number','•••35'],['wallet','Wallet & purchases']])}
  <div class="grp-lbl mt20">Privacy & safety</div>${ROWS([['message-square-lock','Who can message me','Everyone'],['ban','Blocked users','1'],['shield-check','Safety Centre']])}
  <div class="grp-lbl mt20">App</div>${ROWS([['bell','Notifications'],['life-buoy','Help & support'],['scale','Legal']])}
  <div class="list mt20"><div class="li"><div class="lic">${I('log-out','ic-s')}</div><div class="lt"><div class="a">Log out</div></div></div><div class="li"><div class="lic err">${I('trash-2','ic-s')}</div><div class="lt"><div class="a errc">Delete account</div></div></div></div>
  <div class="cap ink3 center mt16">Dashuri 1.0.0 (100)</div></div>`}));

S({id:'S04',folder:F_SET,name:'Privacy_Messaging',title:'Privacy — who can message me',
 desc:'User-controlled messaging permission (confirmed rule): Everyone, or only people you\'ve had a call with.',
 notes:['Applies immediately to new conversations; existing threads follow the new rule.','Hosts see the same control in H13 / H24.'],
 to:['S03']},
()=>SCR({body:`${APPBAR('Privacy')}<div class="content pad">
  <div class="t-s mt8">Who can message me</div><div class="b-s ink3 mt4">Choose who can start a chat with you.</div>
  <div class="col g12 mt16">${[['Everyone','Anyone on Dashuri can send you a message.',1],['People I\'ve called','Only people you\'ve had a video call with.',0]].map(([a,b,on])=>`<div class="card row g12 ai-s" style="padding:16px;${on?'border:1.5px solid var(--primary);background:var(--b50)':''}"><div class="f1"><div class="t-s">${a}</div><div class="b-s ink2 mt4">${b}</div></div><div class="radio ${on?'on':''}"></div></div>`).join('')}</div>
  <div class="grp-lbl mt32">Safety</div>${ROWS([['ban','Blocked users','1'],['flag','My reports'],['shield-check','Safety Centre']])}</div>`}));

S({id:'S05',folder:F_SET,name:'Notification_Settings',title:'Notification settings',
 desc:'Per-category notification toggles. Safety and account notices cannot be turned off.',
 notes:['Mirrors Android notification channels (one channel per row).','Hosts get an extra "Incoming calls" channel (always on while online).'],
 to:['S03']},
()=>SCR({body:`${APPBAR('Notifications')}<div class="content pad">
  <div class="list mt8">${[['Messages','New chat messages',1],['Payments','Purchases, refunds and receipts',1],['Call summaries','After each call',0],['Reminders','Unused Free Call Card',0]].map(([a,b,on])=>`<div class="li noic" style="padding:16px"><div class="lt"><div class="a">${a}</div><div class="b">${b}</div></div><div class="switch ${on?'on':''}"></div></div>`).join('')}</div>
  <div class="list mt16"><div class="li noic" style="padding:16px"><div class="lt"><div class="a">Safety & account</div><div class="b">Report outcomes, security alerts. Always on.</div></div><div class="switch on" style="opacity:.45"></div></div></div></div>`}));

S({id:'S06',folder:F_SET,name:'Blocked_Users',title:'Blocked users',
 desc:'List of blocked accounts with unblock. Blocked users cannot see, call or message you.',
 notes:['Unblock asks for confirmation.','Empty state: "You haven\'t blocked anyone."'],
 to:['S04']},
()=>SCR({body:`${APPBAR('Blocked users')}<div class="content pad">
  <div class="b-m ink2 mt8 mb16">Blocked people can't see your profile, call or message you. They aren't notified.</div>
  <div class="list">${[['tara','Tara','Blocked 12 Nov'],['zoya','Zoya','Blocked 3 Nov']].map(([k,n,d])=>`<div class="li">${av(k,44,null,'filter:grayscale(1)')}<div class="lt"><div class="a">${n}</div><div class="b">${d}</div></div><div class="btn neu xs">Unblock</div></div>`).join('')}</div></div>`}));

S({id:'S07',folder:F_SET,name:'Help_Support',title:'Help & support / Safety Centre',
 desc:'Self-serve help topics, Safety Centre, and contact options. Ticket form pre-fills context (transaction, call).',
 notes:['Safety Centre card is always first.','Contact channels and SLA — D-22.'],
 flags:['D-22'],to:['S08']},
()=>SCR({body:`${APPBAR('Help')}<div class="content pad">
  <div class="search">${I('search','ic-s')}Search help articles</div>
  <div class="card mt16 row g14" style="gap:14px;padding:16px;background:var(--b50);border-color:var(--b100)"><div style="width:44px;height:44px;border-radius:14px;background:var(--primary);color:#fff;display:flex;align-items:center;justify-content:center">${I('shield-check')}</div><div class="f1"><div class="t-s" style="color:var(--b900)">Safety Centre</div><div class="b-s" style="color:var(--b800)">Report a problem, child safety, staying safe on calls</div></div>${I('chevron-right','ic-s','color:var(--b400)')}</div>
  <div class="grp-lbl mt20">Topics</div>
  ${ROWS([['gem','Diamonds & payments'],['video','Calls & billing'],['message-circle','Chats & messages'],['user-round','Account & verification']])}
  <div class="grp-lbl mt20">Still need help?</div>
  ${ROWS([['messages-square','Contact support','Reply in app']])}</div>`}));

S({id:'S08',folder:F_SET,name:'Legal',title:'Legal information',
 desc:'Legal documents, including the grievance redressal contact required under Indian IT Rules and Play\'s Child Safety Standards.',
 notes:['Documents open in an in-app reader.','Grievance Officer details are a legal requirement (PRO-REVIEW, D-12).'],
 flags:['D-12'],to:['S03']},
()=>SCR({body:`${APPBAR('Legal')}<div class="content pad">
  ${ROWS([['file-text','Terms of Service'],['lock-keyhole','Privacy Policy'],['users','Community Guidelines'],['baby','Child Safety Standards'],['coins','Diamonds & refunds policy']])}
  <div class="grp-lbl mt20">Grievance redressal</div>
  <div class="card" style="padding:16px"><div class="t-s">Grievance Officer</div><div class="b-s ink2 mt4">For complaints under the IT Rules. We acknowledge within 24 hours.</div><div class="btn neu sm mt12" style="width:fit-content">${I('mail','ic-s')}Contact Grievance Officer</div></div>
  <div class="cap ink3 center mt24">BK Enterprises · Dashuri</div></div>`}));

S({id:'S09',folder:F_SET,name:'Delete_Account',title:'Delete account',
 desc:'Explains what deletion means before the user commits. Highlights any remaining Diamond balance.',
 notes:['Treatment of unspent Diamonds on deletion is NOT decided — D-21.','Retention of records required by law is disclosed.','Continue → confirmation dialog (S10).'],
 flags:['D-21'],to:['S10']},
()=>SCR({body:`${APPBAR('Delete account')}<div class="content pad">
  <div class="d-m mt8">We're sorry to see you go</div>
  <div class="b-l ink2 mt8">Deleting your account is permanent. Here's what happens:</div>
  <div class="col g12 mt20">${[['user-x','Your profile, photos and chats are removed'],['ban','You can\'t log back in with this account'],['file-lock','Some records are kept as required by law']].map(([ic,t])=>`<div class="row g12">${I(ic,'ic-s','color:var(--ink-2)')}<span class="b-m">${t}</span></div>`).join('')}</div>
  <div class="banner warn mt20">${I('gem','ic-s')}<span>You still have <b>12,480 Diamonds</b>. Unused Diamonds can't be recovered after deletion.</span></div>
  <div class="t-s mt24 mb8">Why are you leaving? (optional)</div>
  <div class="row wrap g8">${['Too expensive','Not enough hosts','Safety concerns','Taking a break','Other'].map((r,i)=>`<div class="chip sm ${i===3?'pon':''}">${r}</div>`).join('')}</div></div>`,
 overlay:`<div style="position:absolute;bottom:0;left:0;right:0;padding:12px 20px 0;background:var(--bg)"><div class="btn dan-o full">Continue to delete</div><div class="btn txt full" style="color:var(--ink)">Keep my account</div>${GB()}</div>`,noGb:true}));

S({id:'S10',folder:F_SET,name:'Delete_Account_Confirm',title:'Delete account — final confirmation',
 desc:'Final, deliberate confirmation. Requires re-verification by OTP before deletion is processed.',
 notes:['"Delete" sends an OTP to the registered phone, then deletes.','Grace period / undo window — D-21.'],
 flags:['D-21'],to:['A02']},
()=>SCR({body:`${APPBAR('Delete account')}<div class="content pad"><div class="d-m mt8">We're sorry to see you go</div></div>`,
 overlay:`<div class="dim"></div><div class="dialog center"><div class="row jc"><div style="width:64px;height:64px;border-radius:20px;background:var(--err-100);color:var(--err);display:flex;align-items:center;justify-content:center">${I('trash-2','ic-l')}</div></div>
  <div class="t-l mt16">Delete your account?</div>
  <div class="b-m ink2 mt8">This can't be undone. Your 12,480 Diamonds will be lost. We'll send a code to +91 •••••17735 to confirm.</div>
  <div class="btn dan full mt24">Send code & delete</div><div class="btn txt full mt4" style="color:var(--ink)">Cancel</div></div>`}));
