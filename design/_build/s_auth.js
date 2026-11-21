// AUTHENTICATION & ONBOARDING
const F_AUTH='Authentication';
const NUMPAD = () => `<div class="kbd">${[['1',''],['2','ABC'],['3','DEF'],['4','GHI'],['5','JKL'],['6','MNO'],['7','PQRS'],['8','TUV'],['9','WXYZ']].reduce((a,k,i)=>{if(i%3===0)a.push([]);a[a.length-1].push(k);return a;},[]).map(r=>`<div class="kr">${r.map(([n,l])=>`<div class="k">${n}<small>${l}</small></div>`).join('')}</div>`).join('')}<div class="kr"><div class="k g" style="font-size:15px">+*#</div><div class="k">0</div><div class="k g">${I('delete','ic')}</div></div>${GB()}</div>`;
const AUTHTOP = (step, total=6) => `<div class="appbar"><div class="iconbtn">${I('arrow-left')}</div><div class="f1 pad" style="padding:0 8px"><div class="steps">${Array.from({length:total},(_, i)=>`<i class="${i<step?'on':''}"></i>`).join('')}</div></div><div class="lbl ink3" style="width:44px;text-align:center">${step}/${total}</div></div>`;
const GOOGLE_G = `<svg width="20" height="20" viewBox="0 0 48 48"><path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z"/><path fill="#FF3D00" d="m6.3 14.7 6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z"/><path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2c-2 1.5-4.5 2.4-7.2 2.4-5.2 0-9.6-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44z"/><path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z"/></svg>`;

S({id:'A01',folder:F_AUTH,name:'Splash',title:'Splash',
 desc:'Cold-start brand moment while the session is restored (SessionCubit). Shown for the minimum time needed; never longer than ~1.5 s.',
 notes:['Full-bleed burgundy radial gradient (Burgundy 600 → 950).','Monogram 88 pt, wordmark Display XL in white.','Routes to Welcome (no session) or Discover / Host Home (session restored).'],
 to:['A02','C01','H12']},
()=>SCR({light:true,bg:'radial-gradient(90% 60% at 50% 38%,#9A2D50 0%,#761C3B 38%,#451024 78%,#2B0A17 100%)',body:`<div class="content col jc" style="align-items:center;color:#fff">
  <div style="position:absolute;width:420px;height:420px;border-radius:50%;border:1px solid rgba(255,255,255,.08);top:150px;left:-15px"></div>
  <div style="position:absolute;width:300px;height:300px;border-radius:50%;border:1px solid rgba(255,255,255,.1);top:210px;left:45px"></div>
  ${LOGO(88,'#fff','var(--b700)')}<div class="mt24">${WORD(52,'#fff')}</div>
  <div class="b-m mt12" style="opacity:.75;letter-spacing:.02em">Real conversations, face to face.</div>
  <div style="position:absolute;bottom:36px;left:0;right:0" class="center"><span class="cap" style="opacity:.6;letter-spacing:.14em">FOR ADULTS 18+ ONLY</span></div></div>`}));

S({id:'A02',folder:F_AUTH,name:'Welcome',title:'Welcome',
 desc:'First screen for signed-out users. Sets the premium tone and explains the product in one line before asking for anything.',
 notes:['Arched photo trio uses verified-host imagery only (never customer photos).','Primary: Create account → A04. Secondary: Log in → A03.','Legal line links to Terms and Privacy (S08).'],
 to:['A03','A04']},
()=>SCR({body:`<div class="content">
  <div style="position:relative;height:430px;margin-top:4px">
   ${ph('meera','',`position:absolute;left:18px;top:70px;width:118px;height:220px;border-radius:60px 60px 22px 22px;box-shadow:var(--sh2)`,180,330)}
   ${ph('ananya','',`position:absolute;left:136px;top:10px;width:132px;height:262px;border-radius:66px 66px 24px 24px;box-shadow:var(--sh3);z-index:2;border:4px solid var(--bg)`,200,390)}
   ${ph('kavya','',`position:absolute;right:18px;top:96px;width:118px;height:220px;border-radius:60px 60px 22px 22px;box-shadow:var(--sh2)`,180,330)}
   <div class="pill-status light" style="position:absolute;left:150px;top:248px;z-index:3;box-shadow:var(--sh2)"><i class="dot on"></i>342 hosts online</div>
   <div style="position:absolute;left:0;right:0;top:350px" class="row jc">${LOGO(40)}</div>
  </div>
  <div class="pad center" style="margin-top:-6px">
   <div class="d-l">Meet someone <span class="it pri">real</span>,<br>face to face.</div>
   <div class="b-l ink2 mt12" style="padding:0 12px">Private one-to-one video calls with verified hosts who are online right now.</div>
  </div>
  <div class="pad col g12" style="position:absolute;bottom:20px;left:0;right:0">
   <div class="btn pri full">Create account</div>
   <div class="btn neu full">I already have an account</div>
   <div class="cap ink3 center mt8" style="line-height:16px;padding:0 10px">By continuing you confirm you are 18 or older and agree to our <u>Terms</u> and <u>Privacy Policy</u>.</div>
  </div></div>`}));

