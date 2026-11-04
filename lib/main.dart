import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AttendTrackApp());
}

// ============================================================================
// HELPERS
// ============================================================================
String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

Color _statusColor(double pct) {
  if (pct >= 75.0) return const Color(0xFF22C55E); // Safe green
  if (pct >= 65.0) return const Color(0xFFF59E0B); // Condonation amber
  return const Color(0xFFEF4444); // Shortage red
}

class AttendTrackApp extends StatelessWidget {
  const AttendTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AttendTrack 75%',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2563EB),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardTheme: CardTheme(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const RootDecider(),
    );
  }
}

// ============================================================================
// STATES & COLLEGES DATABASE
// ============================================================================
class IndiaCollegeDatabase {
  static const List<String> allStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Delhi (NCT)',
    'Jammu & Kashmir',
    'Puducherry',
    'Chandigarh',
  ];

  static const Map<String, List<String>> btechColleges = {
    'Telangana': [
      'University College of Engineering & Technology, MGU Nalgonda',
      'JNTUH College of Engineering, Hyderabad',
      'University College of Engineering, Osmania University (OU)',
      'Chaitanya Bharathi Institute of Technology (CBIT), Hyderabad',
      'VNR Vignana Jyothi Institute of Engineering & Technology (VNRVJIET)',
      'Vasavi College of Engineering, Hyderabad',
      'Gokaraju Rangaraju Institute of Engineering & Technology (GRIET)',
      'CVR College of Engineering, Ibrahimpatnam',
      'MVSR Engineering College, Hyderabad',
      'Kakatiya Institute of Technology & Science (KITS), Warangal',
      'NIT Warangal',
      'IIT Hyderabad',
      'IIIT Hyderabad',
      'Malla Reddy Engineering College (MREC)',
      'CMR College of Engineering & Technology',
      'Anurag University, Hyderabad',
      'SR University, Warangal',
      'Jaya Prakash Narayan College of Engineering (JPNCE), Mahabubnagar',
      'SVS Group of Institutions, Bheemaram',
      'Vardhaman College of Engineering, Shamshabad',
      'BVRIT Narsapur',
      'MGIT Hyderabad',
    ],
    'Andhra Pradesh': [
      'JNTUK University College of Engineering, Kakinada',
      'JNTUA College of Engineering, Anantapur',
      'Andhra University College of Engineering (AUCE), Visakhapatnam',
      'SVU College of Engineering, Tirupati',
      'Gayatri Vidya Parishad College of Engineering (GVPCE), Vizag',
      'VR Siddhartha Engineering College, Vijayawada',
      'RVR & JC College of Engineering, Guntur',
      'Vishnu Institute of Technology, Bhimavaram',
      'Sree Vidyanikethan Engineering College, Tirupati',
      'GITAM University, Visakhapatnam',
      'KL University, Vijayawada',
      'SRM University AP, Amaravati',
      'VIT-AP University, Amaravati',
      'IIT Tirupati',
      'NIT Andhra Pradesh, Tadepalligudem',
    ],
    'Karnataka': [
      'RV College of Engineering (RVCE), Bengaluru',
      'BMS College of Engineering (BMSCE), Bengaluru',
      'MS Ramaiah Institute of Technology (MSRIT), Bengaluru',
      'PES University, Bengaluru',
      'NIT Karnataka (NITK), Surathkal',
      'IIIT Bangalore',
      'Dayananda Sagar College of Engineering, Bengaluru',
      'Manipal Institute of Technology (MIT), Manipal',
      'BMS Institute of Technology (BMSIT)',
    ],
    'Tamil Nadu': [
      'College of Engineering, Guindy (CEG - Anna University), Chennai',
      'MIT Campus, Anna University, Chennai',
      'PSG College of Technology, Coimbatore',
      'SSN College of Engineering, Chennai',
      'IIT Madras',
      'NIT Tiruchirappalli (NIT Trichy)',
      'VIT Vellore',
      'SRM Institute of Science & Technology, Kattankulathur',
      'Sathyabama Institute of Science & Technology',
    ],
    'Maharashtra': [
      'College of Engineering Pune (COEP Tech)',
      'VJTI Mumbai',
      'IIT Bombay',
      'VNIT Nagpur',
      'Sardar Patel Institute of Technology (SPIT), Mumbai',
      'PICT Pune',
      'VIT Pune',
      'KJ Somaiya College of Engineering, Mumbai',
    ],
    'Delhi (NCT)': [
      'IIT Delhi',
      'Delhi Technological University (DTU)',
      'Netaji Subhas University of Technology (NSUT)',
      'IIIT Delhi',
      'NIT Delhi',
      'Jamia Millia Islamia (Faculty of Engineering)',
    ],
  };

  static const Map<String, List<String>> degreeColleges = {
    'Telangana': [
      'MVS Government Arts & Science Degree College, Mahabubnagar',
      'NG College (Nagarjuna Government College), Nalgonda',
      'Nizam College, Hyderabad (OU)',
      'University College of Science, Saifabad (OU)',
      'Loyola Academy Degree & PG College, Alwal',
      'St. Francis College for Women, Begumpet',
      "St. Ann's College for Women, Mehdipatnam",
      "Bhavan's Vivekananda College, Sainikpuri",
      'Badruka College of Commerce & Arts, Kachiguda',
      "Aurora's Degree & PG College, Chikkadpally",
      'AV College of Arts, Science & Commerce, Hyderabad',
      'Kakatiya Government Degree College, Hanamkonda',
      'Government City College, Nayapul, Hyderabad',
      'Tara Government Degree College, Sangareddy',
      'SR & BGNR Government Arts & Science College, Khammam',
    ],
    'Andhra Pradesh': [
      'Andhra Loyola College, Vijayawada',
      'PB Siddhartha College of Arts & Science, Vijayawada',
      'Dr. Lankapalli Bullayya College, Visakhapatnam',
      "St. Joseph's College for Women, Visakhapatnam",
      'PR Government College, Kakinada',
      'Government College (Autonomous), Rajahmundry',
      'Silver Jubilee Government College, Kurnool',
      'JKC College, Guntur',
      'SV Arts College, Tirupati',
    ],
    'Karnataka': [
      'Christ University, Bengaluru',
      "St. Joseph's University, Bengaluru",
      'Mount Carmel College, Bengaluru',
      'Kristu Jayanti College, Bengaluru',
      'Jain University, Bengaluru',
      'St. Aloysius College, Mangaluru',
    ],
    'Tamil Nadu': [
      'Loyola College, Chennai',
      'Madras Christian College (MCC), Chennai',
      'Presidency College, Chennai',
      'Stella Maris College, Chennai',
      'PSG College of Arts & Science, Coimbatore',
      'Ethiraj College for Women, Chennai',
    ],
    'Maharashtra': [
      "St. Xavier's College, Mumbai",
      'Fergusson College, Pune',
      'Jai Hind College, Mumbai',
      'Narsee Monjee College of Commerce & Economics, Mumbai',
      'HR College of Commerce & Economics, Mumbai',
      'Symbiosis College of Arts & Commerce, Pune',
    ],
    'Delhi (NCT)': [
      "St. Stephen's College, Delhi University",
      'Hindu College, Delhi University',
      'Shri Ram College of Commerce (SRCC), DU',
      'Hansraj College, Delhi University',
      'Miranda House, Delhi University',
      'Kirori Mal College, Delhi University',
    ],
  };

  static List<String> getColleges(String course, String state) {
    final map = course == 'B.Tech' ? btechColleges : degreeColleges;
    final list = List<String>.from(map[state] ?? []);
    if (list.isEmpty) {
      list.addAll([
        'Government ${course == 'B.Tech' ? 'Engineering' : 'Degree'} College, $state',
        'State University ${course == 'B.Tech' ? 'College of Engineering' : 'Degree College'}, $state',
      ]);
    }
    return list;
  }
}

