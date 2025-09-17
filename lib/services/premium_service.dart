import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PremiumService {
  static const String _premiumKey = 'is_premium_user';
  static const String _adRemovalKey = 'ad_removal_purchased';

  // Product IDs for different platforms
  static const String _premiumProductId = 'ball_sort_premium';
  static const String _adRemovalProductId = 'ball_sort_ad_removal';

  static bool _isPremium = false;
  static bool _adRemovalPurchased = false;
  static bool _initialized = false;

  // Owner override via build flag:
  // flutter run --dart-define=OWNER_UNLOCK=true
  static const bool _ownerUnlock =
      bool.fromEnvironment('OWNER_UNLOCK', defaultValue: false);

  // Initialize the premium service
  static Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_premiumKey) ?? false;
    _adRemovalPurchased = prefs.getBool(_adRemovalKey) ?? false;

    // Initialize in-app purchase
    await _initializeInAppPurchase();

    _initialized = true;
  }

  // Initialize in-app purchase
  static Future<void> _initializeInAppPurchase() async {
    final InAppPurchase inAppPurchase = InAppPurchase.instance;

    // Check if in-app purchase is available
    final bool isAvailable = await inAppPurchase.isAvailable();
    if (!isAvailable) {
      print('In-app purchase not available');
      return;
    }

    // Listen to purchase updates
    inAppPurchase.purchaseStream.listen((purchaseDetailsList) {
      for (final purchaseDetails in purchaseDetailsList) {
        _handlePurchaseUpdate(purchaseDetails);
      }
    });
  }

  // Handle purchase updates
  static Future<void> _handlePurchaseUpdate(
      PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.status == PurchaseStatus.purchased) {
      await _processPurchase(purchaseDetails.productID);
    }
  }

  // Process a successful purchase
  static Future<void> _processPurchase(String productId) async {
    final prefs = await SharedPreferences.getInstance();

    switch (productId) {
      case _premiumProductId:
        _isPremium = true;
        await prefs.setBool(_premiumKey, true);
        break;
      case _adRemovalProductId:
        _adRemovalPurchased = true;
        await prefs.setBool(_adRemovalKey, true);
        break;
    }
  }

  // Check if user has premium access
  static bool get isPremium => _isPremium;
  // Treat owner override as premium everywhere
  static bool get isOwnerPremium => _ownerUnlock || _isPremium;

  // Check if ads should be shown
  static bool get shouldShowAds => !_adRemovalPurchased && !isOwnerPremium;

  // Check if difficulty level is unlocked
  static bool isDifficultyUnlocked(int tubeCount) {
    if (isOwnerPremium) return true;

    // Free users only get 7-tube beginner mode
    return tubeCount == 7;
  }

  // Get available difficulty levels for current user
  static List<int> getAvailableDifficulties() {
    if (isOwnerPremium) {
      return [7, 9, 11, 13, 15];
    }
    return [7]; // Only beginner mode for free users
  }

  // Check if custom themes are available
  static bool get hasCustomThemes => isOwnerPremium;

  // Check if unlimited undo is available
  static bool get hasUnlimitedUndo => isOwnerPremium;

  // Check if statistics are available
  static bool get hasStatistics => isOwnerPremium;

  // Purchase premium upgrade
  static Future<bool> purchasePremium() async {
    try {
      final InAppPurchase inAppPurchase = InAppPurchase.instance;
      final ProductDetailsResponse response =
          await inAppPurchase.queryProductDetails({_premiumProductId});

      if (response.notFoundIDs.isNotEmpty) {
        print('Product not found: ${response.notFoundIDs}');
        return false;
      }

      final ProductDetails productDetails = response.productDetails.first;
      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: productDetails);

      return await inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      print('Error purchasing premium: $e');
      return false;
    }
  }

  // Purchase ad removal
  static Future<bool> purchaseAdRemoval() async {
    try {
      final InAppPurchase inAppPurchase = InAppPurchase.instance;
      final ProductDetailsResponse response =
          await inAppPurchase.queryProductDetails({_adRemovalProductId});

      if (response.notFoundIDs.isNotEmpty) {
        print('Product not found: ${response.notFoundIDs}');
        return false;
      }

      final ProductDetails productDetails = response.productDetails.first;
      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: productDetails);

      return await inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      print('Error purchasing ad removal: $e');
      return false;
    }
  }

  // Restore purchases (for iOS)
  static Future<void> restorePurchases() async {
    try {
      final InAppPurchase inAppPurchase = InAppPurchase.instance;
      await inAppPurchase.restorePurchases();
    } catch (e) {
      print('Error restoring purchases: $e');
    }
  }

  // Get premium features description
  static String getPremiumFeaturesDescription() {
    return '''
Premium Features:
• Unlock all difficulty levels (9, 11, 13, 15 tubes)
• Remove all advertisements
• Access detailed statistics and achievements
• Custom ball themes and colors
• Unlimited undo moves
• Priority support
''';
  }

  // Get pricing information
  static Map<String, String> getPricingInfo() {
    return {
      'iOS': 'Premium Upgrade: \$2.99',
      'Android': 'Ad Removal: \$1.99 | Premium Pack: \$2.99',
      'Web': 'Premium Subscription: \$2.99/month or \$19.99/year'
    };
  }
}
