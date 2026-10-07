import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../providers/store_provider.dart';
import '../services/ad_service.dart';

class ConsentBanner extends StatefulWidget {
  const ConsentBanner({super.key, this.adService});
  final AdService? adService;

  @override
  State<ConsentBanner> createState() => _ConsentBannerState();
}

class _ConsentBannerState extends State<ConsentBanner> {
  AdService get _ads => widget.adService ?? AdService.instance;
  BannerAd? _banner;
  bool _loading = false;
  bool _loaded = false;
  bool _attempted = false;

  void _loadIfAllowed(bool isVip) {
    if (isVip ||
        !_ads.canShowAds ||
        _attempted ||
        _loading ||
        _banner != null ||
        (kReleaseMode && !AdIds.isProductionUnit(AdIds.banner))) {
      return;
    }
    _attempted = true;
    _loading = true;
    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || !context.read<StoreProvider>().vipStatusLoaded ||
              context.read<StoreProvider>().isVip) {
            ad.dispose();
            return;
          }
          setState(() {
            _loading = false;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _banner = null;
            _loading = false;
          });
          debugPrint('Banner unavailable: $error');
        },
      ),
    );
    _banner = ad;
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StoreProvider>(builder: (context, store, _) {
      return AnimatedBuilder(
        animation: _ads,
        builder: (context, _) {
          if (!store.vipStatusLoaded || store.isVip || !_ads.canShowAds) {
            if (_banner != null) {
              final ad = _banner!;
              _banner = null;
              _loaded = false;
              _loading = false;
              _attempted = false;
              WidgetsBinding.instance.addPostFrameCallback((_) => ad.dispose());
            }
            return const SizedBox.shrink();
          }
          if (_banner == null && !_loading && !_attempted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadIfAllowed(context.read<StoreProvider>().isVip);
            });
          }
          return _loaded && _banner != null
              ? SizedBox(height: 50, width: 320, child: AdWidget(ad: _banner!))
              : const SizedBox.shrink();
        },
      );
    });
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }
}
