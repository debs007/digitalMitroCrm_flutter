/// Central place for the backend base URL and every endpoint path used
/// by the app.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api.digitalmitro.info';

  // ── Mobile (built specifically for Flutter) ──────────────────────────────
  static const String mobileLogin = '/mobile/login';
  static const String mobileProfile = '/mobile/profile';
  static const String mobileDashboard = '/mobile/dashboard';
  static const String mobileChannels = '/mobile/channels';
  static const String mobileDms = '/mobile/dms';
  static const String mobileFcmToken = '/mobile/fcm-token';
  static const String mobileSocketInfo = '/mobile/socket-info';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String authAll = '/auth/all';

  // ── Attendance ────────────────────────────────────────────────────────────
  static const String punchIn = '/attendance/punch-in';
  static const String punchOut = '/attendance/punch-out';
  static const String attendanceUser = '/attendance/user';
  static const String attendanceToday = '/attendance/today';
  static String attendanceListForAdmin(String userId) => '/attendance/list/$userId';
  static String employeeDashboard(String userId) => '/attendance/employeesdashboard/$userId';

  // ── Tasks (channel tasks) ────────────────────────────────────────────────
  static const String allTasks = '/channels/tasks/all';
  static const String pendingTasksCount = '/channels/tasks/count';
  static String channelTasks(String channelId) => '/channels/$channelId/tasks';
  static String updateTask(String channelId, String taskId) =>
      '/channels/$channelId/tasks/$taskId';

  // ── Channels & channel chat ──────────────────────────────────────────────
  static const String channelsAll = '/api/all';
  static String channelDetail(String channelId) => '/api/$channelId';
  static String channelMessages(String channelId) => '/channels/$channelId';
  static const String sendChannelMessage = '/channels/send';
  static String markChannelRead(String channelId) => '/channels/$channelId/read';
  static String editChannelMessage(String messageId) => '/channels/messages/$messageId';
  static String deleteChannelMessage(String messageId) => '/channels/messages/$messageId';
  static String pinChannelMessage(String messageId) => '/channels/messages/$messageId/pin';
  static String pinnedChannelMessages(String channelId) => '/channels/$channelId/pinned';
  static String mentionCandidates(String channelId) => '/channels/$channelId/mentions';

  // ── Direct messages ───────────────────────────────────────────────────────
  static String dmMessages(String senderId, String receiverId) =>
      '/message/messages/$senderId/$receiverId';
  static const String sendMessage = '/message/send-message';
  static const String recentChats = '/message/recentChats';
  static const String markDmRead = '/message/messages/mark-as-read';
  static String editDmMessage(String messageId) => '/message/messages/$messageId';
  static String deleteDmMessage(String messageId) => '/message/messages/$messageId';
  static String pinDmMessage(String messageId) => '/message/messages/$messageId/pin';
  static const String pinnedDmMessages = '/message/pinned';

  // ── File upload (chat attachments) ────────────────────────────────────────
  static const String fileUpload = '/files/upload';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String getNotifications = '/notification/get-notifications';
  static const String clearNotifications = '/notification/clear-notifications';

  // ── Notes ──────────────────────────────────────────────────────────────────
  // Real mount point is /notepad (not /notes — this was a bug).
  static const String notes = '/notepad';
  static String notesForEmployee(String employeeId) => '/notepad/$employeeId';

  // ── Leads: Callback / Sale / Transfer (identical shape, different mount) ──
  static String leadCreate(String typePath) => '/$typePath';
  static String leadMine(String typePath) => '/$typePath/user';
  static String leadAll(String typePath) => '/$typePath/all';
  static String leadForEmployee(String typePath, String employeeId) => '/$typePath/user/$employeeId';
  static String leadDelete(String typePath, String id) => '/$typePath/$id';
  static String leadUpdate(String typePath, String id) => '/$typePath/$id';

  // ── Concerns ───────────────────────────────────────────────────────────────
  static const String submitConcern = '/concern/submit';
  static const String myConcerns = '/concern/user';
  static const String allConcerns = '/concern/all';
  static String approveConcern(String userId, String concernId) =>
      '/concern/approve/$userId/$concernId';
  static String rejectConcern(String userId, String concernId) =>
      '/concern/reject/$userId/$concernId';

  // ── Profile / avatar ───────────────────────────────────────────────────────
  static const String profileMe = '/profile/me';
  static const String profileAvatar = '/profile/avatar';
  static const String profileAvatarsBatch = '/profile/avatars';
  static const String adminProfile = '/auth/admin/profile';
  static String updateEmployeeProfile(String userId) => '/auth/$userId';

  // ── Payslip / Salary ───────────────────────────────────────────────────────
  static const String myPayslips = '/payslips/me';
  static String downloadPayslip(String id) => '/payslips/download/$id';
  static const String payslipsBase = '/payslips';
  static String employeePayslips(String employeeId) => '/payslips/employee/$employeeId';
  static String payslipDelete(String id) => '/payslips/$id';
  static const String salarySheet = '/salary-sheet';
  static const String salarySheetUpload = '/salary-sheet/upload';
  static String salarySheetDelete(String id) => '/salary-sheet/$id';

  // ── Employee directory (Admin "Activity") ─────────────────────────────────
  static const String allEmployees = '/auth/';
  static const String createEmployee = '/auth/admin/create-user';
  static String employeeById(String id) => '/auth/$id';

  // ── SuperAdmin — manage admins ────────────────────────────────────────────
  static const String saAdmins = '/superadmin/admins';
  static String saAdminPermissions(String id) => '/superadmin/admins/$id/permissions';
  static String saAdminScope(String id) => '/superadmin/admins/$id/scope';
  static String saAdminDelete(String id) => '/superadmin/admins/$id';
  static const String saAllEmployeesPicker = '/superadmin/all-employees';
  static const String saAllChannelsPicker = '/superadmin/all-channels';
}