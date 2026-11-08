import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'splash.dart';
import 'holidays.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:qr/qr.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ui_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init: $e');
  }
  runApp(const AttendTrackApp());
}

class AttendTrackApp extends StatelessWidget {
  const AttendTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AttendTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppEntry(),
    );
  }
}

class AttendanceAppLogo extends StatelessWidget {
  final double size;
  const AttendanceAppLogo({super.key, this.size = 76});

  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: LogoPainter(1, 1)));
}

class SubjectModel {
  String name;
  int attendedHours;
  int totalHours;
  String scheduleSlot;
  List<String> days;

  SubjectModel({
    required this.name,
    this.attendedHours = 0,
    this.totalHours = 0,
    this.scheduleSlot = '09:30 AM - 10:30 AM',
    List<String>? days,
  }) : days = days ?? ['Mon', 'Wed', 'Fri'];

  double get percentage =>
      totalHours == 0 ? 100.0 : (attendedHours / totalHours) * 100.0;

  int get safeBunks {
    if (totalHours == 0 || percentage < 75.0) return 0;
    return (attendedHours / 0.75 - totalHours).floor();
  }

  int get classesNeededFor75 {
    if (totalHours == 0 || percentage >= 75.0) return 0;
    final needed = (3 * totalHours) - (4 * attendedHours);
    return needed > 0 ? needed : 1;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'attendedHours': attendedHours,
        'totalHours': totalHours,
        'scheduleSlot': scheduleSlot,
        'days': days,
      };

  factory SubjectModel.fromJson(Map<String, dynamic> json) => SubjectModel(
        name: json['name'] ?? '',
        attendedHours: json['attendedHours'] ?? 0,
        totalHours: json['totalHours'] ?? 0,
        scheduleSlot: json['scheduleSlot'] ?? '09:30 AM - 10:30 AM',
        days: json['days'] != null
            ? List<String>.from(json['days'])
            : ['Mon', 'Wed', 'Fri'],
      );
}

class AttendanceLogItem {
  final String id;
  final String subject;
  final bool present;
  final int hours;
  final String dateKey;
  final String timeStr;

  AttendanceLogItem({
    required this.id,
    required this.subject,
    required this.present,
    required this.hours,
    required this.dateKey,
    required this.timeStr,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'present': present,
        'hours': hours,
        'dateKey': dateKey,
        'timeStr': timeStr,
      };

  factory AttendanceLogItem.fromJson(Map<String, dynamic> json) =>
      AttendanceLogItem(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        subject: json['subject'] ?? '',
        present: json['present'] ?? true,
        hours: json['hours'] ?? 1,
        dateKey: json['dateKey'] ??
            DateFormat('yyyy-MM-dd').format(DateTime.now()),
        timeStr: json['timeStr'] ?? '',
      );
}

class CloudBackupService {
  static User? get user {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Google sign-in. Same Google account = same uid after reinstall.
  static String lastError = '';

  static Future<User?> signInWithGoogle() async {
    lastError = '';
    try {
      final g = await GoogleSignIn().signIn();
      if (g == null) {
        lastError = 'Sign-in cancelled.';
        return null;
      }
      final a = await g.authentication;
      final cred = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(
            accessToken: a.accessToken, idToken: a.idToken),
      );
      return cred.user;
    } catch (e) {
      lastError = e.toString();
      debugPrint('Google sign-in error: $e');
      return null;
    }
  }

  static Future<bool> syncUserToFirestore({
    required String email,
    required String userName,
    required String course,
    required String year,
    required String timetableFileName,
    required List<SubjectModel> subjects,
    required List<String> holidays,
    required List<AttendanceLogItem> historyLogs,
  }) async {
    final u = user;
    if (u == null) return false;
    try {
      await FirebaseFirestore.instance
          .collection('student_backups')
          .doc(u.uid)
          .set({
        'email': (u.email ?? email).trim().toLowerCase(),
        'userName': userName,
        'course': course,
        'year': year,
        'state': (await SharedPreferences.getInstance()).getString('state') ?? '',
        'timetableFileName': timetableFileName,
        'subjects': subjects.map((s) => s.toJson()).toList(),
        'holidays': holidays,
        'historyLogs': historyLogs.map((l) => l.toJson()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Firestore backup error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> restoreUserFromFirestore() async {
    final u = user;
    if (u == null) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('student_backups')
          .doc(u.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
    } catch (e) {
      debugPrint('Firestore restore error: $e');
    }
    return null;
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: kMed,
      child: _splashDone
          ? const RootFlowController(key: ValueKey('root'))
          : SplashScreen(
              key: const ValueKey('splash'),
              onDone: () {
                if (mounted) setState(() => _splashDone = true);
              }),
    );
  }
}

class RootFlowController extends StatefulWidget {
  const RootFlowController({super.key});

  @override
  State<RootFlowController> createState() => _RootFlowControllerState();
}

class _RootFlowControllerState extends State<RootFlowController> {
  bool _loading = true;
  bool _isOnboarded = false;
  int _initialDashboardTab = 0;

  @override
  void initState() {
    super.initState();
    _checkState();
  }

  Future<void> _checkState() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('is_onboarded') ?? false;
    setState(() {
      _isOnboarded = onboarded;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isOnboarded) {
      return InitialStudentSetupScreen(
        onCompletedOpenProfile: () {
          setState(() {
            _isOnboarded = true;
            _initialDashboardTab = 4;
          });
        },
      );
    }
    return MainDashboardScreen(
      initialTab: _initialDashboardTab,
      onEditProfileRequested: () {
        setState(() => _isOnboarded = false);
      },
    );
  }
}

class InitialStudentSetupScreen extends StatefulWidget {
  final VoidCallback onCompletedOpenProfile;
  const InitialStudentSetupScreen({
    super.key,
    required this.onCompletedOpenProfile,
  });

  @override
  State<InitialStudentSetupScreen> createState() =>
      _InitialStudentSetupScreenState();
}

class _InitialStudentSetupScreenState extends State<InitialStudentSetupScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _courseCtrl = TextEditingController();
  String _selectedState = '';
  String _selectedCourse = 'B.Tech';
  String _selectedYear = '2nd Year';
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _prefillExisting();
  }

  Future<void> _prefillExisting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text = prefs.getString('user_name') ?? '';
      _emailCtrl.text = prefs.getString('user_email') ?? '';
      final c = prefs.getString('course') ?? 'B.Tech';
      if (c == 'B.Tech' || c == 'Degree') {
        _selectedCourse = c;
      } else {
        _selectedCourse = 'Other';
        _courseCtrl.text = c == 'Other' ? '' : c;
      }
      _selectedYear = prefs.getString('year') ?? '2nd Year';
      _selectedState = prefs.getString('state') ?? '';
    });
  }

