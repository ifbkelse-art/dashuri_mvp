// WALLET & PAYMENTS (customer)
const F_WAL='Wallet';
const PKGS=[['Starter','₹99',4000],['Small','₹299',12500],['Medium','₹599',26000],['Popular','₹1,199',54000],['Large','₹2,999',140000],['Premium','₹5,999',290000]];
const TX = (ic,bg,fg,a,b,amt,pos) => `<div class="li"><div class="lic" style="background:${bg};color:${fg};border-radius:14px">${ic}</div><div class="lt"><div class="a">${a}</div><div class="b">${b}</div></div><div class="row g4 num" style="font-weight:800;font-size:15px;color:${pos?'var(--ok)':'var(--ink)'}">${pos?'+':'−'}${amt}${DIA(14)}</div></div>`;

S({id:'W01',folder:F_WAL,name:'Wallet_Overview',title:'Wallet overview',
 desc:'Customer wallet: Diamond balance (purchased vs promotional), quick buy, and recent activity.',
 notes:['Balance from WalletSummary (server).','Purchased Diamonds never expire; promotional Diamonds expire after 30 days — shown with an expiry line when present.','Diamonds are non-transferable (no send/gift affordance).','"See all" → W08. Row tap → W09.'],
 to:['W02','W08','W09']},
()=>SCR({body:`<div class="largetitle row between" style="padding-top:8px"><span class="d-m">Wallet</span><div class="iconbtn filled" style="width:40px;height:40px">${I('circle-help','ic-s')}</div></div><div class="content">
  <div class="pad"><div class="whero">
   <div class="row between"><span class="cap" style="opacity:.75;letter-spacing:.12em">DIAMOND BALANCE</span>${I('gem','ic-s','opacity:.7')}</div>
   <div class="row g10 mt12">${DIA(34)}<span class="num" style="font-size:44px;font-weight:800;letter-spacing:-.03em;line-height:1">12,480</span></div>
   <div class="b-s mt8" style="opacity:.75">About 5 min with a 2,400 / min host</div>
   <div class="row g12 mt20"><div class="btn white sm f1">${I('plus','ic-s')}Buy Diamonds</div><div class="btn sm f1" style="background:rgba(255,255,255,.14);color:#fff">${I('receipt-text','ic-s')}History</div></div></div></div>
  <div class="pad mt16"><div class="card flat row" style="padding:14px 16px">
   <div class="f1"><div class="cap ink3">PURCHASED</div><div class="row g6 mt4">${DIA(15)}<span class="t-s num">12,480</span></div><div class="cap ink3 mt4" style="font-weight:600">Never expire</div></div>
   <div style="width:1px;height:52px;background:var(--line)"></div>
   <div class="f1" style="padding-left:16px"><div class="cap ink3">PROMOTIONAL</div><div class="row g6 mt4">${DIA(15)}<span class="t-s num">0</span></div><div class="cap ink3 mt4" style="font-weight:600">Expire after 30 days</div></div></div></div>
  <div class="section-h mt24"><span class="t">Recent activity</span><span class="a">See all</span></div>
  <div class="pad"><div class="list">
   ${TX(I('video','ic-s'),'var(--surface-2)','var(--ink)','Call with Meera','Today, 8:42 PM · 6 min 00 s','18,000',0)}
   ${TX(I('arrow-down-to-line','ic-s'),'var(--ok-100)','var(--ok)','Popular pack','Today, 8:31 PM · UPI','54,000',1)}
   ${TX(I('video','ic-s'),'var(--surface-2)','var(--ink)','Call with Ananya','Yesterday · 12 min 40 s','30,400',0)}
   ${TX(I('rotate-ccw','ic-s'),'var(--info-100)','var(--info)','Call didn\'t connect','Yesterday · Returned','4,500',1)}
  </div></div></div>`, nav:CNAV('wallet')}));

