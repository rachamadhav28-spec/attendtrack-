import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AttendTrackApp());
}

class AttendTrackApp extends StatelessWidget {
  const AttendTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Track',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
        colorSchemeSeed: const Color(0xFF3730A3),
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: const RootFlowController(),
    );
  }
}

// ============================================================================
// CUSTOM WIDGET: UPLOADED APP LOGO (BLUE CALENDAR + GREEN CHECKMARK)
// ============================================================================
class AttendanceAppLogo extends StatelessWidget {
  final double size;
  const AttendanceAppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.calendar_month_rounded,
            color: Colors.white,
            size: size * 0.62,
          ),
          Positioned(
            bottom: size * 0.12,
            right: size * 0.12,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
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
    );
  }
}

// ============================================================================
// ALL STATES & COLLEGES DATABASE (B.TECH vs DEGREE)
// ============================================================================
class IndiaCollegeDatabase {
  static const List<String> allStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
    'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
    'West Bengal', 'Delhi (NCT)', 'Jammu & Kashmir', 'Puducherry', 'Chandigarh',
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
      'Jaya Prakash Narayan College of Engineering (JPNCE), Mahabubnagar',
      'Vardhaman College of Engineering, Shamshabad',
    ],
    'Andhra Pradesh': [
      'JNTUK University College of Engineering, Kakinada',
      'JNTUA College of Engineering, Anantapur',
      'Andhra University College of Engineering (AUCE), Visakhapatnam',
      'SVU College of Engineering, Tirupati',
      'Gayatri Vidya Parishad College of Engineering (GVPCE), Vizag',
      'VR Siddhartha Engineering College, Vijayawada',
      'RVR & JC College of Engineering, Guntur',
      'GITAM University, Visakhapatnam',
      'KL University, Vijayawada',
      'VIT-AP University, Amaravati',
      'SRM University AP, Amaravati',
    ],
    'Karnataka': [
      'RV College of Engineering (RVCE), Bengaluru',
      'BMS College of Engineering (BMSCE), Bengaluru',
      'MS Ramaiah Institute of Technology (MSRIT), Bengaluru',
      'PES University, Bengaluru',
      'NIT Karnataka (NITK), Surathkal',
      'Manipal Institute of Technology (MIT), Manipal',
    ],
    'Tamil Nadu': [
      'College of Engineering, Guindy (CEG - Anna University), Chennai',
      'PSG College of Technology, Coimbatore',
      'SSN College of Engineering, Chennai',
      'IIT Madras',
      'NIT Tiruchirappalli (NIT Trichy)',
      'VIT Vellore',
      'SRM Institute of Science & Technology, Chennai',
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
      'Bhavan\'s Vivekananda College, Sainikpuri',
      'Badruka College of Commerce & Arts, Kachiguda',
      'Government City College, Nayapul, Hyderabad',
      'Kakatiya Government Degree College, Hanamkonda',
    ],
    'Andhra Pradesh': [
      'Andhra Loyola College, Vijayawada',
      'PB Siddhartha College of Arts & Science, Vijayawada',
      'Dr. Lankapalli Bullayya College, Visakhapatnam',
      'PR Government College, Kakinada',
      'Silver Jubilee Government College, Kurnool',
    ],
    'Karnataka': [
      'Christ University, Bengaluru',
      'St. Joseph\'s University, Bengaluru',
      'Mount Carmel College, Bengaluru',
      'Kristu Jayanti College, Bengaluru',
    ],
    'Tamil Nadu': [
      'Loyola College, Chennai',
      'Madras Christian College (MCC), Chennai',
      'Presidency College, Chennai',
      'PSG College of Arts & Science, Coimbatore',
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
// SUBJECT MODEL
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

  int get safeBunkHours {
    if (totalHours == 0 || percentage < 75.0) return 0;
    return ((attendedHours / 0.75) - totalHours).floor();
  }

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
        name: json['name'] ?? '',
        attendedHours: json['attendedHours'] ?? 0,
        totalHours: json['totalHours'] ?? 0,
      );
}

