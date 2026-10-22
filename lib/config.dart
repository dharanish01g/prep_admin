/// The prep-admin Supabase project. The publishable key is safe to ship in
/// the app; row level security in the database decides what each user sees.
const supabaseUrl = 'https://loqzmoshhhwnknkjzcfo.supabase.co';
const supabasePublishableKey = 'sb_publishable_s4bDjOI9gc_NayZLHaQlqQ_vm76WVn5';

/// Public legal pages, served by GitHub Pages from `docs/`.
const privacyPolicyUrl =
    'https://dharanish01g.github.io/prepwisely-team/privacy.html';
const deleteAccountUrl =
    'https://dharanish01g.github.io/prepwisely-team/delete-account.html';

/// Crash and error reports go to the tiny-tasks Sentry project. Like the
/// Supabase key, a DSN only lets the app send events, so it's fine to ship.
const sentryDsn =
    'https://35aafbb19f2152526a8e2183b3b80bfe@o4512011940200448.ingest.de.sentry.io/4512292080386128';
