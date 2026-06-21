import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';

/// The backend stores notes as a single array of strings per user
/// (upserted wholesale on every save) — not individual note documents.
/// GET /notes returns 404 if the user has never saved any notes yet.
class NotesService {
  NotesService._();
  static final NotesService instance = NotesService._();

  final ApiClient _api = ApiClient.instance;

  Future<List<String>> getNotes() async {
    try {
      final res = await _api.get(ApiConstants.notes);
      final list = res['notes'];
      if (list is List) return List<String>.from(list);
      return [];
    } on ApiException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }
  }

  /// Replaces the entire notes list — mirrors the backend's upsert behaviour.
  Future<void> saveNotes(List<String> notes) async {
    await _api.post(ApiConstants.notes, data: {'notes': notes});
  }
}
