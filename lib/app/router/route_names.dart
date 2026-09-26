/// Named route paths for the application
class RouteNames {
  RouteNames._();

  // ─── Auth ─────────────────────────────────────────────────────
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String passwordSecurity = '/password-security';
  static const String emailVerification = '/email-verification';
  static const String userTypeSelection = '/user-type-selection';
  static const String clientProfileSetup = '/client-profile-setup';
  static const String freelancerProfileSetup = '/freelancer-profile-setup';

  // ─── Main Tabs ────────────────────────────────────────────────
  static const String home = '/home';
  static const String search = '/search';
  static const String jobs = '/jobs';
  static const String chat = '/chat';
  static const String profile = '/profile';

  // ─── Freelancer ───────────────────────────────────────────────
  static const String freelancerProfile = '/freelancer/:id';
  static const String editProfile = '/profile/edit';
  static const String portfolio = '/portfolio';
  static const String addPortfolio = '/portfolio/add';
  static const String createGig = '/gig/create';
  static const String myGigs = '/my-gigs';
  static const String verification = '/verification';
  static const String earnings = '/earnings';
  static const String applications = '/applications';
  static const String applyForJob = '/job/:id/apply';

  // ─── Client ───────────────────────────────────────────────────
  static const String postJob = '/job/post';
  static const String myPostedJobs = '/my-jobs';
  static const String freelancerDiscovery = '/freelancers';
  static const String jobDetail = '/job/:id';
  static const String hireFreelancer = '/hire/:id';

  // ─── Projects ─────────────────────────────────────────────────
  static const String projectDetail = '/project/:id';
  static const String milestones = '/project/:id/milestones';

  // ─── Chat ─────────────────────────────────────────────────────
  static const String chatRoom = '/chat/:id';

  // ─── Payments ─────────────────────────────────────────────────
  static const String wallet = '/wallet';
  static const String paymentMethods = '/payment-methods';
  static const String transactionHistory = '/transactions';
  static const String withdraw = '/withdraw';
  static const String invoiceDetail = '/invoice/:id';

  // ─── Settings ─────────────────────────────────────────────────
  static const String settings = '/settings';
  static const String notifications = '/notifications';

  // ─── Admin ────────────────────────────────────────────────────
  static const String adminDashboard = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminVerification = '/admin/verification';
  static const String adminJobs = '/admin/jobs';
  static const String adminProjects = '/admin/projects';
  static const String adminPayments = '/admin/payments';
  static const String adminTransactions = '/admin/transactions';
  static const String adminReports = '/admin/reports';
  static const String adminSupport = '/admin/support';
  static const String adminSupportInbox = '/admin/support/inbox';
  static const String adminContacts = '/admin/support/contacts';
  static const String adminHelpCenter = '/admin/support/help-center';
}
