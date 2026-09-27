import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../presentation/auth/screens/splash_screen.dart';
import '../../presentation/auth/screens/onboarding_screen.dart';
import '../../presentation/auth/screens/login_screen.dart';
import '../../presentation/auth/screens/register_screen.dart';
import '../../presentation/auth/screens/forgot_password_screen.dart';
import '../../presentation/auth/screens/password_security_screen.dart';
import '../../presentation/auth/screens/email_verification_screen.dart';
import '../../presentation/auth/screens/user_type_selection_screen.dart';
import '../../presentation/auth/screens/client_profile_setup_screen.dart';
import '../../presentation/auth/screens/freelancer_profile_setup_screen.dart';
import '../../presentation/home/screens/main_shell_screen.dart';
import '../../presentation/home/screens/home_screen.dart';
import '../../presentation/home/screens/jobs_screen.dart';
import '../../presentation/home/screens/messages_screen.dart';
import '../../presentation/home/screens/profile_screen.dart';
import '../../presentation/settings/screens/settings_screen.dart';
import '../../presentation/freelancer/screens/edit_profile_screen.dart';
import '../../presentation/freelancer/screens/freelancer_profile_screen.dart';
import '../../presentation/freelancer/screens/portfolio_screen.dart';
import '../../presentation/freelancer/screens/verification_screen.dart';
import '../../presentation/client/screens/post_job_screen.dart';
import '../../presentation/client/screens/my_jobs_screen.dart';
import '../../presentation/client/screens/client_applications_screen.dart';
import '../../presentation/client/screens/freelancer_discovery_screen.dart';
import '../../presentation/jobs/screens/job_detail_screen.dart';
import '../../presentation/jobs/screens/apply_job_screen.dart';
import '../../presentation/jobs/screens/applications_screen.dart';
import '../../presentation/chat/screens/chat_room_screen.dart';
import '../../presentation/payments/screens/wallet_screen.dart';
import '../../presentation/payments/screens/payment_methods_screen.dart';
import '../../presentation/payments/screens/invoices_screen.dart';
import '../../presentation/projects/screens/projects_screen.dart';
import '../../presentation/projects/screens/work_calendar_screen.dart';
import '../../presentation/search/screens/search_screen.dart';
import '../../presentation/notifications/screens/notifications_screen.dart';
import '../../presentation/support/screens/support_center_screen.dart';
import '../../presentation/common/widgets/ws_animated_page.dart';
import '../../presentation/admin/screens/admin_dashboard_screen.dart';
import '../../presentation/admin/screens/admin_verification_screen.dart';
import '../../presentation/admin/screens/admin_section_screen.dart';
import '../../presentation/admin/screens/admin_support_detail_screen.dart';
import '../../presentation/admin/widgets/admin_access_gate.dart';
import 'route_names.dart';