S({id:'W02',folder:F_WAL,name:'Diamond_Packages',title:'Buy Diamonds — packages',
 desc:'Package picker. Six packages in a two-column grid with a talk-time hint against the last host viewed. Prices include GST.',
 notes:['Package prices are the six simulation packages — not final (D-14).','Talk-time hint uses the most recently viewed host\'s rate.','Selected state: burgundy border + halo. CTA mirrors selection.','Payment rail per brief is Cashfree; ADR-010 specifies Google Play Billing — D-01.'],
 flags:['D-14','D-01'],to:['W03']},
()=>SCR({body:`${APPBAR('Buy Diamonds',{left:'x'})}<div class="content pad">
  <div class="card flat row between" style="padding:12px 16px;background:var(--surface-2);border:none"><span class="b-m ink2">Current balance</span><span class="row g6 t-s num">${DIA(16)}12,480</span></div>
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:20px">${PKGS.map(([n,p,d])=>{const sel=n==='Popular';return `<div class="pkg ${sel?'sel':''}" style="padding:16px 14px 14px">${sel?'<span class="ribbon">Most popular</span>':''}
    <div class="row between"><span class="cap ink3" style="letter-spacing:.08em">${n.toUpperCase()}</span>${sel?`<div class="radio on" style="width:18px;height:18px"></div>`:''}</div>
    <div class="row g6 mt8">${DIA(22)}<span class="num" style="font-size:22px;font-weight:800;letter-spacing:-.02em">${fmt(d)}</span></div>
    <div class="cap ink3" style="font-weight:600">≈ ${(d/2400)<10?(Math.floor(d/2400*10)/10):Math.floor(d/2400)} min with Ananya</div>
    <div class="t-s mt8 ${sel?'pri':''}">${p}</div></div>`;}).join('')}</div>
  <div class="row g8 jc mt16 ink3">${I('receipt','ic-xs')}<span class="cap">Prices include GST · Purchased Diamonds never expire</span></div>
  <div style="position:absolute;bottom:12px;left:20px;right:20px"><div class="btn pri full">Continue · ₹1,199</div></div></div>`}));

S({id:'W03',folder:F_WAL,name:'Payment_Confirmation',title:'Payment confirmation & method (Cashfree)',
 desc:'Order summary with GST breakdown and payment method selection. UPI apps first (India), then cards and net banking.',
 notes:['Order summary: pack, Diamonds, base amount + GST = total.','UPI intent apps listed by installed availability; "Pay by UPI ID" fallback.','Payment provider choice is an OPEN DECISION (D-01): brief = Cashfree; ADR-010 = Google Play Billing. If Play Billing, this screen is replaced by the Play purchase sheet.'],
 flags:['D-01'],to:['W04']},
()=>SCR({body:`${APPBAR('Checkout')}<div class="content pad">
  <div class="card pad16"><div class="row g12"><div style="width:48px;height:48px;border-radius:14px;background:var(--b50);display:flex;align-items:center;justify-content:center">${DIA(28)}</div><div class="f1"><div class="t-s">Popular pack</div><div class="b-s ink3 num">54,000 Diamonds</div></div><span class="t-m num">₹1,199</span></div>
   <div class="hr mt16"></div>
   <div class="row between mt12 b-s ink2"><span>Pack price</span><span class="num">₹1,016.10</span></div>
   <div class="row between mt8 b-s ink2"><span>GST (18%)</span><span class="num">₹182.90</span></div>
   <div class="row between mt12 t-s"><span>Total</span><span class="num">₹1,199.00</span></div></div>
  <div class="t-s mt24 mb8">Pay with UPI</div>
  <div class="list">${[['Google Pay','#4285F4','G',1],['PhonePe','#5F259F','Pe',0],['Paytm','#00B9F1','P',0]].map(([n,c,l,on])=>`<div class="li"><div style="width:36px;height:36px;border-radius:10px;background:${c};color:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:13px;flex:none">${l}</div><div class="lt"><div class="a">${n}</div></div><div class="radio ${on?'on':''}"></div></div>`).join('')}
   <div class="li"><div class="lic">${I('at-sign','ic-s')}</div><div class="lt"><div class="a">Pay with UPI ID</div></div>${I('chevron-right','ic-s chev')}</div></div>
  <div class="t-s mt20 mb8">Other methods</div>
  <div class="list">${[['credit-card','Debit or credit card'],['landmark','Net banking']].map(([ic,n])=>`<div class="li"><div class="lic">${I(ic,'ic-s')}</div><div class="lt"><div class="a">${n}</div></div>${I('chevron-right','ic-s chev')}</div>`).join('')}</div>
  <div style="position:absolute;bottom:0;left:0;right:0;padding:12px 20px 8px;background:var(--bg);border-top:1px solid var(--line-2)"><div class="btn pri full">Pay ₹1,199</div><div class="row g6 jc mt8 ink3">${I('lock','ic-xs')}<span class="cap">Secured by Cashfree Payments</span></div></div></div>`}));

