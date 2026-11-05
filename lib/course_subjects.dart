/// Suggested subjects for each course / branch / year / semester.
/// These are common syllabus subjects shown as a starting point;
/// students can still add or delete subjects to match their own university.
class CourseSubjects {
  static const List<String> btechBranches = [
    'Computer Science (CSE)',
    'Information Technology (IT)',
    'AI & Machine Learning',
    'Electronics & Communication (ECE)',
    'Electrical & Electronics (EEE)',
    'Mechanical Engineering',
    'Civil Engineering',
  ];

  static const List<String> degreeStreams = [
    'B.Sc (Maths, Physics, Chemistry)',
    'B.Sc (Computer Science)',
    'B.Com',
    'BBA',
    'BA',
  ];

  static List<String> branchesFor(String course) =>
      course == 'B.Tech' ? btechBranches : degreeStreams;

  static List<String> subjectsFor(
    String course,
    String branch,
    String year,
    String semester,
  ) {
    final key = '$year|$semester';
    if (course == 'B.Tech') {
      if (year == '1st Year') {
        return _btechFirstYear[semester] ?? const [];
      }
      return _btech[branch]?[key] ?? const [];
    }
    return _degree[branch]?[key] ?? const [];
  }

  // Most universities keep 1st year common for all engineering branches.
  static const Map<String, List<String>> _btechFirstYear = {
    'Semester 1': [
      'Mathematics - I',
      'Engineering Physics',
      'Programming in C',
      'English Communication',
      'Engineering Graphics',
      'Physics Lab',
      'C Programming Lab',
    ],
    'Semester 2': [
      'Mathematics - II',
      'Engineering Chemistry',
      'Basic Electrical Engineering',
      'Data Structures',
      'Environmental Science',
      'Chemistry Lab',
      'Workshop Practice',
    ],
  };

