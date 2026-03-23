import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

class AdminOnboardingScreen extends StatefulWidget {
  const AdminOnboardingScreen({
    super.key,
    required this.bootstrap,
    required this.user,
  });

  final VanavilFirebaseBootstrap bootstrap;
  final User user;

  @override
  State<AdminOnboardingScreen> createState() => _AdminOnboardingScreenState();
}

class _AdminOnboardingScreenState extends State<AdminOnboardingScreen> {
  bool _isSaving = false;
  String? _message;

  Future<void> _createAdminDocument() async {
    setState(() {
      _isSaving = true;
      _message = null;
    });

    final email = widget.user.email ?? '';
    final inferredName = email.contains('@')
        ? email.split('@').first.replaceAll('.', ' ')
        : 'Admin User';

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.admins)
          .doc(widget.user.uid)
          .set({
            'email': email,
            'name': inferredName,
            'role': 'admin',
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (error) {
      setState(() {
        _message = error.toString();
        _isSaving = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _message = 'Admin profile created. Reloading access...';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: VanavilSectionCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finish admin setup',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This account is signed in, but there is no matching admin profile document yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Text('Signed in as: ${widget.user.email ?? widget.user.uid}'),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: VanavilPalette.creamSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.bootstrap.statusLabel),
                        const SizedBox(height: 10),
                        const Text(
                          'This step creates admins/{uid} in Firestore so the app recognizes this user as an admin.',
                        ),
                      ],
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(_message!),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving ? null : _createAdminDocument,
                          child: Text(
                            _isSaving ? 'Creating...' : 'Create admin profile',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => FirebaseAuth.instance.signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
