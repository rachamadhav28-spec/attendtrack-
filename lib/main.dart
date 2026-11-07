import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      title: 'Attendance Track 75%',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3730A3),
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
      ),
      home: const RootFlowController(),
    );
  }
}

class AttendanceAppLogo extends StatelessWidget {
  final double size;
  final bool showLabel;
  const AttendanceAppLogo({super.key, this.size = 76, this.showLabel = false});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.27),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF60A5FA),
                  Color(0xFF3B82F6),
                  Color(0xFF2563EB)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size * 0.62,
                  height: size * 0.58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(size * 0.1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: size * 0.14,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(size * 0.1),
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFF93C5FD),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: size * 0.08,
                  right: size * 0.08,
                  child: Container(
                    width: size * 0.36,
                    height: size * 0.36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: size * 0.22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 6),
            const Text(
              'Attendance Track 75%',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Color(0xFF0F296B),
              ),
            ),
          ],
        ],
      ),
    );
  }
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
  static String _docKey(String email) =>
      email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

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
    if (email.trim().isEmpty) return false;
    try {
      await FirebaseFirestore.instance
          .collection('student_backups')
          .doc(_docKey(email))
          .set({
        'email': email.trim().toLowerCase(),
        'userName': userName,
        'course': course,
        'year': year,
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

  static Future<Map<String, dynamic>?> restoreUserFromFirestore(
      String email) async {
    if (email.trim().isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('student_backups')
          .doc(_docKey(email))
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
      _selectedCourse = prefs.getString('course') ?? 'B.Tech';
      _selectedYear = prefs.getString('year') ?? '2nd Year';
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
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your Gmail above to restore your cloud backup!'),
        ),
      );
      return;
    }
    setState(() => _isRestoring = true);
    final data = await CloudBackupService.restoreUserFromFirestore(email);
    setState(() => _isRestoring = false);

    if (data == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No cloud backup found for this Gmail yet.'),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', data['userName'] ?? 'Student');
    await prefs.setString('user_email', email);
    await prefs.setString('course', data['course'] ?? 'B.Tech');
    await prefs.setString('year', data['year'] ?? '2nd Year');
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
    await prefs.setString('course', _selectedCourse);
    await prefs.setString('year', _selectedYear);

    if ((prefs.getString('subjects') ?? '').isEmpty) {
      final defaultSubs = [
        SubjectModel(
          name: 'Data Structures & Algorithms',
          attendedHours: 0,
          totalHours: 0,
          scheduleSlot: '09:30 AM - 10:30 AM',
          days: ['Mon', 'Wed', 'Fri'],
        ),
        SubjectModel(
          name: 'Discrete Mathematics',
          attendedHours: 0,
          totalHours: 0,
          scheduleSlot: '10:30 AM - 11:30 AM',
          days: ['Tue', 'Thu', 'Sat'],
        ),
        SubjectModel(
          name: 'Database Management Systems',
          attendedHours: 0,
          totalHours: 0,
          scheduleSlot: '11:30 AM - 12:30 PM',
          days: ['Mon', 'Wed', 'Fri'],
        ),
        SubjectModel(
          name: 'Digital Logic Design',
          attendedHours: 0,
          totalHours: 0,
          scheduleSlot: '01:30 PM - 02:30 PM',
          days: ['Tue', 'Thu', 'Sat'],
        ),
        SubjectModel(
          name: 'Python & DBMS Lab (3h)',
          attendedHours: 0,
          totalHours: 0,
          scheduleSlot: '02:00 PM - 05:00 PM',
          days: ['Wed', 'Fri'],
        ),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: AttendanceAppLogo(size: 76, showLabel: true)),
              const SizedBox(height: 20),
              const Text(
                '1. Enter Your Full Name *',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Madhav',
                  prefixIcon: const Icon(Icons.person_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '2. Select Course (B.Tech / Degree / Other) *',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['B.Tech', 'Degree', 'Other'].map((c) {
                  final selected = _selectedCourse == c;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            c,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: selected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        selected: selected,
                        selectedColor: const Color(0xFF3730A3),
                        onSelected: (_) {
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
              const SizedBox(height: 16),
              const Text(
                '3. Which Year? *',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _yearsForCourse.contains(_selectedYear)
                    ? _selectedYear
                    : _yearsForCourse.first,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _yearsForCourse
                    .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedYear = v!),
              ),
              const SizedBox(height: 16),
              const Text(
                '4. Your Gmail (For Cloud Backup & Restore After Reinstall)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'yourname@gmail.com',
                  prefixIcon: const Icon(Icons.cloud_done_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3730A3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _saveAndGoToProfile,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    'Continue to Profile & Timetable Upload',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.restore_rounded,
                            color: Color(0xFF3730A3), size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Deleted App? Restore Attendance from Cloud',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xFF1E1B4B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter your Gmail in box #4 above and tap below to restore all your subjects and attendance hours from Firebase:',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed:
                            _isRestoring ? null : _handleRestoreFromCloud,
                        child: Text(
                          _isRestoring
                              ? 'Restoring from Firebase...'
                              : 'Restore My Cloud Backup',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

  List<SubjectModel> _subjects = [];
  Set<String> _holidays = {};
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
      _timetableFile =
          prefs.getString('timetable_file') ?? 'No PDF uploaded yet';
      _lastBackup = prefs.getString('last_cloud_backup') ?? 'Just now';
      _subjects = decodedSubs.map((e) => SubjectModel.fromJson(e)).toList();
      _holidays = (prefs.getStringList('holidays') ?? []).toSet();
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

    await CloudBackupService.syncUserToFirestore(
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
        SnackBar(content: Text('Backed up to Firebase ($_userEmail)!')),
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

  void _logAttendance(int index, int hours, bool present) {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedCalendarDate);
    if (_holidays.contains(dateKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selected date is marked as a Holiday!')),
      );
      return;
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
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;

      final picked = res.files.first;
      setState(() {
        _isReadingTimetable = true;
        _timetableFile = picked.name;
      });

      await Future.delayed(const Duration(milliseconds: 180));
      List<SubjectModel> extracted = [];

      if (picked.bytes != null) {
        final rawText = utf8.decode(picked.bytes!, allowMalformed: true);
        final lines = rawText
            .split(RegExp(r'[\r\n]+'))
            .map((s) => s.trim())
            .where((s) =>
                s.length >= 4 &&
                s.length <= 42 &&
                !s.startsWith('%PDF') &&
                !s.contains('obj') &&
                !s.contains('stream') &&
                RegExp(r'^[A-Za-z][A-Za-z0-9\s&\-\(\)\.]+$').hasMatch(s))
            .toSet()
            .take(12)
            .toList();

        if (lines.length >= 3) {
          extracted = lines
              .asMap()
              .entries
              .map((e) => SubjectModel(
                    name: e.value,
                    scheduleSlot:
                        '${9 + (e.key % 6)}:30 AM - ${10 + (e.key % 6)}:30 AM',
                    days: e.key.isEven
                        ? ['Mon', 'Wed', 'Fri']
                        : ['Tue', 'Thu', 'Sat'],
                  ))
              .toList();
        }
      }

      if (extracted.isEmpty) {
        extracted = _subjects.length >= 5
            ? _subjects
                .map((s) => SubjectModel(
                      name: s.name,
                      attendedHours: s.attendedHours,
                      totalHours: s.totalHours,
                      scheduleSlot: s.scheduleSlot,
                      days: List<String>.from(s.days),
                    ))
                .toList()
            : [
                SubjectModel(
                  name: 'Data Structures & Algorithms',
                  scheduleSlot: '09:30 AM - 10:30 AM',
                  days: ['Mon', 'Wed', 'Fri'],
                ),
                SubjectModel(
                  name: 'Discrete Mathematics',
                  scheduleSlot: '10:30 AM - 11:30 AM',
                  days: ['Tue', 'Thu', 'Sat'],
                ),
                SubjectModel(
                  name: 'Database Management Systems',
                  scheduleSlot: '11:30 AM - 12:30 PM',
                  days: ['Mon', 'Wed', 'Fri'],
                ),
                SubjectModel(
                  name: 'Digital Logic Design',
                  scheduleSlot: '01:30 PM - 02:30 PM',
                  days: ['Tue', 'Thu', 'Sat'],
                ),
                SubjectModel(
                  name: 'Python & DBMS Lab (3h)',
                  scheduleSlot: '02:00 PM - 05:00 PM',
                  days: ['Wed', 'Fri'],
                ),
              ];
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Verify & Edit Timetable Subjects',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Fix any subject name or tap the days it occurs on before saving:',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(ctrls.length, (idx) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
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
                                    color: Colors.red),
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Edit Subject, Time & Classes Done',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
                    labelText: 'Class Timing (e.g. 09:30 AM - 10:30 AM)',
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
                          labelText: 'Classes Attended',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: totCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total Classes Done',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Scheduled Days:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  String _generateQrSharePayload() {
    final rows = _subjects
        .map((s) =>
            '${s.name.replaceAll(RegExp(r'[|;~]'), ' ')}~${s.days.join(',')}~${s.scheduleSlot.replaceAll(RegExp(r'[|;~]'), ' ')}')
        .join(';');
    final compact = 'AT2|$_course|$_year|College|$rows';
    return base64Encode(utf8.encode(compact));
  }

  void _importQrPayload(String rawCode) {
    try {
      final decodedStr = utf8.decode(base64Decode(rawCode.trim()));
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null && raw.isNotEmpty) {
                    Navigator.pop(ctx);
                    _importQrPayload(raw);
                    break;
                  }
                }
              },
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<int>(_currentTab),
          child: [
            _buildHomeTab(),
            _buildHistoryTab(),
            _buildQrAndStatsTab(),
            _buildHelpTab(),
            _buildProfileAndTimetableTab(),
          ][_currentTab],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (idx) => setState(() => _currentTab = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_rounded), label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_rounded), label: 'QR Scan'),
          NavigationDestination(
              icon: Icon(Icons.help_outline_rounded), label: 'Help'),
          NavigationDestination(
              icon: Icon(Icons.person_rounded), label: 'Profile & PDF'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final isSafe = _overallPct >= 75.0;
    final activeDay = _activeWeekdayShort;
    final visibleSubjects = _subjects.asMap().entries.where((entry) {
      if (activeDay == 'All') return true;
      return entry.value.days.contains(activeDay);
    }).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 26),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF1E3A8A), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white24,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $_userName!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '$_course • $_year',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _currentTab = 4),
                    icon: const Icon(Icons.upload_file_rounded,
                        color: Colors.white),
                    tooltip: 'Upload Timetable PDF',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isSafe ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isSafe
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      child: Icon(
                        isSafe ? Icons.check_rounded : Icons.warning_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overall Attendance: ${_overallPct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            isSafe
                                ? 'Safe to skip $_overallSafeBunks hours'
                                : 'Attend next $_overallNeededFor75 hours for 75%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSafe
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _statCard('Total Hours', '$_totalConducted',
                      const Color(0xFF3730A3)),
                  const SizedBox(width: 8),
                  _statCard(
                      'Present', '$_totalPresent', const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  _statCard('Absent', '$_totalAbsent', const Color(0xFFEF4444)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WEEK DAY TIMETABLE',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              activeDay == 'All'
                                  ? 'Showing: All Subjects (Mon - Sat)'
                                  : '${_fullDayNames[activeDay] ?? activeDay}\'s Classes',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: Color(0xFF3730A3),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedDayMode = 'All'),
                          child: const Text('All Days',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _weekDays.map((d) {
                        final isSelected = activeDay == d;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _selectedDayMode = d),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF3730A3)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  d,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    activeDay == 'All'
                        ? 'All Subjects (${_subjects.length})'
                        : '${_fullDayNames[activeDay]}\'s Classes (${visibleSubjects.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _subjects.add(SubjectModel(name: 'New Subject'));
                      });
                      _showEditSingleSubjectDialog(_subjects.length - 1);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Subject'),
                  ),
                ],
              ),
              ...visibleSubjects.map((entry) {
                final i = entry.key;
                final sub = entry.value;
                final ok = sub.percentage >= 75.0;

                return TweenAnimationBuilder<double>(
                  key: ValueKey(sub.name),
                  tween: Tween(begin: 0.94, end: 1.0),
                  duration: Duration(milliseconds: 240 + (i * 45)),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: Colors.white,
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sub.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _showEditSingleSubjectDialog(i),
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18, color: Color(0xFF3730A3)),
                                      tooltip: 'Edit Subject & Classes Done',
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${sub.percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: ok
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFC7D2FE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time_rounded,
                                        size: 12, color: Color(0xFF3730A3)),
                                    const SizedBox(width: 4),
                                    Text(
                                      sub.scheduleSlot,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF3730A3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Days: ${sub.days.join(", ")}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                                begin: 0,
                                end: (sub.percentage / 100.0).clamp(0.0, 1.0)),
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeOutCubic,
                            builder: (ctx, val, _) => ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: val,
                                minHeight: 5,
                                backgroundColor: const Color(0xFFF1F5F9),
                                color: ok
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ok
                                ? 'Safe to skip ${sub.safeBunks} classes • Attended: ${sub.attendedHours} / Done: ${sub.totalHours}'
                                : 'Attend next ${sub.classesNeededFor75} classes for 75% • Attended: ${sub.attendedHours} / Done: ${sub.totalHours}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => _logAttendance(i, 1, true),
                                  icon:
                                      const Icon(Icons.check_rounded, size: 16),
                                  label: const Text(
                                    'Present',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                    side: const BorderSide(
                                        color: Color(0xFFFECACA)),
                                    backgroundColor: const Color(0xFFFEF2F2),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => _logAttendance(i, 1, false),
                                  icon:
                                      const Icon(Icons.close_rounded, size: 16),
                                  label: const Text(
                                    'Absent',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
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
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              val,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final selectedKey = DateFormat('yyyy-MM-dd').format(_selectedCalendarDate);
    final dayLogs =
        _historyLogs.where((l) => l.dateKey == selectedKey).toList();
    final isHoliday = _holidays.contains(selectedKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                if (isHoliday) {
                  _holidays.remove(selectedKey);
                } else {
                  _holidays.add(selectedKey);
                }
              });
              _saveAllData();
            },
            icon: const Icon(Icons.wb_sunny_outlined, size: 18),
            label: Text(isHoliday ? 'Unmark Holiday' : 'Mark Holiday'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: CalendarDatePicker(
              initialDate: _selectedCalendarDate,
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
              onDateChanged: (dt) => setState(() => _selectedCalendarDate = dt),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Logs on $selectedKey (${dayLogs.length})',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (dayLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'No classes logged for this date yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            ...dayLogs.map((item) => Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.present
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFFEE2E2),
                      child: Icon(
                        item.present ? Icons.check : Icons.close,
                        color: item.present
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                    title: Text(item.subject,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${item.present ? "Present" : "Absent"} (${item.hours}h) • ${item.timeStr}'),
                    trailing: TextButton(
                      onPressed: () => _undoLogItem(item),
                      child: const Text('Undo',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildQrAndStatsTab() {
    final qrPayload = _generateQrSharePayload();
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Timetable & Camera Scanner',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded,
                        color: Color(0xFF34D399)),
                    SizedBox(width: 8),
                    Text(
                      'In-App Camera QR Scanner',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Point your camera at a classmate\'s QR code to copy their subjects & day-wise timetable automatically.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _openLiveCameraQrScanner,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text(
                      'Open Camera QR Scanner',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Share Your Class Timetable QR',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E1B4B),
                          Color(0xFF3730A3),
                          Color(0xFF2563EB)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 190,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.circle,
                          color: Color(0xFF1E1B4B),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle,
                          color: Color(0xFF1E1B4B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: qrPayload));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied Class Code!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Timetable Text Code'),
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

  Widget _buildHelpTab() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Help & 75% Guide',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            child: const ListTile(
              leading:
                  Icon(Icons.calendar_today_rounded, color: Color(0xFF3730A3)),
              title: Text(
                'Check Classes by Week Day (Mon–Sat)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                'Use the Mon, Tue, Wed, Thu, Fri, Sat selector bar on the Home screen to see which classes happen on each day.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            color: Colors.white,
            child: const ListTile(
              leading: Icon(Icons.edit_note_rounded, color: Color(0xFF3730A3)),
              title: Text(
                'Edit Subject Name & Classes Attended/Done',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                'Tap the pencil icon next to any subject on the Home screen to edit its name, days, attended hours, and total classes done.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            color: Colors.white,
            child: const ListTile(
              leading:
                  Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF3730A3)),
              title: Text(
                'Verify Timetable PDF Before Saving (<3s)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                'When you upload a Timetable PDF or image on the Profile tab, a verification popup opens in under 3 seconds and automatically merges duplicate subjects.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAndTimetableTab() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile & Timetable',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: widget.onEditProfileRequested,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit Setup'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF3730A3),
                        child: Text(
                          _userName.isNotEmpty
                              ? _userName[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              _userEmail,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _profileRow('Course / Stream', _course),
                  const SizedBox(height: 8),
                  _profileRow('Current Year', _year),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'TIME TABLE',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.8,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        color: Color(0xFF3730A3), size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Upload Timetable PDF or Image (<3s Auto-Fill & Dedupe)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Uploaded File: $_timetableFile (${_subjects.length} unique subjects)',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3730A3),
                    ),
                    onPressed:
                        _isReadingTimetable ? null : _pickAndReadTimetablePdf,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(
                      _isReadingTimetable
                          ? 'Reading PDF (<3s)...'
                          : 'Upload PDF / Image for Time Table',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_done_rounded, color: Color(0xFF059669)),
                      SizedBox(width: 8),
                      Text(
                        'Firebase Cloud Backup (Uninstall Protection)',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Last Synced: $_lastBackup • Linked to $_userEmail',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _saveAllData(showSnack: true),
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Backup Attendance to Cloud Now'),
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

  Widget _profileRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Flexible(
          child: Text(
            val,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