S({id:'W04',folder:F_WAL,name:'Payment_Processing_UPI',title:'Payment processing — awaiting UPI approval',
 desc:'Cashfree UPI intent in progress. The user approves in their UPI app; the screen waits for confirmation with a visible session timer.',
 notes:['Do not allow back navigation without confirmation.','Timer reflects the payment session expiry from the provider.','Server verifies the payment before crediting (never the client).'],
 flags:['D-01'],to:['W05','W06','W07']},
()=>SCR({body:`${APPBAR('',{left:'x'})}<div class="content pad col" style="align-items:center">
  <div style="position:relative;width:168px;height:168px;margin-top:40px">
   <svg width="168" height="168" viewBox="0 0 168 168" style="position:absolute;inset:0"><circle cx="84" cy="84" r="78" fill="none" stroke="var(--b100)" stroke-width="6"/><circle cx="84" cy="84" r="78" fill="none" stroke="var(--primary)" stroke-width="6" stroke-linecap="round" stroke-dasharray="490" stroke-dasharray="490" stroke-dashoffset="80" transform="rotate(-90 84 84)"/></svg>
   <div style="position:absolute;inset:22px;border-radius:50%;background:var(--surface);box-shadow:var(--sh2);display:flex;flex-direction:column;align-items:center;justify-content:center"><div style="width:44px;height:44px;border-radius:12px;background:#4285F4;color:#fff;display:flex;align-items:center;justify-content:center;font-weight:800">G</div><div class="t-s num mt8">4:12</div></div></div>
  <div class="d-m center mt32">Approve in Google Pay</div>
  <div class="b-l ink2 center mt8">Open Google Pay and approve the request for <b style="color:var(--ink)">₹1,199</b> from Dashuri.</div>
  <div class="card flat mt24" style="width:100%;padding:4px 16px">${[['Paying to','Dashuri (via Cashfree)'],['UPI ID','arjun.m@okhdfc'],['Order','CF-58210-77413']].map(([a,b],i)=>`<div class="row between" style="height:44px;${i?'border-top:1px solid var(--line-2)':''}"><span class="b-m ink3">${a}</span><span class="b-m" style="font-weight:700">${b}</span></div>`).join('')}</div>
  <div class="row g8 mt20 ink3"><div class="spinner dark" style="width:16px;height:16px;border-width:2px"></div><span class="b-s">Waiting for confirmation… please don't close this screen</span></div>
  <div class="spacer"></div><div class="btn neu full" style="margin-bottom:12px">Open Google Pay</div></div>`}));

