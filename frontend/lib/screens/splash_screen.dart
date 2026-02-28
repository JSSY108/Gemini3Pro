import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../main.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  // 1. ADD: Accept the flag from main.dart
  final bool launchedFromShare;
  const SplashScreen({super.key, this.launchedFromShare = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<double> _sloganFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1440),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.2, curve: Curves.easeIn)),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.4, 0.6, curve: Curves.easeIn)),
    );

    _sloganFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.8, 1.0, curve: Curves.easeIn)),
    );

    _startSequence();
  }

  void _startSequence() async {
    // 1. START the animation immediately! No waiting.
    _controller.forward();

    // 2. Start the share check in the background (Don't use 'await' here yet)
    // We want the result, but we don't want to block the screen.
    Future<List<SharedMediaFile>> shareCheck =
        ReceiveSharingIntent.instance.getInitialMedia();

    // 3. Wait for your logo animation to reach the end (1.44s)
    // Plus that 0.4 second pause for reading.
    await Future.delayed(const Duration(milliseconds: 1840));

    // 4. NOW we check if that background task found anything.
    // If it's still somehow stuck, we timeout after 100ms so the user isn't trapped.
    List<SharedMediaFile> initialMedia = [];
    try {
      initialMedia =
          await shareCheck.timeout(const Duration(milliseconds: 100));
    } catch (_) {
      // If it fails or times out, we just assume no share.
    }

    if (!mounted) return;

    // 5. DECIDE: Where do we go?
    if (initialMedia.isNotEmpty) {
      // Shared content found! Jump to Dashboard.
      Navigator.of(context).pushReplacement(
        createSlideRoute(const DashboardScreen()),
      );
    } else {
      // No share found. Proceed to the Landing/Intro as usual.
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 720),
          pageBuilder: (context, animation, secondaryAnimation) {
            return FadeTransition(
              opacity: animation,
              child: const LandingWrapper(),
            );
          },
        ),
      );
    }
  }

  // ... (dispose and build methods stay exactly the same) ...
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'veriscan_logo',
              child: FadeTransition(
                opacity: _logoFade,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFD4AF37), width: 2.0),
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFFD4AF37).withValues(alpha: 0.3),
                            blurRadius: 30)
                      ]),
                  child: const Center(
                    child:
                        Icon(Icons.shield, color: Color(0xFFD4AF37), size: 60),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Hero(
              tag: 'veriscan_title',
              child: Material(
                type: MaterialType.transparency,
                child: FadeTransition(
                  opacity: _titleFade,
                  child: Text(
                    "VERISCAN: FORENSIC TRUTH ENGINE",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Hero(
              tag: 'veriscan_slogan',
              child: Material(
                type: MaterialType.transparency,
                child: FadeTransition(
                  opacity: _sloganFade,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "VERIFY",
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD4AF37)),
                        ),
                        TextSpan(
                          text: ", before you trust anything.",
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w300,
                              color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