  static const Map<String, Map<String, List<String>>> _btech = {
    'Computer Science (CSE)': {
      '2nd Year|Semester 1': [
        'Discrete Mathematics',
        'Digital Logic Design',
        'Object Oriented Programming (Java)',
        'Data Structures',
        'Data Structures Lab',
        'OOP Lab',
      ],
      '2nd Year|Semester 2': [
        'Design & Analysis of Algorithms',
        'Computer Organization',
        'Operating Systems',
        'Database Management Systems',
        'DBMS Lab',
        'OS Lab',
      ],
      '3rd Year|Semester 1': [
        'Computer Networks',
        'Compiler Design',
        'Software Engineering',
        'Web Technologies',
        'Networks Lab',
        'Web Technologies Lab',
      ],
      '3rd Year|Semester 2': [
        'Machine Learning',
        'Cryptography & Network Security',
        'Cloud Computing',
        'Formal Languages & Automata',
        'Machine Learning Lab',
      ],
      '4th Year|Semester 1': [
        'Big Data Analytics',
        'Internet of Things',
        'Professional Elective - I',
        'Open Elective - I',
        'Project Work Phase - I',
      ],
      '4th Year|Semester 2': [
        'Professional Elective - II',
        'Open Elective - II',
        'Seminar',
        'Major Project',
      ],
    },
    'Information Technology (IT)': {
      '2nd Year|Semester 1': [
        'Discrete Mathematics',
        'Digital Logic Design',
        'Object Oriented Programming (Java)',
        'Data Structures',
        'Data Structures Lab',
        'OOP Lab',
      ],
      '2nd Year|Semester 2': [
        'Design & Analysis of Algorithms',
        'Computer Organization',
        'Operating Systems',
        'Database Management Systems',
        'DBMS Lab',
        'OS Lab',
      ],
      '3rd Year|Semester 1': [
        'Computer Networks',
        'Software Engineering',
        'Web Technologies',
        'Information Security',
        'Networks Lab',
        'Web Technologies Lab',
      ],
      '3rd Year|Semester 2': [
        'Machine Learning',
        'Cloud Computing',
        'Data Mining',
        'Mobile Application Development',
        'Mobile App Lab',
      ],
      '4th Year|Semester 1': [
        'Big Data Analytics',
        'Internet of Things',
        'Professional Elective - I',
        'Open Elective - I',
        'Project Work Phase - I',
      ],
      '4th Year|Semester 2': [
        'Professional Elective - II',
        'Open Elective - II',
        'Seminar',
        'Major Project',
      ],
    },
    'AI & Machine Learning': {
      '2nd Year|Semester 1': [
        'Discrete Mathematics',
        'Probability & Statistics',
        'Python Programming',
        'Data Structures',
        'Data Structures Lab',
        'Python Lab',
      ],
      '2nd Year|Semester 2': [
        'Design & Analysis of Algorithms',
        'Operating Systems',
        'Database Management Systems',
        'Foundations of AI',
        'DBMS Lab',
        'AI Lab',
      ],
      '3rd Year|Semester 1': [
        'Machine Learning',
        'Computer Networks',
        'Data Science',
        'Knowledge Representation & Reasoning',
        'Machine Learning Lab',
      ],
      '3rd Year|Semester 2': [
        'Deep Learning',
        'Natural Language Processing',
        'Computer Vision',
        'Reinforcement Learning',
        'Deep Learning Lab',
      ],
      '4th Year|Semester 1': [
        'Generative AI',
        'Big Data Analytics',
        'Professional Elective - I',
        'Open Elective - I',
        'Project Work Phase - I',
      ],
      '4th Year|Semester 2': [
        'Professional Elective - II',
        'AI Ethics & Governance',
        'Seminar',
        'Major Project',
      ],
    },
    'Electronics & Communication (ECE)': {
      '2nd Year|Semester 1': [
        'Network Analysis',
        'Electronic Devices & Circuits',
        'Signals & Systems',
        'Switching Theory & Logic Design',
        'EDC Lab',
        'Digital Logic Lab',
      ],
      '2nd Year|Semester 2': [
        'Analog Circuits',
        'Electromagnetic Theory',
        'Probability & Random Processes',
        'Pulse & Digital Circuits',
        'Analog Circuits Lab',
      ],
      '3rd Year|Semester 1': [
        'Analog Communications',
        'Linear IC Applications',
        'Microprocessors & Microcontrollers',
        'Control Systems',
        'Analog Communications Lab',
        'Microprocessors Lab',
      ],
      '3rd Year|Semester 2': [
        'Digital Communications',
        'Digital Signal Processing',
        'Antennas & Wave Propagation',
        'VLSI Design',
        'DSP Lab',
      ],
      '4th Year|Semester 1': [
        'Microwave Engineering',
        'Embedded Systems',
        'Professional Elective - I',
        'Open Elective - I',
        'Project Work Phase - I',
      ],
      '4th Year|Semester 2': [
        'Optical Communications',
        'Professional Elective - II',
        'Seminar',
        'Major Project',
      ],
    },
    'Electrical & Electronics (EEE)': {
      '2nd Year|Semester 1': [
        'Electrical Circuit Analysis',
        'Electromagnetic Fields',
        'Analog Electronics',
        'DC Machines & Transformers',
        'Circuits Lab',
        'DC Machines Lab',
      ],
      '2nd Year|Semester 2': [
        'AC Machines',
        'Power Systems - I',
        'Digital Electronics',
        'Control Systems',
        'AC Machines Lab',
      ],
      '3rd Year|Semester 1': [
        'Power Systems - II',
        'Power Electronics',
        'Microprocessors & Microcontrollers',
        'Measurements & Instrumentation',
        'Power Electronics Lab',
      ],
      '3rd Year|Semester 2': [
        'Power System Protection',
        'Electric Drives',
        'Renewable Energy Systems',
        'Digital Signal Processing',
        'Control Systems Lab',
      ],
      '4th Year|Semester 1': [
        'HVDC & FACTS',
        'Utilization of Electrical Energy',
        'Professional Elective - I',
        'Open Elective - I',
        'Project Work Phase - I',
      ],
      '4th Year|Semester 2': [
        'Smart Grid Technologies',
        'Professional Elective - II',
        'Seminar',
        'Major Project',
      ],
    },
    'Mechanical Engineering': {
      '2nd Year|Semester 1': [
        'Engineering Mechanics',
        'Thermodynamics',
        'Mechanics of Solids',
        'Materials Science',
        'Machine Drawing',
        'Material Testing Lab',
      ],
      '2nd Year|Semester 2': [
        'Fluid Mechanics & Hydraulic Machines',
        'Kinematics of Machinery',
        'Manufacturing Processes',
        'Applied Thermodynamics',
        'Fluid Mechanics Lab',
      ],
      '3rd Year|Semester 1': [
        'Dynamics of Machinery',
        'Heat Transfer',
        'Design of Machine Elements',
        'Metal Cutting & Machine Tools',
        'Heat Transfer Lab',
      ],
      '3rd Year|Semester 2': [
        'Refrigeration & Air Conditioning',
        'Finite Element Methods',
        'Industrial Engineering & Management',
        'Automobile Engineering',
        'CAD/CAM Lab',
      ],
      '4th Year|Semester 1': [
        'Power Plant Engineering',
        'Mechatronics',
        'Professional Elective - I',
        'Open Elective - I',
        'Project Work Phase - I',
      ],
      '4th Year|Semester 2': [
        'Professional Elective - II',
        'Operations Research',
        'Seminar',
        'Major Project',
      ],
    },
    'Civil Engineering': {
      '2nd Year|Semester 1': [
        'Strength of Materials',
        'Surveying',
        'Fluid Mechanics',
        'Building Materials & Construction',
        'Surveying Lab',
        'Strength of Materials Lab',
      ],
      '2nd Year|Semester 2': [
        'Structural Analysis - I',
        'Hydraulics & Hydraulic Machinery',
        'Concrete Technology',
        'Engineering Geology',
        'Fluid Mechanics Lab',
      ],
      '3rd Year|Semester 1': [
        'Structural Analysis - II',
        'Design of Reinforced Concrete Structures',
        'Geotechnical Engineering',
        'Transportation Engineering',
        'Geotechnical Lab',
      ],
      '3rd Year|Semester 2': [
        'Design of Steel Structures',
        'Water Resources Engineering',
        'Environmental Engineering',
        'Estimation & Costing',
        'Environmental Engineering Lab',
      ],
      '4th Year|Semester 1': [
        'Foundation Engineering',
        'Prestressed Concrete',
        'Professional Elective - I',
        'Open Elective - I',
        'Project Work Phase - I',
      ],
      '4th Year|Semester 2': [
        'Construction Management',
        'Professional Elective - II',
        'Seminar',
        'Major Project',
      ],
    },
  };

