import 'package:feature_purchases/feature_purchases.dart';

const popular = DiamondPackage(
  productId: 'dia_1199',
  diamonds: 54000,
  pricePaise: 119900,
  label: 'Popular',
  badge: 'Most popular',
  provisional: true,
);
const starter = DiamondPackage(
  productId: 'dia_99',
  diamonds: 4000,
  pricePaise: 9900,
  label: 'Starter',
  provisional: true,
);

const bothRails = {PaymentRail.googlePlay, PaymentRail.cashfree};

PackageCatalogue catalogue({Set<PaymentRail> rails = bothRails}) =>
    PackageCatalogue(
      packages: const [starter, popular],
      rails: rails,
      currentBalance: 12480,
    );

CashfreeOrder order({
  CashfreeOrderState state = CashfreeOrderState.created,
  int credited = 0,
}) => CashfreeOrder(
  orderId: 'dsh_1',
  productId: 'dia_1199',
  amountPaise: 119900,
  diamonds: 54000,
  paymentSessionId: state == CashfreeOrderState.created ? 'sess_1' : null,
  environment: 'sandbox',
  state: state,
  diamondsCredited: credited,
);