S({id:'W05',folder:F_WAL,name:'Payment_Success',title:'Payment success',
 desc:'Confirmation once the server verifies payment and credits the ledger. Shows Diamonds added and the new balance, then routes back to the user\'s intent.',
 notes:['Numbers from PurchaseVerification.diamondsCredited.','If the purchase started from a call attempt, primary CTA becomes "Call Kavya now".','Subtle confetti of gem facets — no loud animation.'],
 to:['C01','V01']},
()=>SCR({body:`<div class="content pad col" style="align-items:center">
  <div style="position:relative;width:100%;height:270px;margin-top:20px">${[[40,30,14,-20],[300,50,10,30],[70,190,10,40],[310,200,16,-10],[180,10,8,0],[20,120,8,10],[340,130,8,0]].map(([x,y,s,r])=>`<div style="position:absolute;left:${x}px;top:${y}px;transform:rotate(${r}deg);opacity:.7">${DIA(s)}</div>`).join('')}
   <div style="position:absolute;left:50%;top:40px;margin-left:-90px;width:180px;height:180px;border-radius:50%;background:radial-gradient(circle,var(--b50) 0%,var(--b100) 100%);display:flex;align-items:center;justify-content:center"><div style="width:120px;height:120px;border-radius:50%;background:var(--surface);box-shadow:var(--sh2);display:flex;align-items:center;justify-content:center">${DIA(64)}</div></div>
   <div style="position:absolute;left:50%;top:186px;margin-left:30px;width:40px;height:40px;border-radius:20px;background:var(--ok);color:#fff;display:flex;align-items:center;justify-content:center;border:3px solid var(--bg)">${I('check','ic-s')}</div></div>
  <div class="over pri">Payment successful</div>
  <div class="row g8 mt8"><span class="num" style="font-size:44px;font-weight:800;letter-spacing:-.03em">+54,000</span></div>
  <div class="b-l ink2">Diamonds added to your wallet</div>
  <div class="card flat mt24" style="width:100%;padding:4px 16px">${[['New balance',`<span class="row g6">${DIA(15)}66,480</span>`],['Paid','₹1,199 · Google Pay'],['Order','CF-58210-77413']].map(([a,b],i)=>`<div class="row between" style="height:46px;${i?'border-top:1px solid var(--line-2)':''}"><span class="b-m ink3">${a}</span><span class="b-m num" style="font-weight:700">${b}</span></div>`).join('')}</div>
  <div class="spacer"></div><div class="btn pri full">Start a call</div><div class="btn txt full mt4" style="margin-bottom:4px">Back to wallet</div></div>`}));

S({id:'W06',folder:F_WAL,name:'Payment_Failed',title:'Payment failed',
 desc:'Failure state from the payment provider (declined, cancelled, timed out). Clear reassurance that no Diamonds were charged and an easy retry with another method.',
 notes:['Reason line maps provider error codes to plain copy.','"Try another method" returns to W03 with the same pack selected.','Support link carries the order reference.'],
 flags:['D-01'],to:['W03','S07']},
()=>SCR({body:`${APPBAR('',{left:'x'})}<div class="content pad col" style="align-items:center">
  <div class="empty mt40" style="padding:0 12px"><div class="art" style="background:var(--err-100);color:var(--err)">${I('circle-x','ic-xl')}</div>
  <div class="d-m">Payment didn't go through</div>
  <div class="b-l ink2 mt12">The request expired before it was approved in Google Pay. No Diamonds were added.</div></div>
  <div class="banner info mt24" style="width:100%">${I('info','ic-s')}<span>If money was debited from your account, it will be reversed automatically by your bank. Reference CF-58210-77413.</span></div>
  <div class="spacer"></div><div class="btn pri full">Try again · ₹1,199</div><div class="btn neu full mt12">Use another method</div><div class="btn txt full mt4" style="margin-bottom:4px">Contact support</div></div>`}));

S({id:'W07',folder:F_WAL,name:'Payment_Pending',title:'Payment pending verification',
 desc:'The provider has not yet confirmed the result. Diamonds are credited automatically when the server verifies the payment; the user can leave safely.',
 notes:['Non-blocking: user may return to the app.','Notification arrives on success or failure (C11).','Wallet shows a "Pending" row meanwhile.'],
 flags:['D-01'],to:['W01','C11']},
()=>SCR({body:`${APPBAR('',{left:'x'})}<div class="content pad col" style="align-items:center">
  <div class="empty mt40" style="padding:0 12px"><div class="art" style="background:var(--warn-100);color:var(--warn)">${I('clock-3','ic-xl')}</div>
  <div class="d-m">Confirming your payment</div>
  <div class="b-l ink2 mt12">This is taking a little longer than usual. Your Diamonds will be added as soon as the payment is confirmed — you can leave this screen.</div></div>
  <div class="card flat mt24" style="width:100%;padding:4px 16px">${[['Amount','₹1,199'],['Diamonds','54,000'],['Status','<span class="tag warn">Pending</span>']].map(([a,b],i)=>`<div class="row between" style="height:46px;${i?'border-top:1px solid var(--line-2)':''}"><span class="b-m ink3">${a}</span><span class="b-m num" style="font-weight:700">${b}</span></div>`).join('')}</div>
  <div class="spacer"></div><div class="btn pri full" style="margin-bottom:12px">Got it</div></div>`}));