S({id:'A03',folder:F_AUTH,name:'Log_In',title:'Log in',
 desc:'Returning users sign in with their phone number (OTP) or Google. Phone OTP is the primary method per the product brief.',
 notes:['Country code fixed to +91 at launch (India-first). Tap opens nothing.','Google sign-in still requires a verified phone number (A07) — see open decision D-02.','Primary button is disabled until a valid 10-digit number is entered.'],
 flags:['D-02'],to:['A05','A07']},
()=>SCR({body:`${APPBAR('')}<div class="content pad">
  <div class="d-m mt8">Welcome back</div>
  <div class="b-l ink2 mt8">Log in with the phone number you used to create your account.</div>
  <div class="field mt32"><span class="flabel">Mobile number</span>
   <div class="input focus"><span class="row g6" style="padding-right:10px;border-right:1px solid var(--line)">🇮🇳 <span>+91</span></span><span class="num" style="letter-spacing:.04em">98204 1</span><span class="caret" style="margin-left:-8px"></span></div>
   <span class="helper">We'll send a 6-digit code by SMS.</span></div>
  <div class="btn dis full mt24">Send code</div>
  <div class="row g12 mt32"><div class="hr f1"></div><span class="lbl ink3">OR</span><div class="hr f1"></div></div>
  <div class="btn neu full mt24">${GOOGLE_G}Continue with Google</div>
  <div class="center mt24 b-m ink2">New to Dashuri? <span class="pri" style="font-weight:800">Create account</span></div>
 </div>${NUMPAD()}`, noGb:true}));

S({id:'A04',folder:F_AUTH,name:'Registration_Phone',title:'Registration — phone number',
 desc:'Step 1 of account creation. A phone number is mandatory for every account (one Free Call Card per phone and device; OTP login).',
 notes:['Step indicator shows 1 of 6 onboarding steps.','Valid number state: primary button enabled.','Google alternative available below the fold.'],
 to:['A05','A07']},
()=>SCR({body:`${AUTHTOP(1)}<div class="content pad">
  <div class="d-m mt8">What's your number?</div>
  <div class="b-l ink2 mt8">We'll text you a code to verify it's you. Your number is never shown to anyone.</div>
  <div class="field mt32"><span class="flabel">Mobile number</span>
   <div class="input focus"><span class="row g6" style="padding-right:10px;border-right:1px solid var(--line)">🇮🇳 <span>+91</span></span><span class="num" style="letter-spacing:.04em">98204 17735</span><span class="caret" style="margin-left:-8px"></span></div></div>
  <div class="row g8 mt12 ink3">${I('lock','ic-xs')}<span class="cap">Protected and private. Used only for sign-in and safety.</span></div>
  <div class="btn pri full mt24">Send code</div>
  <div class="btn neu full mt12">${GOOGLE_G}Sign up with Google instead</div>
 </div>${NUMPAD()}`, noGb:true}));

