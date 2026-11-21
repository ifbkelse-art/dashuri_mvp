// USER FLOWS — journey boards built from rendered screen thumbnails
const FLOWS = [];
const TW = 120, TH = 260;
const thumbSrc = id => { const r = REG.find(x => x.id === id); return `../Dashuri_Design/${r.folder}/${r.id}_${r.name}.png`; };
function flowBoard(num, title, sub, nodes, edges, extra='') {
  const pos = Object.fromEntries(nodes.map(n => [n.id, n]));
  const nodeHtml = nodes.map(n => { const r = REG.find(x => x.id === n.id);
    return `<div style="position:absolute;left:${n.x}px;top:${n.y}px;width:${TW}px">
      <div style="width:${TW}px;height:${TH}px;border-radius:16px;overflow:hidden;box-shadow:0 4px 14px rgba(28,24,22,.14);border:1px solid var(--line);${n.hl?'outline:3px solid var(--primary);outline-offset:3px':''}"><img src="${thumbSrc(n.id)}" style="width:100%;height:100%;display:block"></div>
      <div class="row g6 mt8"><span class="tag ${n.hl?'pri':''}" style="height:20px;font-size:10px;padding:0 7px">${n.id}</span></div>
      <div class="cap" style="margin-top:3px;line-height:13px;font-size:10.5px">${n.label || r.title}</div></div>`; }).join('');
  const P = (n, side) => ({ r:[n.x+TW, n.y+TH/2], l:[n.x, n.y+TH/2], b:[n.x+TW/2, n.y+TH], t:[n.x+TW/2, n.y] })[side];
  const edgeHtml = edges.map(([a, b, label, style]) => { const A = pos[a], B = pos[b]; let s, e, d;
    if (Math.abs(A.y - B.y) < 10) { const fwd = B.x > A.x; s = P(A, fwd?'r':'l'); e = P(B, fwd?'l':'r'); d = `M${s[0]},${s[1]} L${e[0]-(fwd?6:-6)},${e[1]}`; }
    else if (Math.abs(A.x - B.x) < 10) { const dn = B.y > A.y; s = P(A, dn?'b':'t'); e = P(B, dn?'t':'b'); s[1]+=dn?44:0; d = `M${s[0]},${s[1]} L${e[0]},${e[1]-(dn?6:-6)}`; }
    else { const dn = B.y > A.y; s = P(A, dn?'b':'t'); e = P(B, dn?'t':'b'); if (dn) s[1]+=44; else e[1]+=44; const my=(s[1]+e[1])/2; d = `M${s[0]},${s[1]} C${s[0]},${my} ${e[0]},${my} ${e[0]},${e[1]-(dn?6:-6)}`; }
    const mx = (s[0]+e[0])/2, my2 = (s[1]+e[1])/2;
    return { path:`<path d="${d}" fill="none" stroke="${style==='alt'?'var(--n400)':'var(--b500)'}" stroke-width="2" ${style==='alt'?'stroke-dasharray="5 5"':''} marker-end="url(#ah${style==='alt'?'2':''})"/>`,
      lab: label ? `<div style="position:absolute;left:${mx}px;top:${my2}px;transform:translate(-50%,-50%);background:${style==='alt'?'var(--surface-2)':'var(--b50)'};color:${style==='alt'?'var(--ink-2)':'var(--b800)'};border:1px solid ${style==='alt'?'var(--line)':'var(--b200)'};border-radius:10px;padding:2px 8px;font-size:10.5px;font-weight:700;white-space:nowrap;z-index:3">${label}</div>` : '' }; });
  return board(num, title, sub, `<div style="position:relative;height:100%">
    <svg style="position:absolute;inset:0;overflow:visible;z-index:2" width="1488" height="820"><defs><marker id="ah" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--b500)"/></marker><marker id="ah2" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--n400)"/></marker></defs>${edgeHtml.map(e=>e.path).join('')}</svg>
    ${nodeHtml}${edgeHtml.map(e=>e.lab).join('')}${extra}
    <div class="row g16" style="position:absolute;right:0;bottom:-6px"><span class="row g6 cap"><svg width="28" height="6"><line x1="0" y1="3" x2="28" y2="3" stroke="var(--b500)" stroke-width="2"/></svg>Main path</span><span class="row g6 cap"><svg width="28" height="6"><line x1="0" y1="3" x2="28" y2="3" stroke="var(--n400)" stroke-width="2" stroke-dasharray="5 5"/></svg>Alternate / error path</span></div></div>`);
}
const FL = (id, name, title, fn) => FLOWS.push({ id, name, title, html: fn });
const X = i => i * 170, R1 = 0, R2 = 420;

