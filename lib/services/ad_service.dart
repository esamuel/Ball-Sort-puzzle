import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'premium_service.dart';

class AdService {
  static bool _initialized = false;
  static BannerAd? _bannerAd;
  static InterstitialAd? _interstitialAd;
  static RewardedAd? _rewardedAd;

  // Ad unit IDs (replace with your actual IDs)
  static const String _bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111'; // Test ID
  static const String _interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712'; // Test ID
  static const String _rewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917'; // Test ID

  // Initialize the ad service
  static Future<void> initialize() async {
    if (_initialized) return;

    await MobileAds.instance.initialize();
    _initialized = true;
  }

  // Create banner ad
  static BannerAd? createBannerAd() {
    if (!_initialized || !PremiumService.shouldShowAds) return null;

    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Banner ad loaded');
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner ad failed to load: $error');
          ad.dispose();
        },
      ),
    );

    _bannerAd!.load();
    return _bannerAd;
  }

  // Show interstitial ad
  static Future<void> showInterstitialAd() async {
    if (!_initialized || !PremiumService.shouldShowAds) return;

    await InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              print('Interstitial ad showed full screen content');
            },
            onAdDismissedFullScreenContent: (ad) {
              print('Interstitial ad dismissed');
              ad.dispose();
              _interstitialAd = null;
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('Interstitial ad failed to show: $error');
              ad.dispose();
              _interstitialAd = null;
            },
          );
          _interstitialAd!.show();
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: $error');
        },
      ),
    );
  }

  // Show rewarded ad
  static Future<bool> showRewardedAd() async {
    if (!_initialized || !PremiumService.shouldShowAds) return false;

    bool rewardEarned = false;

    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              print('Rewarded ad showed full screen content');
            },
            onAdDismissedFullScreenContent: (ad) {
              print('Rewarded ad dismissed');
              ad.dispose();
              _rewardedAd = null;
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('Rewarded ad failed to show: $error');
              ad.dispose();
              _rewardedAd = null;
            },
          );
          _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
            print('User earned reward: ${reward.amount} ${reward.type}');
            rewardEarned = true;
          });
        },
        onAdFailedToLoad: (error) {
          print('Rewarded ad failed to load: $error');
        },
      ),
    );

    return rewardEarned;
  }

  // Show rewarded ad for extra moves
  static Future<bool> showRewardedAdForExtraMoves() async {
    return await showRewardedAd();
  }

  // Show rewarded ad for hints
  static Future<bool> showRewardedAdForHints() async {
    return await showRewardedAd();
  }

  // Show rewarded ad for themes
  static Future<bool> showRewardedAdForThemes() async {
    return await showRewardedAd();
  }

  // Dispose banner ad
  static void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  // Dispose interstitial ad
  static void disposeInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  // Dispose rewarded ad
  static void disposeRewardedAd() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }

  // Dispose all ads
  static void disposeAllAds() {
    disposeBannerAd();
    disposeInterstitialAd();
    disposeRewardedAd();
  }

  // Check if ads should be shown
  static bool get shouldShowAds => PremiumService.shouldShowAds;

  // Get ad-free message
  static String getAdFreeMessage() {
    return 'Remove ads and support the developer!';
  }

  // Get rewarded ad benefits
  static Map<String, String> getRewardedAdBenefits() {
    return {
      'extra_moves': 'Watch an ad to get 3 extra undo moves',
      'hints': 'Watch an ad to get a helpful hint',
      'themes': 'Watch an ad to unlock a new ball theme',
    };
  }
}