S({id:'A05',folder:F_AUTH,name:'OTP_Verification',title:'Phone OTP verification',
 desc:'Six-digit SMS code entry with auto-advance and SMS autofill. Resend is rate-limited by a countdown.',
 notes:['Boxes auto-advance; paste fills all six.','Android SMS Retriever autofill supported.','Auto-submits on the 6th digit and shows the button loading state.'],
 to:['A06','A08']},
()=>SCR({body:`${AUTHTOP(2)}<div class="content pad">
  <div class="d-m mt8">Enter the code</div>
  <div class="b-l ink2 mt8">Sent to <b style="color:var(--ink)">+91 98204 17735</b>. <span class="pri" style="font-weight:700">Edit</span></div>
  <div class="otp mt32 num"><div>4</div><div>8</div><div>2</div><div>9</div><div class="f"><span class="caret"></span></div><div></div></div>
  <div class="row between mt20"><span class="b-m ink3">Didn't get it?</span><span class="b-m ink3 num">Resend code in <b style="color:var(--ink)">0:24</b></span></div>
  <div class="btn pri full mt32" style="opacity:.5">Verify</div>
 </div>${NUMPAD()}`, noGb:true}));

S({id:'A06',folder:F_AUTH,name:'OTP_Error',title:'OTP — incorrect / expired code',
 desc:'Error state for a wrong or expired code. Inputs turn red, a clear message explains what to do, resend becomes available.',
 notes:['Error copy never blames the user.','Resend link becomes active once the countdown ends.','Repeated failures show a temporary lock message from the server (copy from API error code).'],
 to:['A05']},
()=>SCR({body:`${AUTHTOP(2)}<div class="content pad">
  <div class="d-m mt8">Enter the code</div>
  <div class="b-l ink2 mt8">Sent to <b style="color:var(--ink)">+91 98204 17735</b>. <span class="pri" style="font-weight:700">Edit</span></div>
  <div class="otp error mt32 num"><div>4</div><div>8</div><div>2</div><div>9</div><div>1</div><div>6</div></div>
  <div class="row g8 mt12 errc">${I('circle-alert','ic-s')}<span class="b-s" style="font-weight:700">That code didn't match or has expired.</span></div>
  <div class="row between mt20"><span class="b-m ink3">Didn't get it?</span><span class="b-m pri" style="font-weight:800">Resend code</span></div>
  <div class="btn pri full mt32">Try again</div>
 </div>${NUMPAD()}`, noGb:true}));

S({id:'A07',folder:F_AUTH,name:'Google_Sign_In',title:'Google sign-in → verify phone',
 desc:'After the Google account picker (system UI) returns, the user is signed in but must still verify a phone number before continuing.',
 notes:['Google account chip confirms which account was used; tap to switch.','Phone verification is required for every account (fraud, Free Call Card eligibility) — see D-02.','Continues to the OTP screen (A05).'],
 flags:['D-02'],to:['A05']},
()=>SCR({body:`${AUTHTOP(1)}<div class="content pad">
  <div class="card flat pad16 row g12 mt8" style="background:var(--surface-2);border:none">
   ${av('arjun',44)}<div class="f1"><div class="t-s">Arjun Mehta</div><div class="b-s ink3">arjun.mehta@gmail.com</div></div><div class="row g6 okc">${I('circle-check','ic-s')}<span class="lbl">Connected</span></div></div>
  <div class="d-m mt32">One more step</div>
  <div class="b-l ink2 mt8">Add your mobile number to secure your account. It's never shown on your profile.</div>
  <div class="field mt24"><span class="flabel">Mobile number</span>
   <div class="input"><span class="row g6" style="padding-right:10px;border-right:1px solid var(--line)">🇮🇳 <span>+91</span></span><span class="ph-t">10-digit number</span></div></div>
  <div class="banner info mt20">${I('shield-check','ic-s')}<span>Every Dashuri account is linked to one verified phone number. This keeps the community safe.</span></div>
  <div style="position:absolute;bottom:20px;left:20px;right:20px"><div class="btn dis full">Send code</div><div class="btn txt full mt8">Use a different Google account</div></div>
 </div>`}));