// ============================================================================
// DATA MODEL
// ============================================================================
class SubjectModel {
  String name;
  int attendedHours;
  int totalHours;

  SubjectModel({
    required this.name,
    this.attendedHours = 0,
    this.totalHours = 0,
  });

  double get percentage =>
      totalHours == 0 ? 100.0 : (attendedHours / totalHours) * 100.0;

  // How many hours can be skipped and still stay >= 75%?
  int get safeBunkHours {
    if (totalHours == 0 || percentage < 75.0) return 0;
    return ((attendedHours / 0.75) - totalHours).floor();
  }

  // How many continuous hours must be attended to reach 75%?
  int get requiredHoursFor75 {
    if (totalHours == 0 || percentage >= 75.0) return 0;
    final needed = (3 * totalHours) - (4 * attendedHours);
    return needed > 0 ? needed : 1;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'attendedHours': attendedHours,
        'totalHours': totalHours,
      };

  factory SubjectModel.fromJson(Map<String, dynamic> json) => SubjectModel(
        name: (json['name'] ?? '') as String,
        attendedHours: (json['attendedHours'] ?? 0) as int,
        totalHours: (json['totalHours'] ?? 0) as int,
      );
}

// ============================================================================
// ROOT DECIDER (ONBOARDING vs DASHBOARD)
// ============================================================================
class RootDecider extends StatefulWidget {
  const RootDecider({super.key});