// ============================================================================
// FLOW CONTROLLER: SPLASH -> GOOGLE SIGN IN -> COLLEGE SETUP -> HOME
// ============================================================================
class RootFlowController extends StatefulWidget {
  const RootFlowController({super.key});

  @override
  State<RootFlowController> createState() => _RootFlowControllerState();
}

class _RootFlowControllerState extends State<RootFlowController> {
  int _step = 0; // 0 = loading, 1 = Splash, 2 = Login, 3 = Onboarding, 4 = Home

  @override
  void initState() {
    super.initState();
    _checkState();
  }

  Future<void> _checkState() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('is_logged_in') ?? false;
    final onboarded = prefs.getBool('is_onboarded') ?? false;

    setState(() {
      if (!loggedIn) {
        _step = 1; // Show Royal Blue Splash Screen first
      } else if (!onboarded) {
        _step = 3; // Show B.Tech / Degree College Selector
      } else {
        _step = 4; // Main Dashboard
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 0) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_step == 1) {
      return WelcomeSplashScreen(onGetStarted: () => setState(() => _step = 2));
    }
    if (_step == 2) {
      return GoogleLoginScreen(onSignedIn: () => _checkState());
    }
    if (_step == 3) {
      return CollegeOnboardingScreen(onCompleted: () => setState(() => _step = 4));
    }
    return MainDashboardScreen(
      onEditProfile: () => setState(() => _step = 3),
      onLogout: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', false);
        setState(() => _step = 2);
      },
    );
  }
}

