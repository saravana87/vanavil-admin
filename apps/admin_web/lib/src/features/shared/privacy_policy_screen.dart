import 'package:flutter/material.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const routeName = '/privacy-policy';

  static const _sections = <_PrivacySection>[
    _PrivacySection(
      heading: 'What VANAVIL collects',
      body:
          'VANAVIL stores the information needed to run the child task and rewards experience. This can include admin account details, child profile details managed by a parent or administrator, assigned tasks, task submissions, announcements, badges, and reward activity.',
    ),
    _PrivacySection(
      heading: 'How information is used',
      body:
          'The information is used to let administrators manage children, assign and review tasks, track progress, publish announcements, and operate the family or program workflow inside VANAVIL. We use uploaded proofs and review data only to support those product features.',
    ),
    _PrivacySection(
      heading: 'Storage and service providers',
      body:
          'VANAVIL uses Firebase services for authentication and application data, and secure object storage for task attachments and proof uploads. Access is limited to authorized administrators and the child accounts associated with them.',
    ),
    _PrivacySection(
      heading: 'Who can access data',
      body:
          'Admins can access the data that belongs to their workspace. Super admins may have broader administrative access for support and platform operations. Child users only see the assignments, rewards, announcements, and profile information available to them.',
    ),
    _PrivacySection(
      heading: 'Data retention',
      body:
          'Information is kept for as long as it is needed to operate VANAVIL, maintain records, resolve support issues, and meet legal or operational requirements. Administrators can remove some records from the admin workspace, subject to platform rules and audit needs.',
    ),
    _PrivacySection(
      heading: 'Contact',
      body:
          'For privacy-related questions about VANAVIL, contact the VANAVIL administrator or support contact managing your deployment before sharing any sensitive information through public channels.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VanavilPalette.creamSoft,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
              child: const Text('Admin sign in'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VanavilSectionCard(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VANAVIL Privacy Policy',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Last updated: March 24, 2026',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'This page explains how VANAVIL handles information for the admin web app and the connected child experience. It is a public page and can be viewed without signing in.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                for (final section in _sections) ...[
                  VanavilSectionCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.heading,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          section.body,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacySection {
  const _PrivacySection({required this.heading, required this.body});

  final String heading;
  final String body;
}