  @override
  State<RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<RootDecider> {
  bool? _isOnboarded;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isOnboarded = prefs.getBool('is_onboarded') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnboarded == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isOnboarded!) {
      return MainHomeScreen(
        onEditProfile: () => setState(() {
          _isEditing = true;
          _isOnboarded = false;
        }),
      );
    }
    return OnboardingScreen(
      isEditing: _isEditing,
      onFinished: () => setState(() {
        _isOnboarded = true;
        _isEditing = false;
      }),
    );
  }
}

// ============================================================================
// ONBOARDING (FIRST SETUP + EDIT PROFILE, KEEPS ATTENDANCE WHEN EDITING)
// ============================================================================
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final bool isEditing;
  const OnboardingScreen({
    super.key,
    required this.onFinished,
    this.isEditing = false,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _selectedCourse = 'B.Tech';
  String _selectedYear = '1st Year';
  String _selectedSemester = 'Semester 1';
  String _selectedState = 'Telangana';
  String? _selectedCollege;
  bool _useCustomCollege = false;
  final TextEditingController _customCollegeCtrl = TextEditingController();
  final TextEditingController _collegeSearchCtrl = TextEditingController();

  List<SubjectModel> _subjects = [
    SubjectModel(name: 'Mathematics'),
    SubjectModel(name: 'Programming in C'),
    SubjectModel(name: 'Programming Lab'),
    SubjectModel(name: 'English'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCollege =
        IndiaCollegeDatabase.getColleges(_selectedCourse, _selectedState).first;
    if (widget.isEditing) _loadExisting();
  }

  @override
  void dispose() {
    _customCollegeCtrl.dispose();
    _collegeSearchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<String> get _years => _selectedCourse == 'B.Tech'
      ? ['1st Year', '2nd Year', '3rd Year', '4th Year']
      : ['1st Year', '2nd Year', '3rd Year'];

  void _ensureYearValid() {
    if (!_years.contains(_selectedYear)) _selectedYear = '1st Year';
  }

  void _onCourseOrStateChanged() {
    _ensureYearValid();
    final colleges =
        IndiaCollegeDatabase.getColleges(_selectedCourse, _selectedState);
    _selectedCollege = colleges.isNotEmpty ? colleges.first : null;
  }

  // Load saved profile + subjects (with attendance) when editing
  Future<void> _loadExisting() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('subjects');
    if (!mounted) return;
    setState(() {
      _selectedCourse = prefs.getString('course') ?? _selectedCourse;
      _selectedYear = prefs.getString('year') ?? _selectedYear;
      _selectedSemester = prefs.getString('semester') ?? _selectedSemester;
      _selectedState = prefs.getString('state') ?? _selectedState;
      _ensureYearValid();

      final savedCollege = prefs.getString('college') ?? '';
      final list =
          IndiaCollegeDatabase.getColleges(_selectedCourse, _selectedState);
      if (list.contains(savedCollege)) {
        _useCustomCollege = false;
        _selectedCollege = savedCollege;
      } else {
        _useCustomCollege = true;
        _customCollegeCtrl.text = savedCollege;
      }

      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _subjects = decoded
            .map((e) => SubjectModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    });
  }

  Future<void> _saveAndStart() async {
    final collegeName = _useCustomCollege
        ? _customCollegeCtrl.text.trim()
        : (_selectedCollege ?? '');

    if (collegeName.isEmpty) {
      _snack('Please select or type your college name');
      return;
    }
    if (_subjects.isEmpty) {
      _snack('Add at least 1 subject to start');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('course', _selectedCourse);
    await prefs.setString('year', _selectedYear);
    await prefs.setString('semester', _selectedSemester);
    await prefs.setString('state', _selectedState);
    await prefs.setString('college', collegeName);
    await prefs.setString(
      'subjects',
      jsonEncode(_subjects.map((s) => s.toJson()).toList()),
    );
    await prefs.setBool('is_onboarded', true);

    if (!mounted) return;
    widget.onFinished();
  }

  void _showAddSubjectDialog() {
    final nameCtrl = TextEditingController();
    final attendedCtrl = TextEditingController(text: '0');
    final totalCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Subject / Lab'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Subject or Lab Name',
                hintText: 'e.g. Data Structures / Python Lab',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Joining mid-semester? Enter past hours (optional):',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: attendedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Hours Attended'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: totalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total Hours Held'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final tot = int.tryParse(totalCtrl.text) ?? 0;
              final att = int.tryParse(attendedCtrl.text) ?? 0;
              setState(() {
                _subjects.add(SubjectModel(
                  name: name,
                  attendedHours: att <= tot ? att : tot,
                  totalHours: tot,
                ));
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Applies a share code from a CR/friend. Keeps hours for subjects whose
  // names already exist, so importing never erases attendance.
  Future<void> _applyImport(String code) async {
    final data = jsonDecode(utf8.decode(base64Decode(code.trim())))
        as Map<String, dynamic>;
    final course = data['course'] as String?;
    final state = data['state'] as String?;
    final year = data['year'] as String?;
    final college = (data['college'] as String?) ?? '';
    final names = (data['subjects'] as List?) ?? [];
    if (names.isEmpty) throw const FormatException('no subjects');
    final holidays =
        (data['holidays'] as List?)?.map((e) => e.toString()).toList();

    final oldByName = {for (final s in _subjects) s.name: s};

    setState(() {
      if (course == 'B.Tech' || course == 'Degree') _selectedCourse = course!;
      if (state != null && IndiaCollegeDatabase.allStates.contains(state)) {
        _selectedState = state;
      }
      if (year != null) _selectedYear = year;
      _onCourseOrStateChanged();
      _useCustomCollege = college.isNotEmpty;
      _customCollegeCtrl.text = college;
      _subjects = names.map((n) {
        final name = n.toString();
        final old = oldByName[name];
        return SubjectModel(
          name: name,
          attendedHours: old?.attendedHours ?? 0,
          totalHours: old?.totalHours ?? 0,
        );
      }).toList();
    });

    if (holidays != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('holidays', holidays);
    }
  }

  void _showImportFromFriendDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Setup from Friend / CR'),
        content: TextField(
          controller: codeCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Paste Class Code Here',
            hintText: 'Paste the code shared on WhatsApp by your CR or friend...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _applyImport(codeCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                _snack('Class subjects & holidays imported!');
              } catch (_) {
                _snack('Invalid share code. Please check again.');
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allCollegesForState =
        IndiaCollegeDatabase.getColleges(_selectedCourse, _selectedState);
    final searchQuery = _collegeSearchCtrl.text.trim().toLowerCase();
    final filteredColleges = allCollegesForState
        .where((c) => c.toLowerCase().contains(searchQuery))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing
            ? 'Edit Your Profile'
            : 'Welcome to AttendTrack 75%'),
        actions: [
          TextButton.icon(
            onPressed: _showImportFromFriendDialog,
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Import Code'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Course
            const Text(
              '1. Select Your Course',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: ['B.Tech', 'Degree'].map((course) {
                final selected = _selectedCourse == course;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          course == 'B.Tech'
                              ? '🎓 B.Tech / B.E.'
                              : '📘 Degree (B.Sc/B.Com/BCA)',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _selectedCourse = course;
                          _onCourseOrStateChanged();
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 2. Year & Semester
            const Text(
              '2. Select Year & Semester',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    items: _years
                        .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedYear = val!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSemester,
                    decoration: const InputDecoration(
                      labelText: 'Semester',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Semester 1', 'Semester 2']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedSemester = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 3. State
            const Text(
              '3. Select Your State',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedState,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'State / UT (All India)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: IndiaCollegeDatabase.allStates
                  .map((st) => DropdownMenuItem(value: st, child: Text(st)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedState = val!;
                  _onCourseOrStateChanged();
                });
              },
            ),
            const SizedBox(height: 20),

            // 4. College
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '4. Select Your $_selectedCourse College',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _useCustomCollege = !_useCustomCollege),
                  child: Text(
                    _useCustomCollege ? 'Pick from List' : 'Type Manually',
                  ),
                ),
              ],
            ),
            if (_useCustomCollege)
              TextField(
                controller: _customCollegeCtrl,
                decoration: InputDecoration(
                  labelText: 'Enter Your $_selectedCourse College Name',
                  hintText: 'Type full college name & city...',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.school_outlined),
                ),
              )
            else ...[
              TextField(
                controller: _collegeSearchCtrl,
                decoration: InputDecoration(
                  labelText:
                      'Search $_selectedCourse Colleges in $_selectedState',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: filteredColleges.contains(_selectedCollege)
                    ? _selectedCollege
                    : (filteredColleges.isNotEmpty
                        ? filteredColleges.first
                        : null),
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select College',
                  border: OutlineInputBorder(),
                ),
                items: filteredColleges
                    .map((col) => DropdownMenuItem(
                          value: col,
                          child: Text(col, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCollege = val),
              ),
            ],
            const SizedBox(height: 24),

            // 5. Subjects
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '5. Your Subjects & Labs',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                FilledButton.tonalIcon(
                  onPressed: _showAddSubjectDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Subject'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._subjects.asMap().entries.map((entry) {
              final idx = entry.key;
              final sub = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(sub.name),
                  subtitle: Text(
                    sub.totalHours > 0
                        ? 'Attendance: ${sub.attendedHours}/${sub.totalHours} hrs (${sub.percentage.toStringAsFixed(1)}%)'
                        : 'Starting fresh (0/0 hrs)',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    onPressed: () => setState(() => _subjects.removeAt(idx)),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _saveAndStart,
                icon: const Icon(Icons.rocket_launch),
                label: Text(
                  widget.isEditing
                      ? 'Save Changes'
                      : 'Start Tracking My 75% Attendance',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MAIN HOME (DASHBOARD + CALENDAR + SHARE)
// ============================================================================
class MainHomeScreen extends StatefulWidget {
  final VoidCallback onEditProfile;
  const MainHomeScreen({super.key, required this.onEditProfile});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _tabIndex = 0;
  String _course = '';
  String _year = '';
  String _semester = '';
  String _state = '';
  String _college = '';
  List<SubjectModel> _subjects = [];
  Set<String> _holidays = {};
  Map<String, List<String>> _dailyLogs = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final subRaw = prefs.getString('subjects') ?? '[]';
    final logsRaw = prefs.getString('daily_logs') ?? '{}';
    final List<dynamic> decodedSubs = jsonDecode(subRaw);
    final Map<String, dynamic> decodedLogs = jsonDecode(logsRaw);
    if (!mounted) return;
    setState(() {
      _course = prefs.getString('course') ?? 'B.Tech';
      _year = prefs.getString('year') ?? '1st Year';
      _semester = prefs.getString('semester') ?? 'Semester 1';
      _state = prefs.getString('state') ?? 'Telangana';
      _college = prefs.getString('college') ?? '';
      _subjects = decodedSubs
          .map((e) => SubjectModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _holidays = (prefs.getStringList('holidays') ?? []).toSet();
      _dailyLogs = decodedLogs.map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      );
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'subjects',
      jsonEncode(_subjects.map((s) => s.toJson()).toList()),
    );
    await prefs.setStringList('holidays', _holidays.toList());
    await prefs.setString('daily_logs', jsonEncode(_dailyLogs));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int get _totalAttended =>
      _subjects.fold(0, (sum, s) => sum + s.attendedHours);
  int get _totalConducted =>
      _subjects.fold(0, (sum, s) => sum + s.totalHours);

  double get _overallPercentage =>
      _totalConducted == 0 ? 100.0 : (_totalAttended / _totalConducted) * 100.0;

  int get _overallSafeBunks {
    if (_totalConducted == 0 || _overallPercentage < 75.0) return 0;
    return ((_totalAttended / 0.75) - _totalConducted).floor();
  }

  int get _overallNeededFor75 {
    if (_totalConducted == 0 || _overallPercentage >= 75.0) return 0;
    final needed = (3 * _totalConducted) - (4 * _totalAttended);
    return needed > 0 ? needed : 1;
  }

  void _markAttendance(int subIndex, int hours, bool isPresent) {
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    if (_holidays.contains(todayKey)) {
      _snack('Today is marked as a Holiday! Unmark holiday first.');
      return;
    }
    if (now.weekday == DateTime.sunday) {
      _snack('Sunday: no classes. Attendance cannot be marked.');
      return;
    }

    setState(() {
      final sub = _subjects[subIndex];
      sub.totalHours += hours;
      if (isPresent) sub.attendedHours += hours;
      _dailyLogs.putIfAbsent(todayKey, () => []);
      _dailyLogs[todayKey]!.add(
        '${sub.name}: ${isPresent ? 'Present' : 'Absent'} (${hours}h)',
      );
    });
    _saveData();
  }

  void _toggleHoliday(DateTime date) {
    final key = _dateKey(date);
    setState(() {
      if (_holidays.contains(key)) {
        _holidays.remove(key);
      } else {
        _holidays.add(key);
      }
    });
    _saveData();
  }

  String _generateShareCode() {
    final payload = {
      'course': _course,
      'year': _year,
      'semester': _semester,
      'state': _state,
      'college': _college,
      'subjects': _subjects.map((s) => s.name).toList(),
      'holidays': _holidays.toList(),
    };
    return base64Encode(utf8.encode(jsonEncode(payload)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_course • $_year ($_semester)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              '$_college, $_state',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Edit College / Profile',
            icon: const Icon(Icons.settings_outlined),
            onPressed: widget.onEditProfile,
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildDashboardTab(),
          _buildCalendarTab(),
          _buildShareTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: '75% Tracker',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Monthly Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2),
            selectedIcon: Icon(Icons.qr_code),
            label: 'CR / Friend Share',
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 1: 75% DASHBOARD
  // --------------------------------------------------------------------------
  Widget _buildDashboardTab() {
    final todayKey = _dateKey(DateTime.now());
    final isTodayHoliday = _holidays.contains(todayKey);
    final pct = _overallPercentage;
    final color = _statusColor(pct);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      height: 92,
                      width: 92,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: (pct / 100.0).clamp(0.0, 1.0),
                            strokeWidth: 10,
                            backgroundColor: Colors.white12,
                            color: color,
                          ),
                          Center(
                            child: Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pct >= 75.0
                                ? 'SAFE ZONE (>= 75%)'
                                : pct >= 65.0
                                    ? 'CONDONATION ZONE (65% - 74%)'
                                    : 'SHORTAGE DANGER (< 65%)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Total Hours: $_totalAttended attended / $_totalConducted conducted',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _totalConducted == 0
                                ? 'Tap +1h or +3h Lab below as classes finish!'
                                : pct >= 75.0
                                    ? '🎉 You can safely bunk $_overallSafeBunks hours and stay at 75%.'
                                    : '⚠️ Attend the next $_overallNeededFor75 hours continuously to hit 75%.',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleHoliday(DateTime.now()),
                    icon: Icon(
                      isTodayHoliday ? Icons.check_circle : Icons.beach_access,
                      color: isTodayHoliday ? Colors.amber : Colors.white70,
                    ),
                    label: Text(
                      isTodayHoliday
                          ? 'Today is Marked as Holiday / No Classes (Tap to Undo)'
                          : 'Mark Today as Holiday / Exam / No Classes',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Subject-Wise Attendance (1 Hour = 1 Period)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        ..._subjects.asMap().entries.map((entry) {
          final i = entry.key;
          final sub = entry.value;
          final subPct = sub.percentage;
          final subColor = _statusColor(subPct);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          sub.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: subColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${subPct.toStringAsFixed(1)}% (${sub.attendedHours}/${sub.totalHours}h)',
                          style: TextStyle(
                            color: subColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sub.totalHours == 0
                        ? 'No classes logged yet'
                        : subPct >= 75.0
                            ? 'Safe to skip next ${sub.safeBunkHours} hrs'
                            : 'Attend next ${sub.requiredHoursFor75} hrs for 75%',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _markAttendance(i, 1, true),
                        child: const Text('+1h Present'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _markAttendance(i, 3, true),
                        child: const Text('+3h Lab Present'),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        onPressed: () => _markAttendance(i, 1, false),
                        child: const Text('1h Absent'),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        onPressed: () => _markAttendance(i, 3, false),
                        child: const Text('3h Lab Absent'),
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

  // --------------------------------------------------------------------------
  // TAB 2: MONTHLY CALENDAR
  // --------------------------------------------------------------------------
  Widget _buildCalendarTab() {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final monthName = DateFormat('MMMM yyyy').format(now);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '$monthName — Academic Calendar',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap any date to toggle Holiday / Festival / Exam day. Sundays are off by default.',
          style: TextStyle(fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (ctx, idx) {
            final dayNum = idx + 1;
            final date = DateTime(now.year, now.month, dayNum);
            final key = _dateKey(date);
            final isSunday = date.weekday == DateTime.sunday;
            final isHoliday = _holidays.contains(key) || isSunday;
            final hasLogs = (_dailyLogs[key] ?? []).isNotEmpty;

            return InkWell(
              onTap: isSunday ? null : () => _toggleHoliday(date),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: isHoliday
                      ? Colors.amber.withOpacity(0.2)
                      : hasLogs
                          ? Colors.green.withOpacity(0.25)
                          : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isHoliday
                        ? Colors.amber
                        : hasLogs
                            ? Colors.greenAccent
                            : Colors.white12,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNum',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isHoliday ? Colors.amber : Colors.white,
                      ),
                    ),
                    Text(
                      isHoliday
                          ? (isSunday ? 'Sunday' : 'Holiday')
                          : hasLogs
                              ? '${_dailyLogs[key]!.length} logs'
                              : '',
                      style: const TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // TAB 3: SHARE CODE
  // --------------------------------------------------------------------------
  Widget _buildShareTab() {
    final shareCode = _generateShareCode();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Share Subjects & Holidays with Classmates',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Any student or CR can share this QR or WhatsApp code so classmates don't have to type subjects and holidays manually.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: shareCode,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareCode));
                      _snack(
                          'Class Setup Code copied! Paste it in your WhatsApp group.');
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Code for WhatsApp Group'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