S({id:'A08',folder:F_AUTH,name:'Create_Profile',title:'Profile creation — name & photo',
 desc:'Collects the public display name and an optional profile photo. Customers see this name in calls and chats.',
 notes:['Photo optional for customers; required for hosts (H05).','Name 2–20 characters; contact details are blocked (no numbers, @, links).','Photo goes to signed-URL storage after moderation.'],
 to:['A09']},
()=>SCR({body:`${AUTHTOP(3)}<div class="content pad">
  <div class="d-m mt8">How should we<br>call you?</div>
  <div class="b-l ink2 mt8">This is how you'll appear to hosts.</div>
  <div class="col mt32" style="align-items:center">
   <div style="position:relative">${av('arjun',112)}<div style="position:absolute;right:-2px;bottom:2px;width:38px;height:38px;border-radius:19px;background:var(--primary);color:#fff;display:flex;align-items:center;justify-content:center;border:3px solid var(--bg)">${I('camera','ic-s')}</div></div>
   <span class="lbl pri mt12">Change photo</span></div>
  <div class="field mt24"><span class="flabel">Display name</span><div class="input focus">Arjun<span class="caret"></span><span class="spacer"></span><span class="cap ink3">5/20</span></div>
   <span class="helper">Use your first name or a nickname. No phone numbers or links.</span></div>
  <div style="position:absolute;bottom:20px;left:20px;right:20px"><div class="btn pri full">Continue</div></div>
 </div>`}));

S({id:'A09',folder:F_AUTH,name:'Age_Verification',title:'Age verification (18+)',
 desc:'Customers declare their date of birth and confirm they are 18+. Uses SubmitAgeDeclaration. Hosts are age-verified separately from their ID during KYC.',
 notes:['Date picker wheels; derived age shown live.','Checkbox confirmation is required in addition to the date.','Under-18 dates route to the blocked state (A10). DOB is never shown publicly.'],
 to:['A10','A11']},
()=>SCR({body:`${AUTHTOP(4)}<div class="content pad">
  <div class="d-m mt8">When's your birthday?</div>
  <div class="b-l ink2 mt8">Dashuri is only for adults. Your date of birth stays private.</div>
  <div class="card mt24" style="padding:8px 0;position:relative;overflow:hidden">
   <div style="position:absolute;left:12px;right:12px;top:50%;height:46px;margin-top:-23px;border-radius:12px;background:var(--b50)"></div>
   <div class="row" style="position:relative">${[['12','13','14','15','16'],['February','March','April','May','June'],['1996','1997','1998','1999','2000']].map((c,ci)=>`<div class="col f1" style="align-items:center">${c.map((v,i)=>`<div style="height:44px;display:flex;align-items:center;font-size:${i===2?19:16}px;font-weight:${i===2?800:600};color:${i===2?'var(--primary)':'var(--n400)'};opacity:${i===0||i===4?.5:1}">${v}</div>`).join('')}</div>`).join('')}</div></div>
  <div class="row between mt16"><span class="b-m ink2">Your age</span><span class="t-s num">28 years</span></div>
  <div class="card flat pad16 row g12 ai-s mt20" style="border:1.5px solid var(--primary);background:var(--b50)"><div class="check on">${I('check','ic-xs')}</div><span class="b-m" style="color:var(--b900)">I confirm I am 18 years or older and that the date above is correct.</span></div>
  <div style="position:absolute;bottom:20px;left:20px;right:20px"><div class="btn pri full">Continue</div></div>
 </div>`}));

S({id:'A10',folder:F_AUTH,name:'Age_Blocked',title:'Age gate — under 18 (blocked)',
 desc:'Terminal state when the declared age is under 18. The account is not created and the device is remembered by the server.',
 notes:['No back-door: there is no "edit date" action.','Links to Child Safety Standards / help (required for Play).','Neutral tone, not punitive.'],
 to:[]},
()=>SCR({body:`<div class="content col jc" style="align-items:center">
  <div class="empty"><div class="art" style="background:var(--surface-2);color:var(--ink-2)">${I('shield-alert','ic-xl')}</div>
  <div class="d-m">Dashuri is for adults only</div>
  <div class="b-l ink2 mt12">You need to be 18 or older to use Dashuri. We can't create an account for you right now.</div></div>
  <div style="position:absolute;bottom:20px;left:20px;right:20px" class="col g12"><div class="btn neu full">Close app</div><div class="btn txt full">Learn about our safety standards</div></div></div>`}));

