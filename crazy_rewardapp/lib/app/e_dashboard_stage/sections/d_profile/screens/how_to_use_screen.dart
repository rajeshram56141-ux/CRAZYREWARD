// ignore_for_file: depend_on_referenced_packages
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../services/launch_url.dart';
import '../../../../../utils/constant/constant.dart';
import '../../../../b_splash_stage/splash_service.dart';

@RoutePage()
class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, dynamic>> defaultTutorials = {
      'dailyTask': {
        'title': 'Daily Task',
        'desc': 'Complete tasks daily to earn high coin amounts. Follow instructions carefully!',
        'icon': Icons.task_alt_rounded,
        'steps': [
          'Navigate to the Daily Task section.',
          'Select an active task from the list.',
          'Follow the instructions for the task.',
          'Submit verification details to claim rewards.'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'dailyChallenge': {
        'title': 'Daily Challenge',
        'desc': 'Complete specific daily challenges to earn bonus coins and level up.',
        'icon': Icons.stars_rounded,
        'steps': [
          'Open the Daily Challenge section from the Home screen.',
          'Check today’s available challenge goal.',
          'Complete the required activities before midnight.',
          'Claim your extra bonus rewards upon completion.'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'battleArena': {
        'title': 'Battle Arena',
        'desc': 'Compete in head-to-head battle games and win winner-takes-all coin rewards.',
        'icon': Icons.sports_mma_rounded,
        'steps': [
          'Enter the Battle Arena section.',
          'Join an active battle match or matchmaking queue.',
          'Outscore your opponent in the battle game.',
          'Winner collects the grand coin prize pool!'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'hotOffer': {
        'title': 'Hot Offer',
        'desc': 'Complete high paying offers to get massive rewards and bonuses.',
        'icon': Icons.local_fire_department_rounded,
        'steps': [
          'Open the Hot Offers section on the homepage.',
          'Ensure you have the required gems balance.',
          'Complete the necessary steps (e.g. watch ads or install).',
          'Tap "Claim Coins" to claim your big bonus instantly.'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'giveaway': {
        'title': 'Giveaway',
        'desc': 'Participate in giveaways to win big prize pools and entry tickets.',
        'icon': Icons.card_giftcard_rounded,
        'steps': [
          'Open the Giveaway section.',
          'Select a live giveaway tournament or raffle.',
          'Click "Join Giveaway" to register your entry.',
          'Wait for the draw timer to complete and check winners.'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'offerwall': {
        'title': 'Offerwall',
        'desc': 'Download apps, play games, and complete quizzes to earn coins from our partners.',
        'icon': Icons.view_carousel_rounded,
        'steps': [
          'Open the Offerwalls page.',
          'Choose any active Offerwall partner (e.g. AdGate, PubScale).',
          'Select a task (e.g., download an app or complete a quiz).',
          'Complete the task exactly as specified to receive rewards.'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'survey': {
        'title': 'Survey',
        'desc': 'Share your opinions in quick surveys and earn high coin payouts.',
        'icon': Icons.poll_rounded,
        'steps': [
          'Go to the Surveys tab.',
          'Choose an available survey router (e.g. CPX Research).',
          'Answer the profile questions truthfully.',
          'Complete the survey to earn high coin payouts.'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'playGames': {
        'title': 'Play Games',
        'desc': 'Play fun casual games and score high to win coins and gems per minute.',
        'icon': Icons.sports_esports_rounded,
        'steps': [
          'Choose your favorite game from the "Play Games" section.',
          'Play games and score points to generate gems.',
          'Maintain gameplay to accumulate coins dynamically.',
          'Redeem top rewards with your earned gems and coins.'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'readEarn': {
        'title': 'Read Articles',
        'desc': 'Read articles, stay engaged for a short duration, and claim instant rewards.',
        'icon': Icons.menu_book_rounded,
        'steps': [
          'Tap on the "Read Now" button to open an article.',
          'Read or browse the page for the specified time limit.',
          'Copy the article URL from your browser address bar.',
          'Paste the copied URL in the verification box to claim coins.'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'watchEarn': {
        'title': 'Watch Video',
        'desc': 'Watch short promotional videos and advertisements to get steady coins instantly.',
        'icon': Icons.play_circle_fill_rounded,
        'steps': [
          'Open the "Watch Video" section.',
          'Click on a video category or task.',
          'Watch the complete video advertisement without skipping.',
          'Your coins will be credited immediately after the video finishes.'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'playWin': {
        'title': 'Play & Win',
        'desc': 'Enter lucky number contests and win huge coin pools daily.',
        'icon': Icons.videogame_asset_rounded,
        'steps': [
          'Enter the Play & Win lucky number contest.',
          'Select your lucky numbers and place a ticket.',
          'Submit your ticket and wait for the lottery draw.',
          'If your number matches, you win the massive coin pool!'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'promoCode': {
        'title': 'Promo Code',
        'desc': 'Redeem codes from our social handles to get free bonus coins.',
        'icon': Icons.confirmation_number_rounded,
        'steps': [
          'Follow our social channels to find active promo codes.',
          'Open the Promo Code section in the app.',
          'Type or paste the valid code into the field.',
          'Tap "Redeem" to claim your free reward coins.'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'referral': {
        'title': 'Invite & Earn',
        'desc': 'Invite friends and get high commissions on all their task earnings.',
        'icon': Icons.people_alt_rounded,
        'steps': [
          'Go to the Invite tab to copy your unique referral link.',
          'Share your link and code with friends and family.',
          'Make sure your friend enters your code during signup.',
          'Get high coin commissions whenever they complete tasks.'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'leaderboard': {
        'title': 'Leaderboard',
        'desc': 'Compete with top players to rank high and get daily extra bonuses.',
        'icon': Icons.leaderboard_rounded,
        'steps': [
          'Earn coins and refer friends daily to collect points.',
          'Check the Leaderboard tab to see your current rank.',
          'Compete with top users to rank in the top positions.',
          'Daily/weekly winners receive extra bonus coins!'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
      'aToZ': {
        'title': 'How To Use Crazyreward?',
        'desc': 'Complete guide of the app to understand features and maximize your earnings.',
        'icon': Icons.help_center_rounded,
        'steps': [
          'Browse our complete guide to understand the app ecosystem.',
          'Learn tips and tricks on how to maximize daily coin earnings.',
          'Understand the terms, rules, and redeem policies.',
          'Reach out to Support Tickets if you need help with anything.'
        ],
        'tutorialUrl': 'https://www.youtube.com/watch?v=demo',
      },
    };

    final List<String> orderedKeys = [
      'aToZ',
      'dailyTask',
      'dailyChallenge',
      'battleArena',
      'hotOffer',
      'giveaway',
      'offerwall',
      'survey',
      'playGames',
      'readEarn',
      'watchEarn',
      'playWin',
      'promoCode',
      'referral',
      'leaderboard',
    ];

    final List<Map<String, dynamic>> tutorials = [];

    for (final key in orderedKeys) {
      final defaultData = defaultTutorials[key]!;
      final dynamicData = SplashService.howToUseConfig[key];

      bool enabled = true;
      String title = defaultData['title'] as String;
      String desc = defaultData['desc'] as String;
      String tutorialUrl = defaultData['tutorialUrl'] as String;
      List<String> steps = List<String>.from(defaultData['steps'] as List<dynamic>);

      if (dynamicData is Map<String, dynamic>) {
        if (dynamicData.containsKey('enabled')) {
          enabled = dynamicData['enabled'] == true;
        }
        if (dynamicData['title'] != null && (dynamicData['title'] as String).trim().isNotEmpty) {
          title = (dynamicData['title'] as String).trim();
        }
        if (dynamicData['tutorialUrl'] != null && (dynamicData['tutorialUrl'] as String).trim().isNotEmpty) {
          tutorialUrl = (dynamicData['tutorialUrl'] as String).trim();
        }
        if (dynamicData['steps'] != null) {
          final rawSteps = dynamicData['steps'];
          if (rawSteps is List) {
            final parsedSteps = rawSteps.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            if (parsedSteps.isNotEmpty) {
              steps = parsedSteps;
            }
          } else if (rawSteps is String && rawSteps.trim().isNotEmpty) {
            steps = rawSteps.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          }
        }
      }

      if (enabled) {
        tutorials.add({
          'key': key,
          'title': title,
          'desc': desc,
          'icon': defaultData['icon'],
          'steps': steps,
          'tutorialUrl': tutorialUrl,
        });
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Executive Top Navigation Bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        AutoRouter.of(context).maybePop();
                      },
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15.r),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: const Color(0xFF26262B),
                          size: 20.sp,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'How To Use',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF26262B),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 40.w), // Balance back button
                  ],
                ),
              ),

              // Main Scrollable Tutorial Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16.w,
                    4.h,
                    16.w,
                    MediaQuery.of(context).padding.bottom + 24.h,
                  ),
                  child: Column(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: tutorials.length,
                        separatorBuilder: (_, __) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final t = tutorials[index];
                          return _TutorialCard(tutorial: t);
                        },
                      ),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// TUTORIAL EXPANSION CARD ITEM (DARK OBSIDIAN & CLEAN WHITE)
// -------------------------------------------------------------
class _TutorialCard extends StatelessWidget {
  const _TutorialCard({required this.tutorial});

  final Map<String, dynamic> tutorial;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          leading: Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              tutorial['icon'] as IconData,
              color: const Color(0xFF26262B),
              size: 22.sp,
            ),
          ),
          title: Text(
            tutorial['title'] as String,
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
              fontWeight: FontWeight.w700,
              fontSize: 15.sp,
            ),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: Text(
              tutorial['desc'] as String,
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          iconColor: const Color(0xFF26262B),
          collapsedIconColor: const Color(0xFF94A3B8),
          childrenPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(
                  color: const Color(0xFFF1F5F9),
                  height: 16.h,
                ),
                Text(
                  'Step-by-Step Guide:',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF26262B),
                    fontWeight: FontWeight.w700,
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                ...(tutorial['steps'] as List<String>).map((step) {
                  final idx = (tutorial['steps'] as List<String>).indexOf(step) + 1;
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20.w,
                          height: 20.w,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$idx',
                            style: GoogleFonts.poppins(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF26262B),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            step,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5.sp,
                              color: const Color(0xFF26262B),
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: 14.h),

                // Dark Obsidian Gradient "Watch Video Tutorial" Button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final url = (tutorial['tutorialUrl'] as String).isNotEmpty
                        ? tutorial['tutorialUrl'] as String
                        : (AppConst.youtubeLink.isNotEmpty
                            ? AppConst.youtubeLink
                            : 'https://www.youtube.com');
                    LaunchUrl.inWeb(url: url, context: context);
                  },
                  child: Container(
                    height: 44.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF26262B), Color(0xFF18181B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF18181B).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Watch Video Tutorial',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
