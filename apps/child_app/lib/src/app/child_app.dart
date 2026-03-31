import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:vanavil_core/vanavil_core.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

import '../../firebase_options.dart';
import '../data/child_auth_service.dart';
import '../features/auth/child_pin_login_screen.dart';
import '../features/auth/profile_selection_screen.dart';
import '../features/home/child_home_screen.dart';

void runVanavilChildApp() {
  runApp(const VanavilChildApp());
}

class VanavilChildApp extends StatefulWidget {
  const VanavilChildApp({super.key});

  @override
  State<VanavilChildApp> createState() => _VanavilChildAppState();
}

class _VanavilChildAppState extends State<VanavilChildApp> {
  late final Future<void> _firebaseInitialization;
  ChildProfile? _selectedChild;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    _firebaseInitialization = Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VANAVIL Child',
      debugShowCheckedModeBanner: false,
      theme: buildChildTheme(),
      home: FutureBuilder<void>(
        future: _firebaseInitialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ChildLoadingScreen();
          }

          if (snapshot.hasError) {
            return _FirebaseSetupErrorScreen(error: snapshot.error.toString());
          }

          if (_selectedChild == null) {
            return _ActiveChildProfilesScreen(
              onSelected: (child) => setState(() => _selectedChild = child),
            );
          }

          if (!_isSignedIn) {
            return ChildPinLoginScreen(
              child: _selectedChild!,
              onBack: () => setState(() => _selectedChild = null),
              onSignedIn: () => setState(() => _isSignedIn = true),
            );
          }

          return ChildHomeScreen(
            featuredChild: _selectedChild!,
            onSwitchProfile: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) {
                return;
              }
              setState(() {
                _selectedChild = null;
                _isSignedIn = false;
              });
            },
          );
        },
      ),
    );
  }
}

class _ActiveChildProfilesScreen extends StatefulWidget {
  const _ActiveChildProfilesScreen({required this.onSelected});

  final ValueChanged<ChildProfile> onSelected;

  @override
  State<_ActiveChildProfilesScreen> createState() =>
      _ActiveChildProfilesScreenState();
}

class _ActiveChildProfilesScreenState
    extends State<_ActiveChildProfilesScreen> {
  late Future<List<ChildProfile>> _childrenFuture;

  @override
  void initState() {
    super.initState();
    _childrenFuture = ChildAuthService().loadActiveChildren();
  }

  void _retryLoad() {
    setState(() {
      _childrenFuture = ChildAuthService().loadActiveChildren();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChildProfile>>(
      future: _childrenFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ChildProfileLoadErrorScreen(
            error: snapshot.error.toString(),
            onRetry: _retryLoad,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _ChildLoadingScreen();
        }

        final children = snapshot.data ?? const <ChildProfile>[];

        return ProfileSelectionScreen(
          children: children,
          onSelected: widget.onSelected,
        );
      },
    );
  }
}

class _ChildLoadingScreen extends StatelessWidget {
  const _ChildLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _FirebaseSetupErrorScreen extends StatelessWidget {
  const _FirebaseSetupErrorScreen({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: VanavilSectionCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Child app setup is incomplete',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This app now expects real Firebase Auth and Firestore so it can use the Python PIN auth API and load active child profiles.',
                    ),
                    const SizedBox(height: 16),
                    for (final step in VanavilSetupGuide.childSteps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $step'),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      error,
                      style: const TextStyle(color: VanavilPalette.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildProfileLoadErrorScreen extends StatelessWidget {
  const _ChildProfileLoadErrorScreen({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: VanavilSectionCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unable to load child profiles',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The child picker now loads from the Python auth API before Firebase child sign-in starts.',
                    ),
                    const SizedBox(height: 16),
                    for (final step in VanavilSetupGuide.childSteps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $step'),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error,
                      style: const TextStyle(color: VanavilPalette.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