/// GoRouter configuration for WorkSphere
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      const publicRoutes = {
        RouteNames.splash,
        RouteNames.onboarding,
        RouteNames.login,
        RouteNames.register,
        RouteNames.forgotPassword,
        RouteNames.emailVerification,
      };
      final location = state.matchedLocation;
      final isPublicRoute = publicRoutes.contains(location);
      final signedIn = Supabase.instance.client.auth.currentSession != null;
      if (!signedIn && !isPublicRoute) return RouteNames.login;
      if (signedIn &&
          (location == RouteNames.login || location == RouteNames.register)) {
        return RouteNames.splash;
      }
      return null;
    },
    routes: [
      // ─── Auth Routes ────────────────────────────────────────────
      GoRoute(
        path: RouteNames.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        name: 'onboarding',
        builder: (context, state) =>
            const WsAnimatedPage(child: OnboardingScreen()),
      ),
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (context, state) => const WsAnimatedPage(child: LoginScreen()),
      ),
      GoRoute(
        path: RouteNames.register,
        name: 'register',
        builder: (context, state) =>
            const WsAnimatedPage(child: RegisterScreen()),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        name: 'forgot-password',
        builder: (context, state) =>
            const WsAnimatedPage(child: ForgotPasswordScreen()),
      ),
      GoRoute(
        path: RouteNames.passwordSecurity,
        name: 'password-security',
        builder: (context, state) =>
            const WsAnimatedPage(child: PasswordSecurityScreen()),
      ),
      GoRoute(
        path: RouteNames.emailVerification,
        name: 'email-verification',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is EmailVerificationArguments) {
            return WsAnimatedPage(
              child: EmailVerificationScreen(email: extra.email),
            );
          }
          final email = (extra is Map<String, dynamic>)
              ? (extra['email'] as String? ?? '')
              : (extra as String? ?? '');
          return WsAnimatedPage(child: EmailVerificationScreen(email: email));
        },
      ),
      GoRoute(
        path: RouteNames.userTypeSelection,
        name: 'user-type-selection',
        builder: (context, state) =>
            const WsAnimatedPage(child: UserTypeSelectionScreen()),
      ),
      GoRoute(
        path: RouteNames.clientProfileSetup,
        name: 'client-profile-setup',
        builder: (context, state) =>
            const WsAnimatedPage(child: ClientProfileSetupScreen()),
      ),
      GoRoute(
        path: RouteNames.freelancerProfileSetup,
        name: 'freelancer-profile-setup',
        builder: (context, state) =>
            const WsAnimatedPage(child: FreelancerProfileSetupScreen()),
      ),
      GoRoute(
        path: RouteNames.settings,
        name: 'settings',
        builder: (context, state) =>
            const WsAnimatedPage(child: SettingsScreen()),
      ),
      GoRoute(
        path: RouteNames.editProfile,
        name: 'edit-profile',
        builder: (context, state) =>
            const WsAnimatedPage(child: EditProfileScreen()),
      ),
      GoRoute(
        path: RouteNames.portfolio,
        name: 'portfolio',
        builder: (context, state) =>
            const WsAnimatedPage(child: PortfolioScreen()),
      ),
      GoRoute(
        path: RouteNames.verification,
        name: 'verification',
        builder: (context, state) =>
            const WsAnimatedPage(child: VerificationScreen()),
      ),
      GoRoute(
        path: RouteNames.postJob,
        name: 'post-job',
        builder: (context, state) =>
            const WsAnimatedPage(child: PostJobScreen()),
      ),
      GoRoute(
        path: RouteNames.notifications,
        name: 'notifications',
        builder: (context, state) =>
            const WsAnimatedPage(child: NotificationsScreen()),
      ),
      GoRoute(
        path: RouteNames.myPostedJobs,
        name: 'my-posted-jobs',
        builder: (context, state) =>
            const WsAnimatedPage(child: MyJobsScreen()),
      ),
      GoRoute(
        path: '/job/:id/applications',
        name: 'client-job-applications',
        builder: (context, state) => WsAnimatedPage(
          child: ClientApplicationsScreen(
            jobId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.freelancerDiscovery,
        name: 'freelancer-discovery',
        builder: (context, state) =>
            const WsAnimatedPage(child: FreelancerDiscoveryScreen()),
      ),
      GoRoute(
        path: RouteNames.jobDetail,
        name: 'job-detail',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return WsAnimatedPage(child: JobDetailScreen(jobId: id));
        },
      ),
      GoRoute(
        path: RouteNames.applyForJob,
        name: 'apply-for-job',
        builder: (context, state) => WsAnimatedPage(
          child: ApplyJobScreen(jobId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: RouteNames.applications,
        name: 'applications',
        builder: (context, state) =>
            const WsAnimatedPage(child: ApplicationsScreen()),
      ),
      GoRoute(
        path: RouteNames.freelancerProfile,
        name: 'freelancer-profile',
        builder: (context, state) => WsAnimatedPage(
          child: FreelancerProfileScreen(
            freelancerId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.chatRoom,
        name: 'chat-room',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return WsAnimatedPage(child: ChatRoomScreen(conversationId: id));
        },
      ),
      GoRoute(
        path: RouteNames.wallet,
        name: 'wallet',
        builder: (context, state) =>
            const WsAnimatedPage(child: WalletScreen()),
      ),
      GoRoute(
        path: RouteNames.paymentMethods,
        name: 'payment-methods',
        builder: (context, state) =>
            const WsAnimatedPage(child: PaymentMethodsScreen()),
      ),
      GoRoute(
        path: RouteNames.supportCenter,
        name: 'support-center',
        builder: (context, state) =>
            const WsAnimatedPage(child: SupportCenterScreen()),
      ),
      GoRoute(
        path: RouteNames.invoices,
        name: 'invoices',
        builder: (context, state) =>
            const WsAnimatedPage(child: InvoicesScreen()),
      ),
      GoRoute(
        path: RouteNames.invoiceDetail,
        name: 'invoice-detail',
        builder: (context, state) => WsAnimatedPage(
          child: InvoiceDetailScreen(
            invoiceId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.calendar,
        name: 'work-calendar',
        builder: (context, state) =>
            const WsAnimatedPage(child: WorkCalendarScreen()),
      ),
      GoRoute(
        path: RouteNames.projects,
        name: 'projects',
        builder: (context, state) =>
            const WsAnimatedPage(child: ProjectsScreen()),
      ),
      GoRoute(
        path: RouteNames.projectDetail,
        name: 'project-detail',
        builder: (context, state) => WsAnimatedPage(
          child: ProjectDetailScreen(
            projectId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),

      // ─── Main Shell (Bottom Navigation) ─────────────────────────
      GoRoute(
        path: RouteNames.adminDashboard,
        name: 'admin-dashboard',
        builder: (context, state) => const AdminAccessGate(
          child: WsAnimatedPage(child: AdminDashboardScreen()),
        ),
        routes: [
          GoRoute(
            path: 'users',
            name: 'admin-users',
            builder: (context, state) => const AdminAccessGate(
              child: WsAnimatedPage(
                child: AdminSectionScreen(section: 'users'),
              ),
            ),
          ),
          GoRoute(
            path: 'jobs',
            name: 'admin-jobs',
            builder: (context, state) => const AdminAccessGate(
              child: WsAnimatedPage(child: AdminSectionScreen(section: 'jobs')),
            ),
          ),
          GoRoute(
            path: 'projects',
            name: 'admin-projects',
            builder: (context, state) => const AdminAccessGate(
              child: WsAnimatedPage(
                child: AdminSectionScreen(section: 'projects'),
              ),
            ),
          ),
          GoRoute(
            path: 'transactions',
            name: 'admin-transactions',
            builder: (context, state) => const AdminAccessGate(
              child: WsAnimatedPage(
                child: AdminSectionScreen(section: 'transactions'),
              ),
            ),
          ),
          GoRoute(
            path: 'payments',
            name: 'admin-payments',
            builder: (context, state) => const AdminAccessGate(
              child: WsAnimatedPage(
                child: AdminSectionScreen(section: 'payment-methods'),
              ),
            ),
          ),
          GoRoute(
            path: 'reports',
            name: 'admin-reports',
            builder: (context, state) => const AdminAccessGate(
              child: WsAnimatedPage(
                child: AdminSectionScreen(section: 'reports'),
              ),
            ),
          ),
          GoRoute(
            path: 'support',
            name: 'admin-support',
            builder: (context, state) => const AdminAccessGate(
              child: WsAnimatedPage(
                child: AdminSectionScreen(section: 'support'),
              ),
            ),
          ),
          GoRoute(
            path: 'support/inbox',
            name: 'admin-support-inbox',
            builder: (context, state) => const AdminAccessGate(
              child: WsAnimatedPage(
                child: AdminSupportDetailScreen(section: 'inbox'),
              ),
            ),
          ),
          GoRoute(
            path: 'support/contacts',
            name: 'admin-contacts',
            builder: (context, state) => const AdminAccessGate(
              child: WsAnimatedPage(
                child: AdminSupportDetailScreen(section: 'contacts'),
              ),
            ),
          ),
          GoRoute(
            path: 'support/help-center',
            name: 'admin-help-center',
            builder: (context, state) => const AdminAccessGate(
              child: WsAnimatedPage(
                child: AdminSupportDetailScreen(section: 'help-center'),
              ),
            ),
          ),
          GoRoute(
            path: 'verification',
            name: 'admin-verification',
            builder: (context, state) => const AdminAccessGate(
              child: WsAnimatedPage(child: AdminVerificationScreen()),
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          GoRoute(
            path: RouteNames.home,
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WsAnimatedPage(child: HomeScreen()),
            ),
          ),
          // Placeholder routes for other tabs
          GoRoute(
            path: RouteNames.search,
            name: 'search',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WsAnimatedPage(child: SearchScreen()),
            ),
          ),
          GoRoute(
            path: RouteNames.jobs,
            name: 'jobs',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WsAnimatedPage(child: JobsScreen()),
            ),
          ),
          GoRoute(
            path: RouteNames.chat,
            name: 'chat',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WsAnimatedPage(child: MessagesScreen()),
            ),
          ),
          GoRoute(
            path: RouteNames.profile,
            name: 'profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WsAnimatedPage(child: ProfileScreen()),
            ),
          ),
        ],
      ),
    ],

    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
