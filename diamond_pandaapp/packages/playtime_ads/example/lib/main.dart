import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:playtime_ads/playtime_ads.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 30,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final res = await PlaytimeAds.initSdk(
                    appKey: 'app-1234567890',
                    userId: 'user-1234567890',
                  );
                  if (res) {
                    log('SDK initialized successfully');
                  } else {
                    log('Failed to initialize SDK');
                  }
                },
                child: Text('Init Sdk'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final res = await PlaytimeAds.launchOfferwall();
                  if (res) {
                    log('Offerwall launched successfully');
                  } else {
                    log('Failed to launch Offerwall');
                  }
                },
                child: Text('Open Offerwall'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final res = await PlaytimeAds.destroySdk();
                  if (res) {
                    log('SDK destroyed successfully');
                  } else {
                    log('Failed to destroy sdk');
                  }
                },
                child: Text('Destroy SDK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
