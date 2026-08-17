import 'package:flutter/material.dart';

class LegalDialogs {
  static void _show(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor = isDark ? iconColor : theme.colorScheme.primary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: effectiveColor, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(child: content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: effectiveColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showPrivacyPolicy(BuildContext context) => _show(
        context,
        icon: Icons.privacy_tip_outlined,
        iconColor: Colors.cyanAccent,
        title: 'Privacy Policy',
        content: const _PrivacyPolicyContent(),
      );

  static void showTermsOfService(BuildContext context) => _show(
        context,
        icon: Icons.gavel,
        iconColor: Colors.amber,
        title: 'Terms of Service',
        content: const _TermsOfServiceContent(),
      );

  static void showAttribution(BuildContext context) => _show(
        context,
        icon: Icons.menu_book,
        iconColor: Colors.purpleAccent,
        title: 'Legal & SRD 5.1 / 5.2 Attribution',
        content: const _AttributionContent(),
      );
}

class _PrivacyPolicyContent extends StatelessWidget {
  const _PrivacyPolicyContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headingColor = isDark ? Colors.cyanAccent : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Privacy Policy',
          style: TextStyle(color: headingColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'DangerouslyNerdy 5e Toolkit operates on a strict data minimization principle. '
          'We do not collect personal identifying information (PII), require account registration, or use tracking cookies.',
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        Text(
          'Data Storage & Ephemeral Rooms',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          '• Local Storage: Custom presets are stored locally on your device in browser cache.\n'
          '• Live Rooms: Shared room payloads (room code, optional display name, roll totals) are stream-only and ephemeral.\n'
          '• Security: Data in transit is encrypted using TLS 1.3 via Firebase Cloud Infrastructure.',
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        Text(
          'Contact: kevin@burke.land',
          style: TextStyle(color: headingColor, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _TermsOfServiceContent extends StatelessWidget {
  const _TermsOfServiceContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headingColor = isDark ? Colors.amber : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Terms of Service & EULA',
          style: TextStyle(color: headingColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          '1. Permitted Use: Granted personal, non-commercial license for TTRPG sessions.\n'
          '2. AS-IS Disclaimer: Provided "AS-IS" without warranties of uninterrupted service or stream sync latency protection.\n'
          '3. Limitation of Liability: Developers are not liable for loss of local preset data or game session disruption.\n'
          '4. DMCA & Contact: Contact kevin@burke.land for intellectual property notices.',
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}

class _AttributionContent extends StatelessWidget {
  const _AttributionContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final purpleHeader = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;
    final cyanHeader = isDark ? Colors.cyanAccent : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Compatibility & Legal Disclaimer',
          style: TextStyle(color: purpleHeader, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          'DangerouslyNerdy 5e Toolkit is an independent software companion compatible with the 5th Edition (5e) tabletop roleplaying game rules. '
          'This application is not affiliated with, endorsed, sponsored, or specifically approved by Wizards of the Coast LLC.',
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.85), fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        Text(
          'System Reference Document 5.1 & 5.2 (SRD 5.1 & SRD 5.2) License',
          style: TextStyle(color: cyanHeader, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          'This work includes material taken from the System Reference Document 5.1 ("SRD 5.1") and System Reference Document 5.2 ("SRD 5.2") by Wizards of the Coast LLC and available at https://dnd.wizards.com/resources/systems-reference-document.\n\n'
          'The SRD 5.1 and SRD 5.2 are licensed under the Creative Commons Attribution 4.0 International License (CC-BY-4.0) available at https://creativecommons.org/licenses/by/4.0/legalcode.\n\n'
          'Attribution Notices:\n'
          '• SRD 5.1: System Reference Document 5.1 Copyright 2016, Wizards of the Coast LLC, a subsidiary of Hasbro, Inc.; Authors Mike Mearls, Jeremy Crawford, Chris Perkins, Rodney Thompson, Peter Lee, James Wyatt, Robert J. Schwalb, Bruce R. Cordell, Chris Sims, and Steve Townshend, based on original material by E. Gary Gygax and Dave Arneson.\n\n'
          '• SRD 5.2: System Reference Document 5.2 Copyright 2024, Wizards of the Coast LLC, a subsidiary of Hasbro, Inc.',
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.85), fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}
