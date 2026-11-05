import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Online backup + class-code sharing through Firebase.
///
/// Firebase settings are injected at build time (see .github/workflows/build.yml)
/// from `google-services.json`. If that file was not added to the repo, every
/// method here quietly does nothing and the app keeps working offline.
class FirebaseCloudSyncService {
  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const String _bucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String _webClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static bool isReady = false;

  static bool get isConfigured =>
      _apiKey.isNotEmpty && _appId.isNotEmpty && _projectId.isNotEmpty;

  /// Google sign-in object; passes the web client id when Firebase is configured
  /// so Google returns an ID token that Firebase can verify.
  static GoogleSignIn newGoogleSignIn() => GoogleSignIn(
        scopes: ['email'],
        serverClientId: _webClientId.isEmpty ? null : _webClientId,
      );

  static Future<void> init() async {
    if (!isConfigured) return;
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
          storageBucket: _bucket.isEmpty ? null : _bucket,
        ),
      );
      isReady = true;
    } catch (_) {
      isReady = false;
    }
  }

  /// Links the Google account the student picked to Firebase, so their data is
  /// stored under their own private user id.
  static Future<bool> signInWithGoogleAccount(GoogleSignInAccount account) async {
    if (!isReady) return false;
    try {
      final auth = await account.authentication;
      if (auth.idToken == null && auth.accessToken == null) return false;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String? get _uid =>
      isReady ? FirebaseAuth.instance.currentUser?.uid : null;

  /// Back up subjects, attendance and college info to users/{uid}.
  static Future<bool> backupStudentAttendance({
    required String email,
    required String userName,
    required String course,
    required String year,
    required String college,
    required List<Map<String, dynamic>> subjects,
    required List<String> holidays,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'userName': userName,
        'course': course,
        'year': year,
        'college': college,
        'subjects': subjects,
        'holidays': holidays,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restore the signed-in student's backup (null if none / offline).
  static Future<Map<String, dynamic>?> restoreStudentAttendance() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (_) {
      return null;
    }
  }

  /// A CR publishes a class code (e.g. "CSE-75") that friends can import.
  static Future<bool> publishClassRoomCode({
    required String roomCode,
    required String course,
    required String year,
    required String state,
    required String college,
    required List<String> subjectNames,
    required List<String> holidays,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await FirebaseFirestore.instance
          .collection('shared_classes')
          .doc(roomCode.trim().toUpperCase())
          .set({
        'ownerUid': uid,
        'course': course,
        'year': year,
        'state': state,
        'college': college,
        'subjects': subjectNames,
        'holidays': holidays,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Import subjects and holidays using a CR / friend class code.
  static Future<Map<String, dynamic>?> fetchClassRoomCode(String roomCode) async {
    if (_uid == null) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shared_classes')
          .doc(roomCode.trim().toUpperCase())
          .get();
      return doc.exists ? doc.data() : null;
    } catch (_) {
      return null;
    }
  }
}
