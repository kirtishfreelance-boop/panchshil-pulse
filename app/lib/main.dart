import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/session_store.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/community_provider.dart';
import 'providers/event_provider.dart';
import 'providers/notice_provider.dart';
import 'providers/site_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/wallet_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final session = await SessionStore.create();
  final api = ApiClient(session);

  runApp(PulseApp(session: session, api: api));
}

class PulseApp extends StatelessWidget {
  const PulseApp({super.key, required this.session, required this.api});

  final SessionStore session;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        Provider.value(value: session),
        ChangeNotifierProvider(create: (_) => ThemeProvider(session)),
        ChangeNotifierProvider(create: (_) => AuthProvider(api, session)),
        ChangeNotifierProvider(create: (_) => SiteProvider(api)),
        ChangeNotifierProvider(create: (_) => EventProvider(api)),
        ChangeNotifierProvider(create: (_) => NoticeProvider(api)),
        ChangeNotifierProvider(create: (_) => CommunityProvider(api)),
        ChangeNotifierProvider(create: (_) => WalletProvider(api)),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => ScreenUtilInit(
          // Matches the reference design width the original app was laid out on.
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (context, _) => MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: theme.mode,
            home: const SplashScreen(),
          ),
        ),
      ),
    );
  }
}
