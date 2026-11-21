// Dashuri six-month simulation engine (daily steps, monthly reporting).
// Accounting rules:
//  - Top-ups are cash/receivables, NOT revenue. Unspent purchased Diamonds are a customer liability.
//  - Revenue is recognised only when purchased Diamonds are consumed in billable calls.
//  - The Play fee is deferred with the Diamonds and expensed as they are consumed.
//  - Host Beans are an expense and a liability when earned; cash leaves only at weekly payouts.
import { CONSTANTS, DEFAULT_PACKAGES, DEFAULT_XP_THRESHOLDS, RATE_LADDERS } from './assumptions.js';
import { createRng } from './rng.js';
import { beansForDiamonds, gstIncluded, gstForConsumption, playFee, levelForXp, maxRateForLevel, breakEven } from './finance.js';

const DAYS = CONSTANTS.daysPerMonth;
const MONTHS = CONSTANTS.months;
const HORIZON = DAYS * MONTHS;

function blankMonth(m) {
  return {
    month: m + 1,
    installs: 0, registrations: 0, eligible: 0,
    activeCustomers: 0, payingCustomers: 0, newPayers: 0, retainedPayers: 0,
    newPayersFromFreeCall: 0, newPayersOther: 0, newPayersLate: 0,
    freeCardUsers: 0, freeCallsServed: 0, freeCallsCompleted: 0, freeCallsUnserved: 0, freeCallMinutes: 0,
    purchases: 0, purchasesByPackage: [0, 0, 0, 0, 0, 0], topupGross: 0, diamondsPurchased: 0,
    refunds: 0, refundGross: 0, refundDiamonds: 0,
    chargebacks: 0, chargebackGross: 0,
    diamondsConsumed: 0, diamondsConsumedPurchased: 0, promoDiamondsGranted: 0, promoDiamondsConsumed: 0, promoDiamondsExpired: 0,
    unservedDemandDiamonds: 0,
    activeHosts: 0, newHosts: 0, hostOnlineDays: 0, hostCapacityMinutes: 0,
    incomingCalls: 0, acceptedCalls: 0, connectedCalls: 0, failedConnections: 0, completedCalls: 0,
    paidMinutes: 0, connectedMinutes: 0, rateMinuteSum: 0,
    beansEarnedPaid: 0, beansEarnedFree: 0, beansEarnedPromo: 0, beansClawedBack: 0, beansWithdrawn: 0, payouts: 0, payoutCash: 0,
    // P&L
    grossConsumed: 0, gstOnConsumption: 0, revenue: 0, playFeeExpense: 0,
    hostPaidExpense: 0, clawbackRecovery: 0, videoPaid: 0, moderationPaid: 0, chargebackLoss: 0, chargebackFees: 0,
    contribution: 0,
    freeCallHostCost: 0, videoFree: 0, moderationFree: 0, freeCallCost: 0,
    promoHostCost: 0, safetyOps: 0, reportReview: 0, otp: 0, kyc: 0, payoutFees: 0, fixedInfra: 0, socialLevy: 0,
    opex: 0, preLaunch: 0, operatingProfit: 0, acquisitionSpend: 0, profitAfterAcquisition: 0,
    // Cash
    cashIn: 0, cashOutHosts: 0, cashOutGst: 0, cashOutOpex: 0, cashOutAcquisition: 0, cashOutPreLaunch: 0, netCash: 0,
    closingCash: 0, minCashInMonth: 0, googleSettlementReceived: 0,
    // Balances at month end
    walletDiamonds: 0, walletValueGross: 0, promoWalletDiamonds: 0,
    beansInHold: 0, beansAvailable: 0, hostLiabilityInr: 0, customerLiabilityInr: 0,
    googleReceivable: 0,
  };
}

