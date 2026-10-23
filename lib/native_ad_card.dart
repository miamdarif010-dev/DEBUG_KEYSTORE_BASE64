import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// =========================================================
// AD CONFIG
// =========================================================

class AdConfig {
  // Release build করার আগে false করে দাও এবং নিচে নিজের Ad Unit ID বসাও।
  static const bool useTestAds = true;

  static String get nativeAdUnitId {
    if (useTestAds) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/2247696110'
          : 'ca-app-pub-3940256099942544/3986624511';
    }

    return 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  }
}

// =========================================================
// NATIVE AD STRIP (full width, slim)
// =========================================================

class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _nativeAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();

    _nativeAd = NativeAd(
      adUnitId: AdConfig.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }

          setState(() {
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();

          if (!mounted) return;

          setState(() {
            _nativeAd = null;
            _loaded = false;
          });
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: Colors.white,
        cornerRadius: 10,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.redAccent,
          style: NativeTemplateFontStyle.bold,
          size: 13,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black87,
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black54,
          size: 12,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ad না এলে কোনো খালি জায়গা থাকবে না।
    if (!_loaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    // Small template: উচ্চতা ~91–200dp, প্রস্থ পুরো স্ক্রিন।
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      height: 112,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}

// =========================================================
// PRODUCT GRID + ADS
// প্রথম [firstAdAfter] টি প্রোডাক্টের পর প্রথম বিজ্ঞাপন,
// তারপর প্রতি [adEvery] টি প্রোডাক্টের পর একটি করে।
// প্রোডাক্টগুলো আগের মতোই ২ কলামের গ্রিডে থাকে,
// বিজ্ঞাপন দুই গ্রিড অংশের মাঝে পুরো প্রস্থে বসে।
// =========================================================

List<Widget> buildProductSlivers({
  required int count,
  required Widget Function(int index) itemBuilder,
  int firstAdAfter = 6,
  int adEvery = 8,
}) {
  final slivers = <Widget>[];

  int start = 0;
  int adNumber = 0;

  while (start < count) {
    final chunk = start == 0 ? firstAdAfter : adEvery;
    final end = (start + chunk) > count ? count : (start + chunk);
    final chunkStart = start;

    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => itemBuilder(chunkStart + i),
            childCount: end - chunkStart,
          ),
        ),
      ),
    );

    // শেষ প্রোডাক্টের পরে বিজ্ঞাপন নয়।
    if (end < count) {
      slivers.add(
        SliverToBoxAdapter(
          child: NativeAdCard(key: ValueKey('native_ad_$adNumber')),
        ),
      );

      adNumber++;
    }

    start = end;
  }

  return slivers;
}
