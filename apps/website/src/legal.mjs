// Legal and policy pages, version 1.0 (25 Nov 2026).
//
// Written for India, against: Information Technology Act, 2000 and the IT
// (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021;
// Digital Personal Data Protection Act, 2023 and DPDP Rules, 2025; Consumer
// Protection Act, 2019 and Consumer Protection (E-Commerce) Rules, 2020;
// POCSO Act, 2012; Bharatiya Nyaya Sanhita, 2023; Indian Contract Act, 1872;
// CGST Act, 2017 and income-tax law. Prepared WITHOUT a lawyer or CA; see
// apps/website/README.md "Legal status".
//
// Every statement about how Dashuri works must match the live app and
// backend. Check the code before changing a fact (retention periods,
// billing, deletion) and change the code and this text together.
//
// The in-app texts (packages/features/settings/.../legal_texts.dart) are
// short summaries; this website is the full, governing version.
//
// Placeholders filled from site.mjs: {operator} {address} {city} {email}
// {gemail} {phone} {officer} {version} {effective}.

export const legalPages = [
  {
    slug: 'terms',
    title: 'Terms of Service',
    summary: 'The agreement between you and Dashuri: eligibility, Diamonds, calls, conduct and your rights.',
    sections: [
      ['1. About these terms', `
<p>These Terms of Service (“Terms”) are an agreement between you and {operator}, {address} (“Dashuri”, “we”, “us”). They apply to the Dashuri mobile app, this website and every related service (together, the “Service”).</p>
<p>By creating an account or using the Service you accept these Terms, the <a href="/privacy/">Privacy Policy</a>, the <a href="/community-guidelines/">Community Guidelines</a> and the <a href="/refunds/">Diamonds, Billing &amp; Refunds Policy</a>, which form part of these Terms. Hosts also accept the <a href="/host-agreement/">Host Agreement</a>. If you do not agree, do not use the Service.</p>`],
      ['2. Who can use Dashuri', `
<ul>
<li>You must be at least 18 years old and competent to contract under the Indian Contract Act, 1872. Dashuri is not for anyone under 18, and we close accounts we believe belong to a minor.</li>
<li>The Service is offered only in India. You must sign up with a valid Indian mobile number that belongs to you. One account per person and per number.</li>
<li>You may not use the Service if we have previously banned you, or if the law forbids you from using it.</li>
<li>The information you give us, including your date of birth, must be true. Giving a false age is a serious breach of these Terms.</li>
</ul>`],
      ['3. What Dashuri is', `
<p>Dashuri lets adults (“callers”) have one-to-one video calls and chats with independent people who offer their time on the platform (“hosts”). Dashuri provides the technology, payments and safety tools. Hosts are not our employees or agents, and we do not control what they say. Dashuri is an intermediary under the Information Technology Act, 2000 for the content users exchange.</p>
<p>Dashuri is for conversation and companionship in a social sense only. It is not a dating, escort, adult-entertainment or matchmaking service, and no user may offer, ask for or arrange sexual content or services, or meetings for payment.</p>`],
      ['4. Your account', `
<ul>
<li>Keep your phone and sign-in codes secure. You are responsible for everything done through your account.</li>
<li>Tell us at once at <a href="mailto:{email}">{email}</a> if you think someone else is using your account.</li>
<li>Your account is personal. You may not sell, rent, transfer or share it.</li>
</ul>`],
      ['5. Diamonds', `
<ul>
<li>Diamonds are a virtual item used to pay for video calls on Dashuri. They are a limited, personal, non-transferable licence to use a feature of the Service. They are not money, a deposit, a wallet balance, a prepaid payment instrument or property, and they have no cash value.</li>
<li>Diamonds cannot be sold, exchanged, gifted to other users, withdrawn or redeemed for cash, except where the law requires a refund.</li>
<li>Diamonds are bought through Google Play at the price shown at checkout, which includes applicable taxes. Google Play’s terms also apply to the purchase.</li>
<li>Purchased Diamonds do not expire while your account is open. Promotional Diamonds that we give for free expire 30 days after we give them. When you spend Diamonds, promotional Diamonds are used first.</li>
<li>The full rules on charging, failed calls and refunds are in the <a href="/refunds/">Diamonds, Billing &amp; Refunds Policy</a>.</li>
</ul>`],
      ['6. Calls and billing', `
<ul>
<li>Each host sets a price in Diamonds per minute. The app shows it before you start a call. It cannot change during a call.</li>
<li>To start a call you need enough Diamonds for at least one minute. The app warns you when your balance is about to run out, and the call ends when it does.</li>
<li>Our servers measure call time. You are charged for the seconds a call is connected with the host’s video on, at the per-minute price, rounded down to whole Diamonds. Calls that never connect are not charged.</li>
<li>Calls are not recorded by Dashuri. You must not record, screenshot or share a call without the clear consent of the other person.</li>
</ul>`],
      ['7. Messages', '<p>You can send messages to people as allowed by your and their privacy settings. Messages are checked automatically for phone numbers, social handles and payment details, which may not be shared on Dashuri.</p>'],
      ['8. Your conduct', `
<p>You must follow the <a href="/community-guidelines/">Community Guidelines</a> and the law. In particular, you must not host, display, upload, share or transmit anything that:</p>
<ol>
<li>belongs to someone else and you have no right to;</li>
<li>is obscene, pornographic, paedophilic, invasive of another’s privacy (including bodily privacy), insulting or harassing on the basis of gender, racially or ethnically objectionable, relates to or encourages money laundering or gambling, or promotes enmity between groups on the grounds of religion or caste with intent to incite violence;</li>
<li>is harmful to children;</li>
<li>infringes any patent, trademark, copyright or other proprietary right;</li>
<li>deceives or misleads about where a message came from, or knowingly and intentionally communicates information that is patently false or misleading;</li>
<li>impersonates another person;</li>
<li>threatens the unity, integrity, defence, security or sovereignty of India, friendly relations with foreign States or public order, incites an offence, prevents the investigation of an offence or insults another nation;</li>
<li>contains software viruses or any code designed to interrupt, destroy or limit any computer resource; or</li>
<li>violates any law in force.</li>
</ol>
<p>You must also not: use the Service if you are under 18; solicit or offer sexual content or services; move a conversation or payment off Dashuri; harass, threaten or stalk anyone; use bots, scripts or modified apps; scrape the Service; abuse refunds or chargebacks; or try to get around a block, suspension or ban.</p>`],
      ['9. Content and licence', `
<p>You keep ownership of the content you create (your profile, photos and messages). You give Dashuri a non-exclusive, royalty-free licence, valid in India, to store, process, display and transmit that content only to run, secure and improve the Service and to comply with the law. The licence ends when the content is deleted, except for copies we must keep under the law or for safety (see the <a href="/privacy/">Privacy Policy</a>).</p>
<p>The Dashuri name, logo, app and website belong to {operator} or its licensors. You may not copy or use them except as the Service allows.</p>`],
      ['10. Safety checks and moderation', `
<p>To keep calls safe, still frames from the first minutes of each call may be checked automatically for nudity. Users can report and block others. Our team reviews reports and may remove content, end calls, restrict features, or suspend or ban accounts that break these Terms or the law. We act on court orders and lawful requests from government agencies, and we report child sexual abuse material and other crimes to the authorities as the law requires.</p>`],
      ['11. Suspension, termination and appeals', `
<ul>
<li>We may suspend or close an account, with notice where practical, if you break these Terms, the law or the Community Guidelines, if your account poses a risk to others, or if the law requires it.</li>
<li>If we take action against your account, we tell you why in the app (unless the law prevents it), and you can appeal from the account status screen or through the <a href="/grievance/">grievance process</a>.</li>
<li>If we close your account for a serious breach (for example, being under 18, sexual content, fraud or refund abuse), unused Diamonds are forfeited to the extent the law allows. If we close the Service or your account for any other reason, we will refund unused purchased Diamonds.</li>
<li>You can stop using Dashuri and <a href="/delete-account/">delete your account</a> at any time.</li>
</ul>`],
      ['12. Availability and changes to the Service', '<p>We work to keep Dashuri available but do not promise that it will be uninterrupted or error-free. Calls depend on your device and internet connection. We may change, add or remove features. If a change materially reduces what you paid for, we will tell you in advance and refund unused purchased Diamonds if you ask.</p>'],
      ['13. Hosts and other users', '<p>Hosts are independent. Dashuri does not guarantee any host’s availability, identity beyond the checks we describe, or what is said in a call. Be careful about what you share, and report anything that worries you. We are not responsible for what users do outside Dashuri.</p>'],
      ['14. Disclaimers and limits of liability', `
<p>To the extent the law allows, the Service is provided “as is”. We are not liable for indirect or consequential loss, or for loss caused by other users, events outside our reasonable control, or your breach of these Terms. Our total liability to you for any claim is limited to the amount you paid us in the three months before the claim arose, or ₹1,000, whichever is higher.</p>
<p>Nothing in these Terms limits liability that cannot be limited by law, or your rights as a consumer under the Consumer Protection Act, 2019.</p>`],
      ['15. Indemnity', '<p>If you break these Terms or the law and a third party makes a claim against Dashuri because of it, you will compensate us for the resulting reasonable losses and costs, to the extent the law allows.</p>'],
      ['16. Complaints, governing law and disputes', `
<p>Please contact us first: most issues are solved quickly. Complaints go to our Grievance Officer as described on the <a href="/grievance/">Grievance Redressal</a> page. These Terms are governed by the laws of India. Subject to your right to approach a consumer commission or other authority under Indian law, the courts at {city} have exclusive jurisdiction.</p>`],
      ['17. Changes to these Terms', '<p>We may update these Terms to reflect changes in the law or the Service. We will show the new version in the app and on this website before it takes effect, and for material changes we will ask you to accept it again. If you do not accept, you can delete your account; unused purchased Diamonds are handled as in section 11.</p>'],
      ['18. General', '<p>If part of these Terms cannot be enforced, the rest still applies. If we do not enforce a right at once, we do not give it up. You may not transfer your rights under these Terms; we may transfer ours to a successor that continues the Service under equivalent terms. These Terms are an electronic record under the Information Technology Act, 2000 and need no signature.</p>'],
      ['19. Contact', '<p>{operator}, {address}. Email <a href="mailto:{email}">{email}</a>, phone {phone}.</p>'],
    ],
  },

  {
    slug: 'privacy',
    title: 'Privacy Policy',
    summary: 'What personal data Dashuri collects, why, who receives it, how long it is kept and your rights under the DPDP Act.',
    sections: [
      ['1. Who we are', '<p>{operator}, {address} (“Dashuri”, “we”) decides how and why your personal data is processed for the Dashuri app and website. Under the Digital Personal Data Protection Act, 2023 (“DPDP Act”) we are the Data Fiduciary. This notice explains what we collect, why, and the choices and rights you have. Questions: <a href="mailto:{gemail}">{gemail}</a>.</p>'],
      ['2. The personal data we process and why', `
<table>
<thead><tr><th>Data</th><th>Why we use it</th></tr></thead>
<tbody>
<tr><td>Mobile number and sign-in codes</td><td>Creating your account, signing you in, preventing duplicate and fake accounts.</td></tr>
<tr><td>Date of birth</td><td>Confirming you are 18 or older. It is never shown to other users.</td></tr>
<tr><td>Profile: display name, photos, bio, languages, optional city</td><td>Showing your profile to other users and helping callers find hosts. Photos are reviewed before they are shown.</td></tr>
<tr><td>Gender</td><td>Optional; kept private and used only to improve the Service. Never shown to other users.</td></tr>
<tr><td>Approximate location (only if you tap “Use my location”)</td><td>Finding your nearest city once. Your coordinates are not stored.</td></tr>
<tr><td>Call records: who, when, how long, price, and connection events</td><td>Billing, host earnings, call history, safety reviews and resolving disputes. Calls are <strong>not</strong> recorded.</td></tr>
<tr><td>Still frames from the first minutes of a call</td><td>Automated nudity checks to keep calls safe. Frames are not stored unless a check flags them or they are linked to a report.</td></tr>
<tr><td>Messages</td><td>Delivering your chats and blocking shared phone numbers, social handles and payment details.</td></tr>
<tr><td>Purchases and wallet: Google Play order id, product, amount, Diamond and Bean balances and history</td><td>Crediting Diamonds exactly once, preventing fraud, refunds, accounting and tax.</td></tr>
<tr><td>Reports, blocks, appeals and complaints</td><td>Safety, enforcement and handling your complaints.</td></tr>
<tr><td>Device data: push token, a hashed device identifier, Google Play Integrity results, app version</td><td>Notifications, preventing abuse of offers and fake devices, security.</td></tr>
<tr><td>Technical logs: IP address, request times, errors</td><td>Security, fraud prevention and fixing problems.</td></tr>
<tr><td>Hosts only: identity document details checked during activation, availability, price, earnings; and, when payouts start, PAN and bank or UPI details</td><td>Verifying identity and age, paying hosts, tax deduction and reporting required by law.</td></tr>
</tbody>
</table>
<p>We do not sell your personal data, show third-party advertising or use advertising trackers. We do not use your data to train AI models.</p>`],
      ['3. Legal basis', `
<p>We process your personal data on the basis of your consent, which you give when you create an account and accept this notice, and for the legitimate uses the DPDP Act allows, such as complying with the law, court orders and safety obligations. Optional features (location, marketing messages, optional analytics) have their own consent, which you can withdraw in Settings at any time. Withdrawing consent does not affect processing already done; if you withdraw consent needed to run your account, the way to do that is to delete your account.</p>`],
      ['4. Who receives your data', `
<p>Other users see only your public profile and what you share in calls and chats. We use these service providers (“Data Processors”), under contracts that limit them to processing on our instructions:</p>
<ul>
<li>Google Cloud (servers, Mumbai region) and Supabase (database, sign-in and file storage, Mumbai region);</li>
<li>Stream (video call delivery);</li>
<li>Sightengine (automated image checks for nudity);</li>
<li>Google Play (payments and Play Integrity) and Firebase Cloud Messaging (notifications);</li>
<li>an SMS provider that delivers sign-in codes.</li>
</ul>
<p>We share data with government agencies, courts and law enforcement only when Indian law requires or permits it, including reporting child sexual abuse. If Dashuri is sold or merged, your data passes to the new operator under this notice.</p>`],
      ['5. Data stored outside India', '<p>Our main database and servers are in India. Some providers (video delivery, image checks, notifications, payments) may process data in other countries. We transfer data only to countries the Government of India has not restricted under the DPDP Act, and only as needed for the purposes above.</p>'],
      ['6. How long we keep data', `
<ul>
<li>Account and profile data: while your account is open. When you delete your account, profile details, photos, devices and consents are erased after the 7-day grace period.</li>
<li>Messages: a conversation belongs to both people. After you delete your account, messages you sent remain in the other person’s chat history, shown as from “Deleted user”.</li>
<li>Payment, wallet, call and earnings records: up to 8 years, because tax, GST and accounting laws require it. They are kept separately from your profile after deletion.</li>
<li>Flagged call frames and safety evidence: 180 days, or longer if needed for an ongoing investigation, a legal claim or a request from an authority.</li>
<li>Records of content removed under the IT Rules: at least 180 days, as those Rules require.</li>
<li>Security and access logs: at least one year, as the DPDP Rules require.</li>
</ul>
<p>When the period ends, we delete the data or make it anonymous.</p>`],
      ['7. Security', '<p>We use encryption in transit, private storage for photos and evidence, role-based staff access with audit logs, and server-side checks for every payment. If a personal data breach affects you, we will tell you and the Data Protection Board of India as the DPDP Act requires.</p>'],
      ['8. Your rights', `
<p>Under the DPDP Act you can:</p>
<ul>
<li><strong>access</strong> a summary of your personal data and how it is processed (Settings › Download my data);</li>
<li><strong>correct, complete or update</strong> your data (edit your profile, or ask us);</li>
<li><strong>erase</strong> your data by <a href="/delete-account/">deleting your account</a>, subject to the records the law requires us to keep;</li>
<li><strong>withdraw consent</strong> for optional processing in Settings;</li>
<li><strong>nominate</strong> someone to exercise your rights if you die or become incapacitated, by writing to us;</li>
<li><strong>complain</strong> to us, and then to the Data Protection Board of India if you are not satisfied.</li>
</ul>
<p>Write to <a href="mailto:{gemail}">{gemail}</a> from the app or with your registered mobile number. We verify your identity first and reply within 30 days.</p>`],
      ['9. Children', '<p>Dashuri is only for adults. We do not knowingly process the personal data of anyone under 18. If we learn that an account belongs to a child, we close it and delete the data, except what we must keep to report abuse or comply with the law.</p>'],
      ['10. This website', '<p>This website does not use cookies, analytics or tracking. Fonts are loaded from Google Fonts, so your browser sends your IP address to Google when you visit. If you email us, we use your message only to reply.</p>'],
      ['11. Changes', '<p>We will show any change to this notice in the app and on this page, with a new version number, before it takes effect. If a change needs new consent, we will ask for it.</p>'],
      ['12. Contact', '<p>Grievance Officer: {officer}, {operator}, {address}. Email <a href="mailto:{gemail}">{gemail}</a>.</p>'],
    ],
  },

  {
    slug: 'community-guidelines',
    title: 'Community Guidelines',
    summary: 'What is and isn’t allowed on Dashuri, and what happens if the rules are broken.',
    sections: [
      ['Our standard', '<p>Dashuri is for respectful conversation between adults. These rules apply to calls, messages, profiles and photos, and to callers and hosts alike. They are part of our <a href="/terms/">Terms of Service</a>.</p>'],
      ['Adults only', '<p>Everyone on Dashuri must be 18 or older. Never bring a child into a call. Report anyone who seems under 18 with “Appears to be under 18”; we review those reports first.</p>'],
      ['No nudity or sexual content', '<p>No nudity, sexual acts, sexual poses, sexual talk or requests for any of these, on camera or in messages. Calls are checked automatically, and a flagged call can be ended at once.</p>'],
      ['No sexual services or paid meetings', '<p>Dashuri is not an escort or adult service. Do not offer, request or arrange sexual services, “private shows”, or meetings in person in return for money or Diamonds.</p>'],
      ['Respect everyone', '<p>No harassment, bullying, threats, stalking, hate speech or slurs based on religion, caste, race, ethnicity, gender, sexual orientation, disability or region. No pressuring anyone to stay on a call, spend money or share personal details.</p>'],
      ['Keep it on Dashuri', '<p>Do not share or ask for phone numbers, social media handles, addresses, UPI IDs or other payment details. Do not ask anyone to pay outside the app.</p>'],
      ['Be real', '<p>Use your own photos and true age. No impersonation, fake profiles, catfishing or misleading claims.</p>'],
      ['Respect privacy', '<p>Do not record, screenshot or share a call or chat without the other person’s clear consent. Never share intimate images of anyone. We remove non-consensual intimate content within 24 hours of a complaint.</p>'],
      ['No illegal or harmful content', '<p>Nothing that is illegal in India, including content that is harmful to children, promotes violence, terrorism, self-harm, drugs, gambling or money laundering, infringes someone’s copyright or trademark, contains malware, or threatens India’s unity, security or public order.</p>'],
      ['No fraud or abuse', '<p>No scams, begging for money or gifts, refund or chargeback abuse, fake reports, bots, modified apps, or attempts to get around blocks and bans.</p>'],
      ['What happens if rules are broken', '<p>Depending on how serious it is: a warning, removal of content, an ended call, restricted features, a temporary suspension or a permanent ban. Child sexual abuse, sexual services and threats of violence lead to an immediate ban and a report to the authorities. You can appeal any action from the account status screen or through the <a href="/grievance/">grievance process</a>.</p>'],
      ['Report a problem', '<p>Use Report in a call, a profile or a chat, or email <a href="mailto:{email}">{email}</a>. Blocking someone stops them from finding or contacting you.</p>'],
    ],
  },

  {
    slug: 'child-safety',
    title: 'Child Safety Standards',
    summary: 'Dashuri’s published standards against child sexual abuse and exploitation (CSAE).',
    sections: [
      ['Our commitment', '<p>Dashuri has zero tolerance for child sexual abuse and exploitation (CSAE), including child sexual abuse material (CSAM), grooming, sextortion and any sexualisation of minors. Dashuri is only for adults, and any contact with minors on the platform is prohibited.</p>'],
      ['Prevention', `
<ul>
<li>Every user must confirm a date of birth of 18 or older; under-18 declarations are refused.</li>
<li>Hosts complete an identity and age check before they can take calls.</li>
<li>Still frames from the first minutes of each call are checked automatically for nudity, and flagged calls can be ended immediately.</li>
<li>Messages block the sharing of contact details that could move a conversation off the platform.</li>
<li>Our reviewers look for signs of a minor or of grooming in every report they handle.</li>
</ul>`],
      ['In-app reporting', '<p>Every call, profile and chat has a Report option with the category “Appears to be under 18”. These reports go to the front of the review queue. Anyone can also report by email to <a href="mailto:{email}">{email}</a>, without an account.</p>'],
      ['How we respond', `
<ul>
<li>We remove CSAM and suspected CSAE content, and ban the accounts involved, as soon as we become aware of it.</li>
<li>We report CSAM and child sexual abuse to the authorities as the Protection of Children from Sexual Offences Act, 2012 (sections 19 to 21) and the IT Act require, including through the National Cyber Crime Reporting Portal (cybercrime.gov.in), and preserve the related records for investigation.</li>
<li>We cooperate fully with law enforcement.</li>
<li>We never store CSAM in ordinary moderation storage; it follows the reporting path only.</li>
</ul>`],
      ['Compliance with the law', '<p>Dashuri complies with the child safety laws that apply in India, including the POCSO Act, 2012, section 67B of the Information Technology Act, 2000, the Bharatiya Nyaya Sanhita, 2023 and the IT (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021, and with Google Play’s Child Safety Standards policy.</p>'],
      ['Child safety point of contact', '<p>{officer}, {operator}. Email <a href="mailto:{gemail}">{gemail}</a>, phone {phone}. This contact can speak to our CSAM prevention practices and compliance.</p>'],
      ['If a child is in danger', '<p>Call 112 (emergency) or 1098 (Childline), or report at cybercrime.gov.in.</p>'],
    ],
  },

  {
    slug: 'refunds',
    title: 'Diamonds, Billing & Refunds Policy',
    summary: 'How Diamond purchases, call charges, failed calls and refunds work.',
    sections: [
      ['Buying Diamonds', '<p>Diamonds are sold in packs through Google Play. The price shown at checkout includes applicable taxes. Diamonds are added only after Google Play confirms the payment, and each purchase is credited once.</p>'],
      ['How calls are charged', `
<ul>
<li>The host’s price in Diamonds per minute is shown before you call and is fixed for that call.</li>
<li>You need enough Diamonds for one minute to start. Diamonds for the call are reserved while it runs.</li>
<li>You are charged for the seconds the call is connected with the host’s video on, at the per-minute price, rounded down to whole Diamonds. The app shows a summary after every call, and your wallet lists every charge.</li>
</ul>`],
      ['Failed and interrupted calls', '<p>If a call never connects, you are not charged and reserved Diamonds come back automatically. If a call drops because of a technical fault on our side, you are charged only for the time it was connected. If you think a charge is wrong, contact us within 30 days with the call time; we check our server records and credit back Diamonds for any error.</p>'],
      ['Refunds for purchases', `
<ul>
<li>Within 48 hours of purchase you can ask Google Play for a refund from your Google Play order history; after that, ask us at <a href="mailto:{email}">{email}</a> with your Google Play order number.</li>
<li>We refund a purchase if Diamonds were not credited, if you were charged more than once, or if the law requires it. We do not refund Diamonds that have already been spent on calls that took place.</li>
<li>When a purchase is refunded or charged back, the Diamonds from that purchase that are still unspent are removed from your wallet. Repeated refund or chargeback abuse may lead to account restrictions.</li>
<li>Approved refunds are paid to the original payment method through Google Play.</li>
</ul>`],
      ['Account closure', '<p>Unused Diamonds are lost if you delete your account, so spend or ask about them first. If we close the Service, or close your account for a reason other than a breach of our Terms, we refund unused purchased Diamonds. Promotional Diamonds are never refunded.</p>'],
      ['Your consumer rights', '<p>Nothing in this policy limits your rights under the Consumer Protection Act, 2019. You can also raise a complaint through our <a href="/grievance/">grievance process</a> or the National Consumer Helpline (1915, consumerhelpline.gov.in).</p>'],
    ],
  },

  {
    slug: 'host-agreement',
    title: 'Host Agreement',
    summary: 'The terms for hosts: independent status, earnings in Beans, withdrawals, tax and conduct.',
    sections: [
      ['1. This agreement', '<p>This Host Agreement is between you and {operator}, {address} (“Dashuri”). It applies in addition to the <a href="/terms/">Terms of Service</a>, the <a href="/community-guidelines/">Community Guidelines</a> and the <a href="/privacy/">Privacy Policy</a>. You accept it in the app when you apply to host.</p>'],
      ['2. Eligibility and activation', '<p>You must be 18 or older, live in India and complete our identity and age check. We review every application by hand and may accept or decline it. You must keep your details true and tell us if they change.</p>'],
      ['3. Independent status', '<p>You are an independent service provider, not an employee, agent or partner of Dashuri. You decide whether, when and for how long you are available, and which calls you take. Nothing in this agreement creates employment. You are free to work on other platforms.</p>'],
      ['4. Your price', '<p>You set your price in Diamonds per minute within the limits the app shows for your level. A new price applies to new calls only. We may lower a price that is above your current limit, and we tell you when we do.</p>'],
      ['5. Earnings in Beans', `
<ul>
<li>For calls you take, you earn Beans: every 16,670 Diamonds a caller spends with you earns you 10,000 Beans. 200 Beans are worth ₹1.</li>
<li>The difference between what callers pay and what you earn is Dashuri’s service fee for the platform, payments, safety and support.</li>
<li>Beans are recorded in your earnings screen after each call and do not expire. Beans are not transferable and can only be withdrawn as described below.</li>
<li>If a caller’s payment is refunded or charged back, or a call is found to break the rules, we may reverse the Beans earned from it.</li>
</ul>`],
      ['6. Withdrawals', `
<p>Withdrawals are not yet available. When they open (we will announce it in the app):</p>
<ul>
<li>Beans become withdrawable 7 days after you earn them;</li>
<li>withdrawals are processed weekly, with a minimum of ₹500;</li>
<li>payment goes only to a bank account or UPI ID in your own name, after a PAN check.</li>
</ul>
<p>We may hold a withdrawal while we investigate suspected fraud or a breach of the rules, and tell you why.</p>`],
      ['7. Tax', '<p>You are responsible for your own income tax and, where it applies to you, GST registration. We deduct or collect tax at source from payouts where income-tax or GST law requires it, deposit it with the government and give you the related certificates. PAN is mandatory for withdrawals; without it, tax may be deducted at a higher rate.</p>'],
      ['8. Conduct', '<p>You must follow the Community Guidelines in every call and message. In particular: no nudity or sexual content, no sexual services, no meetings or payments outside Dashuri, no sharing of contact details, and no calls with anyone who appears to be under 18 (end the call and report it). Breaking these rules can lead to removal of earnings from the calls concerned, suspension or a ban.</p>'],
      ['9. Your data', '<p>We use your identity, call and earnings data to verify you, pay you, meet tax obligations and keep calls safe, as described in the <a href="/privacy/">Privacy Policy</a>.</p>'],
      ['10. Ending this agreement', '<p>You can stop hosting at any time. We may end this agreement under the Terms of Service. Withdrawable Beans earned under the rules remain payable once withdrawals are available; you cannot delete your account while you still have Beans, so withdraw them first.</p>'],
      ['11. Contact', '<p>Host questions: <a href="mailto:{email}">{email}</a>.</p>'],
    ],
  },

  {
    slug: 'grievance',
    title: 'Grievance Redressal',
    summary: 'How to raise a complaint and our Grievance Officer’s details, under the IT Rules, consumer and data protection law.',
    sections: [
      ['Grievance Officer', '<p>{officer}<br>{operator}, {address}<br>Email: <a href="mailto:{gemail}">{gemail}</a><br>Phone: {phone}</p>'],
      ['How to complain', '<p>Use Help &amp; support › Raise a complaint in the app, or email the Grievance Officer. Tell us your registered mobile number, what happened, and links or screenshots if you have them. You can complain about content, another user, a charge, your account or how we handle your personal data.</p>'],
      ['Our timelines', `
<ul>
<li>We acknowledge every complaint within 24 hours and resolve it within 15 days, in line with the IT Rules, 2021 and the Consumer Protection (E-Commerce) Rules, 2020.</li>
<li>Complaints about content that exposes a person’s private area, shows them in full or partial nudity or in a sexual act, or impersonates them (including morphed images) are acted on within 24 hours.</li>
<li>Requests about your personal data under the DPDP Act are answered within 30 days.</li>
</ul>`],
      ['If you are not satisfied', `
<ul>
<li>For decisions under the IT Rules, you can appeal to the Grievance Appellate Committee at gac.gov.in within 30 days of our decision.</li>
<li>For personal data complaints, you can approach the Data Protection Board of India after using our process.</li>
<li>For consumer complaints, you can contact the National Consumer Helpline (1915) or file at e-daakhil.nic.in.</li>
</ul>`],
    ],
  },

  {
    slug: 'delete-account',
    title: 'Delete your Dashuri account',
    summary: 'How to delete your Dashuri account and data, with or without the app, and what is kept.',
    sections: [
      ['In the app', '<ol><li>Open Dashuri and go to <strong>Settings</strong>.</li><li>Tap <strong>Delete account</strong>.</li><li>Confirm. Your account is deleted after a 7-day grace period. Sign in during those 7 days if you change your mind.</li></ol>'],
      ['Without the app', '<p>Email <a href="mailto:{email}?subject=Delete%20my%20Dashuri%20account">{email}</a> with the subject “Delete my Dashuri account” and the mobile number you signed up with. We confirm that the number is yours, then follow the same process as in the app, and email you when it is done.</p>'],
      ['What is deleted', '<ul><li>Your profile: name, bio, photos, languages, city and gender.</li><li>Your date of birth, devices and consents.</li><li>Your sign-in: your mobile number is removed from sign-in, and you can’t log back in to this account.</li><li>Unused Diamonds, which are lost.</li></ul>'],
      ['What is kept, and for how long', '<ul><li>Messages you sent stay in the other person’s chat history, shown as from “Deleted user”.</li><li>Payment, wallet, call and earnings records: up to 8 years, as tax, GST and accounting laws require.</li><li>Safety reports and evidence linked to your account: 180 days, or longer if an investigation or legal claim needs them.</li></ul>'],
      ['Hosts', '<p>If you still have Beans, withdraw them before deleting your account; a request is declined while Beans remain or while you are in a call.</p>'],
      ['Only want to remove some data?', '<p>You can delete photos, change your consents and download a copy of your data from Settings without deleting your account.</p>'],
    ],
  },
];
