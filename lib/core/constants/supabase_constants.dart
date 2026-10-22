/// Core Supabase Constants for Gym ElDeeb
///
/// Contains the project URL, publishable anonymous key, Edge Function endpoints,
/// and exact public table identifiers according to the existing database schema.
class SupabaseConstants {
  SupabaseConstants._();

  /// Supabase Project URL
  static const String supabaseUrl = 'https://rpwcjfayhdwbsnecomnk.supabase.co';

  /// Supabase Publishable Key (Safe for client-side Flutter distribution)
  /// NEVER use service_role or privileged secret keys in client code!
  static const String supabaseAnonKey =
      'sb_publishable_rtuOsvmeYSvl827xFVYp4A_Z0gmqmGy';

  /// Secure join-gym Edge Function for owner invitation and joining flow
  static const String joinGymFunctionUrl =
      'https://rpwcjfayhdwbsnecomnk.supabase.co/functions/v1/join-gym';

  // --- Database Table Names (Existing Public Schema) ---
  static const String tableGyms = 'gyms';
  static const String tableProfiles = 'profiles';
  static const String tableMembers = 'members';
  static const String tableMembershipPlans = 'membership_plans';
  static const String tableMemberships = 'memberships';
  static const String tablePayments = 'payments';
  static const String bucketMemberPhotos = 'member-photos';
  static const String tableSyncMetadata = 'sync_metadata';
  static const String tableGymInvites = 'gym_invites';
}