export function simulate(params, seed = 1) {
  const p = params;
  const rng = createRng(seed);
  const packages = p.packages || DEFAULT_PACKAGES;
  const thresholds = p.xpThresholds || DEFAULT_XP_THRESHOLDS;
  const ladder = p.customLadder || RATE_LADDERS[p.ladder || 'A'].max;
  const inrPerBean = p.inrPerBean ?? CONSTANTS.inrPerBean;
  const fx = p.fxInrPerUsd;
  const holdDays = CONSTANTS.holdDays;
  const minWithdrawBeans = CONSTANTS.minWithdrawInr / inrPerBean;
  const freeBeans = CONSTANTS.freeCallHostInr / inrPerBean;
  const months = Array.from({ length: MONTHS }, (_, m) => blankMonth(m));
  const cashDelta = new Array(HORIZON).fill(0);
  const dayLog = Array.from({ length: HORIZON }, () => ({ inflow: 0, hosts: 0, gst: 0, opex: 0, acq: 0, pre: 0 }));
  const postHorizon = { settlements: 0 };
  const monthOf = (d) => Math.min(MONTHS - 1, Math.floor(d / DAYS));

  const addCash = (day, amount, kind) => {
    if (day >= HORIZON) {
      if (kind === 'inflow') postHorizon.settlements += amount;
      return;
    }
    cashDelta[day] += amount;
    const log = dayLog[day];
    if (kind === 'inflow') log.inflow += amount;
    else if (kind === 'hosts') log.hosts -= amount;
    else if (kind === 'gst') log.gst -= amount;
    else if (kind === 'opex') log.opex -= amount;
    else if (kind === 'acq') log.acq -= amount;
    else if (kind === 'pre') log.pre -= amount;
  };

  // ---------- Hosts ----------
  const hosts = [];
  let nextHostId = 1;
  const setRate = (h) => {
    h.level = levelForXp(h.xp, thresholds);
    const max = maxRateForLevel(h.level, ladder);
    h.rate = Math.max(CONSTANTS.minRate, Math.min(max, Math.round((max * h.positioning) / 10) * 10));
  };
  const addHost = (m) => {
    const h = {
      id: nextHostId++, xp: 0, level: 1, rate: CONSTANTS.minRate,
      positioning: Math.min(1, Math.max(0.3, p.ratePositioning + (rng.next() - 0.5) * 0.2)),
      hours: p.hostOnlineHours * (0.6 + 0.8 * rng.next()),
      optIn: rng.next() < p.freePoolOptIn,
      holds: [], available: 0, withdrawnInr: 0, earnedInr: 0,
      monthEarn: new Array(MONTHS).fill(0), joined: m, active: true,
      capRem: 0, freeSlots: 0,
    };
    setRate(h);
    hosts.push(h);
    return h;
  };

  // ---------- Customers & wallet ----------
  const buys = Array.from({ length: HORIZON }, () => new Array(packages.length).fill(0));
  const pickPkg = () => rng.pick(p.packageMix);
  const scheduleFirstAndRepeat = (day) => {
    // First purchase on conversion day, extra purchases spread over the rest of the month.
    const m = monthOf(day);
    const monthEnd = (m + 1) * DAYS;
    buys[day][pickPkg()] += 1;
    const remainFrac = (monthEnd - day) / DAYS;
    const extra = rng.poisson(Math.max(0, p.purchasesPerPayer - 1) * remainFrac);
    for (let i = 0; i < extra; i++) {
      const d = Math.min(monthEnd - 1, day + Math.floor(rng.next() * (monthEnd - day)));
      buys[d][pickPkg()] += 1;
    }
  };

  let walletActiveD = 0;
  let walletDormantD = 0;
  let walletV = 0; // gross ₹ paid for purchased Diamonds still in wallets
  let walletFee = 0; // deferred Play fee on those Diamonds
  let promo = []; // {expires, d}
  let cardQueue = [];
  let prevPayers = 0;
  let nonPayPool = 0;
  const chargebackQueue = []; // {day, gross, diamonds, fee}
  let pendingChargebackExposure = 0;
  const chargebacksByMonth = new Array(MONTHS).fill(0).map(() => ({ deduct: 0, fees: 0, gstCredit: 0 }));
  const purchaseByMonth = new Array(MONTHS).fill(0).map(() => ({ gross: 0, fee: 0, gst: 0 }));
  let uniquePayers = 0;
  let cumPurchasedD = 0;
  let cumRefundD = 0;
  let cumConsumedPurchasedD = 0;
  let cumBeansEarned = 0;
  let cumBeansClawed = 0;
  let cumBeansWithdrawn = 0;

  for (let m = 0; m < MONTHS; m++) {
    const mo = months[m];
    const startDay = m * DAYS;

    // Host roster for the month.
    let active = hosts.filter((h) => h.active);
    if (m > 0) {
      for (const h of active) if (rng.next() < p.hostChurn) h.active = false;
      active = hosts.filter((h) => h.active);
    }
    const target = Math.max(0, Math.round(p.hostsByMonth[m] ?? p.hostsByMonth[p.hostsByMonth.length - 1]));
    while (active.length < target) {
      active.push(addHost(m));
      mo.newHosts += 1;
    }
    if (active.length > target) {
      for (const h of active.slice(target)) h.active = false;
      active = active.slice(0, target);
    }
    mo.activeHosts = active.length;

    // Lapsed payers' balances become dormant.
    const lapse = walletActiveD * (1 - p.payerRetention);
    walletActiveD -= lapse;
    walletDormantD += lapse;

    // Acquisition.
    const noise = Math.exp(0.1 * rng.normal() - 0.005);
    mo.installs = Math.round(p.installsM1 * Math.pow(1 + p.installGrowth, m) * noise);
    mo.registrations = rng.binomial(mo.installs, p.registrationRate);
    mo.eligible = rng.binomial(mo.registrations, p.eligibilityRate);

    // Retained payers buy during the month.
    mo.retainedPayers = rng.binomial(prevPayers, p.payerRetention);
    for (let i = 0; i < mo.retainedPayers; i++) {
      const k = 1 + rng.poisson(Math.max(0, p.purchasesPerPayer - 1));
      for (let j = 0; j < k; j++) buys[startDay + Math.floor(rng.next() * DAYS)][pickPkg()] += 1;
    }

    // Late conversions from earlier non-paying users.
    const late = rng.binomial(nonPayPool, p.lateConversionRate);
    nonPayPool -= late;
    for (let i = 0; i < late; i++) scheduleFirstAndRepeat(startDay + Math.floor(rng.next() * DAYS));
    mo.newPayersLate = late;

    // New eligible users arrive across the month.
    const cardArrivals = new Array(DAYS).fill(0);
    let nonCardNonPayers = 0;
    for (let i = 0; i < mo.eligible; i++) {
      const d = Math.floor(rng.next() * DAYS);
      if (rng.next() < p.freeCardUseRate) cardArrivals[d] += 1;
      else if (rng.next() < p.nonCardPayRate) {
        scheduleFirstAndRepeat(startDay + d);
        mo.newPayersOther += 1;
      } else nonCardNonPayers += 1;
      if (p.promoDiamondsPerNewUser > 0) mo.promoDiamondsGranted += p.promoDiamondsPerNewUser;
    }
    mo.freeCardUsers = cardArrivals.reduce((s, x) => s + x, 0);
    let freeNonPayers = 0;

    // ---------- Daily loop ----------
    for (let d = 0; d < DAYS; d++) {
      const day = startDay + d;

      // Promotional Diamonds granted to today's new users (if any).
      if (p.promoDiamondsPerNewUser > 0) {
        const grant = (mo.promoDiamondsGranted / DAYS);
        promo.push({ expires: day + 30, d: grant });
      }

      // Hosts online today.
      let online = [];
      for (const h of active) {
        if (rng.next() < p.hostDailyAvailability) {
          h.capRem = h.hours * (0.7 + 0.6 * rng.next()) * 60 * p.maxUtilisation;
          h.freeSlots = h.optIn ? Math.min(CONSTANTS.freeCallsPerHostPerDay, Math.floor(h.capRem)) : 0;
          online.push(h);
          mo.hostOnlineDays += 1;
          mo.hostCapacityMinutes += h.capRem;
        } else {
          h.capRem = 0;
          h.freeSlots = 0;
        }
      }

      // Top-ups.
      for (let k = 0; k < packages.length; k++) {
        const c = buys[day][k];
        if (!c) continue;
        const pkg = packages[k];
        const refunded = rng.binomial(c, p.refundRate);
        const kept = c - refunded;
        const cb = rng.binomial(kept, p.chargebackRate);
        mo.purchases += c;
        mo.purchasesByPackage[k] += c;
        mo.topupGross += c * pkg.price;
        mo.diamondsPurchased += c * pkg.diamonds;
        mo.refunds += refunded;
        mo.refundGross += refunded * pkg.price;
        mo.refundDiamonds += refunded * pkg.diamonds;
        cumPurchasedD += c * pkg.diamonds;
        cumRefundD += refunded * pkg.diamonds;
        const gross = kept * pkg.price;
        const fee = playFee(gross, { playFeeRate: p.playFeeRate, feeBase: p.feeBase });
        walletActiveD += kept * pkg.diamonds;
        walletV += gross;
        walletFee += fee;
        purchaseByMonth[m].gross += gross;
        purchaseByMonth[m].fee += fee;
        for (let i = 0; i < cb; i++) {
          const cbDay = day + 15 + Math.floor(rng.next() * 45);
          const f = playFee(pkg.price, { playFeeRate: p.playFeeRate, feeBase: p.feeBase });
          if (cbDay < HORIZON) chargebackQueue.push({ day: cbDay, gross: pkg.price, diamonds: pkg.diamonds, fee: f });
          else pendingChargebackExposure += pkg.price;
        }
      }

      // Free Call Card queue: served first, at most 20 per opted-in online host.
      if (cardArrivals[d]) cardQueue.push(cardArrivals[d]);
      let waiting = cardQueue.reduce((s, x) => s + x, 0);
      const pool = online.filter((h) => h.freeSlots > 0);
      let slots = pool.reduce((s, h) => s + h.freeSlots, 0);
      const served = Math.min(waiting, slots);
      if (served > 0) {
        let left = served;
        // spread calls across pool hosts in proportion to free slots
        for (let i = 0; i < pool.length && left > 0; i++) {
          const h = pool[i];
          const share = i === pool.length - 1 ? left : Math.min(left, Math.round((served * h.freeSlots) / slots));
          const n = Math.min(share, h.freeSlots, left);
          if (n <= 0) continue;
          const completed = rng.binomial(n, p.freeCallCompleteRate);
          const minutes = completed + (n - completed) * 0.5;
          h.capRem = Math.max(0, h.capRem - minutes);
          h.freeSlots -= n;
          const beans = completed * freeBeans;
          h.holds.push({ release: day + holdDays, beans });
          h.earnedInr += beans * inrPerBean;
          h.monthEarn[m] += beans * inrPerBean;
          mo.beansEarnedFree += beans;
          cumBeansEarned += beans;
          mo.freeCallsServed += n;
          mo.freeCallsCompleted += completed;
          mo.freeCallMinutes += minutes;
          const conv = rng.binomial(completed, p.freeToPaidRate);
          for (let c = 0; c < conv; c++) scheduleFirstAndRepeat(day);
          mo.newPayersFromFreeCall += conv;
          freeNonPayers += n - conv;
          left -= n;
        }
        // remove served from the FIFO queue
        let toRemove = served - left;
        while (toRemove > 0 && cardQueue.length) {
          const take = Math.min(cardQueue[0], toRemove);
          cardQueue[0] -= take;
          toRemove -= take;
          if (cardQueue[0] === 0) cardQueue.shift();
        }
      }

      // Paid demand in Diamonds.
      const promoD = promo.reduce((s, x) => s + x.d, 0);
      const demand = walletActiveD * p.walletBurnPerDay + walletDormantD * p.dormantBurnPerDay + promoD * p.walletBurnPerDay;
      const avail = online.filter((h) => h.capRem > 0.5);
      let consumed = 0;
      if (demand > 0 && avail.length) {
        const meanRate = avail.reduce((s, h) => s + h.rate, 0) / avail.length;
        const alloc = new Map();
        let remaining = demand;
        let pool2 = avail.slice();
        for (let pass = 0; pass < 3 && remaining > 1 && pool2.length; pass++) {
          const weights = pool2.map((h) => h.capRem * Math.pow(meanRate / h.rate, 0.3));
          const wsum = weights.reduce((s, w) => s + w, 0);
          const next = [];
          let used = 0;
          pool2.forEach((h, i) => {
            const capD = h.capRem * h.rate - (alloc.get(h) || 0);
            const want = (remaining * weights[i]) / wsum;
            const give = Math.min(want, capD);
            alloc.set(h, (alloc.get(h) || 0) + give);
            used += give;
            if (want < capD) next.push(h);
          });
          remaining -= used;
          pool2 = next;
        }
        for (const [h, dAlloc] of alloc) {
          if (dAlloc <= 0) continue;
          const minutes = dAlloc / h.rate;
          const beans = beansForDiamonds(dAlloc);
          h.capRem -= minutes;
          consumed += dAlloc;
          mo.paidMinutes += minutes;
          mo.rateMinuteSum += minutes * h.rate;
          h.holds.push({ release: day + holdDays, beans });
          h.earnedInr += beans * inrPerBean;
          h.monthEarn[m] += beans * inrPerBean;
          h.xp += beans; // XP from Beans earned in paid calls only
          setRate(h); // new rate applies from the next call
          cumBeansEarned += beans;
          // split promo vs purchased by wallet share
          const wTotal = walletActiveD + walletDormantD + promoD;
          const promoShare = wTotal > 0 ? promoD / wTotal : 0;
          if (promoShare > 0) mo.beansEarnedPromo += beans * promoShare;
          mo.beansEarnedPaid += beans * (1 - promoShare);
        }
        mo.unservedDemandDiamonds += Math.max(0, demand - consumed);
      } else {
        mo.unservedDemandDiamonds += demand;
      }

      if (consumed > 0) {
        const wTotal = walletActiveD + walletDormantD + promoD;
        const fromPromo = wTotal > 0 ? (consumed * promoD) / wTotal : 0;
        const fromPurchased = consumed - fromPromo;
        // take promo FIFO
        let pr = fromPromo;
        for (const x of promo) {
          const t = Math.min(x.d, pr);
          x.d -= t;
          pr -= t;
        }
        promo = promo.filter((x) => x.d > 0.0001);
        const purchasedTotal = walletActiveD + walletDormantD;
        const take = Math.min(fromPurchased, purchasedTotal);
        const activePart = purchasedTotal > 0 ? (take * (walletActiveD * p.walletBurnPerDay)) / (walletActiveD * p.walletBurnPerDay + walletDormantD * p.dormantBurnPerDay || 1) : 0;
        const fromActive = Math.min(walletActiveD, activePart);
        const fromDormant = Math.min(walletDormantD, take - fromActive);
        const usedPurchased = fromActive + fromDormant;
        const share = purchasedTotal > 0 ? usedPurchased / purchasedTotal : 0;
        const grossUsed = walletV * share;
        const feeUsed = walletFee * share;
        walletActiveD -= fromActive;
        walletDormantD -= fromDormant;
        walletV -= grossUsed;
        walletFee -= feeUsed;
        cumConsumedPurchasedD += usedPurchased;
        mo.diamondsConsumed += consumed;
        mo.diamondsConsumedPurchased += usedPurchased;
        mo.promoDiamondsConsumed += fromPromo;
        mo.grossConsumed += grossUsed;
        mo.playFeeExpense += feeUsed;
        const hostInrPurchased = beansForDiamonds(usedPurchased) * inrPerBean;
        mo.gstOnConsumption += gstForConsumption(grossUsed, hostInrPurchased, p.gstMode);
      }

      // Promo expiry.
      for (const x of promo) if (x.expires <= day) mo.promoDiamondsExpired += x.d;
      promo = promo.filter((x) => x.expires > day);

      // Chargebacks landing today.
      for (const cb of chargebackQueue) {
        if (cb.day !== day) continue;
        const cm = monthOf(day);
        const cmo = months[cm];
        const hostInr = beansForDiamonds(cb.diamonds) * inrPerBean;
        const gst = gstForConsumption(cb.gross, hostInr, p.gstMode);
        cmo.chargebacks += 1;
        cmo.chargebackGross += cb.gross;
        cmo.chargebackLoss += cb.gross - gst - cb.fee; // lost net proceeds (revenue less fee)
        cmo.chargebackFees += p.chargebackFeeInr;
        chargebacksByMonth[cm].deduct += cb.gross - cb.fee - (p.gstMode === 'google' ? gstIncluded(cb.gross) : 0);
        chargebacksByMonth[cm].fees += p.chargebackFeeInr;
        if (p.gstMode !== 'google') chargebacksByMonth[cm].gstCredit += gst;
        // Claw back a share of related Beans from hosts' held balances.
        let claw = beansForDiamonds(cb.diamonds) * p.clawbackShare;
        const holders = hosts.filter((h) => h.holds.some((x) => x.release > day));
        for (const h of holders) {
          for (const x of h.holds) {
            if (claw <= 0) break;
            if (x.release <= day) continue;
            const t = Math.min(x.beans, claw);
            x.beans -= t;
            claw -= t;
            cmo.beansClawedBack += t;
            cmo.clawbackRecovery += t * inrPerBean;
            cumBeansClawed += t;
            h.earnedInr -= t * inrPerBean;
          }
          if (claw <= 0) break;
        }
      }

      // Release held Beans daily; pay out weekly.
      for (const h of hosts) {
        if (!h.holds.length) continue;
        const keep = [];
        for (const x of h.holds) {
          if (x.release <= day) h.available += x.beans;
          else keep.push(x);
        }
        h.holds = keep;
      }
      if (day % CONSTANTS.payoutIntervalDays === CONSTANTS.payoutIntervalDays - 1) {
        for (const h of hosts) {
          if (h.available >= minWithdrawBeans && rng.next() < p.withdrawProb) {
            const inr = h.available * inrPerBean;
            mo.beansWithdrawn += h.available;
            cumBeansWithdrawn += h.available;
            mo.payouts += 1;
            mo.payoutCash += inr;
            h.withdrawnInr += inr;
            h.available = 0;
            addCash(day, -(inr + p.payoutFeeInr), 'hosts');
            mo.payoutFees += p.payoutFeeInr;
          }
        }
      }

      // Daily acquisition spend (what-if CAC).
      if (p.cacPerInstall > 0) addCash(day, -(mo.installs * p.cacPerInstall) / DAYS, 'acq');
    }

    // Unserved free-call users at month end lapse.
    mo.freeCallsUnserved = cardQueue.reduce((s, x) => s + x, 0);
    cardQueue = [];

    // Customers.
    mo.newPayers = mo.newPayersFromFreeCall + mo.newPayersOther + mo.newPayersLate;
    uniquePayers += mo.newPayers;
    mo.payingCustomers = mo.retainedPayers + mo.newPayers;
    const retainedNonPay = nonPayPool;
    mo.activeCustomers = mo.eligible + retainedNonPay + mo.retainedPayers + late;
    nonPayPool = rng.binomial(retainedNonPay + freeNonPayers + nonCardNonPayers + mo.freeCallsUnserved, p.userRetention);
    prevPayers = mo.payingCustomers;

    // Calls funnel (paid).
    mo.completedCalls = mo.paidMinutes / p.avgPaidCallMin;
    mo.connectedCalls = mo.completedCalls;
    mo.connectedMinutes = mo.paidMinutes / (1 - p.interruptionShare);
    mo.acceptedCalls = mo.connectedCalls / p.connectRate;
    mo.failedConnections = mo.acceptedCalls - mo.connectedCalls;
    mo.incomingCalls = mo.acceptedCalls / p.acceptRate;

    // P&L.
    mo.revenue = mo.grossConsumed - mo.gstOnConsumption;
    mo.hostPaidExpense = mo.beansEarnedPaid * inrPerBean;
    mo.promoHostCost = mo.beansEarnedPromo * inrPerBean;
    mo.freeCallHostCost = mo.beansEarnedFree * inrPerBean;
    const paidParticipantMin = (mo.connectedMinutes + mo.failedConnections * 0.25) * 2;
    const freeParticipantMin = mo.freeCallMinutes * 2;
    const usd = ((paidParticipantMin + freeParticipantMin) * p.videoUsdPer1000) / 1000;
    const usdAfterCredit = Math.max(0, usd - p.streamFreeCreditUsd);
    const videoInr = usdAfterCredit * fx;
    const paidShare = paidParticipantMin + freeParticipantMin > 0 ? paidParticipantMin / (paidParticipantMin + freeParticipantMin) : 0;
    mo.videoPaid = videoInr * paidShare;
    mo.videoFree = videoInr - mo.videoPaid;
    const modMinPaidCall = Math.min(p.avgPaidCallMin, p.moderationMinutes);
    const frameCost = p.moderationFramesPerMin * p.moderationStreams * p.moderationUsdPerFrame * fx;
    mo.moderationPaid = mo.connectedCalls * modMinPaidCall * frameCost;
    mo.moderationFree = mo.freeCallsServed * Math.min(1, p.moderationMinutes) * frameCost;
    mo.contribution = mo.revenue - mo.playFeeExpense - mo.hostPaidExpense + mo.clawbackRecovery - mo.videoPaid - mo.moderationPaid - mo.chargebackLoss - mo.chargebackFees;
    mo.freeCallCost = mo.freeCallHostCost + mo.videoFree + mo.moderationFree;
    mo.safetyOps = p.safetyOpsMonthlyInr;
    mo.reportReview = ((mo.connectedCalls + mo.freeCallsServed) / 1000) * p.reportsPer1000Calls * p.reviewCostPerReport;
    mo.otp = mo.registrations * p.smsPerRegistration * p.otpInrPerSms;
    mo.kyc = mo.newHosts * p.kycInrPerHost;
    mo.fixedInfra = (p.supabaseUsd + p.cloudRunUsd) * fx + p.otherFixedInr;
    mo.socialLevy = mo.revenue * p.socialLevyRate;
    mo.opex = mo.promoHostCost + mo.safetyOps + mo.reportReview + mo.otp + mo.kyc + mo.payoutFees + mo.fixedInfra + mo.socialLevy;
    mo.preLaunch = m === 0 ? p.preLaunchInr : 0;
    mo.operatingProfit = mo.contribution - mo.freeCallCost - mo.opex - mo.preLaunch;
    mo.acquisitionSpend = mo.installs * p.cacPerInstall;
    mo.profitAfterAcquisition = mo.operatingProfit - mo.acquisitionSpend;

    // Cash events for this month.
    const endDay = startDay + DAYS - 1;
    if (m === 0 && p.preLaunchInr > 0) addCash(0, -p.preLaunchInr, 'pre');
    const monthOpexCash = mo.videoPaid + mo.videoFree + mo.moderationPaid + mo.moderationFree + mo.safetyOps + mo.reportReview + mo.otp + mo.kyc + mo.fixedInfra + mo.socialLevy;
    addCash(endDay, -monthOpexCash, 'opex');
    // Google settlement for this month's purchases (net of refunds, fee, GST if Google remits, chargebacks this month).
    const pm = purchaseByMonth[m];
    const gstOnPurchases = gstIncluded(pm.gross);
    pm.gst = gstOnPurchases;
    const settleDay = startDay + DAYS + (p.settlementDay - 1) + p.bankTransitDays;
    const settlement = pm.gross - pm.fee - (p.gstMode === 'google' ? gstOnPurchases : 0) - chargebacksByMonth[m].deduct - chargebacksByMonth[m].fees;
    addCash(settleDay, settlement, 'inflow');
    if (settleDay < HORIZON) months[monthOf(settleDay)].googleSettlementReceived += settlement;
    // GST payable by Dashuri (20th of next month).
    if (p.gstMode !== 'google') {
      const gstDay = startDay + DAYS + 19;
      let gstDue = p.gstMode === 'agent' ? mo.gstOnConsumption : gstOnPurchases;
      gstDue -= chargebacksByMonth[m].gstCredit;
      addCash(gstDay, -gstDue, 'gst');
      mo.gstPayable = gstDue;
    } else mo.gstPayable = 0;

    // Month-end balances.
    mo.walletDiamonds = walletActiveD + walletDormantD;
    mo.walletValueGross = walletV;
    mo.promoWalletDiamonds = promo.reduce((s, x) => s + x.d, 0);
    let hold = 0;
    let availB = 0;
    for (const h of hosts) {
      hold += h.holds.reduce((s, x) => s + x.beans, 0);
      availB += h.available;
    }
    mo.beansInHold = hold;
    mo.beansAvailable = availB;
    mo.hostLiabilityInr = (hold + availB) * inrPerBean;
    mo.customerLiabilityInr = walletV; // GST-inclusive value of unspent purchased Diamonds
    mo.avgRate = mo.paidMinutes > 0 ? mo.rateMinuteSum / mo.paidMinutes : 0;
    mo.utilisation = mo.hostCapacityMinutes > 0 ? (mo.paidMinutes + mo.freeCallMinutes) / mo.hostCapacityMinutes : 0;
    mo.avgTopup = mo.purchases > 0 ? mo.topupGross / mo.purchases : 0;
    mo.cumUniquePayers = uniquePayers;
  }

  // ---------- Cash timeline ----------
  const balance = new Array(HORIZON).fill(0);
  let bal = 0;
  let minBal = 0;
  let minDay = 0;
  for (let d = 0; d < HORIZON; d++) {
    bal += cashDelta[d];
    balance[d] = bal;
    if (bal < minBal) {
      minBal = bal;
      minDay = d;
    }
  }
  for (let m = 0; m < MONTHS; m++) {
    const mo = months[m];
    let minM = Infinity;
    for (let d = m * DAYS; d < (m + 1) * DAYS; d++) {
      const l = dayLog[d];
      mo.cashIn += l.inflow;
      mo.cashOutHosts += l.hosts;
      mo.cashOutGst += l.gst;
      mo.cashOutOpex += l.opex;
      mo.cashOutAcquisition += l.acq;
      mo.cashOutPreLaunch += l.pre;
      minM = Math.min(minM, balance[d]);
    }
    mo.netCash = mo.cashIn - mo.cashOutHosts - mo.cashOutGst - mo.cashOutOpex - mo.cashOutAcquisition - mo.cashOutPreLaunch;
    mo.closingCash = balance[(m + 1) * DAYS - 1];
    mo.minCashInMonth = minM;
  }
  // Google receivable at the end of month 6 = settlements not yet received.
  months[MONTHS - 1].googleReceivable = postHorizon.settlements;

  return finalise({ params: p, seed, months, balance, dayLog, hosts, minBal, minDay, pendingChargebackExposure, uniquePayers, recon: { cumPurchasedD, cumRefundD, cumConsumedPurchasedD, cumBeansEarned, cumBeansClawed, cumBeansWithdrawn } });
}

