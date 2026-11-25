// Site-wide settings. Change contact and company details HERE only; every
// page reads them.
//
// PRODUCTION GATE: `node check.mjs --production` (the Netlify build) fails
// while any field in `required` below is empty. Indian law requires these
// to be published before launch:
//   * operatorName, registeredAddress, supportPhone: Consumer Protection
//     (E-Commerce) Rules, 2020, Rule 4(1) and 4(4).
//   * grievanceOfficer: IT (Intermediary Guidelines) Rules, 2021, Rule 3(2),
//     and E-Commerce Rules, Rule 4(4). Must be a named person in India.
//   * jurisdictionCity: the courts named in the Terms of Service.
export const site = {
  name: 'Dashuri',
  tagline: 'Real conversations, face to face.',

  // Founder, 25 Nov 2026.
  supportEmail: 'contact.dashuri@gmail.com',
  // Grievances use the same mailbox; a separate one is better later.
  grievanceEmail: 'contact.dashuri@gmail.com',

  // Legal name of the business that operates Dashuri, exactly as on its
  // registration (e.g. "Firstname Lastname, proprietor of BK Enterprises",
  // or "XYZ Private Limited"). This is the Data Fiduciary under DPDP.
  // Founder, 25 Nov 2026: Dashuri is a brand of BK Enterprises.
  operatorName: 'BK Enterprises',
  // Full postal address of the operator's principal place of business.
  registeredAddress: '10, Lakshmipuram Main Road, Palani, Tamil Nadu 624601, India',
  // Customer care phone number (E-Commerce Rules require one).
  supportPhone: '04545-295 719',
  // Name and designation of the Grievance Officer (a person, in India).
  grievanceOfficer: 'Balakumaaran Bharathiyar, Founder & Chief Executive Officer',
  // City whose courts have jurisdiction (normally where the operator is).
  // Not given by the founder: set from the address (Palani, Dindigul district).
  jurisdictionCity: 'Palani, Tamil Nadu',

  // Google Play listing. Empty until the app is publicly listed; the
  // download buttons then say "Coming soon" instead of linking.
  playStoreUrl: '',
  // Absolute origin once a domain is chosen (used for canonical links).
  origin: '',

  // Policy version shown on every policy page. Bump both on any change and
  // tell users in the app (Terms §17).
  policyVersion: '1.0',
  effectiveDate: '25 November 2026',
};

export const required = ['operatorName', 'registeredAddress', 'supportPhone', 'grievanceOfficer', 'jurisdictionCity'];
