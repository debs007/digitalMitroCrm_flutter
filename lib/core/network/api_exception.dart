/// Uniform exception thrown by [ApiClient] so every screen can catch
/// one type and show `error.message` directly to the user.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