S({id:'A11',folder:F_AUTH,name:'Gender_Selection',title:'Gender selection',
 desc:'Collects gender for safety and matching rules. Hosting is open to women only at launch, so this answer gates the host application entry point.',
 notes:['Large single-select option cards.','Option list and visibility (public or private) need a product decision — D-03.','Selection is private by default; never shown on customer profiles.'],
 flags:['D-03'],to:['A12']},
()=>SCR({body:`${AUTHTOP(5)}<div class="content pad">
  <div class="d-m mt8">How do you identify?</div>
  <div class="b-l ink2 mt8">This stays private. It helps us keep Dashuri safe and relevant for you.</div>
  <div class="col g12 mt32">${[['Man',1],['Woman',0],['Non-binary',0],['Prefer not to say',0]].map(([l,on])=>`<div class="card flat row g12" style="padding:18px 18px;${on?'border:1.5px solid var(--primary);background:var(--b50)':''}"><span class="t-s f1">${l}</span><div class="radio ${on?'on':''}"></div></div>`).join('')}</div>
  <div style="position:absolute;bottom:20px;left:20px;right:20px"><div class="btn pri full">Continue</div></div>
 </div>`}));

S({id:'A12',folder:F_AUTH,name:'Choose_Experience',title:'Choose your experience',
 desc:'Splits the customer and host journeys. Customers continue to permissions and Discover; women can apply to host, which starts host onboarding.',
 notes:['Shown only to users who selected Woman (hosting is women-only at launch); everyone else skips straight to A13.','Host path explains that ID verification is required before choosing.','Entry point and whether one account can be both roles — D-04.'],
 flags:['D-04'],to:['A13','H01']},
()=>SCR({body:`${AUTHTOP(6)}<div class="content pad">
  <div class="d-m mt8">How will you use<br>Dashuri?</div>
  <div class="b-l ink2 mt8">You can change this later from Settings.</div>
  <div class="card mt24" style="padding:0;overflow:hidden;border:1.5px solid var(--primary);box-shadow:0 0 0 4px var(--b50)">
   <div style="height:116px;position:relative;display:flex">${ph('ananya','',`flex:1;height:116px`,130,116)}${ph('meera','',`flex:1;height:116px`,130,116)}${ph('naina','',`flex:1;height:116px`,130,116)}<div class="radio on" style="position:absolute;top:12px;right:12px;background:#fff"></div></div>
   <div style="padding:16px 18px 18px"><div class="t-m">Talk with hosts</div><div class="b-m ink2 mt4">Browse verified hosts who are online and start a private video call.</div></div></div>
  <div class="card mt16" style="padding:16px 18px;display:flex;gap:14px;align-items:flex-start">
   <div style="width:48px;height:48px;border-radius:16px;background:var(--gold-100);display:flex;align-items:center;justify-content:center">${BEAN(26)}</div>
   <div class="f1"><div class="row between"><span class="t-m">Become a host</span><div class="radio"></div></div><div class="b-m ink2 mt4">Earn Beans for your time on video calls. Go online whenever you like.</div>
   <div class="row g6 mt12 ink3">${I('id-card','ic-xs')}<span class="cap">ID and selfie verification required</span></div></div></div>
  <div style="position:absolute;bottom:20px;left:20px;right:20px"><div class="btn pri full">Continue</div></div>
 </div>`}));

S({id:'A13',folder:F_AUTH,name:'Community_Rules',title:'Community rules & consent',
 desc:'Users accept the content rules and terms before first use. Mirrors the safety baseline (no nudity, no minors, no contact details, respect).',
 notes:['Scrollable list of four core rules with icons.','Accept is a single explicit action; links to full Terms and Privacy.','Wording requires legal review before launch (PRO-REVIEW).'],
 flags:['D-12'],to:['A14']},
()=>SCR({body:`${APPBAR('')}<div class="content pad">
  <div class="over pri">Before you start</div>
  <div class="d-m mt8">Our promise to<br>each other</div>
  <div class="col g20 mt24">${[
   ['heart-handshake','Be kind and respectful','Treat every person on a call the way you\'d want to be treated.'],
   ['eye-off','No nudity or sexual content','Calls are checked for safety. Breaking this rule leads to removal.'],
   ['phone-off','Keep it on Dashuri','Don\'t share phone numbers, social handles or payment details.'],
   ['shield-check','Adults only, always','Report anyone who seems under 18. We act on every report.']
  ].map(([ic,a,b])=>`<div class="row g16 ai-s"><div style="width:44px;height:44px;border-radius:14px;background:var(--b50);color:var(--primary);display:flex;align-items:center;justify-content:center;flex:none">${I(ic)}</div><div><div class="t-s">${a}</div><div class="b-m ink2 mt4">${b}</div></div></div>`).join('')}</div>
  <div style="position:absolute;bottom:20px;left:20px;right:20px"><div class="cap ink3 center mb12" style="line-height:16px">By tapping "I agree" you accept the <u>Terms of Service</u>, <u>Community Guidelines</u> and <u>Privacy Policy</u>.</div><div class="btn pri full">I agree</div></div>
 </div>`}));

