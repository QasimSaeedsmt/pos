class AppConstants {
  static const String appName = 'POS System';
  static const String currencyName = '\$';
  static const String tenantName = 'Your Business';

  // Cache durations
  static const int dashboardCacheHours = 1;
  static const int defaultCacheHours = 24;

  // Pagination
  static const int defaultPageSize = 50;
  static const int recentItemsLimit = 5;

  // Sync
  static const int maxSyncAttempts = 3;
  static const int syncDebounceMs = 500;

  // UI
  static const double defaultBorderRadius = 8.0;
  static const double defaultPadding = 16.0;
  static const double cardElevation = 2.0;
}