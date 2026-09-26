import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      alignment: Alignment.center,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16.0,
        runSpacing: 16.0,
        children: [
          Text(
            '© ${DateTime.now().year} Dangerously Nerdy',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          Semantics(
            label: 'External Link: View AGPLv3 License details',
            link: true,
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
              onPressed: () =>
                  _launchUrl('https://www.gnu.org/licenses/agpl-3.0.html'),
              child: const Text('Licensed under AGPLv3'),
            ),
          ),
          Semantics(
            label:
                'External Link: Dangerously Nerdy 5e Toolkit GitHub Repository',
            link: true,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.code),
              label: const Text('GitHub Source'),
              onPressed: () => _launchUrl(
                  'https://github.com/kevinburkeland/dangerously_nerdy_5e_toolkit'),
            ),
          ),
        ],
      ),
    );
  }
}
