import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pulse_widgets.dart';

/// Lets a tester point the app at a different backend without a new build —
/// a laptop on the office Wi-Fi, a staging host, or production.
class ServerSettingsSheet extends StatefulWidget {
  const ServerSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const ServerSettingsSheet(),
      );

  @override
  State<ServerSettingsSheet> createState() => _ServerSettingsSheetState();
}

class _ServerSettingsSheetState extends State<ServerSettingsSheet> {
  late final TextEditingController _controller;
  bool _checking = false;
  bool? _reachable;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<ApiClient>().baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final api = context.read<ApiClient>();
    final entered = _controller.text.trim();
    final previous = api.baseUrl;

    setState(() {
      _checking = true;
      _reachable = null;
    });

    await api.setBaseUrl(entered.isEmpty ? null : entered);
    final ok = await api.ping();

    if (!mounted) return;
    setState(() {
      _checking = false;
      _reachable = ok;
    });

    if (ok) {
      showPulseSnack(context, 'Connected to ${api.baseUrl}');
      Navigator.of(context).pop();
    } else {
      // Don't strand the tester on an address that does not answer.
      await api.setBaseUrl(previous);
      if (mounted) {
        setState(() => _controller.text = api.baseUrl);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Server', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Where this app looks for Pulse data. Change it to test against a '
            'different backend.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'https://your-api.onrender.com',
              prefixIcon: const Icon(Icons.dns_outlined, size: 20),
              suffixIcon: _reachable == null
                  ? null
                  : Icon(
                      _reachable! ? Icons.check_circle : Icons.error_outline,
                      color: _reachable! ? AppColors.success : AppColors.danger,
                    ),
            ),
          ),
          if (_reachable == false) ...[
            const SizedBox(height: 10),
            Text(
              'No response from that address. Check the server is running and '
              'that this phone can reach it.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _checking ? null : _testAndSave,
            child: _checking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text('Test & save'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _checking
                ? null
                : () async {
                    await context.read<ApiClient>().setBaseUrl(null);
                    if (mounted) {
                      setState(() {
                        _controller.text = AppConfig.apiBaseUrl;
                        _reachable = null;
                      });
                    }
                  },
            child: const Text('Reset to the built-in address'),
          ),
        ],
      ),
    );
  }
}
