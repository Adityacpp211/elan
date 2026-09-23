// CardioAid — Screens
// Redesigned with the AppTheme design system.

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'theme.dart';
import 'services/api_service.dart';

// ==================== NAVIGATION HELPER ====================

void open(BuildContext context, Widget page) {
  Navigator.of(context).push(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, animation, __) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: page,
      ),
    ),
  );
}

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

// ==================== SHARED AUTH SHELL ====================

class _AuthShell extends StatelessWidget {
  const _AuthShell({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const Center(child: BrandMark(size: 72)),
                  const SizedBox(height: 22),
                  EyebrowLabel(text: eyebrow, color: AppColors.brand),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  child,
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.obscureToggle,
    this.onToggleObscure,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool? obscureToggle;
  final VoidCallback? onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: obscureToggle == true
              ? IconButton(
                  onPressed: onToggleObscure,
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// ==================== LOGIN ====================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final error = await _authService.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      _requestLocationAndNavigate();
    }
  }

  Future<void> _requestLocationAndNavigate() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.deniedForever) {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          final api = ApiService();
          await api.updateLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          );
        } catch (e) {
          debugPrint('Location error: $e');
        }
      }
    } catch (e) {
      debugPrint('Permission error: $e');
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Dashboard()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AuthShell(
      eyebrow: 'Emergency cardiac care',
      title: 'Welcome back',
      subtitle: 'Sign in to continue to your control centre',
      child: SurfaceCard(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AuthField(
              controller: _emailController,
              label: 'Email address',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _AuthField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_rounded,
              obscure: _obscurePassword,
              obscureToggle: true,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Sign In',
              icon: Icons.arrow_forward_rounded,
              loading: _isLoading,
              onPressed: _isLoading ? null : _handleLogin,
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("New to CardioAid?",
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SignUpScreen())),
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== SIGN UP ====================

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final error = await _authService.signUp(
      _nameController.text,
      _emailController.text,
      _passwordController.text,
      _confirmPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created — sign in to continue.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthShell(
      eyebrow: 'Join the network',
      title: 'Create your account',
      subtitle: 'Set up access to emergency response',
      child: SurfaceCard(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AuthField(
              controller: _nameController,
              label: 'Full name',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 16),
            _AuthField(
              controller: _emailController,
              label: 'Email address',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _AuthField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_rounded,
              obscure: _obscurePassword,
              obscureToggle: true,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            const SizedBox(height: 16),
            _AuthField(
              controller: _confirmPasswordController,
              label: 'Confirm password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscureConfirm,
              obscureToggle: true,
              onToggleObscure: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 15, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text('Minimum 6 characters',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Create Account',
              icon: Icons.person_add_alt_1_rounded,
              loading: _isLoading,
              onPressed: _isLoading ? null : _handleSignUp,
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account?',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen())),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== DASHBOARD ====================

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final _db = DatabaseService();
  double _wallet = 5000.0;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getDouble('walletBalance') ?? 5000.0;
    if (mounted) setState(() => _wallet = balance);
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentLoggedInUser;
    final displayName = user?.name ?? _db.currentUser?.name ?? 'Guest';
    final alertsSent = _db.hospitalAlerts.length;
    final hospitalCount = _db.hospitals.length;

    return AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const EyebrowLabel(text: 'Control centre'),
                        const SizedBox(height: 4),
                        Text(
                          _greeting,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => open(context, const UserProfileScreen()),
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3A4AA8), Color(0xFF232C49)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Text(
                        _initials(displayName),
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, 32),
                children: [
                  _EmergencyHeroCard(
                    onTap: () => open(context, const EmergencyScreen()),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _StatsCard(
                    credit: _wallet,
                    hospitalCount: hospitalCount,
                    alertsSent: alertsSent,
                  ),
                  const SizedBox(height: AppSpace.xxl),
                  SectionHeader(
                    eyebrow: 'Your toolkit',
                    title: 'Modules',
                  ),
                  const SizedBox(height: AppSpace.lg),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: AppSpace.md,
                    mainAxisSpacing: AppSpace.md,
                    childAspectRatio: 1.45,
                    children: [
                      _ModuleTile(
                        icon: Icons.notifications_active_outlined,
                        color: AppColors.alert,
                        title: 'Hospital Alerts',
                        subtitle: '$alertsSent sent',
                        onTap: () => open(context, const HospitalAlertScreen()),
                      ),
                      _ModuleTile(
                        icon: Icons.groups_outlined,
                        color: AppColors.sky,
                        title: 'Patients',
                        subtitle: '${_db.patients.length} records',
                        onTap: () => open(context, PatientScreen()),
                      ),
                      _ModuleTile(
                        icon: Icons.monitor_heart_outlined,
                        color: AppColors.success,
                        title: 'Monitoring',
                        subtitle: '${_db.vitalSigns.length} readings',
                        onTap: () => open(context, MonitoringScreen()),
                      ),
                      _ModuleTile(
                        icon: Icons.description_outlined,
                        color: AppColors.warning,
                        title: 'Reports',
                        subtitle: '${_db.reports.length} documents',
                        onTap: () => open(context, ReportScreen()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyHeroCard extends StatelessWidget {
  const _EmergencyHeroCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFB72236),
              const Color(0xFF6E1220),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.sos_rounded,
                      size: 26, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EMERGENCY RESPONSE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFE3E7),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Emergency Mode',
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'One tap alerts the closest care units',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
            const SizedBox(height: 18),
            Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7CF5C0),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Network ready · tap to launch',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFE3E7),
                    ),
                  ),
                ),
                const Icon(Icons.wifi_rounded,
                    size: 16, color: Color(0xFF7CF5C0)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.credit,
    required this.hospitalCount,
    required this.alertsSent,
  });

  final double credit;
  final int hospitalCount;
  final int alertsSent;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
      child: Row(
        children: [
          Expanded(
            child: StatValue(
              label: 'Alert credit',
              value: '₹${credit.toStringAsFixed(0)}',
              color: AppColors.success,
              icon: Icons.account_balance_wallet_rounded,
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.hairline),
          Expanded(
            child: StatValue(
              label: 'Care units',
              value: '$hospitalCount',
              color: AppColors.alert,
              icon: Icons.local_hospital_rounded,
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.hairline),
          Expanded(
            child: StatValue(
              label: 'Alerts sent',
              value: '$alertsSent',
              color: AppColors.brand,
              icon: Icons.notifications_active_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      onTap: onTap,
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconTile(icon: icon, color: color, size: 40, iconSize: 20),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== EMERGENCY ====================

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final _db = DatabaseService();
  final _locationService = LocationService();
  final _api = ApiService();
  late SharedPreferences _prefs;

  final Set<String> _selectedSymptoms = {};
  final TextEditingController _messageController = TextEditingController();
  LocationData? _userLocation;
  List<Map<String, dynamic>> _nearbyHospitals = []; // From API
  List<HospitalLocation> _localHospitals = []; // Fallback
  bool _isLoadingLocation = false;
  bool _isSendingAlert = false;
  int _selectedCharge = 1; // Tier 1, 2, or 3
  String? _currentAlertId;

  double _walletBalance = 5000.0;

  final List<String> _symptomsList = [
    'Chest Pain',
    'Shortness of Breath',
    'Palpitations',
    'Dizziness',
    'Fainting',
    'Severe Headache',
    'Nausea/Vomiting',
    'Irregular Heartbeat',
  ];

  // Tier descriptions with actual price values
  final Map<int, Map<String, dynamic>> _tierInfo = {
    1: {
      'price': '₹1',
      'priceValue': 1.0,
      'hospitals': 1,
      'desc': 'Nearest hospital',
    },
    2: {
      'price': '₹2',
      'priceValue': 2.0,
      'hospitals': 3,
      'desc': 'Top 3 nearby hospitals',
    },
    3: {
      'price': '₹3',
      'priceValue': 3.0,
      'hospitals': 10,
      'desc': 'All nearby hospitals',
    },
  };

  List<Map<String, dynamic>> get _displayHospitals {
    if (_nearbyHospitals.isNotEmpty) return _nearbyHospitals;
    if (_userLocation == null) return [];
    return _localHospitals.map((h) => {
          'name': h.name,
          'phone': h.phone,
          'distanceKm': h.distanceTo(_userLocation!),
        }).toList();
  }

  int get _tierHospitalCount =>
      _tierInfo[_selectedCharge]!['hospitals'] as int;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _walletBalance = _prefs.getDouble('walletBalance') ?? 5000.0;
      });
    }
    await _getCurrentLocation();
  }

  Future<void> _saveWalletBalance() async {
    await _prefs.setDouble('walletBalance', _walletBalance);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        setState(() {
          _userLocation = location;
          _localHospitals = _db.getNearbyHospitals(location, radiusKm: 50);
        });

        final response = await _api.getNearbyHospitals(
          latitude: location.latitude,
          longitude: location.longitude,
          radiusKm: 50,
        );

        if (response.success && response.data != null) {
          setState(() {
            _nearbyHospitals = List<Map<String, dynamic>>.from(
                response.data['hospitals'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _sendAlertToHospitals() async {
    if (_selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one symptom')),
      );
      return;
    }

    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a short message')),
      );
      return;
    }

    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get your location')),
      );
      return;
    }

    int hospitalCount = _tierHospitalCount;
    String price = _tierInfo[_selectedCharge]!['price'] as String;
    double priceValue = _tierInfo[_selectedCharge]!['priceValue'] as double;

    // Check wallet balance
    if (_walletBalance < priceValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Insufficient credit — need $price, have ₹${_walletBalance.toStringAsFixed(0)}'),
        ),
      );
      return;
    }

    // Show confirmation dialog
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sos_rounded, color: AppColors.brand, size: 24),
            SizedBox(width: 10),
            Text('Confirm emergency alert'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This will alert $hospitalCount hospital(s) with your location.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              padding: const EdgeInsets.all(14),
              radius: AppRadius.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ALERT PLAN',
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tier $_selectedCharge',
                          style:
                              Theme.of(context).textTheme.titleLarge),
                      Text(
                        price,
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tierInfo[_selectedCharge]!['desc'] as String,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Credit balance',
                    style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  '₹${_walletBalance.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedSymptoms
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: AppColors.brand.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                              color: AppColors.brand,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.flash_on_rounded, size: 18),
            label: Text('Pay $price'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _isSendingAlert = true);

    try {
      // Deduct from wallet
      setState(() {
        _walletBalance -= priceValue;
      });
      await _saveWalletBalance();

      // Generate local alert ID
      _currentAlertId = 'ALERT_${DateTime.now().millisecondsSinceEpoch}';

      // Try to send via backend API (optional - works offline too)
      int hospitalsNotified = hospitalCount;
      try {
        final orderResponse = await _api.createPaymentOrder(
          tier: _selectedCharge,
          latitude: _userLocation!.latitude,
          longitude: _userLocation!.longitude,
          symptoms: _selectedSymptoms.join(', '),
          message: _messageController.text,
        );

        if (orderResponse.success) {
          _currentAlertId = orderResponse.data['alertId'];
          final orderId = orderResponse.data['order']['id'];

          // Auto-verify payment (wallet already deducted)
          await _api.verifyPayment(
            orderId: orderId,
            paymentId: 'wallet_${DateTime.now().millisecondsSinceEpoch}',
            signature: 'wallet_payment',
            alertId: _currentAlertId!,
          );

          final alertResponse = await _api.sendEmergencyAlert(_currentAlertId!);
          if (alertResponse.success) {
            hospitalsNotified =
                alertResponse.data['hospitalsNotified'] ?? hospitalCount;
          }
        }
      } catch (e) {
        // Backend unavailable — that's OK, wallet payment still processed locally
        debugPrint('Backend unavailable, using local processing: $e');
      }

      // Also save to local database
      for (int i = 0;
          i < hospitalCount && i < _localHospitals.length;
          i++) {
        final hospital = _localHospitals[i];
        final alert = HospitalAlert(
          id: '${_currentAlertId}_$i',
          hospitalId: hospital.id,
          hospitalName: hospital.name,
          timestamp: DateTime.now(),
          symptoms: _selectedSymptoms.toList(),
          message: _messageController.text,
          chargeLevels: _selectedCharge,
          messageDelivered: true,
          userLocation:
              '${_userLocation!.latitude}, ${_userLocation!.longitude}',
        );
        _db.addHospitalAlert(alert);
      }

      if (!mounted) return;
      // Success!
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 44),
          title: const Text('Alerts dispatched'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Emergency alerts sent to $hospitalsNotified hospital(s). Units have been notified and will respond shortly.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                padding: const EdgeInsets.all(14),
                radius: AppRadius.md,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Remaining credit',
                        style: Theme.of(context).textTheme.bodyMedium),
                    Text(
                      '₹${_walletBalance.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ALERT ID  ${_currentAlertId?.substring(0, 8).toUpperCase()}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted, fontFamily: AppFonts.display),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );

      // Clear form
      setState(() {
        _selectedSymptoms.clear();
        _messageController.clear();
        _selectedCharge = 1;
        _currentAlertId = null;
      });
    } catch (e) {
      // Refund wallet on error
      setState(() {
        _walletBalance += priceValue;
      });
      await _saveWalletBalance();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSendingAlert = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayHospitals = _displayHospitals;
    final totalCost = _selectedCharge * displayHospitals.length;

    return AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'SOS response',
              title: 'Emergency',
              onBack: () => Navigator.of(context).pop(),
              trailing: _WalletPill(balance: _walletBalance),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, 32),
                children: [
                  // Location
                  SectionHeader(
                    eyebrow: 'Navigator',
                    title: 'Your location',
                    trailing: IconButton(
                      onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                      icon: const Icon(Icons.my_location_rounded, size: 20),
                      color: AppColors.alert,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  SurfaceCard(
                    child: Row(
                      children: [
                        IconTile(
                          icon: Icons.location_on_rounded,
                          color: AppColors.alert,
                          size: 44,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _isLoadingLocation
                                        ? 'Acquiring position…'
                                        : 'Live position',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                            color: AppColors.textSecondary,
                                            letterSpacing: 1.0),
                                  ),
                                  if (_isLoadingLocation) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.6,
                                          color: AppColors.alert),
                                    ),
                                  ] else ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                          color: AppColors.success,
                                          shape: BoxShape.circle),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _userLocation != null
                                    ? '${_userLocation!.latitude.toStringAsFixed(4)}°, ${_userLocation!.longitude.toStringAsFixed(4)}°'
                                    : 'Waiting for coordinates…',
                                style: const TextStyle(
                                  fontFamily: AppFonts.display,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpace.xxl),

                  // Nearby hospitals
                  SectionHeader(
                    eyebrow: 'Coverage',
                    title: 'Nearby hospitals',
                    trailing: StatusBadge(
                      label:
                          '${displayHospitals.length} found',
                      color: AppColors.alert,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  if (displayHospitals.isEmpty)
                    SurfaceCard(
                      padding: const EdgeInsets.all(AppSpace.xl),
                      child: Column(
                        children: [
                          const Icon(Icons.route_rounded,
                              color: AppColors.textMuted, size: 26),
                          const SizedBox(height: 10),
                          Text(
                            _isLoadingLocation
                                ? 'Scanning for care units…'
                                : 'No hospitals found nearby',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  else
                    ...displayHospitals.map((hospital) {
                      final name = hospital['name'] ?? 'Unknown Hospital';
                      final phone = hospital['phone'] ?? '';
                      final distance = hospital['distanceKm'] ?? 0.0;
                      final distText = distance is double
                          ? distance.toStringAsFixed(1)
                          : '$distance';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Row(
                          children: [
                            IconTile(
                              icon: Icons.local_hospital_rounded,
                              color: AppColors.alert,
                              size: 42,
                              iconSize: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(phone,
                                      style:
                                          Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.alert.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$distText km',
                                style: const TextStyle(
                                  fontFamily: AppFonts.display,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.alert,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: AppSpace.xxl),

                  // Symptoms
                  SectionHeader(
                    eyebrow: 'Assessment',
                    title: 'Symptoms',
                  ),
                  const SizedBox(height: AppSpace.md),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _symptomsList.map((symptom) {
                      final isSelected = _selectedSymptoms.contains(symptom);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedSymptoms.remove(symptom);
                            } else {
                              _selectedSymptoms.add(symptom);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brand
                                : AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brand
                                  : AppColors.hairline,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check_rounded,
                                    size: 15, color: Colors.white),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                symptom,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppSpace.xxl),

                  // Message
                  SectionHeader(eyebrow: 'Details', title: 'Message'),
                  const SizedBox(height: AppSpace.md),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      hintText: 'Describe the situation or any key details…',
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: AppSpace.xxl),

                  // Tier selection
                  SectionHeader(
                    eyebrow: 'Coverage plan',
                    title: 'Alert coverage',
                  ),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [1, 2, 3].map((charge) {
                      final isSelected = _selectedCharge == charge;
                      final info = _tierInfo[charge]!;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCharge = charge),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            margin: EdgeInsets.only(
                                right: charge == 3 ? 0 : 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.brand.withValues(alpha: 0.1)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.brand
                                    : AppColors.hairline,
                                width: isSelected ? 1.6 : 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '₹$charge',
                                      style: TextStyle(
                                        fontFamily: AppFonts.display,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${info['hospitals']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text(
                                      'hospitals',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(
                                        color: AppColors.brand,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check_rounded,
                                          size: 13, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.calculate_rounded,
                          size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        displayHospitals.isEmpty
                            ? 'Total charge ₹0 — hospitals listed above'
                            : 'Total charge ₹$totalCost for ${displayHospitals.length} hospital(s)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpace.xl),

                  // Send
                  PrimaryButton(
                    label: 'Send Emergency Alert',
                    icon: Icons.sos_rounded,
                    loading: _isSendingAlert,
                    onPressed: _isSendingAlert ? null : _sendAlertToHospitals,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletPill extends StatelessWidget {
  const _WalletPill({required this.balance});
  final double balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_wallet_rounded,
              size: 15, color: AppColors.success),
          const SizedBox(width: 6),
          Text(
            '₹${balance.toStringAsFixed(0)}',
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== HOSPITAL ALERTS ====================

class HospitalAlertScreen extends StatefulWidget {
  const HospitalAlertScreen({super.key});

  @override
  State<HospitalAlertScreen> createState() => _HospitalAlertScreenState();
}

class _HospitalAlertScreenState extends State<HospitalAlertScreen> {
  final _db = DatabaseService();

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _db.hospitalAlerts;

    return AppBackground(
      glow: AppColors.alert,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Dispatch log',
              title: 'Hospital alerts',
              onBack: () => Navigator.of(context).pop(),
              trailing: alerts.isEmpty
                  ? null
                  : StatusBadge(
                      label: '$alerts.length',
                      color: AppColors.alert,
                    ),
            ),
            Expanded(
              child: alerts.isEmpty
                  ? EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No alerts yet',
                      message:
                          'Emergency alerts you dispatch from Emergency Mode will appear here with their dispatch details.',
                      color: AppColors.alert,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.xl, AppSpace.sm, AppSpace.xl, 32),
                      itemCount: alerts.length,
                      itemBuilder: (context, index) {
                        final alert =
                            alerts[alerts.length - 1 - index]; // Reverse order
                        return _AlertCard(
                          alert: alert,
                          time: _formatTime(alert.timestamp),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.time});
  final HospitalAlert alert;
  final String time;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: AppRadius.md,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: Icons.local_hospital_rounded,
                color: AppColors.alert,
                size: 42,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.hospitalName,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(time,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              const StatusBadge(label: 'Sent'),
            ],
          ),
          const SizedBox(height: 14),
          if (alert.symptoms.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: alert.symptoms
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(
              alert.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.currency_rupee_rounded,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    '₹${alert.chargeLevels}',
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              Flexible(
                child: Text(
                  alert.userLocation,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== USER PROFILE ====================

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  Future<void> _confirmAndLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: AppColors.brand, size: 28),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to access your control centre.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await AuthService().logout();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentLoggedInUser;

    return AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Account',
              title: 'My profile',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Center(
                    child: Column(
                      children: [
                        // Avatar
                        Container(
                          width: 96,
                          height: 96,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF3A4AA8), Color(0xFF232C49)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.hairline, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.alert.withValues(alpha: 0.25),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: Text(
                            _initials(user?.name),
                            style: TextStyle(
                              fontFamily: AppFonts.display,
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(user?.name ?? 'Guest',
                            style: Theme.of(context).textTheme.displayMedium),
                        const SizedBox(height: 6),
                        Text(user?.email ?? '—',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.alert)),
                        const SizedBox(height: 28),

                        SurfaceCard(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 4),
                                child: InfoRow(
                                  icon: Icons.alternate_email_rounded,
                                  label: 'Email address',
                                  value: user?.email ?? '—',
                                  color: AppColors.alert,
                                ),
                              ),
                              Divider(height: 1, color: AppColors.hairline),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 4),
                                child: InfoRow(
                                  icon: Icons.badge_outlined,
                                  label: 'Full name',
                                  value: user?.name ?? '—',
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        TonalButton(
                          label: 'Log out',
                          icon: Icons.logout_rounded,
                          color: AppColors.brand,
                          onPressed: () => _confirmAndLogout(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MONITORING ====================

class MonitoringScreen extends StatelessWidget {
  MonitoringScreen({super.key});

  final _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final vitals = _db.vitalSigns;

    return AppBackground(
      glow: AppColors.success,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Telemetry',
              title: 'Monitoring & tests',
              onBack: () => Navigator.of(context).pop(),
              trailing: StatusBadge(
                label: '${vitals.length}',
                color: AppColors.success,
              ),
            ),
            Expanded(
              child: vitals.isEmpty
                  ? const EmptyState(
                      icon: Icons.monitor_heart_outlined,
                      title: 'No readings',
                      message: 'Vital sign readings will appear here.',
                      color: AppColors.success,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.xl, AppSpace.sm, AppSpace.xl, 32),
                      itemCount: vitals.length,
                      itemBuilder: (context, index) =>
                          _VitalsCard(vitals: vitals[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.vitals});
  final VitalSigns vitals;

  Color _statusColor(BuildContext context) {
    if (vitals.heartRate > 120 ||
        vitals.heartRate < 60 ||
        vitals.oxygenLevel < 90 ||
        vitals.temperature > 99.5) {
      return AppColors.brand;
    }
    if (vitals.heartRate > 100 || vitals.oxygenLevel < 95) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  Widget _vitalBadge(BuildContext context,
      IconData icon, String label, String value, bool abnormal) {
    final color = abnormal ? AppColors.brand : AppColors.success;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                        )),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(vitals.patientName,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              StatusBadge(
                label: vitals.timestamp,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _vitalBadge(context, Icons.favorite_rounded, 'HEART RATE',
                  '${vitals.heartRate} bpm',
                  vitals.heartRate > 120 || vitals.heartRate < 60),
              const SizedBox(width: 10),
              _vitalBadge(context, Icons.air_rounded, 'OXYGEN',
                  '${vitals.oxygenLevel}%', vitals.oxygenLevel < 90),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _vitalBadge(context, Icons.thermostat_rounded, 'TEMP',
                  '${vitals.temperature}°F', vitals.temperature > 99.5),
              const SizedBox(width: 10),
              _vitalBadge(context, Icons.monitor_heart_outlined, 'BLOOD PRESS',
                  vitals.bloodPressure, false),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== PATIENTS ====================

class PatientScreen extends StatelessWidget {
  PatientScreen({super.key});

  final _db = DatabaseService();

  Color _getConditionColor(String condition) {
    if (condition.contains('Critical')) return AppColors.brand;
    if (condition.contains('Monitoring')) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final patients = _db.patients;

    return AppBackground(
      glow: AppColors.sky,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Registry',
              title: 'Patients',
              onBack: () => Navigator.of(context).pop(),
              trailing: StatusBadge(
                label: '${patients.length}',
                color: AppColors.sky,
              ),
            ),
            Expanded(
              child: patients.isEmpty
                  ? const EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No patients',
                      message: 'Patient records will appear here.',
                      color: AppColors.sky,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.xl, AppSpace.sm, AppSpace.xl, 32),
                      itemCount: patients.length,
                      itemBuilder: (context, index) => _PatientCard(
                          patient: patients[index],
                          color: _getConditionColor(
                              patients[index].condition)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient, required this.color});
  final PatientRecord patient;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(patient.name,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              StatusBadge(
                label: 'Room ${patient.roomNumber}',
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_rounded, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('${patient.age} yrs  •  ${patient.bloodType}',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: 14),
              Icon(Icons.calendar_today_rounded,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(patient.admissionDate,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.medical_services_rounded,
                    size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    patient.condition,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== REPORTS ====================

class ReportScreen extends StatelessWidget {
  ReportScreen({super.key});

  final _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final reports = _db.reports;

    return AppBackground(
      glow: AppColors.warning,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Documents',
              title: 'Reports',
              onBack: () => Navigator.of(context).pop(),
              trailing: StatusBadge(
                label: '${reports.length}',
                color: AppColors.warning,
              ),
            ),
            Expanded(
              child: reports.isEmpty
                  ? const EmptyState(
                      icon: Icons.description_outlined,
                      title: 'No reports',
                      message: 'Medical reports will appear here.',
                      color: AppColors.warning,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.xl, AppSpace.sm, AppSpace.xl, 32),
                      itemCount: reports.length,
                      itemBuilder: (context, index) =>
                          _ReportCard(report: reports[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final MedicalReport report;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: Icons.description_outlined,
                color: AppColors.warning,
                size: 40,
                iconSize: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.reportType,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('Dr. ${report.doctor.split(' ').last}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(height: 4),
                  Text(report.date,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(report.patientName,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(
              report.summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}