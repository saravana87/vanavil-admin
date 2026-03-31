import 'package:flutter/material.dart';
import 'package:vanavil_core/vanavil_core.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

import '../../data/child_auth_service.dart';

class ChildPinLoginScreen extends StatefulWidget {
  const ChildPinLoginScreen({
    super.key,
    required this.child,
    required this.onBack,
    required this.onSignedIn,
  });

  final ChildProfile child;
  final VoidCallback onBack;
  final VoidCallback onSignedIn;

  @override
  State<ChildPinLoginScreen> createState() => _ChildPinLoginScreenState();
}

class _ChildPinLoginScreenState extends State<ChildPinLoginScreen> {
  final _childAuthService = ChildAuthService();
  final _pinController = TextEditingController();
  String? _message;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final draft = ChildPinDraft(
      child: widget.child,
      pin: _pinController.text.trim(),
    );

    if (!draft.isValid) {
      setState(() => _message = 'PIN must be exactly 4 digits.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      await _childAuthService.signInWithPin(
        childId: widget.child.id,
        pin: draft.pin,
      );

      if (!mounted) {
        return;
      }

      widget.onSignedIn();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = _formatErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatErrorMessage(Object error) {
    final rawMessage = error.toString().replaceFirst('Exception: ', '').trim();
    if (rawMessage.contains('VANAVIL_API_BASE_URL')) {
      return 'Start the Python API and pass VANAVIL_API_BASE_URL when running the child app.';
    }
    if (rawMessage.contains('API key not valid') ||
        rawMessage.contains('CONFIGURATION_NOT_FOUND') ||
        rawMessage.contains('Firebase')) {
      return 'Firebase is not configured for this child app yet. Run flutterfire configure first.';
    }
    return rawMessage.isEmpty ? 'Could not sign in with that PIN.' : rawMessage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [VanavilPalette.creamSoft, VanavilPalette.sand],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: VanavilSectionCard(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: VanavilPalette.berry.withValues(
                              alpha: 0.16,
                            ),
                            foregroundColor: VanavilPalette.ink,
                            child: Text(
                              widget.child.avatar,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.child.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your 4-digit PIN',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              letterSpacing: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              hintText: '••••',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_message != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _message!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: VanavilPalette.inkSoft,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
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
                                _isSubmitting ? 'Checking...' : 'Continue',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
