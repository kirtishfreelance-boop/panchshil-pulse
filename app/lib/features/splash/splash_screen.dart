import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../shell/home_shell.dart';

/// Plays the branded splash clip while the session is restored, then routes to
/// either the shell or the login screen. Falls back to the static wordmark if
/// the video cannot be initialised.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _navigated = false;
  bool _waking = false;

  static const _minimumSplash = Duration(milliseconds: 2200);

  @override
  void initState() {
    super.initState();
    _startVideo();
    _boot();
  }

  Future<void> _startVideo() async {
    final controller = VideoPlayerController.asset('assets/splash_screen.mp4');
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _videoReady = true;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _videoReady = false);
    }
  }

  /// Free hosting idles the API between sessions. Pinging /health first means
  /// the cold start happens behind the splash instead of stalling the first
  /// screen the user actually looks at.
  Future<void> _warmUpApi() async {
    if (!AppConfig.isRemoteApi) return;
    setState(() => _waking = true);
    try {
      await context.read<ApiClient>().get('/health');
    } catch (_) {
      // Not fatal — the screens surface their own connection errors.
    }
    if (mounted) setState(() => _waking = false);
  }

  Future<void> _boot() async {
    final auth = context.read<AuthProvider>();
    await _warmUpApi();
    // Hold the splash for the full clip even when the session restores instantly.
    await Future.wait([
      auth.bootstrap(),
      Future<void>.delayed(_minimumSplash),
    ]);
    if (!mounted || _navigated) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) =>
            auth.isSignedIn ? const HomeShell() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          SizedBox.expand(
            child: _videoReady && _controller != null
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : const _StaticSplash(),
          ),
          if (_waking)
            Positioned(
              left: 0,
              right: 0,
              bottom: 56,
              child: Column(
                children: [
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Waking the server…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StaticSplash extends StatelessWidget {
  const _StaticSplash();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.primary,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/pulse_logo_dark.png', width: 200),
            const SizedBox(height: 32),
            const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ),
      );
}