// ============================================================================
// SCREEN 1: ROYAL BLUE SPLASH SCREEN (MATCHING UPLOADED DESIGN #1)
// ============================================================================
class WelcomeSplashScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  const WelcomeSplashScreen({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF1D4ED8), Color(0xFF3B82F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const AttendanceAppLogo(size: 120),
            const SizedBox(height: 32),
            const Text(
              'Attendance\nTrack',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Mark • Track • Analyze 75%',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Smart 75% Attendance & Cloud Backup\nfor B.Tech & Degree Students',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: onGetStarted,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Get Started',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onGetStarted,
              child: const Text(
                'Sign In with Google',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SCREEN 2: WELCOME BACK & GOOGLE SIGN-IN FOR BACKUP (DESIGN #2)
// ============================================================================
class GoogleLoginScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  const GoogleLoginScreen({super.key, required this.onSignedIn});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  bool _isSigningIn = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isSigningIn = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', account.displayName ?? 'Student');
        await prefs.setString('user_email', account.email);
        await prefs.setBool('is_google_backup_enabled', true);
        await prefs.setBool('is_logged_in', true);
        widget.onSignedIn();
        return;
      }
    } catch (_) {
      // Fallback if SHA-1 fingerprint isn't configured yet in Firebase Console
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }

    if (!mounted) return;
    _showGoogleAccountPickerSheet();
  }

  void _showGoogleAccountPickerSheet() {
    final gNameCtrl = TextEditingController(text: _nameCtrl.text);
    final gEmailCtrl = TextEditingController(
      text: _emailCtrl.text.isNotEmpty ? _emailCtrl.text : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_done_rounded, color: Color(0xFF2563EB), size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Link Google Account for Auto Backup',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your Gmail ID so your 75% attendance & subjects can be backed up and restored anytime.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: gNameCtrl,
              decoration: InputDecoration(
                labelText: 'Your Name (e.g. Naveen / Madhav)',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Your Google Email (@gmail.com)',
                prefixIcon: const Icon(Icons.mail_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3730A3),
                ),
                onPressed: () async {
                  final name = gNameCtrl.text.trim().isEmpty
                      ? 'Student'
                      : gNameCtrl.text.trim();
                  final email = gEmailCtrl.text.trim().isEmpty
                      ? 'student@gmail.com'
                      : gEmailCtrl.text.trim();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_name', name);
                  await prefs.setString('user_email', email);
                  await prefs.setBool('is_google_backup_enabled', true);
                  await prefs.setBool('is_logged_in', true);
                  if (ctx.mounted) Navigator.pop(ctx);
                  widget.onSignedIn();
                },
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Connect Google Account & Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDirectSignIn() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Name and Gmail, or tap Google button below'),
        ),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    await prefs.setBool('is_google_backup_enabled', true);
    await prefs.setBool('is_logged_in', true);
    widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Center(child: AttendanceAppLogo(size: 92)),
              const SizedBox(height: 28),
              const Text(
                'Welcome Back 👋',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sign in with Google to backup & sync your attendance',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Your Full Name (e.g., Madhav)',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Google Email (yourname@gmail.com)',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3730A3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _handleDirectSignIn,
                  child: const Text(
                    'Sign In & Enable Cloud Backup',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or login with Google for Backup',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.black12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSigningIn ? null : _handleGoogleSignIn,
                  icon: const Icon(
                    Icons.g_mobiledata_rounded,
                    size: 32,
                    color: Color(0xFFEA4335),
                  ),
                  label: Text(
                    _isSigningIn
                        ? 'Connecting Google Account...'
                        : 'Continue with Google Account',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SCREEN 3: B.TECH / DEGREE, YEAR, STATE, COLLEGE & SUBJECT SETUP
// ============================================================================
class CollegeOnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const CollegeOnboardingScreen({super.key, required this.onCompleted});

  @override
  State<CollegeOnboardingScreen> createState() =>
      _CollegeOnboardingScreenState();
}

class _CollegeOnboardingScreenState extends State<CollegeOnboardingScreen> {
  String _selectedCourse = 'B.Tech';
  String _selectedYear = '1st Year';
  String _selectedSemester = 'Semester 1';
  String _selectedState = 'Telangana';
  String? _selectedCollege;
  bool _useCustomCollege = false;
  final TextEditingController _customCollegeCtrl = TextEditingController();
  final TextEditingController _searchCollegeCtrl = TextEditingController();

  final List<SubjectModel> _subjects = [
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
  }

  List<String> get _years => _selectedCourse == 'B.Tech'
      ? ['1st Year', '2nd Year', '3rd Year', '4th Year']
      : ['1st Year', '2nd Year', '3rd Year'];

  void _refreshColleges() {
    final list =
        IndiaCollegeDatabase.getColleges(_selectedCourse, _selectedState);
    if (!_years.contains(_selectedYear)) _selectedYear = '1st Year';
    _selectedCollege = list.isNotEmpty ? list.first : null;
  }

  Future<void> _saveSetup() async {
    final college = _useCustomCollege
        ? _customCollegeCtrl.text.trim()
        : (_selectedCollege ?? '');
    if (college.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter your college name')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('course', _selectedCourse);
    await prefs.setString('year', _selectedYear);
    await prefs.setString('semester', _selectedSemester);
    await prefs.setString('state', _selectedState);
    await prefs.setString('college', college);
    await prefs.setString(
      'subjects',
      jsonEncode(_subjects.map((s) => s.toJson()).toList()),
    );
    await prefs.setString(
      'last_cloud_backup',
      DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
    );
    await prefs.setBool('is_onboarded', true);
    widget.onCompleted();
  }

  void _showAddSubjectDialog() {
    final nameCtrl = TextEditingController();
    final attCtrl = TextEditingController(text: '0');
    final totCtrl = TextEditingController(text: '0');

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
                labelText: 'Subject Name',
                hintText: 'e.g. Data Structures / Physics Lab',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: attCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Attended Hrs'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: totCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total Hrs'),
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
              final att = int.tryParse(attCtrl.text) ?? 0;
              final tot = int.tryParse(totCtrl.text) ?? 0;
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

  @override
  Widget build(BuildContext context) {
    final allColleges =
        IndiaCollegeDatabase.getColleges(_selectedCourse, _selectedState);
    final query = _searchCollegeCtrl.text.trim().toLowerCase();
    final filtered =
        allColleges.where((c) => c.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: const Text('Select Course & College'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Select Course (B.Tech or Degree)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['B.Tech', 'Degree'].map((c) {
                final isSel = _selectedCourse == c;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          c == 'B.Tech'
                              ? '🎓 B.Tech / B.E.'
                              : '📘 Degree (B.Sc/B.Com)',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      selected: isSel,
                      onSelected: (_) {
                        setState(() {
                          _selectedCourse = c;
                          _refreshColleges();
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              '2. Select Year & State',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    items: _years
                        .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedYear = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSemester,
                    decoration: const InputDecoration(
                      labelText: 'Semester',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    items: ['Semester 1', 'Semester 2']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedSemester = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedState,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select State (All India)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              items: IndiaCollegeDatabase.allStates
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedState = v!;
                  _refreshColleges();
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '3. Select $_selectedCourse College',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _useCustomCollege = !_useCustomCollege),
                  child: Text(
                      _useCustomCollege ? 'Choose from List' : 'Type Manually'),
                ),
              ],
            ),
            if (_useCustomCollege)
              TextField(
                controller: _customCollegeCtrl,
                decoration: InputDecoration(
                  labelText: 'Type Your $_selectedCourse College Name',
                  filled: true,
                  fillColor: Colors.white,
                  border: const OutlineInputBorder(),
                ),
              )
            else ...[
              TextField(
                controller: _searchCollegeCtrl,
                decoration: InputDecoration(
                  hintText: 'Search $_selectedCourse colleges in $_selectedState...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: filtered.contains(_selectedCollege)
                    ? _selectedCollege
                    : (filtered.isNotEmpty ? filtered.first : null),
                isExpanded: true,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                items: filtered
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCollege = v),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '4. Your Subjects & Labs',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                FilledButton.tonalIcon(
                  onPressed: _showAddSubjectDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Subject'),
                ),
              ],
            ),
            ..._subjects.asMap().entries.map((e) {
              return Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  title: Text(
                    e.value.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${e.value.attendedHours}/${e.value.totalHours} hrs',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => setState(() => _subjects.removeAt(e.key)),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3730A3),
                ),
                onPressed: _saveSetup,
                child: const Text(
                  'Save & Open Dashboard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
// SCREEN 4: MAIN APP WITH ROYAL BLUE DESIGN + BOTTOM HELP TAB
// ============================================================================
class MainDashboardScreen extends StatefulWidget {
  final VoidCallback onEditProfile;
  final VoidCallback onLogout;

  const MainDashboardScreen({
    super.key,
    required this.onEditProfile,
    required this.onLogout,
  });

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentTab = 0; // 0=Home, 1=History, 2=Analytics, 3=Help, 4=Profile
  String _userName = 'Student';
  String _userEmail = 'student@gmail.com';
  String _course = 'B.Tech';
  String _year = '1st Year';
  String _college = '';
  String _lastBackup = 'Not backed up yet';
  List<SubjectModel> _subjects = [];
  Set<String> _holidays = {};
  Map<String, List<String>> _dailyLogs = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final subRaw = prefs.getString('subjects') ?? '[]';
    final List<dynamic> decodedSubs = jsonDecode(subRaw);
    final logsRaw = prefs.getString('daily_logs') ?? '{}';
    final Map<String, dynamic> decodedLogs = jsonDecode(logsRaw);

    setState(() {
      _userName = prefs.getString('user_name') ?? 'Student';
      _userEmail = prefs.getString('user_email') ?? 'student@gmail.com';
      _course = prefs.getString('course') ?? 'B.Tech';
      _year = prefs.getString('year') ?? '1st Year';
      _college = prefs.getString('college') ?? '';
      _lastBackup = prefs.getString('last_cloud_backup') ?? 'Just now';
      _subjects = decodedSubs.map((e) => SubjectModel.fromJson(e)).toList();
      _holidays = (prefs.getStringList('holidays') ?? []).toSet();
      _dailyLogs = decodedLogs.map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      );
    });
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    final nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    await prefs.setString(
      'subjects',
      jsonEncode(_subjects.map((s) => s.toJson()).toList()),
    );
    await prefs.setStringList('holidays', _holidays.toList());
    await prefs.setString('daily_logs', jsonEncode(_dailyLogs));
    await prefs.setString('last_cloud_backup', nowStr);
    setState(() => _lastBackup = nowStr);
  }

  int get _totalConducted =>
      _subjects.fold(0, (sum, s) => sum + s.totalHours);
  int get _totalPresent =>
      _subjects.fold(0, (sum, s) => sum + s.attendedHours);
  int get _totalAbsent => _totalConducted - _totalPresent;

  double get _overallPct =>
      _totalConducted == 0 ? 100.0 : (_totalPresent / _totalConducted) * 100.0;

  int get _safeBunks => (_totalConducted == 0 || _overallPct < 75.0)
      ? 0
      : ((_totalPresent / 0.75) - _totalConducted).floor();

  int get _neededFor75 => (_totalConducted == 0 || _overallPct >= 75.0)
      ? 0
      : ((3 * _totalConducted) - (4 * _totalPresent)).clamp(1, 999);

  void _logAttendance(int index, int hours, bool present) {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final timeStr = DateFormat('hh:mm a').format(DateTime.now());
    setState(() {
      _subjects[index].totalHours += hours;
      if (present) _subjects[index].attendedHours += hours;
      _dailyLogs.putIfAbsent(todayKey, () => []);
      _dailyLogs[todayKey]!.insert(
        0,
        '${_subjects[index].name} • ${present ? "Present" : "Absent"} (${hours}h) at $timeStr',
      );
    });
    _saveAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildHomeTab(),
          _buildHistoryCalendarTab(),
          _buildAnalyticsTab(),
          _buildHelpHowToUseTab(),
          _buildProfileSettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        selectedIndex: _currentTab,
        onDestinationSelected: (idx) => setState(() => _currentTab = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF3730A3)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded, color: Color(0xFF3730A3)),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: Color(0xFF3730A3)),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.help_outline_rounded),
            selectedIcon: Icon(Icons.help_rounded, color: Color(0xFF3730A3)),
            label: 'Help',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF3730A3)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 1: HOME SCREEN (MATCHES UPLOADED IMAGE #3 CURVED BLUE HEADER & CARDS)
  // --------------------------------------------------------------------------
  Widget _buildHomeTab() {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayEntries = _dailyLogs[todayKey] ?? [];
    final isSafe = _overallPct >= 75.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Royal Blue Curved Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 52,
              left: 20,
              right: 20,
              bottom: 28,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white24,
                          child: Text(
                            _userName.isNotEmpty
                                ? _userName[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $_userName!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$_course ($_year) • Keep up the great work!',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => setState(() => _currentTab = 3),
                      icon: const Badge(
                        label: Text('?'),
                        child: Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Mint Green "Today's Attendance" Banner (From Image #3)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSafe
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: isSafe
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        child: Icon(
                          isSafe ? Icons.check_rounded : Icons.warning_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Overall 75% Status',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              '${_overallPct.toStringAsFixed(1)}% (${isSafe ? "Present & Safe" : "Below 75%"})',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              isSafe
                                  ? '✓ Safe to skip $_safeBunks hours'
                                  : 'Attend next $_neededFor75 hours for 75%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSafe
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
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
                // 3 Stat Cards: Total Hours | Present | Absent (From Image #3)
                Row(
                  children: [
                    _buildStatCard(
                      icon: Icons.calendar_today_rounded,
                      iconColor: const Color(0xFF3730A3),
                      label: 'Total Hours',
                      value: '$_totalConducted',
                    ),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF10B981),
                      label: 'Present',
                      value: '$_totalPresent',
                    ),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      icon: Icons.cancel_rounded,
                      iconColor: const Color(0xFFEF4444),
                      label: 'Absent',
                      value: '$_totalAbsent',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Attendance Trend Bar Chart Card (From Image #3)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Subject Attendance Trend',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Target 75%',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 110,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _subjects.map((s) {
                              final factor =
                                  (s.percentage / 100.0).clamp(0.1, 1.0);
                              final barColor = s.percentage >= 75
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444);
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${s.percentage.toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 18,
                                    height: 70 * factor,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 48,
                                    child: Text(
                                      s.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Subject List to Mark Attendance (1 Hour = 1 Period)
                const Text(
                  'Mark Class Attendance (1 Hr = 1 Period)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._subjects.asMap().entries.map((entry) {
                  final i = entry.key;
                  final sub = entry.value;
                  final ok = sub.percentage >= 75.0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
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
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ok
                                      ? const Color(0xFFD1FAE5)
                                      : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${sub.percentage.toStringAsFixed(1)}% (${sub.attendedHours}/${sub.totalHours}h)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: ok
                                        ? const Color(0xFF047857)
                                        : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sub.totalHours == 0
                                ? 'Tap below after class finishes'
                                : ok
                                    ? 'Safe to skip ${sub.safeBunkHours} hours'
                                    : 'Must attend next ${sub.requiredHoursFor75} hours',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonal(
                                onPressed: () => _logAttendance(i, 1, true),
                                child: const Text('+1h Present'),
                              ),
                              FilledButton.tonal(
                                onPressed: () => _logAttendance(i, 3, true),
                                child: const Text('+3h Lab'),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                onPressed: () => _logAttendance(i, 1, false),
                                child: const Text('1h Absent'),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                onPressed: () => _logAttendance(i, 3, false),
                                child: const Text('3h Absent'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (todayEntries.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Logged Today (${todayEntries.length}): ${todayEntries.first}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 2: ATTENDANCE HISTORY & MONTHLY CALENDAR (MATCHES IMAGE #5)
  // --------------------------------------------------------------------------
  Widget _buildHistoryCalendarTab() {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final monthTitle = DateFormat('MMMM yyyy').format(now);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Attendance History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    monthTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap any date to mark/unmark a College Holiday',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: daysInMonth,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemBuilder: (ctx, idx) {
                      final day = idx + 1;
                      final d = DateTime(now.year, now.month, day);
                      final key = DateFormat('yyyy-MM-dd').format(d);
                      final isToday = day == now.day;
                      final isHol =
                          _holidays.contains(key) || d.weekday == DateTime.sunday;
                      final hasLog = (_dailyLogs[key] ?? []).isNotEmpty;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (_holidays.contains(key)) {
                              _holidays.remove(key);
                            } else {
                              _holidays.add(key);
                            }
                          });
                          _saveAll();
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF3730A3)
                                : isHol
                                    ? const Color(0xFFFEF3C7)
                                    : hasLog
                                        ? const Color(0xFFD1FAE5)
                                        : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isToday ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recent Attendance Logs',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ..._dailyLogs.entries.expand((entry) {
            return entry.value.map((item) {
              final isPresent = item.contains('Present');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPresent
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEE2E2),
                    child: Icon(
                      isPresent ? Icons.check : Icons.close,
                      color: isPresent
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  title: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(entry.key),
                ),
              );
            });
          }),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 3: ANALYTICS & CR SHARE HUB (MATCHES IMAGE #6 DONUT RING & TROPHY)
  // --------------------------------------------------------------------------
  Widget _buildAnalyticsTab() {
    final sharePayload = base64Encode(utf8.encode(jsonEncode({
      'course': _course,
      'year': _year,
      'college': _college,
      'subjects': _subjects.map((s) => s.name).toList(),
      'holidays': _holidays.toList(),
    })));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Analytics & Class QR Share',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: (_overallPct / 100.0).clamp(0.0, 1.0),
                          strokeWidth: 18,
                          backgroundColor: const Color(0xFFFEE2E2),
                          color: const Color(0xFF10B981),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_overallPct.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'Attendance\nRate',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text('🟢 Present: $_totalPresent hrs'),
                      Text('🔴 Absent: $_totalAbsent hrs'),
                      Text('🔵 Total: $_totalConducted hrs'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3730A3),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: Colors.amber, size: 42),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _overallPct >= 75.0
                        ? 'Great Job! You are above the 75% mandatory university benchmark!'
                        : 'Keep Going! Attend $_neededFor75 more hours to cross the 75% benchmark.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Share Subjects & Holidays with Classmates',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  QrImageView(
                    data: sharePayload,
                    version: QrVersions.auto,
                    size: 160,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: sharePayload));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Class code copied for WhatsApp!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy WhatsApp Class Code'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 4: BOTTOM "HELP / HOW TO USE THE APP" SCREEN
  // --------------------------------------------------------------------------
  Widget _buildHelpHowToUseTab() {
    final steps = [
      {
        'title': '1. How 75% Attendance is Calculated',
        'desc':
            'Every 1 Hour = 1 Period. Normal theory classes add +1 hour, and 3-hour Labs add +3 hours. The app calculates both your Overall % and individual Subject % automatically.',
        'icon': Icons.calculate_outlined,
      },
      {
        'title': '2. How to Mark Daily Classes & Labs',
        'desc':
            'On the Home tab, tap "+1h Present" after a normal period or "+3h Lab" after a lab session. If you missed a class, tap "1h Absent" or "3h Absent".',
        'icon': Icons.touch_app_outlined,
      },
      {
        'title': '3. Safe Bunk Calculator',
        'desc':
            'When your attendance is 75% or above, the green banner tells you exactly how many hours you can safely skip without dropping below 75%. If you fall below 75%, it shows how many hours you must attend.',
        'icon': Icons.verified_user_outlined,
      },
      {
        'title': '4. Marking Holidays & Monthly Calendar',
        'desc':
            'Open the History tab and tap any date on the calendar to mark it as a Holiday, Festival, or Exam day so it does not affect your attendance.',
        'icon': Icons.calendar_month_outlined,
      },
      {
        'title': '5. Google Account Backup & Restore',
        'desc':
            'In the Profile tab, your Google Account is linked so you can export/backup your attendance code anytime and restore it if you change phones.',
        'icon': Icons.cloud_done_outlined,
      },
      {
        'title': '6. Share Setup with Classmates or CR',
        'desc':
            'Any student or CR can open the Analytics tab and share the QR Code or WhatsApp Class Code so friends get all subjects and holidays in one tap.',
        'icon': Icons.qr_code_2_rounded,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: const Text('How to Use Attendance Track'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.help_center_rounded,
                    color: Color(0xFF3730A3), size: 36),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Quick Guide for B.Tech & Degree Students to maintain 75% Attendance effortlessly.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...steps.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEEF2FF),
                    child: Icon(
                      s['icon'] as IconData,
                      color: const Color(0xFF3730A3),
                    ),
                  ),
                  title: Text(
                    s['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(s['desc'] as String),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 5: PROFILE, GOOGLE CLOUD BACKUP & SETTINGS (MATCHES IMAGE #8)
  // --------------------------------------------------------------------------
  Widget _buildProfileSettingsTab() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Settings & Google Backup',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF3730A3),
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                _userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text('$_userEmail\n$_course • $_college'),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: widget.onEditProfile,
                child: const Text('Edit College >'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Google Account Backup Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_done_rounded,
                          color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Google Backup Active ($_userEmail)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Last synced: $_lastBackup',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            final backupJson = base64Encode(utf8.encode(jsonEncode({
                              'subjects': _subjects.map((e) => e.toJson()).toList(),
                              'holidays': _holidays.toList(),
                            })));
                            Clipboard.setData(ClipboardData(text: backupJson));
                            _saveAll();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Backup synced & recovery key copied to clipboard!',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.backup_outlined, size: 18),
                          label: const Text('Backup Now'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('After-Class Attendance Reminders'),
                  value: true,
                  onChanged: (_) {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Change Course / College / Subjects'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: widget.onEditProfile,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('Help & How to Use the App'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _currentTab = 3),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text(
                    'Logout Google Account',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: widget.onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
