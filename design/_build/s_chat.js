// CHAT (customer side shown; host inbox uses the same components)
const F_CHAT='Customer';
const CONV = [['meera','on','It was lovely talking to you! 😊','8:51 PM',2],['ananya','on','Haha yes, Pune rain is something else 🌧️','Yesterday',1],['kavya','off','You: Thank you, have a great night','Mon',0],['ishita','on','Do you watch Satyajit Ray films?','Sun',0],['aditi','off','You: Will call you this weekend','12 Nov',0]];

S({id:'CH01',folder:F_CHAT,name:'Chat_Inbox',title:'Chat — inbox',
 desc:'Conversation list with presence, last message and unread counts. Online hosts show a green dot so customers can jump to a call.',
 notes:['Search filters by name.','Swipe left: Mute · Block · Report.','Is chat free or paid? Not decided — D-15. Design assumes free text only (no media).'],
 flags:['D-15'],to:['CH02']},
()=>SCR({body:`<div class="largetitle row between" style="padding-top:8px"><span class="d-m">Chats</span><div class="iconbtn filled" style="width:40px;height:40px">${I('settings-2','ic-s')}</div></div><div class="content">
  <div class="pad"><div class="search">${I('search','ic-s')}Search chats</div></div>
  <div class="row g12 mt20" style="padding:0 20px;overflow:hidden">${['meera','ananya','ishita','naina','riya'].map(k=>`<div class="col" style="align-items:center;gap:6px">${av(k,60,'on','border:2px solid var(--bg);box-shadow:0 0 0 2px var(--ok)')}<span class="cap">${HOSTS[k].name}</span></div>`).join('')}</div>
  <div class="col mt16">${CONV.map(([k,st,m,t,u])=>`<div class="row g12" style="padding:12px 20px">${av(k,56,st==='on'?'on':null)}<div class="f1"><div class="row between"><span class="t-s">${HOSTS[k].name}</span><span class="cap ${u?'pri':'ink3'}">${t}</span></div><div class="row between mt4"><span class="b-m ${u?'':'ink3'}" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:230px;${u?'font-weight:700':''}">${m}</span>${u?`<span style="min-width:20px;height:20px;border-radius:10px;background:var(--primary);color:#fff;font-size:11px;font-weight:800;display:flex;align-items:center;justify-content:center">${u}</span>`:''}</div></div></div>`).join('')}</div>
 </div>`, nav:CNAV('chats')}));

const CHATHEAD = (k, sub, st) => `<div class="appbar" style="border-bottom:1px solid var(--line-2);background:var(--surface)"><div class="iconbtn">${I('arrow-left')}</div>${av(k,40,st)}<div class="f1" style="padding-left:4px"><div class="t-s">${HOSTS[k].name}</div><div class="cap ${st==='on'?'okc':'ink3'}">${sub}</div></div><div class="btn pri xs">${I('video','ic-xs')}<span class="num">${fmt(HOSTS[k].rate)}</span>/min</div><div class="iconbtn">${I('ellipsis-vertical','ic-s')}</div></div>`;
S({id:'CH02',folder:F_CHAT,name:'Chat_Conversation',title:'Chat — conversation',
 desc:'One-to-one text conversation. The header carries a direct video-call action with the host\'s rate. Call events appear inline as system rows.',
 notes:['Phone numbers, links and handles are filtered (see CH05).','Video button → V01 (respects availability).','Read receipts and typing indicator: not specified — D-15.'],
 flags:['D-15'],to:['V01','CH05']},
()=>SCR({bg:'var(--n50)',body:`${CHATHEAD('meera','Online now','on')}<div class="content col g8" style="padding:16px 16px 8px;justify-content:flex-end">
  <div class="bub sys">${I('video','ic-xs','vertical-align:-2px')} Video call · 6 min 00 s · Today 8:42 PM</div>
  <div class="bub in">That was such a fun chat! I can't believe you've been to Coorg three times 😄</div>
  <div class="bub out">Haha it's my happy place. You should go in the monsoon</div>
  <div class="btime" style="align-self:flex-end">8:49 PM · Seen</div>
  <div class="bub in">Adding it to my list ✨</div>
  <div class="bub in">It was lovely talking to you! 😊</div>
  <div class="btime">8:51 PM</div></div>
 <div class="composer"><div class="iconbtn soft" style="width:44px;height:44px">${I('smile','ic-s')}</div><div class="box">Message Meera…</div><div class="sendbtn">${I('send-horizontal','ic-s')}</div></div>${GB()}`, noGb:true}));

S({id:'CH03',folder:F_CHAT,name:'Chat_Empty',title:'Chat — empty inbox',
 desc:'Empty state for customers with no conversations yet. Explains that chats usually start after a call.',
 notes:['CTA goes to Discover.','Same pattern for hosts with host-specific copy.'],
 to:['C01']},
()=>SCR({body:`<div class="largetitle" style="padding-top:8px"><span class="d-m">Chats</span></div><div class="content col">
  <div class="spacer"></div><div class="empty"><div class="art">${I('messages-square','ic-xl')}</div>
  <div class="d-s">No conversations yet</div>
  <div class="b-l ink2 mt8">After a video call, you can keep the conversation going here — if the host allows messages.</div>
  <div class="btn pri sm mt24">Discover hosts</div></div><div class="spacer"></div><div class="spacer"></div></div>`, nav:CNAV('chats')}));

S({id:'CH04',folder:F_CHAT,name:'Chat_Messaging_Restricted',title:'Chat — messaging not allowed',
 desc:'The host\'s privacy setting allows messages only from past call partners. The composer is replaced with an explanation and a call action.',
 notes:['Driven by the recipient\'s "Who can message me" setting (S04/H21): Everyone or People I\'ve called.','No workaround; the call CTA is the path forward.'],
 to:['V01']},
()=>SCR({bg:'var(--n50)',body:`${CHATHEAD('naina','Online now','on')}<div class="content col jc" style="align-items:center;padding:0 32px">
  ${av('naina',88)}<div class="t-l mt16">Naina, 23</div><div class="b-m ink3">Delhi · Hindi, Punjabi</div></div>
 <div style="background:var(--surface);border-top:1px solid var(--line-2);padding:16px 20px 8px">
  <div class="row g12 ai-s"><div style="width:40px;height:40px;border-radius:14px;background:var(--surface-2);display:flex;align-items:center;justify-content:center;flex:none">${I('lock','ic-s')}</div><div><div class="t-s">Naina accepts messages after a call</div><div class="b-s ink2 mt4">Start a video call first. After that, you'll be able to message each other.</div></div></div>
  <div class="btn pri full mt16">${I('video','ic-s')}Video call · ${DIA(14)} 3,600/min</div></div>${GB()}`, noGb:true}));

S({id:'CH05',folder:F_CHAT,name:'Chat_Message_Blocked_Filter',title:'Chat — message blocked by safety filter',
 desc:'An outgoing message containing a phone number, link or social handle is not delivered. Inline feedback explains the rule.',
 notes:['Filter runs server-side; client shows the rejection inline.','Bubble shows red outline + "Not sent".','Repeated attempts may trigger review (server policy).'],
 to:['CH02']},
()=>SCR({bg:'var(--n50)',body:`${CHATHEAD('ananya','Online now','on')}<div class="content col g8" style="padding:16px 16px 8px;justify-content:flex-end">
  <div class="bub in">Haha yes, Pune rain is something else 🌧️</div>
  <div class="bub out">Totally! Let's talk more on WhatsApp, my number is 98204 1••••</div>
  <div class="row g6" style="align-self:flex-end;color:var(--err)">${I('circle-alert','ic-xs')}<span class="cap">Not sent</span></div>
  <div class="card flat" style="padding:14px 16px;border-color:var(--err-100);background:#FFF8F7;margin-top:4px">
   <div class="row g10 ai-s">${I('shield-alert','ic-s','color:var(--err);margin-top:1px')}<div><div class="t-s" style="font-size:14px">Keep conversations on Dashuri</div><div class="b-s ink2 mt4">Phone numbers, links and social handles aren't allowed in messages. This protects you from scams.</div></div></div></div></div>
 <div class="composer"><div class="iconbtn soft" style="width:44px;height:44px">${I('smile','ic-s')}</div><div class="box">Message Ananya…</div><div class="sendbtn" style="background:var(--n200)">${I('send-horizontal','ic-s')}</div></div>${GB()}`, noGb:true}));