S({id:'W08',folder:F_WAL,name:'Transaction_History',title:'Transaction history',
 desc:'Full ledger view for the customer, filterable by type and grouped by month. Every row reflects an immutable ledger entry.',
 notes:['Segments: All · Purchases · Calls · Refunds.','Reversals (refunds/chargebacks) appear as their own rows, never edits.','Pagination by month; pull to refresh.'],
 to:['W09']},
()=>SCR({body:`${APPBAR('History')}<div class="content">
  <div class="pad"><div class="seg"><div class="on">All</div><div>Purchases</div><div>Calls</div><div>Refunds</div></div></div>
  <div class="grp-lbl" style="padding:20px 24px 8px">November 2026</div>
  <div class="pad"><div class="list">
   ${TX(I('video','ic-s'),'var(--surface-2)','var(--ink)','Call with Meera','19 Nov, 8:42 PM · 6 min 00 s','18,000',0)}
   ${TX(I('arrow-down-to-line','ic-s'),'var(--ok-100)','var(--ok)','Popular pack · ₹1,199','19 Nov, 8:31 PM · UPI','54,000',1)}
   ${TX(I('video','ic-s'),'var(--surface-2)','var(--ink)','Call with Ananya','18 Nov, 10:05 PM · 12 min 40 s','30,400',0)}
   ${TX(I('rotate-ccw','ic-s'),'var(--info-100)','var(--info)','Call didn\'t connect','18 Nov, 9:51 PM · Returned','4,500',1)}
   ${TX(I('arrow-down-to-line','ic-s'),'var(--ok-100)','var(--ok)','Medium pack · ₹599','12 Nov, 7:14 PM · Card','26,000',1)}
  </div></div>
  <div class="grp-lbl" style="padding:20px 24px 8px">October 2026</div>
  <div class="pad"><div class="list">
   ${TX(I('video','ic-s'),'var(--surface-2)','var(--ink)','Call with Kavya','28 Oct, 11:20 PM · 4 min 10 s','18,750',0)}
   ${TX(I('arrow-down-to-line','ic-s'),'var(--ok-100)','var(--ok)','Small pack · ₹299','28 Oct, 11:02 PM · UPI','12,500',1)}
  </div></div></div>`}));

S({id:'W09',folder:F_WAL,name:'Transaction_Detail',title:'Transaction detail (purchase)',
 desc:'Receipt-style detail for a single transaction with payment reference and help.',
 notes:['Purchase variant shown; call variant shows host, billed seconds, rate and credits.','"Get help" pre-fills a support ticket with the reference.'],
 to:['S07']},
()=>SCR({body:`${APPBAR('Transaction')}<div class="content pad">
  <div class="card center" style="padding:28px 20px 20px">
   <div style="width:64px;height:64px;border-radius:20px;background:var(--ok-100);color:var(--ok);display:inline-flex;align-items:center;justify-content:center">${I('arrow-down-to-line','ic-l')}</div>
   <div class="row g8 jc mt16">${DIA(26)}<span class="num" style="font-size:34px;font-weight:800;letter-spacing:-.02em">+54,000</span></div>
   <div class="b-m ink2 mt4">Popular pack</div><div class="tag ok mt12">${I('circle-check','ic-xs')}Completed</div>
   <div style="border-top:1.5px dashed var(--line);margin:20px -20px 4px"></div>
   ${[['Date','19 Nov 2026, 8:31 PM'],['Amount paid','₹1,199.00'],['Includes GST','₹182.90'],['Method','Google Pay (UPI)'],['Order ID','CF-58210-77413'],['Ledger ref.','TX-9F2C-41A7']].map(([a,b])=>`<div class="row between" style="height:42px"><span class="b-m ink3">${a}</span><span class="b-m num" style="font-weight:700">${b}</span></div>`).join('')}</div>
  <div class="list mt16"><div class="li"><div class="lic">${I('life-buoy','ic-s')}</div><div class="lt"><div class="a">Get help with this payment</div></div>${I('chevron-right','ic-s chev')}</div></div></div>`}));
