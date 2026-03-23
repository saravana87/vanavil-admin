import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

import '../../firebase_options.dart';
import '../features/auth/admin_login_screen.dart';
import '../features/auth/admin_onboarding_screen.dart';
import '../features/dashboard/admin_dashboard_screen.dart';

Future<void> runVanavilAdminApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const VanavilAdminApp());
}

class VanavilAdminApp extends StatelessWidget {
  const VanavilAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VANAVIL Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      home: const _AdminAuthGate(),
    );
  }
}

class _AdminAuthGate extends StatelessWidget {
  const _AdminAuthGate();

  @override
  Widget build(BuildContext context) {
    const bootstrap = VanavilFirebaseBootstrap(isConfigured: true);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const AdminLoginScreen(bootstrap: bootstrap);
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(FirestoreCollections.admins)
              .doc(user.uid)
              .snapshots(),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: VanavilSectionCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unable to load admin access',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            adminSnapshot.error.toString(),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton(
                            onPressed: () => FirebaseAuth.instance.signOut(),
                            child: const Text('Sign out'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            if (adminSnapshot.connectionState == ConnectionState.waiting &&
                !adminSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (adminSnapshot.hasData && adminSnapshot.data!.exists) {
              return const AdminDashboardScreen(bootstrap: bootstrap);
            }

            return AdminOnboardingScreen(bootstrap: bootstrap, user: user);
          },
        );
      },
    );
  }
}