  static const Map<String, Map<String, List<String>>> _degree = {
    'B.Sc (Maths, Physics, Chemistry)': {
      '1st Year|Semester 1': [
        'Differential Equations',
        'Mechanics & Waves',
        'Inorganic & Physical Chemistry',
        'English',
        'Physics Lab',
        'Chemistry Lab',
      ],
      '1st Year|Semester 2': [
        'Solid Geometry',
        'Thermal Physics',
        'Organic Chemistry',
        'Environmental Studies',
        'Physics Lab',
        'Chemistry Lab',
      ],
      '2nd Year|Semester 1': [
        'Abstract Algebra',
        'Optics',
        'Physical Chemistry',
        'Mathematics Practicals',
        'Physics Lab',
      ],
      '2nd Year|Semester 2': [
        'Real Analysis',
        'Electricity & Magnetism',
        'Analytical Chemistry',
        'Physics Lab',
        'Chemistry Lab',
      ],
      '3rd Year|Semester 1': [
        'Linear Algebra',
        'Modern Physics',
        'Spectroscopy',
        'Elective - I',
      ],
      '3rd Year|Semester 2': [
        'Complex Analysis',
        'Atomic & Nuclear Physics',
        'Bio-Chemistry',
        'Project Work',
      ],
    },
    'B.Sc (Computer Science)': {
      '1st Year|Semester 1': [
        'Mathematics - I',
        'Programming in C',
        'Digital Fundamentals',
        'English',
        'C Programming Lab',
      ],
      '1st Year|Semester 2': [
        'Mathematics - II',
        'Data Structures',
        'Computer Organization',
        'Environmental Studies',
        'Data Structures Lab',
      ],
      '2nd Year|Semester 1': [
        'Object Oriented Programming',
        'Database Management Systems',
        'Operating Systems',
        'DBMS Lab',
        'OOP Lab',
      ],
      '2nd Year|Semester 2': [
        'Computer Networks',
        'Software Engineering',
        'Web Technologies',
        'Web Technologies Lab',
      ],
      '3rd Year|Semester 1': [
        'Python Programming',
        'Artificial Intelligence',
        'Elective - I',
        'Python Lab',
      ],
      '3rd Year|Semester 2': [
        'Cloud Computing',
        'Data Mining',
        'Project Work',
      ],
    },
    'B.Com': {
      '1st Year|Semester 1': [
        'Financial Accounting - I',
        'Business Organisation',
        'Business Economics',
        'English',
        'Computer Fundamentals',
      ],
      '1st Year|Semester 2': [
        'Financial Accounting - II',
        'Business Law',
        'Macro Economics',
        'Environmental Studies',
        'Spreadsheet Applications',
      ],
      '2nd Year|Semester 1': [
        'Corporate Accounting',
        'Cost Accounting',
        'Business Statistics',
        'Banking & Insurance',
      ],
      '2nd Year|Semester 2': [
        'Income Tax',
        'Company Law',
        'Management Accounting',
        'Marketing Management',
      ],
      '3rd Year|Semester 1': [
        'Auditing',
        'Financial Management',
        'GST & Indirect Taxes',
        'Elective - I',
      ],
      '3rd Year|Semester 2': [
        'Entrepreneurship',
        'Investment Management',
        'Elective - II',
        'Project Work',
      ],
    },
    'BBA': {
      '1st Year|Semester 1': [
        'Principles of Management',
        'Business Economics',
        'Financial Accounting',
        'Business Communication',
      ],
      '1st Year|Semester 2': [
        'Organisational Behaviour',
        'Business Statistics',
        'Marketing Management',
        'Environmental Studies',
      ],
      '2nd Year|Semester 1': [
        'Human Resource Management',
        'Financial Management',
        'Cost & Management Accounting',
        'Business Law',
      ],
      '2nd Year|Semester 2': [
        'Operations Management',
        'Consumer Behaviour',
        'Research Methodology',
        'Entrepreneurship',
      ],
      '3rd Year|Semester 1': [
        'Strategic Management',
        'International Business',
        'Elective - I',
        'Elective - II',
      ],
      '3rd Year|Semester 2': [
        'Business Ethics',
        'Management Information Systems',
        'Elective - III',
        'Project Work',
      ],
    },
    'BA': {
      '1st Year|Semester 1': [
        'English',
        'Second Language',
        'History of India - I',
        'Political Science - I',
        'Economics - I',
      ],
      '1st Year|Semester 2': [
        'English',
        'Second Language',
        'History of India - II',
        'Political Science - II',
        'Economics - II',
      ],
      '2nd Year|Semester 1': [
        'Modern World History',
        'Indian Constitution',
        'Micro Economics',
        'Sociology - I',
      ],
      '2nd Year|Semester 2': [
        'Public Administration',
        'Indian Economy',
        'Sociology - II',
        'Environmental Studies',
      ],
      '3rd Year|Semester 1': [
        'International Relations',
        'Development Economics',
        'Elective - I',
        'Elective - II',
      ],
      '3rd Year|Semester 2': [
        'Research Methods',
        'Indian Political Thought',
        'Elective - III',
        'Project Work',
      ],
    },
  };
}