FL('FL01','Customer_Onboarding','Customer journey — onboarding',()=>flowBoard('Flow 01','Customer journey — onboarding to first screen','Phone OTP is the backbone; Google sign-in still verifies a phone. Under-18 declarations end the flow.',
 [{id:'A01',x:X(0),y:R1},{id:'A02',x:X(1),y:R1},{id:'A04',x:X(2),y:R1},{id:'A05',x:X(3),y:R1},{id:'A08',x:X(4),y:R1},{id:'A09',x:X(5),y:R1},{id:'A11',x:X(6),y:R1},{id:'A13',x:X(7),y:R1},{id:'A14',x:X(8),y:R1},
  {id:'A03',x:X(1),y:R2},{id:'A07',x:X(2),y:R2},{id:'A06',x:X(3),y:R2},{id:'A10',x:X(5),y:R2},{id:'A12',x:X(6),y:R2,label:'Women only → host path'},{id:'C02',x:X(8),y:R2,hl:1,label:'Home (new customer)'}],
 [['A01','A02'],['A02','A04','Create'],['A04','A05'],['A05','A08','verified'],['A08','A09'],['A09','A11','18+'],['A11','A13','Man / other'],['A13','A14'],['A14','C02','done'],
  ['A02','A03','Log in','alt'],['A04','A07','Google','alt'],['A05','A06','wrong code','alt'],['A09','A10','under 18','alt'],['A11','A12','Woman','alt']]));

FL('FL02','Customer_Call_Journey','Customer journey — discover to call',()=>flowBoard('Flow 02','Customer journey — discover, call, follow up','Customers can call online hosts only. Balance ≥ 60 s at the host\'s rate is checked before ringing; billing starts only when both videos are live.',
 [{id:'C01',x:X(0),y:R1,hl:1},{id:'C07',x:X(1),y:R1},{id:'V01',x:X(2),y:R1},{id:'V02',x:X(3),y:R1},{id:'V03',x:X(4),y:R1},{id:'V04',x:X(5),y:R1,hl:1},{id:'V09',x:X(6),y:R1},{id:'CH02',x:X(7),y:R1},
  {id:'C08',x:X(1),y:R2},{id:'V06',x:X(2),y:R2},{id:'V08',x:X(3),y:R2},{id:'V14',x:X(4),y:R2},{id:'V05',x:X(5),y:R2},{id:'V10',x:X(6),y:R2},{id:'V11',x:X(7),y:R2},{id:'V07',x:X(8),y:R2}],
 [['C01','C07','tap card'],['C07','V01','Video call'],['V01','V02','Start'],['V02','V03','accepted'],['V03','V04','both live'],['V04','V09','end'],['V09','CH02','Message'],
  ['C07','C08','host busy','alt'],['V01','V06','< 60 s balance','alt'],['V02','V08','no answer','alt'],['V03','V14','never connects','alt'],['V04','V05','30 s left','alt'],['V05','V10','balance 0','alt'],['V09','V11','Report','alt'],['V04','V07','network drop','alt']]));

FL('FL03','Diamond_Purchase','Diamond purchase flow',()=>flowBoard('Flow 03','Diamond purchase — entry points and payment states','Every entry point lands on packages. The server verifies the payment before Diamonds are credited. Provider choice is open (D-01).',
 [{id:'C01',x:X(0),y:R1,label:'Balance pill'},{id:'W01',x:X(0),y:R2,label:'Wallet'},{id:'V06',x:X(1),y:R1,label:'Insufficient balance'},{id:'V10',x:X(1),y:R2,label:'Balance ran out'},
  {id:'W02',x:X(3),y:R1,hl:1},{id:'W03',x:X(4),y:R1},{id:'W04',x:X(5),y:R1},{id:'W05',x:X(7),y:R1,hl:1},{id:'W06',x:X(6),y:R2},{id:'W07',x:X(8),y:R2},{id:'V01',x:X(8),y:R1,label:'Back to the call'}],
 [['C01','W02','+'],['V06','W02','See all'],['W01','W02','Buy','alt'],['V10','W02','Top up','alt'],['W02','W03','Continue'],['W03','W04','Pay'],['W04','W05','verified'],['W05','V01','if from call'],['W04','W06','failed','alt'],['W04','W07','unconfirmed','alt'],['W06','W03','retry','alt']]));