S({id:'A14',folder:F_AUTH,name:'Permissions',title:'Permissions primer',
 desc:'Explains why camera, microphone and notifications are needed before the Android system dialogs appear. Requested in sequence after "Allow access".',
 notes:['Camera + microphone are required to call; notifications are recommended (incoming messages; incoming calls for hosts).','Each row shows a granted state (check) once the system dialog returns.','"Not now" proceeds; calling later re-prompts (A15).'],
 to:['A15','C01']},
()=>SCR({body:`<div class="content pad col" style="padding-top:40px">
  <div class="row jc" style="gap:-10px;position:relative;height:120px">
   <div style="position:absolute;left:96px;top:10px;width:88px;height:88px;border-radius:28px;background:var(--b50);color:var(--primary);display:flex;align-items:center;justify-content:center;transform:rotate(-8deg)">${I('video','ic-xl')}</div>
   <div style="position:absolute;left:162px;top:22px;width:88px;height:88px;border-radius:28px;background:var(--primary);color:#fff;display:flex;align-items:center;justify-content:center;transform:rotate(6deg);box-shadow:var(--sh2)">${I('mic','ic-xl')}</div></div>
  <div class="d-m center mt24">Ready for your<br>first call</div>
  <div class="b-l ink2 center mt8">Dashuri needs a few permissions so calls work smoothly.</div>
  <div class="list mt32">${[['video','Camera','So the person you call can see you',1],['mic','Microphone','So they can hear you',1],['bell','Notifications','Know when someone messages you',0]].map(([ic,a,b,d])=>`<div class="li"><div class="lic pri">${I(ic,'ic-s')}</div><div class="lt"><div class="a">${a}</div><div class="b">${b}</div></div>${d?`<span class="okc">${I('circle-check','ic')}</span>`:`<span class="tag">Optional</span>`}</div>`).join('')}</div>
  <div style="position:absolute;bottom:20px;left:20px;right:20px" class="col g8"><div class="btn pri full">Allow access</div><div class="btn txt full">Not now</div></div>
 </div>`}));

S({id:'A15',folder:F_AUTH,name:'Permission_Denied',title:'Permission denied state',
 desc:'Shown when a user tries to call (or a host goes online) after camera or microphone access was permanently denied.',
 notes:['Bottom sheet over the screen the user came from.','"Open settings" deep-links to the app\'s Android settings page.','Never blocks browsing — only calling.'],
 to:['C05']},
()=>SCR({body:`<div class="content">${ph('ananya','',`position:absolute;inset:0;height:520px`,390,520)}</div>`,overlay:`<div class="dim"></div><div class="sheet" style="padding-bottom:12px"><div class="grab"></div>
  <div style="width:64px;height:64px;border-radius:20px;background:var(--warn-100);color:var(--warn);display:flex;align-items:center;justify-content:center">${I('video-off','ic-l')}</div>
  <div class="t-l mt16">Camera access is off</div>
  <div class="b-l ink2 mt8">To start a video call, allow Dashuri to use your camera and microphone in your phone's settings.</div>
  <div class="list plain mt20" style="background:var(--surface-2);border:none">${[['Camera','Denied'],['Microphone','Allowed']].map(([a,b])=>`<div class="li noic" style="min-height:48px"><span class="lt a" style="font-weight:700">${a}</span><span class="tag ${b==='Denied'?'err':'ok'}">${b}</span></div>`).join('')}</div>
  <div class="btn pri full mt20">Open settings</div><div class="btn txt full mt4">Not now</div>${GB()}</div>`, noGb:true}));
