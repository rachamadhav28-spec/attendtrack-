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

import 'theme/app_theme.dart';

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
      title: 'Attendance Track',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const RootFlowController(),
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
    this.scheduleSlot = '09:30 AM',
    List<String>? days,
  }) : days = days ?? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  double get percentage =>
      totalHours == 0 ? 100.0 : (attendedHours / totalHours) * 100.0;

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
        scheduleSlot: json['scheduleSlot'] ?? '09:30 AM',
        days: json['days'] != null
            ? List<String>.from(json['days'])
            : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
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
    } catch (e) {}
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
            _initialDashboardTab = 3;
          });
        },
      );
    }
    return MainDashboardScreen(
      initialTab: _initialDashboardTab,
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
  String _selectedYear = '1st Year';
  bool _isRestoring = false;

  Future<void> _handleRestoreFromCloud() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() => _isRestoring = true);
    final data = await CloudBackupService.restoreUserFromFirestore(email);
    setState(() => _isRestoring = false);

    if (data == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No backup found')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', data['userName'] ?? 'Student');
    await prefs.setString('user_email', email);
    await prefs.setString('course', data['course'] ?? 'B.Tech');
    await prefs.setString('year', data['year'] ?? '1st Year');
    if (data['subjects'] != null) {
      await prefs.setString('subjects', jsonEncode(data['subjects']));
    }
    if (data['historyLogs'] != null) {
      await prefs.setString('history_logs_v2', jsonEncode(data['historyLogs']));
    }
    await prefs.setBool('is_onboarded', true);

    if (!mounted) return;
    widget.onCompletedOpenProfile();
  }

  Future<void> _saveAndGoToProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final email = _emailCtrl.text.trim().isEmpty
        ? '${name.toLowerCase()}@gmail.com'
        : _emailCtrl.text.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    await prefs.setString('course', _selectedCourse);
    await prefs.setString('year', _selectedYear);

    if ((prefs.getString('subjects') ?? '').isEmpty) {
      final defaultSubs = [
        SubjectModel(name: 'Mathematics'),
        SubjectModel(name: 'Physics'),
        SubjectModel(name: 'Data Structures'),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Icon(Icons.calendar_month, size: 64, color: AppTheme.primary),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Student Setup',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'Enter name'),
              ),
              const SizedBox(height: 16),
              const Text('Course', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: ['B.Tech', 'Degree', 'Other'].map((c) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(c, textAlign: TextAlign.center),
                        ),
                        selected: _selectedCourse == c,
                        onSelected: (_) => setState(() => _selectedCourse = c),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Year', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedYear,
                items: ['1st Year', '2nd Year', '3rd Year', '4th Year']
                    .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedYear = v!),
              ),
              const SizedBox(height: 16),
              const Text('Backup Email',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(hintText: 'email@gmail.com'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveAndGoToProfile,
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isRestoring ? null : _handleRestoreFromCloud,
                  child: Text(_isRestoring ? 'Restoring...' : 'Backup'),
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
  const MainDashboardScreen({super.key, required this.initialTab});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentTab = 0;
  String _userName = 'Student';
  String _userEmail = 'student@gmail.com';
  String _course = 'B.Tech';
  String _year = '1st Year';
  String _timetableFile = 'No file';
  String _lastBackup = 'Just now';

  List<SubjectModel> _subjects = [];
  Set<String> _holidays = {};
  List<AttendanceLogItem> _historyLogs = [];

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _loadAllData();
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
      _year = prefs.getString('year') ?? '1st Year';
      _timetableFile = prefs.getString('timetable_file') ?? 'No file';
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
    await prefs.setString(
        'history_logs_v2', jsonEncode(_historyLogs.map((l) => l.toJson()).toList()));
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
        const SnackBar(content: Text('Backup saved')),
      );
    }
  }

  int get _totalConducted => _subjects.fold(0, (sum, s) => sum + s.totalHours);
  int get _totalPresent => _subjects.fold(0, (sum, s) => sum + s.attendedHours);
  int get _totalAbsent => _totalConducted - _totalPresent;
  double get _overallPct =>
      _totalConducted == 0 ? 100.0 : (_totalPresent / _totalConducted) * 100.0;

  void _logAttendance(int index, int hours, bool present) {
    final now = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('hh:mm a').format(now);

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

  Future<void> _pickTimetable() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: true);
      if (res == null || res.files.isEmpty) return;
      setState(() {
        _timetableFile = res.files.first.name;
      });
      _saveAllData(showSnack: true);
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: [
        _buildHomeTab(),
        _buildHistoryTab(),
        _buildQrTab(),
        _buildProfileTab(),
      ][_currentTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (idx) => setState(() => _currentTab = idx),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined), label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.qr_code_rounded), label: 'QR'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final isSafe = _overallPct >= 75.0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text('$_course - $_year',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  isSafe ? Icons.check_circle : Icons.warning_rounded,
                  color: isSafe ? AppTheme.good : AppTheme.bad,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance: ${_overallPct.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      isSafe ? 'Safe' : 'Shortage',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSafe ? AppTheme.good : AppTheme.bad,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Text('Total'),
                      Text('$_totalConducted',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Text('Present'),
                      Text('$_totalPresent',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.good)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Text('Absent'),
                      Text('$_totalAbsent',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: AppTheme.bad)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subjects',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            TextButton(
              onPressed: () {
                setState(() => _subjects.add(SubjectModel(name: 'Subject')));
                _saveAllData();
              },
              child: const Text('Add Subject'),
            ),
          ],
        ),
        ..._subjects.asMap().entries.map((entry) {
          final i = entry.key;
          final sub = entry.value;
          final ok = sub.percentage >= 75.0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(sub.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${sub.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: ok ? AppTheme.good : AppTheme.bad)),
                          if (ok)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.check, size: 16, color: AppTheme.good),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: (sub.percentage / 100.0).clamp(0.0, 1.0),
                    ),
                    duration: const Duration(milliseconds: 300),
                    builder: (ctx, val, _) => LinearProgressIndicator(
                      value: val,
                      minHeight: 4,
                      color: ok ? AppTheme.good : AppTheme.bad,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.good),
                          onPressed: () => _logAttendance(i, 1, true),
                          child: const Text('Present'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.bad),
                          onPressed: () => _logAttendance(i, 1, false),
                          child: const Text('Absent'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _historyLogs.isEmpty
            ? [const Center(child: Text('No history'))]
            : _historyLogs
                .map((item) => Card(
                      child: ListTile(
                        leading: Icon(
                          item.present ? Icons.check_circle : Icons.cancel,
                          color: item.present ? AppTheme.good : AppTheme.bad,
                        ),
                        title: Text(item.subject),
                        subtitle: Text('${item.dateKey} • ${item.timeStr}'),
                        trailing: TextButton(
                          onPressed: () => _undoLogItem(item),
                          child: const Text('Undo',
                              style: TextStyle(color: AppTheme.bad)),
                        ),
                      ),
                    ))
                .toList(),
      ),
    );
  }

  Widget _buildQrTab() {
    return Scaffold(
      appBar: AppBar(title: const Text('QR')),
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(data: 'ATTENDTRACK', size: 180),
                const SizedBox(height: 16),
                const Text('Scan Timetable QR'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_userName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(_userEmail),
                  const Divider(),
                  Text('Course: $_course'),
                  Text('Year: $_year'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Timetable',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('File: $_timetableFile'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _pickTimetable,
                    child: const Text('Upload'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Backup',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Last: $_lastBackup'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _saveAllData(showSnack: true),
                    child: const Text('Backup'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}mmm