FL('FL04','Host_Onboarding','Host journey — onboarding & verification',()=>flowBoard('Flow 04','Host journey — application, KYC and setup','Women 18+ at launch. Aadhaar (DigiLocker or offline e-KYC), PAN, liveness, agreement, then profile and rate. Only the failed step is repeated.',
 [{id:'A12',x:X(0),y:R1},{id:'H01',x:X(1),y:R1},{id:'H02',x:X(2),y:R1},{id:'H03',x:X(3),y:R1},{id:'H04',x:X(4),y:R1},{id:'H05',x:X(5),y:R1},{id:'H06',x:X(6),y:R1},{id:'H09',x:X(7),y:R1},{id:'H10',x:X(8),y:R1},
  {id:'H08',x:X(5),y:R2},{id:'H07',x:X(7),y:R2},{id:'H11',x:X(8),y:R2,hl:1}],
 [['A12','H01','Become a host'],['H01','H02','Start'],['H02','H03'],['H03','H04'],['H04','H05'],['H05','H06','passed'],['H06','H09','accept'],['H09','H10'],['H10','H07','submit'],['H07','H11','approved'],['H05','H08','no match','alt'],['H07','H08','needs attention','alt']]));

FL('FL05','Host_Earning_Loop','Host journey — online, calls, earnings',()=>flowBoard('Flow 05','Host journey — go online, take calls, withdraw','Hosts choose when to be online and may decline any call without penalty. Beans are withdrawable 7 days after earning; weekly payouts, ₹500 minimum.',
 [{id:'H11',x:X(0),y:R1},{id:'H12',x:X(1),y:R1,hl:1},{id:'V16',x:X(2),y:R1},{id:'V17',x:X(3),y:R1},{id:'V18',x:X(4),y:R1},{id:'H14',x:X(5),y:R1,hl:1},{id:'H16',x:X(6),y:R1},{id:'H17',x:X(7),y:R1},{id:'H18',x:X(8),y:R1},
  {id:'H13',x:X(1),y:R2},{id:'H15',x:X(5),y:R2},{id:'H21',x:X(4),y:R2},{id:'H25',x:X(6),y:R2},{id:'H20',x:X(7),y:R2},{id:'H19',x:X(8),y:R2}],
 [['H11','H12','Go online'],['H12','V16','call in'],['V16','V17','Accept'],['V17','V18','end'],['V18','H14','earnings'],['H14','H16','Withdraw'],['H16','H17'],['H17','H18','confirm'],['H18','H19'],
  ['H12','H13','settings','alt'],['H14','H15','how Beans work','alt'],['H14','H21','not yet enabled','alt'],['H16','H25','< ₹500','alt'],['H16','H20','change','alt']]));

const TREE = (title, color, groups) => `<div class="card" style="padding:20px;flex:1"><div class="t-m" style="color:${color}">${title}</div><div class="row g16 ai-s mt16">${groups.map(([tab,ic,items])=>`<div class="f1"><div class="row g8" style="background:${color};color:#fff;border-radius:12px;padding:10px 12px">${I(ic,'ic-s')}<span class="t-s" style="font-size:14px">${tab}</span></div><div class="col g6 mt8" style="border-left:2px solid var(--line);margin-left:14px;padding-left:12px">${items.map(id=>{const r=REG.find(x=>x.id===id);return `<div class="row g6" style="padding:5px 8px;border-radius:8px;background:var(--surface-2)"><span class="lbl" style="font-size:10px;color:${color};width:30px">${id}</span><span class="cap" style="font-weight:600;line-height:13px">${r.name.replace(/_/g,' ')}</span></div>`;}).join('')}</div></div>`).join('')}</div></div>`;
FL('FL06','Navigation_Map','Navigation architecture',()=>board('Flow 06','Navigation architecture (sitemap)','Two role-optimised shells share auth, chat, safety and settings. Calls and payments are full-screen flows launched from any tab.',
 `<div class="row g24 ai-s">${TREE('Customer app','var(--b700)',[['Discover','compass',['C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11','C12']],['Chats','message-circle',['CH01','CH02','CH03','CH04','CH05']],['Wallet','gem',['W01','W02','W03','W04','W05','W06','W07','W08','W09']],['Profile','circle-user-round',['S01','S02','S03','S04','S05','S06','S07','S08','S09','S10']]])}
  ${TREE('Host app','#5C4420',[['Home','layout-dashboard',['H11','H12','H13']],['Calls','video',['H22','V16','V17','V18']],['Earnings','coins',['H14','H15','H16','H17','H18','H19','H20','H21','H25']],['Profile','circle-user-round',['H23','H24','H09','H10']]])}</div>
  <div class="row g16 mt16">${[['Auth & onboarding (shared)','A01 → A15','log-in'],['Host application','H01 → H08','id-card'],['Full-screen call flows','V01 → V18','video'],['Safety (shared)','V11 · V12 · V13 · S06','shield-check']].map(([a,b,ic])=>`<div class="card f1 row g12" style="padding:14px 16px"><div class="lic pri" style="width:36px;height:36px;border-radius:12px;background:var(--b50);color:var(--primary);display:flex;align-items:center;justify-content:center">${I(ic,'ic-s')}</div><div><div class="t-s" style="font-size:14px">${a}</div><div class="cap ink3">${b}</div></div></div>`).join('')}</div>`));