  List<String> get _yearsForCourse {
    if (_selectedCourse == 'B.Tech') {
      return ['1st Year', '2nd Year', '3rd Year', '4th Year'];
    } else if (_selectedCourse == 'Degree') {
      return ['1st Year', '2nd Year', '3rd Year'];
    }
    return ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year'];
  }

  Future<void> _handleRestoreFromCloud() async {
    setState(() => _isRestoring = true);
    final account = await CloudBackupService.signInWithGoogle();
    if (account == null) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in failed: ${CloudBackupService.lastError}'),
          duration: const Duration(seconds: 8),
        ),
      );
      return;
    }
    final email = account.email ?? '';
    _emailCtrl.text = email;
    final data = await CloudBackupService.restoreUserFromFirestore();
    if (!mounted) return;
    setState(() => _isRestoring = false);

    if (data == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No cloud backup found for this Google account yet.'),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', data['userName'] ?? 'Student');
    await prefs.setString('user_email', email);
    await prefs.setString('course', data['course'] ?? 'B.Tech');
    await prefs.setString('year', data['year'] ?? '2nd Year');
    await prefs.setString('state', data['state'] ?? '');
    await prefs.setString(
        'timetable_file', data['timetableFileName'] ?? 'Restored from Cloud');
    if (data['subjects'] != null) {
      await prefs.setString('subjects', jsonEncode(data['subjects']));
    }
    if (data['historyLogs'] != null) {
      await prefs.setString('history_logs_v2', jsonEncode(data['historyLogs']));
    }
    await prefs.setBool('is_onboarded', true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Cloud Backup Restored Successfully!')),
    );
    widget.onCompletedOpenProfile();
  }

  Future<void> _saveAndGoToProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Name')),
      );
      return;
    }
    final email = _emailCtrl.text.trim().isEmpty
        ? '${name.toLowerCase().replaceAll(' ', '')}@gmail.com'
        : _emailCtrl.text.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    await prefs.setString(
        'course',
        _selectedCourse == 'Other' && _courseCtrl.text.trim().isNotEmpty
            ? _courseCtrl.text.trim()
            : _selectedCourse);
    await prefs.setString('year', _selectedYear);
    await prefs.setString('state', _selectedState);

    if ((prefs.getString('subjects') ?? '').isEmpty) {
      final defaultSubs = <SubjectModel>[
      ];
      await prefs.setString(
        'subjects',
        jsonEncode(defaultSubs.map((s) => s.toJson()).toList()),
      );
    }

    await prefs.setBool('is_onboarded', true);
    widget.onCompletedOpenProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BoldPage(
        header: Column(
          children: [
            const AttendanceAppLogo(size: 72),
            const SizedBox(height: 12),
            const Text(
              'AttendTrack',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Set up your profile to start tracking.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        children: [
          FadeSlideIn(
            child: _fieldLabel('Full name'),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 1,
            child: TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Madhav',
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(index: 2, child: _fieldLabel('Course')),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 3,
            child: Row(
              children: ['B.Tech', 'Degree', 'Other'].map((c) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AppPill(
                      label: c,
                      selected: _selectedCourse == c,
                      onTap: () {
                        setState(() {
                          _selectedCourse = c;
                          _selectedYear = _yearsForCourse.first;
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          AnimatedSize(
            duration: kMed,
            curve: Curves.easeOutCubic,
            child: _selectedCourse == 'Other'
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      controller: _courseCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Type your course, e.g. MBA, Diploma',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(index: 4, child: _fieldLabel('Year')),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 5,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _yearsForCourse.map((y) {
                final cur = _yearsForCourse.contains(_selectedYear)
                    ? _selectedYear
                    : _yearsForCourse.first;
                return SizedBox(
                  width: 104,
                  child: AppPill(
                    label: y,
                    selected: cur == y,
                    onTap: () => setState(() => _selectedYear = y),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(index: 5, child: _fieldLabel('State (for holidays)')),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 5,
            child: PressScale(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final v = await pickState(context, _selectedState);
                  if (v != null) setState(() => _selectedState = v);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.location_on_outlined),
                      suffixIcon: Icon(Icons.keyboard_arrow_down_rounded)),
                  child: Text(
                    _selectedState.isEmpty ? 'Select your state' : _selectedState,
                    style: TextStyle(
                        fontSize: 16,
                        color: _selectedState.isEmpty
                            ? AppColors.muted
                            : AppColors.ink),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(index: 6, child: _fieldLabel('Gmail (used for cloud backup)')),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 7,
            child: TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'yourname@gmail.com',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeSlideIn(
            index: 8,
            child: SizedBox(
              width: double.infinity,
              child: PressScale(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52)),
                  onPressed: _saveAndGoToProfile,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continue'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            index: 8,
            child: SoftCard(
              color: AppColors.tint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.restore_rounded, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'Reinstalled the app?',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in with the Google account you used before to restore your subjects and attendance.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: PressScale(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                        ),
                        onPressed:
                            _isRestoring ? null : _handleRestoreFromCloud,
                        icon: _isRestoring
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(_isRestoring
                            ? 'Restoring...'
                            : 'Sign in with Google and restore'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String t) => Text(
        t,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
      );
}

class MainDashboardScreen extends StatefulWidget {
  final int initialTab;
  final VoidCallback onEditProfileRequested;

  const MainDashboardScreen({
    super.key,
    required this.initialTab,
    required this.onEditProfileRequested,
  });

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentTab = 0;
  String _userName = 'Student';
  String _userEmail = 'student@gmail.com';
  String _course = 'B.Tech';
  String _year = '2nd Year';
  String _stateName = '';
  String _timetableFile = 'No PDF uploaded yet';
  String _lastBackup = 'Just now';
  bool _isReadingTimetable = false;

  static const List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat'
  ];
  static const Map<String, String> _fullDayNames = {
    'Mon': 'Monday',
    'Tue': 'Tuesday',
    'Wed': 'Wednesday',
    'Thu': 'Thursday',
    'Fri': 'Friday',
    'Sat': 'Saturday',
  };
  String _selectedDayMode = 'All';
  int? _flashIdx;
  bool _flashPresent = true;
  Timer? _flashTimer;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  List<SubjectModel> _subjects = [];
  Set<String> _holidays = {};
  Map<String, String> _holidayNames = {};
  Set<String> _hiddenHols = {}; // 'yyyy-MM-dd|name' of state holidays removed
  List<AttendanceLogItem> _historyLogs = [];
  DateTime _selectedCalendarDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _selectedDayMode = _resolveDayShort(0);
    _loadAllData();
  }

  String _resolveDayShort(int offsetDays) {
    final dt = DateTime.now().add(Duration(days: offsetDays));
    switch (dt.weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
      case DateTime.sunday:
      default:
        return 'Sat';
    }
  }

  String get _activeWeekdayShort {
    if (_weekDays.contains(_selectedDayMode)) return _selectedDayMode;
    return 'All';
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final subRaw = prefs.getString('subjects') ?? '[]';
    final List<dynamic> decodedSubs = jsonDecode(subRaw);
    final logsRaw = prefs.getString('history_logs_v2') ?? '[]';
    final List<dynamic> decodedLogs = jsonDecode(logsRaw);

    setState(() {
      _userName = prefs.getString('user_name') ?? 'Student';
      _userEmail = prefs.getString('user_email') ?? 'student@gmail.com';
      _course = prefs.getString('course') ?? 'B.Tech';
      _year = prefs.getString('year') ?? '2nd Year';
      _stateName = prefs.getString('state') ?? '';
      _timetableFile =
          prefs.getString('timetable_file') ?? 'No PDF uploaded yet';
      _lastBackup = prefs.getString('last_cloud_backup') ?? 'Just now';
      _subjects = decodedSubs.map((e) => SubjectModel.fromJson(e)).toList();
      _holidays = (prefs.getStringList('holidays') ?? []).toSet();
      _holidayNames = Map<String, String>.from(
          jsonDecode(prefs.getString('holiday_names') ?? '{}') as Map);
      _hiddenHols = (prefs.getStringList('hidden_hols') ?? []).toSet();
      _historyLogs =
          decodedLogs.map((e) => AttendanceLogItem.fromJson(e)).toList();
    });
  }

  Future<void> _saveAllData({bool showSnack = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final nowStr = DateFormat('dd MMM, hh:mm a').format(DateTime.now());

    await prefs.setString(
        'subjects', jsonEncode(_subjects.map((s) => s.toJson()).toList()));
    await prefs.setStringList('holidays', _holidays.toList());
    await prefs.setString('history_logs_v2',
        jsonEncode(_historyLogs.map((l) => l.toJson()).toList()));
    await prefs.setString('timetable_file', _timetableFile);
    await prefs.setString('last_cloud_backup', nowStr);

    setState(() => _lastBackup = nowStr);

    final cloudOk = await CloudBackupService.syncUserToFirestore(
      email: _userEmail,
      userName: _userName,
      course: _course,
      year: _year,
      timetableFileName: _timetableFile,
      subjects: _subjects,
      holidays: _holidays.toList(),
      historyLogs: _historyLogs,
    );

    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cloudOk
              ? 'Backed up to cloud ($_userEmail)!'
              : 'Saved on phone. Sign in with Google in Profile to back up to cloud.'),
        ),
      );
    }
  }

  int get _totalConducted => _subjects.fold(0, (sum, s) => sum + s.totalHours);
  int get _totalPresent => _subjects.fold(0, (sum, s) => sum + s.attendedHours);
  int get _totalAbsent => _totalConducted - _totalPresent;
  double get _overallPct =>
      _totalConducted == 0 ? 100.0 : (_totalPresent / _totalConducted) * 100.0;

  int get _overallSafeBunks {
    if (_totalConducted == 0 || _overallPct < 75.0) return 0;
    return (_totalPresent / 0.75 - _totalConducted).floor();
  }

  int get _overallNeededFor75 {
    if (_totalConducted == 0 || _overallPct >= 75.0) return 0;
    final n = (3 * _totalConducted) - (4 * _totalPresent);
    return n > 0 ? n : 1;
  }

  bool _logAttendance(int index, int hours, bool present) {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedCalendarDate);
    if (_holidays.contains(dateKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selected date is marked as a Holiday!')),
      );
      return false;
    }

    final timeStr = DateFormat('hh:mm a').format(DateTime.now());
    setState(() {
      _subjects[index].totalHours += hours;
      if (present) _subjects[index].attendedHours += hours;

      _historyLogs.insert(
        0,
        AttendanceLogItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          subject: _subjects[index].name,
          present: present,
          hours: hours,
          dateKey: dateKey,
          timeStr: timeStr,
        ),
      );
    });
    _saveAllData();
    return true;
  }

  void _undoLogItem(AttendanceLogItem item) {
    setState(() {
      final subIdx = _subjects.indexWhere((s) => s.name == item.subject);
      if (subIdx != -1) {
        _subjects[subIdx].totalHours =
            (_subjects[subIdx].totalHours - item.hours).clamp(0, 9999);
        if (item.present) {
          _subjects[subIdx].attendedHours =
              (_subjects[subIdx].attendedHours - item.hours).clamp(0, 9999);
        }
      }
      _historyLogs.removeWhere((l) => l.id == item.id);
    });
    _saveAllData();
  }

  List<SubjectModel> _deduplicateSubjects(List<SubjectModel> rawList) {
    final Map<String, SubjectModel> uniqueMap = {};
    for (final item in rawList) {
      final cleanName = item.name.trim();
      if (cleanName.isEmpty) continue;
      final normKey =
          cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (normKey.isEmpty) continue;

      if (uniqueMap.containsKey(normKey)) {
        final existing = uniqueMap[normKey]!;
        final mergedDays = {...existing.days, ...item.days}.toList();
        existing.days = mergedDays.isNotEmpty ? mergedDays : ['Mon', 'Wed', 'Fri'];
      } else {
        uniqueMap[normKey] = SubjectModel(
          name: cleanName,
          attendedHours: item.attendedHours,
          totalHours: item.totalHours,
          scheduleSlot: item.scheduleSlot,
          days: item.days.toSet().toList(),
        );
      }
    }
    return uniqueMap.values.toList();
  }

  Future<void> _pickAndReadTimetablePdf() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );
      if (res == null || res.files.isEmpty) return;

      final picked = res.files.first;
      setState(() {
        _isReadingTimetable = true;
        _timetableFile = picked.name;
      });

      List<SubjectModel> extracted = [];
      final path = picked.path;
      if (path != null) {
        final rec = TextRecognizer();
        try {
          final out = await rec.processImage(InputImage.fromFilePath(path));
          final skip = RegExp(
              r'^(mon|tue|wed|thu|fri|sat|sun|day|time|period|break|lunch|recess|lab|class|timetable)[a-z]*\.?$',
              caseSensitive: false);
          final timeRx = RegExp(
              r'(\d{1,2}[:.]\d{2}\s*(?:am|pm)?\s*[-–to]+\s*\d{1,2}[:.]\d{2}\s*(?:am|pm)?)',
              caseSensitive: false);
          for (final block in out.blocks) {
            for (final line in block.lines) {
              final t = line.text.trim();
              if (t.length < 3 || t.length > 40 || skip.hasMatch(t)) continue;
              if (!RegExp(r'^[A-Za-z][A-Za-z0-9\s&\-\(\)\.]+$').hasMatch(t)) {
                continue;
              }
              extracted.add(SubjectModel(
                  name: t,
                  scheduleSlot:
                      timeRx.firstMatch(line.text)?.group(1) ?? '09:30 AM - 10:30 AM',
                  days: []));
            }
          }
        } catch (e) {
          debugPrint('OCR error: $e');
        } finally {
          rec.close();
        }
      }

      if (extracted.isEmpty) {
        setState(() => _isReadingTimetable = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Couldn't read subjects from that file. Use a clear photo or screenshot, or add subjects by hand."),
            duration: Duration(seconds: 6)));
        return;
      }

      final deduplicated = _deduplicateSubjects(extracted);
      setState(() => _isReadingTimetable = false);
      if (!mounted) return;
      _showEditScannedTimetableDialog(deduplicated);
    } catch (e) {
      setState(() => _isReadingTimetable = false);
    }
  }

  void _showEditScannedTimetableDialog(List<SubjectModel> draftList) {
    final List<TextEditingController> ctrls =
        draftList.map((s) => TextEditingController(text: s.name)).toList();
    final List<TextEditingController> slotCtrls = draftList
        .map((s) => TextEditingController(text: s.scheduleSlot))
        .toList();
    final List<List<String>> daysList =
        draftList.map((s) => List<String>.from(s.days)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => SheetDialog(
          title: const Text(
            'Check your timetable',
            
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Fix any name and tap the days each class happens, then save.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(ctrls.length, (idx) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: ctrls[idx],
                                  decoration: InputDecoration(
                                    labelText: 'Subject ${idx + 1} Name',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setDialogState(() {
                                    ctrls.removeAt(idx);
                                    slotCtrls.removeAt(idx);
                                    daysList.removeAt(idx);
                                  });
                                },
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.bad),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: slotCtrls[idx],
                            decoration: const InputDecoration(
                              labelText: 'Class Time (e.g. 09:30 AM - 10:30 AM)',
                              prefixIcon: Icon(Icons.access_time, size: 18),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            children: _weekDays.map((d) {
                              final has = daysList[idx].contains(d);
                              return FilterChip(
                                label: Text(d,
                                    style: const TextStyle(fontSize: 10)),
                                selected: has,
                                onSelected: (val) {
                                  setDialogState(() {
                                    if (val) {
                                      daysList[idx].add(d);
                                    } else {
                                      daysList[idx].remove(d);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        ctrls.add(TextEditingController(text: 'New Subject'));
                        slotCtrls.add(TextEditingController(
                            text: '09:30 AM - 10:30 AM'));
                        daysList.add(['Mon', 'Wed', 'Fri']);
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Another Subject'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final List<SubjectModel> finalSubs = [];
                for (int i = 0; i < ctrls.length; i++) {
                  final text = ctrls[i].text.trim();
                  if (text.isNotEmpty) {
                    finalSubs.add(
                      SubjectModel(
                        name: text,
                        scheduleSlot: slotCtrls[i].text.trim().isEmpty
                            ? '09:30 AM - 10:30 AM'
                            : slotCtrls[i].text.trim(),
                        days: daysList[i].isEmpty
                            ? ['Mon', 'Wed', 'Fri']
                            : daysList[i],
                      ),
                    );
                  }
                }
                if (finalSubs.isNotEmpty) {
                  setState(() => _subjects = _deduplicateSubjects(finalSubs));
                  _saveAllData(showSnack: true);
                }
                Navigator.pop(ctx);
                setState(() => _currentTab = 0);
              },
              child: const Text('Save Timetable'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSingleSubjectDialog(int subIndex) {
    final sub = _subjects[subIndex];
    final nameCtrl = TextEditingController(text: sub.name);
    final slotCtrl = TextEditingController(text: sub.scheduleSlot);
    final attCtrl = TextEditingController(text: sub.attendedHours.toString());
    final totCtrl = TextEditingController(text: sub.totalHours.toString());
    final List<String> selectedDays = List<String>.from(sub.days);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => SheetDialog(
          title: const Text(
            'Edit subject',
            
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Subject Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: slotCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Class time, e.g. 09:30 AM - 10:30 AM',
                    prefixIcon: Icon(Icons.access_time_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: attCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Attended',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: totCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total classes',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Class days',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: _weekDays.map((d) {
                    final has = selectedDays.contains(d);
                    return FilterChip(
                      label: Text(d),
                      selected: has,
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) {
                            selectedDays.add(d);
                          } else {
                            selectedDays.remove(d);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _subjects.removeAt(subIndex));
                _saveAllData();
                Navigator.pop(ctx);
              },
              child: const Text('Delete', style: TextStyle(color: AppColors.bad)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final att = int.tryParse(attCtrl.text.trim()) ?? 0;
                final tot = int.tryParse(totCtrl.text.trim()) ?? 0;
                setState(() {
                  _subjects[subIndex].name = nameCtrl.text.trim().isEmpty
                      ? _subjects[subIndex].name
                      : nameCtrl.text.trim();
                  _subjects[subIndex].scheduleSlot =
                      slotCtrl.text.trim().isEmpty
                          ? '09:30 AM - 10:30 AM'
                          : slotCtrl.text.trim();
                  _subjects[subIndex].attendedHours = att < 0 ? 0 : att;
                  _subjects[subIndex].totalHours = tot < att ? att : tot;
                  _subjects[subIndex].days = selectedDays.isEmpty
                      ? ['Mon', 'Wed', 'Fri']
                      : selectedDays;
                });
                _saveAllData(showSnack: true);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  int _qrHash(String v) {
    var h = 0x811c9dc5;
    for (final u in v.codeUnits) {
      h ^= u;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  Future<void> _signInForBackup() async {
    final u = await CloudBackupService.signInWithGoogle();
    if (!mounted) return;
    if (u == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Google sign-in failed: ${CloudBackupService.lastError}'),
            duration: const Duration(seconds: 8)),
      );
      return;
    }
    setState(() => _userEmail = u.email ?? _userEmail);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', _userEmail);
    await _saveAllData(showSnack: true);
  }

  String _generateQrSharePayload() {
    final rows = _subjects
        .map((s) =>
            '${s.name.replaceAll(RegExp(r'[|;~]'), ' ')}~${s.days.join(',')}~${s.scheduleSlot.replaceAll(RegExp(r'[|;~]'), ' ')}')
        .join(';');
    final compact = 'AT2|$_course|$_year|College|$rows';
    return compact;
  }

  void _importQrPayload(String rawCode) {
    try {
      final trimmed = rawCode.trim();
      final decodedStr = trimmed.startsWith('AT2|')
          ? trimmed
          : utf8.decode(base64Decode(trimmed));
      if (decodedStr.startsWith('AT2|')) {
        final parts = decodedStr.split('|');
        if (parts.length >= 5) {
          final rows =
              parts[4].split(';').where((r) => r.trim().isNotEmpty).toList();
          final imported = rows.map((r) {
            final segs = r.split('~');
            return SubjectModel(
              name: segs.isNotEmpty ? segs[0] : 'Subject',
              days: segs.length > 1 && segs[1].isNotEmpty
                  ? segs[1].split(',')
                  : ['Mon', 'Wed', 'Fri'],
              scheduleSlot:
                  segs.length > 2 ? segs[2] : '09:30 AM - 10:30 AM',
            );
          }).toList();
          if (imported.isNotEmpty) {
            setState(() {
              _course = parts[1].isNotEmpty ? parts[1] : _course;
              _year = parts[2].isNotEmpty ? parts[2] : _year;
              _subjects = _deduplicateSubjects(imported);
            });
            _saveAllData(showSnack: true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Imported ${_subjects.length} unique subjects from QR!'),
              ),
            );
            return;
          }
        }
      }

      final decoded = jsonDecode(decodedStr);
      if (decoded['subjects'] != null) {
        final List<dynamic> list = decoded['subjects'];
        setState(() {
          _course = decoded['course'] ?? _course;
          _year = decoded['year'] ?? _year;
          _subjects = _deduplicateSubjects(
            list.map((item) {
              if (item is String) {
                return SubjectModel(name: item);
              }
              return SubjectModel(
                name: item['name'] ?? 'Subject',
                scheduleSlot: item['slot'] ?? '09:30 AM - 10:30 AM',
                days: item['days'] != null
                    ? List<String>.from(item['days'])
                    : ['Mon', 'Wed', 'Fri'],
              );
            }).toList(),
          );
        });
        _saveAllData(showSnack: true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR Code format.')),
      );
    }
  }

  void _openLiveCameraQrScanner() {
    final controller = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    bool handled = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.black,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: Stack(
          children: [
            MobileScanner(
              controller: controller,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? 'Camera permission denied.\nAllow Camera for this app in phone Settings, then try again.'
                            : 'Camera could not start (${error.errorCode.name}).\n${error.errorDetails?.message ?? ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          try {
                            await controller.stop();
                          } catch (_) {}
                          try {
                            await controller.start();
                          } catch (_) {}
                        },
                        child: const Text('Try again'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () async {
                          final res = await FilePicker.platform
                              .pickFiles(type: FileType.image);
                          final path = res?.files.single.path;
                          if (path == null) return;
                          try {
                            final cap = await controller.analyzeImage(path);
                            final raw = cap?.barcodes.first.rawValue;
                            if (raw != null && !handled) {
                              handled = true;
                              if (ctx.mounted) Navigator.pop(ctx);
                              _importQrPayload(raw);
                            }
                          } catch (_) {}
                        },
                        child: const Text('Choose a QR photo instead'),
                      ),
                    ],
                  ),
                ),
              ),
              onDetect: (capture) {
                if (handled) return;
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null && raw.isNotEmpty) {
                    handled = true;
                    Navigator.pop(ctx);
                    _importQrPayload(raw);
                    break;
                  }
                }
              },
            ),
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scan Classmate Timetable QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget Function()>[
      _buildHomeTab,
      _buildHistoryTab,
      _buildHolidaysTab,
      _buildQrAndStatsTab,
      _buildProfileAndTimetableTab,
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: kMed,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) =>
            reduceMotion(context) ? child : tabTransition(child, anim),
        child: KeyedSubtree(
          key: ValueKey<int>(_currentTab),
          child: pages[_currentTab](),
        ),
      ),
      bottomNavigationBar: AppNavBar(
        index: _currentTab,
        onTap: (idx) => setState(() => _currentTab = idx),
      ),
    );
  }

  void _mark(int i, bool present) {
    final ok = _logAttendance(i, 1, present);
    if (!ok) return;
    setState(() {
      _flashIdx = i;
      _flashPresent = present;
    });
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _flashIdx = null);
    });
  }

  Widget _buildHomeTab() {
    final isSafe = _overallPct >= 75.0;
    final activeDay = _activeWeekdayShort;
    final visibleSubjects = _subjects.asMap().entries.where((entry) {
      if (activeDay == 'All') return true;
      return entry.value.days.contains(activeDay);
    }).toList();

    return BoldPage(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, $_userName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$_course • $_year',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _currentTab = 4),
                icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
                tooltip: 'Upload timetable',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              PctRing(
                pct: _overallPct,
                size: 112,
                textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Overall attendance',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: kFast,
                      child: Text(
                        isSafe ? 'Safe zone' : 'Below 75%',
                        key: ValueKey<bool>(isSafe),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSafe
                          ? 'You can skip $_overallSafeBunks more hours.'
                          : 'Attend the next $_overallNeededFor75 hours to reach 75%.',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      children: [
        FadeSlideIn(
          child: Row(
            children: [
              _statCard('Total hours', _totalConducted, AppColors.ink),
              const SizedBox(width: 8),
              _statCard('Present', _totalPresent, AppColors.good),
              const SizedBox(width: 8),
              _statCard('Absent', _totalAbsent, AppColors.bad),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          index: 1,
          child: Row(
            children: ['All', ..._weekDays].map((d) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AppPill(
                    label: d,
                    selected: activeDay == d,
                    onTap: () => setState(() => _selectedDayMode = d),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                activeDay == 'All'
                    ? 'All subjects (${_subjects.length})'
                    : "${_fullDayNames[activeDay]}'s classes (${visibleSubjects.length})",
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.ink),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _subjects.add(SubjectModel(name: 'New Subject'));
                });
                _showEditSingleSubjectDialog(_subjects.length - 1);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add subject'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (visibleSubjects.isEmpty)
          FadeSlideIn(
            child: SoftCard(
              child: Center(
                child: Text(
                  _subjects.isEmpty
                      ? 'No subjects yet. Tap Add subject, or import a timetable from the Profile tab.'
                      : 'No classes on this day.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
            ),
          )
        else
          ...visibleSubjects.asMap().entries.map(
                (e) => _subjectCard(e.value.key, e.value.value, e.key),
              ),
      ],
    );
  }

  Widget _subjectCard(int i, SubjectModel sub, int order) {
    final ok = sub.percentage >= 75.0;
    final flash = _flashIdx == i;
    final pctColor = ok ? AppColors.good : AppColors.bad;
    return FadeSlideIn(
      key: ValueKey('${sub.name}-$_selectedDayMode-$i'),
      index: order,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PctRing(
                    pct: sub.percentage,
                    size: 56,
                    stroke: 6,
                    color: pctColor,
                    track: ok ? AppColors.goodSoft : AppColors.badSoft,
                    textStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: pctColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${sub.scheduleSlot} • ${sub.days.join(", ")}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showEditSingleSubjectDialog(i),
                    icon: const Icon(Icons.edit_outlined,
                        size: 20, color: AppColors.primary),
                    tooltip: 'Edit subject',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedBar(
                value: sub.percentage / 100.0,
                color: pctColor,
              ),
              const SizedBox(height: 8),
              Text(
                ok
                    ? 'Safe to skip ${sub.safeBunks} classes • Attended ${sub.attendedHours} of ${sub.totalHours}'
                    : 'Attend next ${sub.classesNeededFor75} classes for 75% • Attended ${sub.attendedHours} of ${sub.totalHours}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PressScale(
                      child: FilledButton(
                        onPressed: () => _mark(i, true),
                        child: AnimatedSwitcher(
                          duration: kFast,
                          transitionBuilder: (c, a) =>
                              ScaleTransition(scale: a, child: c),
                          child: (flash && _flashPresent)
                              ? const Icon(Icons.check_rounded,
                                  key: ValueKey('p-check'))
                              : const Text('Present', key: ValueKey('p-text')),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PressScale(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.tint,
                          foregroundColor: AppColors.primary,
                        ),
                        onPressed: () => _mark(i, false),
                        child: AnimatedSwitcher(
                          duration: kFast,
                          transitionBuilder: (c, a) =>
                              ScaleTransition(scale: a, child: c),
                          child: (flash && !_flashPresent)
                              ? const Icon(Icons.close_rounded,
                                  key: ValueKey('a-x'))
                              : const Text('Absent', key: ValueKey('a-text')),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, int val, Color color) {
    return Expanded(
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 4),
            CountUp(
              value: val,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  String _dk(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  List<Holiday> _stateHols() => holidaysForState(_stateName)
      .where((h) => !_hiddenHols.contains('${_dk(h.date)}|${h.name}'))
      .toList();

  Future<void> _saveHolidayExtras() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('holidays', _holidays.toList());
    await prefs.setString('holiday_names', jsonEncode(_holidayNames));
    await prefs.setStringList('hidden_hols', _hiddenHols.toList());
  }

  void _undoSnack(String text, VoidCallback undo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () {
              setState(undo);
              _saveHolidayExtras();
            }),
      ));
  }

  void _removeMyHoliday(String key) {
    final name = _holidayNames[key];
    setState(() {
      _holidays.remove(key);
      _holidayNames.remove(key);
    });
    _saveHolidayExtras();
    _undoSnack('Holiday removed', () {
      _holidays.add(key);
      if (name != null) _holidayNames[key] = name;
    });
  }

  void _hideStateHoliday(Holiday h) {
    final k = '${_dk(h.date)}|${h.name}';
    setState(() => _hiddenHols.add(k));
    _saveHolidayExtras();
    _undoSnack('Holiday hidden', () => _hiddenHols.remove(k));
  }

  Future<void> _addMyHoliday() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (d == null || !mounted) return;
    final ctrl = TextEditingController();
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SheetDialog(
        title: const Text('Holiday name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              hintText: 'Optional, e.g. College fest'),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (name == null) return;
    setState(() {
      _holidays.add(_dk(d));
      if (name.isNotEmpty) _holidayNames[_dk(d)] = name;
    });
    _saveHolidayExtras();
  }

  Widget _buildHolidaysTab() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final list =
        _stateHols().where((h) => !h.date.isBefore(start)).toList();
    final mine = _holidays.toList()..sort();
    final children = <Widget>[
      Row(
        children: [
          const Expanded(
            child: Text('My holidays',
                style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton.icon(
            onPressed: _addMyHoliday,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
        ],
      ),
      if (mine.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Days you mark yourself show up here.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
      for (final k in mine)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded,
                    color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_holidayNames[k] ?? 'Holiday',
                          style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      Text(
                          DateFormat('EEEE, d MMM yyyy')
                              .format(DateTime.parse(k)),
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => _removeMyHoliday(k),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.bad),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
    ];
    if (_stateName.isEmpty) {
      children.add(FadeSlideIn(
        child: SoftCard(
          child: Column(
            children: [
              const Text('Pick your state to see its holidays.',
                  style: TextStyle(color: AppColors.muted, fontSize: 14)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final v = await pickState(context, _stateName);
                  if (v == null) return;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('state', v);
                  if (mounted) setState(() => _stateName = v);
                },
                child: const Text('Choose state'),
              ),
            ],
          ),
        ),
      ));
    } else if (list.isEmpty) {
      children.add(const FadeSlideIn(
        child: SoftCard(
          child: Center(
            child: Text('No more holidays in the list.',
                style: TextStyle(color: AppColors.muted, fontSize: 14)),
          ),
        ),
      ));
    } else {
      String month = '';
      var i = 0;
      for (final h in list) {
        final m = DateFormat('MMMM yyyy').format(h.date);
        if (m != month) {
          month = m;
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(m,
                style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ));
        }
        final days = h.date.difference(start).inDays;
        children.add(FadeSlideIn(
          index: i++ < 8 ? i : 8,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.tint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(DateFormat('d').format(h.date),
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        Text(DateFormat('MMM').format(h.date),
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.name,
                            style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                            '${DateFormat('EEEE').format(h.date)} • ${days == 0 ? 'Today' : days == 1 ? 'Tomorrow' : 'in $days days'}',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hide',
                    onPressed: () => _hideStateHoliday(h),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ));
      }
    }
    return BoldPage(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Holidays',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_stateName.isEmpty ? 'No state selected' : _stateName,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
      children: children,
    );
  }

  Widget _buildHistoryTab() {
    final selectedKey = DateFormat('yyyy-MM-dd').format(_selectedCalendarDate);
    final dayLogs =
        _historyLogs.where((l) => l.dateKey == selectedKey).toList();
    final isHoliday = _holidays.contains(selectedKey);
    final stateHolList =
        _stateHols().where((h) => _dk(h.date) == selectedKey).toList();
    final stateHolNames = {for (final h in _stateHols()) _dk(h.date): h.name};
    final stateHolName =
        stateHolList.isEmpty ? null : stateHolList.map((h) => h.name).join(', ');
    final presentCount = dayLogs.where((l) => l.present).length;
    final absentCount = dayLogs.length - presentCount;

    return BoldPage(
      header: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Attendance history',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, d MMM yyyy').format(_selectedCalendarDate),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          PressScale(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (isHoliday) {
                  _removeMyHoliday(selectedKey);
                } else {
                  setState(() => _holidays.add(selectedKey));
                  _saveAllData();
                }
              },
              icon: const Icon(Icons.wb_sunny_outlined, size: 18),
              label: Text(isHoliday ? 'Unmark holiday' : 'Mark holiday'),
            ),
          ),
        ],
      ),
      children: [
        FadeSlideIn(
          child: SoftCard(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: HolidayCalendar(
                selected: _selectedCalendarDate,
                stateHolidays: stateHolNames.keys.toSet(),
                myHolidays: _holidays.toSet(),
                onSelect: (dt) => setState(() => _selectedCalendarDate = dt),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: kMed,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: isHoliday
              ? const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: SoftCard(
                    color: AppColors.tint,
                    child: Row(
                      children: [
                        Icon(Icons.wb_sunny_outlined, color: AppColors.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Holiday. Attendance is paused for this date.',
                            style:
                                TextStyle(fontSize: 13, color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (stateHolName != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SoftCard(
              color: AppColors.badSoft,
              child: Row(
                children: [
                  const Icon(Icons.celebration_rounded, color: AppColors.bad),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(stateHolName,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.ink)),
                  ),
                  TextButton(
                    onPressed: () => _hideStateHoliday(stateHolList.first),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Logs on $selectedKey',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.ink),
              ),
            ),
            Text(
              'Present $presentCount • Absent $absentCount',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (dayLogs.isEmpty)
          const FadeSlideIn(
            child: SoftCard(
              child: Center(
                child: Text(
                  'No classes logged for this date yet.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
            ),
          )
        else
          ...dayLogs.asMap().entries.map((e) {
            final item = e.value;
            return FadeSlideIn(
              key: ValueKey(item.id),
              index: e.key,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: item.present
                            ? AppColors.goodSoft
                            : AppColors.badSoft,
                        child: Icon(
                          item.present ? Icons.check : Icons.close,
                          color: item.present ? AppColors.good : AppColors.bad,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.subject,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink)),
                            Text(
                              '${item.present ? "Present" : "Absent"} (${item.hours}h) • ${item.timeStr}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _undoLogItem(item),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.bad),
                        child: const Text('Undo'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _qrBlock(String qrPayload) {
    final h = _qrHash(qrPayload);
    final style = kQrStyles[(h ~/ 1000000) % kQrStyles.length];
    final code6 = (h % 1000000).toString().padLeft(6, '0');
    final qr = QrImage(QrCode.fromData(
      data: qrPayload,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    ));
    return Column(
      key: ValueKey(code6),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 250,
            height: 250,
            child: CustomPaint(painter: StyledQrPainter(qr, style)),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.tint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Theme: ${style.name}',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          code6,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: _subjects
              .map((sub) => Chip(
                    label: Text(sub.name, style: const TextStyle(fontSize: 13)),
                    visualDensity: VisualDensity.compact,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildQrAndStatsTab() {
    final qrPayload = _generateQrSharePayload();
    return BoldPage(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Share timetable',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            "Scan a classmate's QR to copy their subjects and days.",
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PressScale(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 52),
                ),
                onPressed: _openLiveCameraQrScanner,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Scan classmate QR'),
              ),
            ),
          ),
        ],
      ),
      children: [
        FadeSlideIn(
          child: SoftCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Your timetable QR',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.ink),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: kMed,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.94, end: 1).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _qrBlock(qrPayload),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: PressScale(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: qrPayload));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied class code!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy timetable code'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAndTimetableTab() {
    final signedIn = CloudBackupService.user != null;
    return BoldPage(
      header: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  _userEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: widget.onEditProfileRequested,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit setup'),
          ),
        ],
      ),
      children: [
        FadeSlideIn(
          child: SoftCard(
            child: Column(
              children: [
                _profileRow('Course', _course),
                const SizedBox(height: 8),
                _profileRow('Year', _year),
                const SizedBox(height: 8),
                _profileRow('State', _stateName.isEmpty ? 'Not set' : _stateName),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 1,
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Timetable',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'File: $_timetableFile (${_subjects.length} subjects)',
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                AnimatedSize(
                  duration: kMed,
                  child: _isReadingTimetable
                      ? const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: PressScale(
                    child: FilledButton.icon(
                      onPressed:
                          _isReadingTimetable ? null : _pickAndReadTimetablePdf,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(_isReadingTimetable
                          ? 'Reading file...'
                          : 'Upload PDF or image'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 2,
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      signedIn
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      color: signedIn ? AppColors.good : AppColors.muted,
                    ),
                    const SizedBox(width: 8),
                    const Text('Cloud backup',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  !signedIn
                      ? 'Not signed in. Cloud backup is off.'
                      : 'Last synced: $_lastBackup • ${CloudBackupService.user?.email ?? _userEmail}',
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                if (!signedIn) ...[
                  SizedBox(
                    width: double.infinity,
                    child: PressScale(
                      child: FilledButton.icon(
                        onPressed: _signInForBackup,
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Sign in with Google'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: PressScale(
                    child: OutlinedButton.icon(
                      onPressed: () => _saveAllData(showSnack: true),
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Back up now'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        Flexible(
          child: Text(
            val,
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}


class QrStyleSpec {
  final String name;
  final Color bg;
  final List<Color> fg;
  final bool grad;
  final String shape;
  final List<double> eye;
  final Color? eyeColor;
  final bool leafEyes;
  const QrStyleSpec(this.name, this.bg, this.fg, this.shape, this.eye,
      {this.grad = false, this.eyeColor, this.leafEyes = false});
}

const List<QrStyleSpec> kQrStyles = [
  QrStyleSpec('Leaf', Color(0xFFF1F8EC), [Color(0xFF1F6B2E)], 'leaf',
      [2.6, 1.6, 1.1],
      leafEyes: true),
  QrStyleSpec('Diamond', Color(0xFFF4F0FF),
      [Color(0xFF311B92), Color(0xFF7C4DFF)], 'diamond', [1.2, 0.6, 0.4],
      grad: true),
  QrStyleSpec('Tall bars', Color(0xFFFFF7EC),
      [Color(0xFFBF360C), Color(0xFFF57C00)], 'vpill', [2, 1.2, 0.9],
      grad: true),
  QrStyleSpec(
      'Mosaic',
      Color(0xFFFFFFFF),
      [Color(0xFF0D47A1), Color(0xFFAD1457), Color(0xFF00695C), Color(0xFFE65100)],
      'mosaic',
      [0.8, 0.4, 0.3],
      eyeColor: Color(0xFF0D1B4A)),
  QrStyleSpec('Liquid', Color(0xFFEEF3FF),
      [Color(0xFF0D1B4A), Color(0xFF1976D2)], 'liquid', [3, 2, 1.4],
      grad: true),
];

class StyledQrPainter extends CustomPainter {
  final QrImage qr;
  final QrStyleSpec st;
  StyledQrPainter(this.qr, this.st);

  bool _isEye(int r, int c, int n) =>
      (r < 7 && c < 7) || (r < 7 && c >= n - 7) || (r >= n - 7 && c < 7);

  @override
  void paint(Canvas canvas, Size size) {
    final n = qr.moduleCount;
    const q = 3;
    final s = size.width / (n + 2 * q);
    canvas.drawRect(Offset.zero & size, Paint()..color = st.bg);

    final paint = Paint()..isAntiAlias = true;
    if (st.grad) {
      paint.shader = ui.Gradient.linear(
          Offset.zero, Offset(size.width, size.height), [st.fg[0], st.fg[1]]);
    } else {
      paint.color = st.fg[0];
    }

    bool dark(int r, int c) =>
        r >= 0 && c >= 0 && r < n && c < n && qr.isDark(r, c) && !_isEye(r, c, n);

    void rr(double x, double y, double w, double h, double tl, double tr,
        double br, double bl, Paint p) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, w, h),
          topLeft: Radius.circular(tl),
          topRight: Radius.circular(tr),
          bottomRight: Radius.circular(br),
          bottomLeft: Radius.circular(bl),
        ),
        p,
      );
    }

    if (st.shape == 'vpill') {
      final pad = s * 0.107;
      final w = s - 2 * pad;
      for (var k = 0; k < n; k++) {
        var run = -1;
        for (var r = 0; r <= n; r++) {
          final on = dark(r, k);
          if (on && run < 0) run = r;
          if (!on && run >= 0) {
            rr((k + q) * s + pad, (run + q) * s + pad, w, (r - run) * s - 2 * pad,
                w / 2, w / 2, w / 2, w / 2, paint);
            run = -1;
          }
        }
      }
    } else {
      for (var r = 0; r < n; r++) {
        for (var k = 0; k < n; k++) {
          if (!dark(r, k)) continue;
          final x = (k + q) * s;
          final y = (r + q) * s;
          final inset = s * 0.035;
          if (st.shape == 'leaf') {
            rr(x + inset, y + inset, s - 2 * inset, s - 2 * inset, s * .5, 0,
                s * .5, 0, paint);
          } else if (st.shape == 'diamond') {
            final h = s * 0.6;
            final cx = x + s / 2;
            final cy = y + s / 2;
            final path = Path()
              ..moveTo(cx, cy - h)
              ..lineTo(cx + h, cy)
              ..lineTo(cx, cy + h)
              ..lineTo(cx - h, cy)
              ..close();
            canvas.drawPath(path, paint);
          } else if (st.shape == 'mosaic') {
            final mp = Paint()
              ..isAntiAlias = true
              ..color = st.fg[(r * 5 + k * 3 + (r * k) % 2) % st.fg.length];
            rr(x + inset, y + inset, s - 2 * inset, s - 2 * inset, s * .2,
                s * .2, s * .2, s * .2, mp);
          } else {
            final rad = s * .5;
            final tl = (!dark(r - 1, k) && !dark(r, k - 1)) ? rad : 0.0;
            final tr = (!dark(r - 1, k) && !dark(r, k + 1)) ? rad : 0.0;
            final br = (!dark(r + 1, k) && !dark(r, k + 1)) ? rad : 0.0;
            final bl = (!dark(r + 1, k) && !dark(r, k - 1)) ? rad : 0.0;
            rr(x - .02 * s, y - .02 * s, s * 1.04, s * 1.04, tl, tr, br, bl, paint);
          }
        }
      }
    }

    final eyePaint = Paint()..isAntiAlias = true;
    if (st.eyeColor != null) {
      eyePaint.color = st.eyeColor!;
    } else {
      eyePaint.shader = paint.shader;
      eyePaint.color = st.fg[0];
    }
    final bgPaint = Paint()
      ..isAntiAlias = true
      ..color = st.bg;
    for (final p in [
      [0, 0],
      [0, n - 7],
      [n - 7, 0]
    ]) {
      final x = (p[1] + q) * s;
      final y = (p[0] + q) * s;
      void box(double ox, double oy, double sz, double v, Paint pt) {
        final r = v * s;
        if (st.leafEyes) {
          rr(x + ox * s, y + oy * s, sz * s, sz * s, r, 0, r, 0, pt);
        } else {
          rr(x + ox * s, y + oy * s, sz * s, sz * s, r, r, r, r, pt);
        }
      }

      box(0, 0, 7, st.eye[0], eyePaint);
      box(1, 1, 5, st.eye[1], bgPaint);
      box(2, 2, 3, st.eye[2], eyePaint);
    }
  }

  @override
  bool shouldRepaint(covariant StyledQrPainter old) =>
      old.qr != qr || old.st != st;
}
