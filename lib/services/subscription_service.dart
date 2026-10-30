/// Subscription service — paywall removed.
/// This is a no-op stub kept for compatibility.
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  bool get isPremium => true; // Everyone is premium now 🎉

  Future<void> init() async {}
  Future<bool> buyPremium() async => true;
  Future<void> restorePurchases() async {}
}