const sum = (arr, k) => arr.reduce((s, x) => s + (x[k] || 0), 0);

function finalise(r) {
  const { months, params: p } = r;
  const m6 = months[MONTHS - 1];
  const totals = {};
  for (const k of ['installs', 'registrations', 'eligible', 'newPayers', 'purchases', 'topupGross', 'refundGross', 'chargebackGross', 'diamondsPurchased', 'diamondsConsumed', 'grossConsumed', 'revenue', 'gstOnConsumption', 'playFeeExpense', 'hostPaidExpense', 'freeCallHostCost', 'clawbackRecovery', 'videoPaid', 'videoFree', 'moderationPaid', 'moderationFree', 'chargebackLoss', 'chargebackFees', 'contribution', 'freeCallCost', 'opex', 'preLaunch', 'operatingProfit', 'acquisitionSpend', 'profitAfterAcquisition', 'paidMinutes', 'freeCallMinutes', 'freeCallsCompleted', 'freeCallsServed', 'freeCardUsers', 'payoutCash', 'payouts', 'beansEarnedPaid', 'beansEarnedFree', 'beansWithdrawn', 'completedCalls', 'safetyOps', 'reportReview', 'otp', 'kyc', 'payoutFees', 'fixedInfra', 'socialLevy', 'promoHostCost', 'cashIn', 'cashOutHosts', 'cashOutGst', 'cashOutOpex', 'unservedDemandDiamonds', 'hostCapacityMinutes', 'newPayersFromFreeCall']) {
    totals[k] = sum(months, k);
  }
  totals.hostObligations = totals.hostPaidExpense + totals.freeCallHostCost + totals.promoHostCost - totals.clawbackRecovery;
  // Steady-state break-even from Month 6.
  const cpm = m6.paidMinutes > 0 ? m6.contribution / m6.paidMinutes : 0;
  const fixedMonthly = m6.freeCallCost + m6.opex;
  const be = breakEven({
    fixedMonthly,
    contributionPerPaidMinute: cpm,
    minutesPerPayer: m6.payingCustomers > 0 ? m6.paidMinutes / m6.payingCustomers : 0,
    avgCallMin: p.avgPaidCallMin,
    revenuePerMinute: m6.paidMinutes > 0 ? m6.revenue / m6.paidMinutes : 0,
  });
  const firstProfitMonth = months.findIndex((mo) => mo.operatingProfit > 0);
  const hostEarnM6 = r.hosts.filter((h) => h.active).map((h) => h.monthEarn[MONTHS - 1]).sort((a, b) => a - b);
  const levelDist = new Array(10).fill(0);
  for (const h of r.hosts.filter((x) => x.active)) levelDist[h.level - 1] += 1;
  const summary = {
    topups: totals.topupGross,
    revenue: totals.revenue,
    hostObligations: totals.hostObligations,
    hostPayoutsMade: totals.payoutCash,
    contribution: totals.contribution,
    operatingProfit: totals.operatingProfit,
    profitAfterAcquisition: totals.profitAfterAcquisition,
    peakFunding: -r.minBal,
    peakFundingDay: r.minDay + 1,
    closingCash: r.balance[r.balance.length - 1],
    googleReceivable: m6.googleReceivable,
    m6ActiveCustomers: m6.activeCustomers,
    m6PayingCustomers: m6.payingCustomers,
    m6ActiveHosts: m6.activeHosts,
    m6PaidMinutes: m6.paidMinutes,
    m6OperatingProfit: m6.operatingProfit,
    m6Contribution: m6.contribution,
    m6Utilisation: m6.utilisation,
    m6AvgRate: m6.avgRate,
    contributionPerPaidMinute: cpm,
    contributionPerPayer: r.uniquePayers > 0 ? totals.contribution / r.uniquePayers : 0,
    uniquePayers: r.uniquePayers,
    breakEven: be,
    breakEvenFixedMonthly: fixedMonthly,
    firstProfitMonth: firstProfitMonth >= 0 ? firstProfitMonth + 1 : null,
    reachesMonthlyBreakEven: months.some((mo) => mo.operatingProfit > 0),
    breakEvenCacPerInstall: totals.installs > 0 ? (totals.operatingProfit + totals.acquisitionSpend) / totals.installs : 0,
    m6HostEarnings: hostEarnM6,
    m6MedianHostEarning: hostEarnM6.length ? hostEarnM6[Math.floor(hostEarnM6.length / 2)] : 0,
    levelDistribution: levelDist,
    pendingChargebackExposure: r.pendingChargebackExposure,
    m6WalletLiability: m6.customerLiabilityInr,
    m6HostLiability: m6.hostLiabilityInr,
  };
  return { ...r, totals, summary };
}

export { HORIZON, MONTHS, DAYS };
