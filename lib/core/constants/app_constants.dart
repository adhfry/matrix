class AppConstants {
  // API Configuration
  static const String baseUrl = 'https://api.silakes.labkesdasumenep.id';
  static const String apiPrefix = '/api/app/v1/matrix';
  
  // Auth Endpoints  
  static const String loginEndpoint = '$apiPrefix/mobile/login';
  static const String logoutEndpoint = '$apiPrefix/mobile/logout';
  static const String userEndpoint = '$apiPrefix/user';
  
  // Activation Endpoints
  static const String activationRequestEndpoint = '$apiPrefix/mobile/activation/request';
  static const String activationVerifyEndpoint = '$apiPrefix/mobile/activation/verify';
  static const String activationStatusEndpoint = '$apiPrefix/mobile/activation/status';
  
  // Attendance Endpoints
  static const String attendanceConfigEndpoint = '$apiPrefix/attendance/config';
  static const String attendanceCheckInEndpoint = '$apiPrefix/attendance/check-in';
  static const String attendanceCheckOutEndpoint = '$apiPrefix/attendance/check-out';
  static const String attendanceHistoryEndpoint = '$apiPrefix/attendance/history';
  static const String attendanceTodayEndpoint = '$apiPrefix/attendance/today';
  static const String attendanceDashboardEndpoint = '$apiPrefix/attendance/dashboard';
  static const String attendanceLocationsEndpoint = '$apiPrefix/mobile/attendance/locations';
  
  // Schedule Endpoints
  static const String scheduleEndpoint = '$apiPrefix/schedule';
  static const String scheduleTodayEndpoint = '$apiPrefix/schedule/today';
  
  // Leave Endpoints
  static const String leaveRequestEndpoint = '$apiPrefix/leave/request';
  static const String leaveHistoryEndpoint = '$apiPrefix/leave/history';
  
  // Performance Endpoints
  static const String performancePointsEndpoint = '$apiPrefix/performance/points';
  static const String performancePenaltiesEndpoint = '$apiPrefix/performance/penalties';
  
  // Salary Endpoints
  static const String salaryEndpoint = '$apiPrefix/salary';
  static const String salaryDownloadEndpoint = '$apiPrefix/salary/download';
  static const String salaryDisbursementEndpoint = '$apiPrefix/salary/request-disbursement';
  
  // Notification Endpoints
  static const String notificationsEndpoint = '$apiPrefix/notifications';
  static const String notificationReadEndpoint = '$apiPrefix/notifications/{id}/read';
  
  // Profile Endpoints
  static const String profileEndpoint = '$apiPrefix/profile';
  static const String profileUpdateEndpoint = '$apiPrefix/profile/update';
  static const String changePasswordEndpoint = '$apiPrefix/profile/change-password';
  
  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String isActivatedKey = 'is_activated';
  static const String biometricEnabledKey = 'biometric_enabled';
  static const String rememberMeKey = 'remember_me';
  static const String lastEmailKey = 'last_email';
  static const String lastUsernameKey = 'last_username';
  
  // Hive Box Names
  static const String attendanceBoxName = 'attendance_cache';
  static const String scheduleBoxName = 'schedule_cache';
  static const String userBoxName = 'user_cache';
  
  // App Configuration
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000;
  static const int activationCodeLength = 6;
  static const int activationCodeExpiry = 300; // 5 minutes in seconds
  static const double defaultRadius = 12.0;
  
  // Location Configuration
  static const double defaultLatitude = -7.0;
  static const double defaultLongitude = 113.0;
  static const double locationAccuracyThreshold = 50.0; // meters
  
  // Face Detection Configuration
  static const double eyeOpenProbabilityThreshold = 0.8;
  static const double eyeClosedProbabilityThreshold = 0.1;
  static const int blinkDetectionTimeoutMs = 3000;
  
  // Image Configuration
  static const int maxImageSizeKB = 500;
  static const int imageQuality = 85;
  static const int imageMaxWidth = 1024;
  static const int imageMaxHeight = 1024;
  
  // Pagination
  static const int defaultPageSize = 20;
  
  // Timer Configuration
  static const int timerUpdateIntervalSeconds = 1;
  
  // App Info
  static const String appName = 'MATRIX Mobile';
  static const String appFullName = 'SiLAKES MATRIX';
  static const String appDescription = 'Manajemen Absensi Terintegrasi dan Remunerasi Insentif eXpert';
  static const String appVersion = '1.0.0';
  
  // Validation Regex
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  
  static final RegExp usernameRegex = RegExp(
    r'^[a-zA-Z0-9_]{3,20}$',
  );
  
  static final RegExp phoneRegex = RegExp(
    r'^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$',
  );
}
