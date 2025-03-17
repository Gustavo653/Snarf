import "package:in_app_purchase/in_app_purchase.dart";
import "package:in_app_purchase_android/in_app_purchase_android.dart";
import "package:in_app_purchase_android/src/billing_client_wrappers/subscription_offer_details_wrapper.dart";

enum BasePlanLength {
  weekly,
  everyFourWeeks,
  monthly,
  everyTwoMonths,
  everyThreeMonths,
  everyFourMonths,
  everySixMonths,
  everyEightMonths,
  yearly,
}

class SubscriptionBasePlanDetails {
  final ProductDetails productDetails;

  late final String subscriptionId;
  late String formattedPrice;
  late String? basePlanId;
  late BasePlanLength? basePlanLength;
  late bool? isFreeTrialAvailable;

  SubscriptionBasePlanDetails(
    this.productDetails,
  ) {
    subscriptionId = productDetails.id;
    formattedPrice = productDetails.price;
    final GooglePlayProductDetails googlePlayProductDetails =
        productDetails as GooglePlayProductDetails;
    final int? basePlanIndex = googlePlayProductDetails.subscriptionIndex;
    final List<SubscriptionOfferDetailsWrapper>? subscriptionOfferDetails =
        googlePlayProductDetails.productDetails.subscriptionOfferDetails;

    if (basePlanIndex != null && subscriptionOfferDetails != null) {
      final SubscriptionOfferDetailsWrapper offerDetailsWrapper =
          subscriptionOfferDetails[basePlanIndex];
      basePlanId = offerDetailsWrapper.basePlanId;
      basePlanLength = _getBasePlanLength(
          offerDetailsWrapper.pricingPhases.first.billingPeriod);
      isFreeTrialAvailable = offerDetailsWrapper.pricingPhases
          .any((phase) => phase.priceAmountMicros == 0);
    }
  }

  BasePlanLength? _getBasePlanLength(String billingPeriod) {
    switch (billingPeriod) {
      case "P1W":
        return BasePlanLength.weekly;
      case "P4W":
        return BasePlanLength.everyFourWeeks;
      case "P1M":
        return BasePlanLength.monthly;
      case "P2M":
        return BasePlanLength.everyTwoMonths;
      case "P3M":
        return BasePlanLength.everyThreeMonths;
      case "P4M":
        return BasePlanLength.everyFourMonths;
      case "P6M":
        return BasePlanLength.everySixMonths;
      case "P8M":
        return BasePlanLength.everyEightMonths;
      case "P1Y":
        return BasePlanLength.yearly;
      default:
        return null;
    }
  }
}
