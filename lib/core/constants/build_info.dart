// Build metadata marker — visible across the app for unambiguous version identification
class BuildInfo {
  BuildInfo._();

  static const String version = '1.0.0';
  static const String commitHash = 'edfd2b0';
  static const String buildDate = '2026-09-24';
  static const String displayVersion = 'v$version ($commitHash)';
  static const String fullBuildTag = 'Darzi Pro v$version · Build $commitHash · 2026-09-24';
}
