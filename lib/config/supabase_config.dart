class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://knydzoglbsvwiqnzheak.supabase.co',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'sb_publishable_PnkcKieBw6L4Md9s_59OVQ_f5MJ07S-',
  );
}
