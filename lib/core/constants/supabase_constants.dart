/// Supabase Table Names, Storage Buckets, and Edge Function Names
class SupabaseConstants {
  SupabaseConstants._();

  // ─── Configuration ────────────────────────────────────────────
  // Ensure the URL matches the exact project ID provided by the user
  static const String supabaseUrl = 'https://otzyosfooxaauhzpovam.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_p2QlQnT-JLOSWopoEFpWIA_n_C0Y3_F';
  static const String authCallbackUrl = 'io.supabase.worksphere://login-callback';

  // ─── Table Names ──────────────────────────────────────────────
  static const String profilesTable = 'profiles';
  static const String freelancerProfilesTable = 'freelancer_profiles';
  static const String clientProfilesTable = 'client_profiles';
  static const String skillsTable = 'skills';
  static const String freelancerSkillsTable = 'freelancer_skills';
  static const String portfolioItemsTable = 'portfolio_items';
  static const String experienceTable = 'experience';
  static const String educationTable = 'education';
  static const String certificatesTable = 'certificates';
  static const String verificationRequestsTable = 'verification_requests';
  static const String categoriesTable = 'categories';
  static const String jobsTable = 'jobs';
  static const String jobApplicationsTable = 'job_applications';
  static const String savedJobsTable = 'saved_jobs';
  static const String projectsTable = 'projects';
  static const String milestonesTable = 'milestones';
  static const String tasksTable = 'tasks';
  static const String deliverablesTable = 'deliverables';
  static const String conversationsTable = 'conversations';
  static const String conversationParticipantsTable = 'conversation_participants';
  static const String messagesTable = 'messages';
  static const String paymentsTable = 'payments';
  static const String walletsTable = 'wallets';
  static const String transactionsTable = 'transactions';
  static const String withdrawalRequestsTable = 'withdrawal_requests';
  static const String reviewsTable = 'reviews';
  static const String notificationsTable = 'notifications';
  static const String gigsTable = 'gigs';
  static const String adminLogsTable = 'admin_logs';
  static const String supportTicketsTable = 'support_tickets';
  static const String reportsTable = 'reports';

  // ─── Storage Buckets ──────────────────────────────────────────
  static const String avatarsBucket = 'avatars';
  static const String coversBucket = 'covers';
  static const String portfolioBucket = 'portfolios';
  static const String documentsBucket = 'documents';
  static const String verificationDocumentsBucket = 'verification-documents';
  static const String chatMediaBucket = 'chat-media';
  static const String resumesBucket = 'resumes';
  static const String gigImagesBucket = 'gig-images';
  static const String projectFilesBucket = 'project-files';

  // ─── Realtime Channels ────────────────────────────────────────
  static const String messagesChannel = 'messages_channel';
  static const String notificationsChannel = 'notifications_channel';
  static const String typingChannel = 'typing_channel';

  // ─── Edge Functions ───────────────────────────────────────────
  static const String sendNotificationFn = 'send-notification';
  static const String processPaymentFn = 'process-payment';
  static const String generateInvoiceFn = 'generate-invoice';
}
