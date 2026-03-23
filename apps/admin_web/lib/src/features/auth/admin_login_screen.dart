import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vanavil_core/vanavil_core.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, required this.bootstrap});

  final VanavilFirebaseBootstrap bootstrap;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _message;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final draft = AdminLoginDraft(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!_formKey.currentState!.validate() || !draft.isValid) {
      setState(() => _message = 'Enter a valid email and password.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: draft.email,
        password: draft.password,
      );
    } on FirebaseAuthException catch (error) {
      setState(() {
        _message = error.message ?? error.code;
      });
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    }

    if (!mounted) return;

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  const Text(
                    'VANAVIL',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: VanavilPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Manage children, tasks, reviews, badges, and announcements from one admin workspace.',
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.6,
                      color: VanavilPalette.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: VanavilPalette.creamSoft,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.bootstrap.statusLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: VanavilPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final step in VanavilSetupGuide.adminSteps)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('• $step'),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: VanavilSectionCard(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin sign in',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Use your admin email and password to open the admin workspace. The owner account is promoted to super admin automatically after sign-in.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || !value.contains('@')
                                ? 'Enter a valid email'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.length < 6
                                ? 'Password must be at least 6 characters'
                                : null,
                          ),
                          if (_message != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _message!,
                              style: const TextStyle(
                                color: VanavilPalette.inkSoft,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isSubmitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: VanavilPalette.sky,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                              ),
                              child: Text(
                                _isSubmitting ? 'Checking...' : 'Sign in',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
