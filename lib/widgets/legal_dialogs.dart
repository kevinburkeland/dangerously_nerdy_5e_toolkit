import 'package:flutter/material.dart';

class LegalDialogs {
  static void showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: Colors.cyanAccent, size: 22),
            SizedBox(width: 8),
            Text('Privacy Policy', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Privacy Policy',
                  style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'DangerouslyNerdy 5e Toolkit operates on a strict data minimization principle. '
                  'We do not collect personal identifying information (PII), require account registration, or use tracking cookies.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  'Data Storage & Ephemeral Rooms',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '• Local Storage: Custom presets are stored locally on your device in browser cache.\n'
                  '• Live Rooms: Shared room payloads (room code, optional display name, roll totals) are stream-only and ephemeral.\n'
                  '• Security: Data in transit is encrypted using TLS 1.3 via Firebase Cloud Infrastructure.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  'Contact: kevin@burke.land',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  static void showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gavel, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text('Terms of Service', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Terms of Service & EULA',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  '1. Permitted Use: Granted personal, non-commercial license for TTRPG sessions.\n'
                  '2. AS-IS Disclaimer: Provided "AS-IS" without warranties of uninterrupted service or stream sync latency protection.\n'
                  '3. Limitation of Liability: Developers are not liable for loss of local preset data or game session disruption.\n'
                  '4. DMCA & Contact: Contact kevin@burke.land for intellectual property notices.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  static void showAttribution(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.menu_book, color: Colors.purpleAccent, size: 22),
            SizedBox(width: 8),
            Text('Legal & SRD 5.1 Attribution', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Compatibility & Legal Disclaimer',
                  style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 6),
                Text(
                  'DangerouslyNerdy 5e Toolkit is an independent software companion compatible with the 5th Edition (5e) tabletop roleplaying game rules. '
                  'This application is not affiliated with, endorsed, sponsored, or specifically approved by Wizards of the Coast LLC.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
                SizedBox(height: 14),
                Text(
                  'System Reference Document 5.1 (SRD 5.1) License',
                  style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 6),
                Text(
                  'This work includes material taken from the System Reference Document 5.1 (“SRD 5.1”) by Wizards of the Coast LLC and available at https://dnd.wizards.com/resources/systems-reference-document. '
                  'The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License (CC-BY-4.0) available at https://creativecommons.org/licenses/by/4.0/legalcode.\n\n'
                  'Attribution Notice:\n'
                  'System Reference Document 5.1 Copyright 2016, Wizards of the Coast LLC, a subsidiary of Hasbro, Inc.; Authors Mike Mearls, Jeremy Crawford, Chris Perkins, Rodney Thompson, Peter Lee, James Wyatt, Robert J. Schwalb, Bruce R. Cordell, Chris Sims, and Steve Townshend, based on original material by E. Gary Gygax and Dave Arneson.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.purpleAccent)),
          ),
        ],
      ),
    );
  }
}
