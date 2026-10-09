// Élan — Screens
// Redesigned with the AppTheme design system.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'theme.dart';
import 'services/api_service.dart';
import 'services/receiver_service.dart';

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

/// Push a page and wait for it to pop, returning the result (if any).
Future<T?> openForResult<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
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

/// Where a session should land: hospital staff get the receiver console,
/// everyone else the member dashboard.
Widget homeForSession() => AuthService().isReceiverSession
    ? const ReceiverConsole()
    : const Dashboard();

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
                  EyebrowLabel(
                    text: eyebrow,
                    color: AppColors.brand,
                    textAlign: TextAlign.center,
                  ),
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
                  const Center(child: ServerStatusPill()),
                  const SizedBox(height: 4),
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
    this.onTap,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool? obscureToggle;
  final VoidCallback? onToggleObscure;

  /// When set, the field is read-only and tapping it runs this instead
  /// (e.g. to open a date picker).
  final VoidCallback? onTap;

  /// Called when the user presses Enter / the keyboard's done key.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        readOnly: onTap != null,
        onTap: onTap,
        onSubmitted: onSubmitted,
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

/// Distances as people read them: metres under 1 km (not "0.0 km").
String formatDistance(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

/// Pick a date into [controller] as yyyy-MM-dd, the format records are sorted
/// by. Returns true when a date was chosen.
Future<bool> pickDateInto(
    BuildContext context, TextEditingController controller) async {
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime.tryParse(controller.text) ?? now,
    firstDate: DateTime(now.year - 30),
    lastDate: now,
  );
  if (picked == null) return false;
  String two(int n) => n.toString().padLeft(2, '0');
  controller.text = '${picked.year}-${two(picked.month)}-${two(picked.day)}';
  return true;
}

// ==================== LOGIN ====================

/// Segmented switch between a member account and a hospital duty-desk account.
class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.role, required this.onChanged});

  final String role;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          _RoleToggleTab(
            label: 'Member',
            icon: Icons.favorite_rounded,
            color: AppColors.brand,
            selected: role == 'member',
            onTap: () => onChanged('member'),
          ),
          _RoleToggleTab(
            label: 'Hospital staff',
            icon: Icons.local_hospital_rounded,
            color: AppColors.alert,
            selected: role == 'hospital',
            onTap: () => onChanged('hospital'),
          ),
        ],
      ),
    );
  }
}

class _RoleToggleTab extends StatelessWidget {
  const _RoleToggleTab({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color:
                  selected ? color.withValues(alpha: 0.45) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17, color: selected ? color : AppColors.textMuted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? color : AppColors.textSecondary,
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

/// Facility picker shown to hospital staff during signup.
class _HospitalPicker extends StatelessWidget {
  const _HospitalPicker({
    required this.hospitals,
    required this.selectedId,
    required this.loading,
    required this.onChanged,
  });

  final List<HospitalLocation> hospitals;
  final String? selectedId;
  final bool loading;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.alert),
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      isExpanded: true,
      dropdownColor: AppColors.surfaceRaised,
      decoration: const InputDecoration(
        labelText: 'Your hospital',
        prefixIcon: Icon(Icons.local_hospital_rounded, size: 20),
      ),
      items: hospitals
          .map((h) => DropdownMenuItem<String>(
                value: h.id,
                child: Text(
                  h.name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ))
          .toList(),
      onChanged: hospitals.isEmpty ? null : onChanged,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.hospitalMode = false});

  /// Pre-selects the hospital staff tab when coming back from signup.
  final bool hospitalMode;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _hospitalMode = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.hospitalMode) _hospitalMode = true;
  }

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
    } else if (_authService.isReceiverSession) {
      // Hospital staff never broadcast their own location — straight to console.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ReceiverConsole()),
      );
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
      eyebrow: _hospitalMode ? 'Receiver desk' : 'Emergency cardiac care',
      title: 'Welcome back',
      subtitle: _hospitalMode
          ? 'Sign in to receive and respond to Élan alerts'
          : 'Sign in to continue to your control centre',
      child: SurfaceCard(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RoleToggle(
              role: _hospitalMode ? 'hospital' : 'member',
              onChanged: (role) =>
                  setState(() => _hospitalMode = role == 'hospital'),
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
              onSubmitted: (_) {
                if (!_isLoading) _handleLogin();
              },
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
                  Text("New to Élan?",
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SignUpScreen(hospitalMode: _hospitalMode))),
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
  const SignUpScreen({super.key, this.hospitalMode = false});

  /// Pre-selects the hospital staff tab when arriving from the login screen.
  final bool hospitalMode;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _api = ApiService();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  String _role = 'member';
  List<HospitalLocation> _hospitals = [];
  String? _hospitalId;
  bool _loadingHospitals = false;

  @override
  void initState() {
    super.initState();
    if (widget.hospitalMode) _role = 'hospital';
    _loadHospitals();
  }

  /// Hospital staff pick their facility at signup, so fetch the live list and
  /// fall back to the bundled directory if the server is unreachable.
  Future<void> _loadHospitals() async {
    setState(() => _loadingHospitals = true);

    final response = await _api.getHospitals();
    final remote = response.success
        ? ((response.data?['hospitals'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((h) => HospitalLocation(
                  id: (h['id'] as String?) ?? '',
                  name: (h['name'] as String?) ?? 'Hospital',
                  address: (h['address'] as String?) ?? '',
                  phone: (h['phone'] as String?) ?? '',
                  latitude: (h['latitude'] as num?)?.toDouble() ?? 0,
                  longitude: (h['longitude'] as num?)?.toDouble() ?? 0,
                  emergencyContactEmail: '',
                ))
            .toList()
        : <HospitalLocation>[];

    if (!mounted) return;
    setState(() {
      _hospitals = remote.isNotEmpty ? remote : DatabaseService().hospitals;
      _loadingHospitals = false;
    });
  }

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
      role: _role,
      hospitalId: _hospitalId,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      if (_role == 'hospital') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text(
                'Account created. An administrator must approve your staff '
                'access before the hospital inbox opens.'),
          ),
        );
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(hospitalMode: _role == 'hospital'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = _role == 'hospital';

    return _AuthShell(
      eyebrow: 'Join the network',
      title: 'Create your account',
      subtitle: isStaff
          ? 'Register the duty desk that receives Élan alerts'
          : 'Set up access to emergency response',
      child: SurfaceCard(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RoleToggle(
              role: _role,
              onChanged: (role) => setState(() => _role = role),
            ),
            if (isStaff) ...[
              const SizedBox(height: 16),
              _HospitalPicker(
                hospitals: _hospitals,
                selectedId: _hospitalId,
                loading: _loadingHospitals,
                onChanged: (id) => setState(() => _hospitalId = id),
              ),
            ],
            const SizedBox(height: 16),
            _AuthField(
              controller: _nameController,
              label: isStaff ? 'Duty officer name' : 'Full name',
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
                            builder: (_) => LoginScreen(
                                hospitalMode: _role == 'hospital'))),
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
  final _api = ApiService();
  double _wallet = 5000.0;

  // Record counts from the server; null until loaded (or when offline).
  int? _alertCount;
  int? _patientCount;
  int? _vitalCount;
  int? _reportCount;

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _syncProfile();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    if (!_api.isAuthenticated) return;
    final results = await Future.wait([
      _api.getAlertHistory(),
      _api.getPatients(),
      _api.getVitals(),
      _api.getReports(),
    ]);
    if (!mounted) return;

    int? count(ApiResponse r, String key) =>
        r.success && r.data is Map && r.data[key] is List
            ? (r.data[key] as List).length
            : null;

    setState(() {
      _alertCount = count(results[0], 'alerts');
      _patientCount = count(results[1], 'patients');
      _vitalCount = count(results[2], 'vitals');
      _reportCount = count(results[3], 'reports');
    });
  }

  String _countLabel(int? count, String singular, String plural) {
    if (count == null) return 'Open $plural';
    return '$count ${count == 1 ? singular : plural}';
  }

  Future<void> _loadWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getDouble('walletBalance') ?? 5000.0;
    if (mounted) setState(() => _wallet = balance);
  }

  Future<void> _syncProfile() async {
    if (AuthService().currentLoggedInUser?.id == null) return;
    final error = await AuthService().syncProfileFromServer();
    if (!mounted) return;
    if (error == null) setState(() {});
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
    final displayName = user?.name ?? 'Guest';
    final alertsSent = _alertCount ?? 0;
    final hospitalCount = DatabaseService().hospitals.length;

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
                        // Status sits on the eyebrow line so the greeting
                        // keeps the full width on phones.
                        const Wrap(
                          spacing: AppSpace.sm,
                          runSpacing: AppSpace.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            EyebrowLabel(text: 'Control centre'),
                            ServerStatusPill(syncing: true),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _greeting,
                          style: Theme.of(context).textTheme.headlineMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                  const SizedBox(width: AppSpace.md),
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
                    // Four across on tablets; two stretched tiles there are
                    // mostly empty space.
                    crossAxisCount:
                        MediaQuery.sizeOf(context).width >= 600 ? 4 : 2,
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
                        subtitle: _alertCount == null
                            ? 'Open log'
                            : '$alertsSent sent',
                        onTap: () => open(context, const HospitalAlertScreen()),
                      ),
                      _ModuleTile(
                        icon: Icons.groups_outlined,
                        color: AppColors.sky,
                        title: 'Patients',
                        subtitle:
                            _countLabel(_patientCount, 'record', 'records'),
                        onTap: () => open(context, PatientScreen()),
                      ),
                      _ModuleTile(
                        icon: Icons.monitor_heart_outlined,
                        color: AppColors.success,
                        title: 'Monitoring',
                        subtitle:
                            _countLabel(_vitalCount, 'reading', 'readings'),
                        onTap: () => open(context, MonitoringScreen()),
                      ),
                      _ModuleTile(
                        icon: Icons.description_outlined,
                        color: AppColors.warning,
                        title: 'Reports',
                        subtitle:
                            _countLabel(_reportCount, 'document', 'documents'),
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
    Widget cell(Widget child) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: child,
          ),
        );

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpace.lg, horizontal: AppSpace.xs),
      child: Row(
        children: [
          cell(StatValue(
            label: 'Credit',
            value: '₹${credit.toStringAsFixed(0)}',
            color: AppColors.success,
            icon: Icons.account_balance_wallet_rounded,
          )),
          Container(width: 1, height: 40, color: AppColors.hairline),
          cell(StatValue(
            label: 'Care units',
            value: '$hospitalCount',
            color: AppColors.alert,
            icon: Icons.local_hospital_rounded,
          )),
          Container(width: 1, height: 40, color: AppColors.hairline),
          cell(StatValue(
            label: 'Alerts sent',
            value: '$alertsSent',
            color: AppColors.brand,
            icon: Icons.notifications_active_rounded,
          )),
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
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
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
  String? _locationError;
  bool _locationIsLastKnown = false;
  List<Map<String, dynamic>> _nearbyHospitals = []; // From API
  List<HospitalLocation> _localHospitals = []; // Offline preview only
  bool _isLoadingLocation = false;
  bool _isSendingAlert = false;
  int _selectedCharge = 1; // Tier 1, 2, or 3

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
    return _localHospitals
        .map((h) => {
              'name': h.name,
              'phone': h.phone,
              'distanceKm': h.distanceTo(_userLocation!),
            })
        .toList();
  }

  int get _tierHospitalCount => _tierInfo[_selectedCharge]!['hospitals'] as int;

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
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });
    try {
      final result = await _locationService.getCurrentLocation();
      if (!mounted) return;

      final location = result.location;
      if (location == null) {
        setState(() {
          _userLocation = null;
          _locationError = result.error;
          _nearbyHospitals = [];
          _localHospitals = [];
        });
        return;
      }

      setState(() {
        _userLocation = location;
        _locationIsLastKnown = result.lastKnown;
        _localHospitals = _db.getNearbyHospitals(location, radiusKm: 50);
      });

      final response = await _api.getNearbyHospitals(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: 50,
      );

      if (mounted && response.success && response.data is Map) {
        setState(() {
          _nearbyHospitals =
              List<Map<String, dynamic>>.from(response.data['hospitals'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  /// The alert did not reach any hospital. Say so plainly — never let the
  /// user believe help is on the way when it is not. Resolves to true when
  /// the user asks to retry (only offered when [retryAlertId] is given).
  Future<bool> _showDispatchFailed(String? reason,
      {String? retryAlertId}) async {
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.error_rounded, color: AppColors.brand, size: 44),
        title: const Text('Alert NOT sent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'No hospital has been notified. Call emergency services now: '
              '112 (national emergency) or 108 (ambulance).',
              style: Theme.of(dialogContext)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(reason, style: Theme.of(dialogContext).textTheme.bodySmall),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Close'),
          ),
          if (retryAlertId != null)
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Retry sending'),
            ),
        ],
      ),
    );
    return retry == true;
  }

  /// Send an alert whose payment is already settled, retrying for as long as
  /// the user asks. Runs inside the caller's sending state, so the SOS button
  /// stays disabled throughout.
  Future<void> _dispatchPaidAlert(String alertId) async {
    while (mounted) {
      final send = await _api.sendEmergencyAlert(alertId);
      if (!mounted) return;

      var notified = send.success && send.data is Map
          ? (send.data['hospitalsNotified'] as num?)?.toInt() ?? 0
          : null;

      // A timeout (or an "already sent" reply to a retry) does not mean the
      // alert failed — the server may have dispatched it. Ask before telling
      // the user it was not sent.
      if (!send.success) notified = await _confirmedDispatchCount(alertId);
      if (!mounted) return;

      if (notified != null && notified > 0) {
        _showDispatchSucceeded(alertId, notified);
        return;
      }
      if (!await _showDispatchFailed(send.error, retryAlertId: alertId)) {
        return;
      }
    }
  }

  /// How many hospitals the server has linked to this alert, or null when
  /// that cannot be determined.
  Future<int?> _confirmedDispatchCount(String alertId) async {
    final details = await _api.getAlertDetails(alertId);
    if (!details.success || details.data is! Map) return null;
    final hospitals = details.data['hospitals'];
    return hospitals is List ? hospitals.length : null;
  }

  void _showDispatchSucceeded(String alertId, int hospitalsNotified) {
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
              'Emergency alert sent to $hospitalsNotified '
              '${hospitalsNotified == 1 ? 'hospital' : 'hospitals'} with your location. '
              'Track who has responded and their ETA in Hospital Alerts. '
              'If your condition worsens, call 112 or 108.',
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
              'ALERT ID  ${alertId.length > 8 ? alertId.substring(0, 8).toUpperCase() : alertId.toUpperCase()}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted, fontFamily: AppFonts.display),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              open(this.context, const HospitalAlertScreen());
            },
            child: const Text('Track responses'),
          ),
        ],
      ),
    );

    // Clear form
    setState(() {
      _selectedSymptoms.clear();
      _messageController.clear();
      _selectedCharge = 1;
    });
  }

  void _sendAlertToHospitals() async {
    if (_selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one symptom')),
      );
      return;
    }

    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationError ??
              'Waiting for your location — tap the location button to retry'),
        ),
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
            // Flexible so the title wraps instead of overflowing on phones
            Flexible(child: Text('Confirm emergency alert')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hospitalCount == 1
                  ? 'This will alert the nearest hospital with your location.'
                  : 'This will alert up to $hospitalCount nearby hospitals with your location.',
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
                          style: Theme.of(context).textTheme.titleLarge),
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

    bool walletDeducted = false;
    String? alertId;

    try {
      // 1. Create the order. The server also checks a hospital is in range
      //    before taking any payment.
      final message = _messageController.text.trim();
      final orderResponse = await _api.createPaymentOrder(
        tier: _selectedCharge,
        latitude: _userLocation!.latitude,
        longitude: _userLocation!.longitude,
        symptoms: _selectedSymptoms.join(', '),
        message: message.isEmpty ? null : message,
      );

      if (!orderResponse.success || orderResponse.data is! Map) {
        if (mounted) await _showDispatchFailed(orderResponse.error);
        return;
      }

      final data = orderResponse.data as Map;
      alertId = data['alertId'] as String;
      final orderId = data['order']['id'] as String;
      final amountPaise = (data['order']['amount'] as num?)?.toInt() ?? 0;
      final keyId = (data['razorpayKeyId'] as String?) ?? '';
      final isMockGateway = data['mockGateway'] == true ||
          keyId == 'test_key' ||
          orderId.startsWith('order_mock_');

      // 2. Pay.
      if (!isMockGateway) {
        // Real payment gateway configured — open Razorpay checkout.
        final user = AuthService().currentLoggedInUser;
        final payment = await _startRazorpayCheckout(
          keyId: keyId,
          orderId: orderId,
          amountPaise: amountPaise,
          email: user?.email ?? '',
          name: user?.name ?? 'Élan User',
        );

        if (!payment.success) {
          if (mounted) {
            await _showDispatchFailed(
                'Payment was not completed: ${payment.error ?? 'cancelled'}');
          }
          return;
        }

        final verify = await _api.verifyPayment(
          orderId: orderId,
          paymentId: payment.paymentId!,
          signature: payment.signature!,
          alertId: alertId,
        );

        if (!verify.success) {
          if (mounted) await _showDispatchFailed(verify.error);
          return;
        }
      } else {
        // Mock gateway (development: no Razorpay keys) — settle via the demo
        // wallet credit.
        if (_walletBalance < priceValue) {
          if (mounted) {
            await _showDispatchFailed(
                'Insufficient demo credit — need $price, have ₹${_walletBalance.toStringAsFixed(0)}');
          }
          return;
        }
        setState(() => _walletBalance -= priceValue);
        await _saveWalletBalance();
        walletDeducted = true;

        final verify = await _api.verifyPayment(
          orderId: orderId,
          paymentId: 'wallet_${DateTime.now().millisecondsSinceEpoch}',
          signature: 'wallet_payment',
          alertId: alertId,
        );
        if (!verify.success) {
          await _refundWallet(priceValue);
          walletDeducted = false;
          if (mounted) await _showDispatchFailed(verify.error);
          return;
        }
      }

      // 3. Dispatch. Payment is settled from here on, so a failure offers a
      //    retry of the same alert rather than a second charge.
      await _dispatchPaidAlert(alertId);
    } catch (e) {
      debugPrint('Emergency dispatch error: $e');
      if (walletDeducted) await _refundWallet(priceValue);
      if (!mounted) return;
      await _showDispatchFailed('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isSendingAlert = false);
    }
  }

  Future<void> _refundWallet(double amount) async {
    if (mounted) {
      setState(() => _walletBalance += amount);
    } else {
      _walletBalance += amount;
    }
    await _saveWalletBalance();
  }

  /// Opens the Razorpay checkout and resolves once the sheet is closed.
  Future<_RazorpayPaymentResult> _startRazorpayCheckout({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String email,
    required String name,
  }) async {
    final completer = Completer<_RazorpayPaymentResult>();
    final razorpay = Razorpay();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (payload) {
      final payment = payload as PaymentSuccessResponse;
      if (!completer.isCompleted) {
        completer.complete(_RazorpayPaymentResult(
          success: true,
          paymentId: payment.paymentId,
          signature: payment.signature,
        ));
      }
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (payload) {
      final error = payload as PaymentFailureResponse;
      if (!completer.isCompleted) {
        completer.complete(_RazorpayPaymentResult(
          success: false,
          error: error.message ?? 'Payment failed',
        ));
      }
    });

    // External wallet selected — the success/error event still arrives next.
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});

    razorpay.open({
      'key': keyId,
      'order_id': orderId,
      'amount': amountPaise,
      'currency': 'INR',
      'name': 'Élan',
      'description': 'Emergency cardiac alert',
      'prefill': {
        if (email.isNotEmpty) 'email': email,
        if (name.isNotEmpty) 'name': name,
      },
      'theme': {'color': '#B72236'},
    });

    // Detach the event listeners once the sheet resolves either way
    return completer.future
        .timeout(
          const Duration(minutes: 3),
          onTimeout: () => _RazorpayPaymentResult(
            success: false,
            error: 'Payment timed out',
          ),
        )
        .whenComplete(razorpay.clear);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayHospitals = _displayHospitals;

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
                      onPressed:
                          _isLoadingLocation ? null : _getCurrentLocation,
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
                                  Flexible(
                                    child: Text(
                                      _isLoadingLocation
                                          ? 'Acquiring position…'
                                          : _locationError != null
                                              ? 'Location unavailable'
                                              : _locationIsLastKnown
                                                  ? 'Last known position'
                                                  : 'Live position',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                              color: AppColors.textSecondary,
                                              letterSpacing: 1.0),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                                      decoration: BoxDecoration(
                                          color: _userLocation == null
                                              ? AppColors.brand
                                              : _locationIsLastKnown
                                                  ? AppColors.warning
                                                  : AppColors.success,
                                          shape: BoxShape.circle),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (_userLocation == null &&
                                  _locationError != null &&
                                  !_isLoadingLocation)
                                Text(
                                  _locationError!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppColors.brand),
                                )
                              else
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
                      label: '${displayHospitals.length} found',
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
                                : _userLocation == null
                                    ? 'Hospitals appear once your location is known'
                                    : 'No hospitals found nearby',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  else
                    ...displayHospitals.map((hospital) {
                      final name = hospital['name'] ?? 'Unknown Hospital';
                      final phone = hospital['phone'] ?? '';
                      final distance =
                          (hospital['distanceKm'] as num?)?.toDouble() ?? 0.0;
                      final distText = formatDistance(distance);
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
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(phone,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
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
                                distText,
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
                  SectionHeader(
                      eyebrow: 'Details (optional)', title: 'Message'),
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
                          onTap: () => setState(() => _selectedCharge = charge),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            margin:
                                EdgeInsets.only(right: charge == 3 ? 0 : 10),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      info['hospitals'] == 1
                                          ? 'hospital'
                                          : 'hospitals',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
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
                      Expanded(
                        child: Text(
                          // Tiers are a flat price, not per hospital
                          'Flat charge ${_tierInfo[_selectedCharge]!['price']} — '
                          'alerts up to $_tierHospitalCount nearest '
                          '${_tierHospitalCount == 1 ? 'hospital' : 'hospitals'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Send — pinned below the form so the SOS action is always one
            // tap away, never two screens of scrolling down.
            Container(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.lg),
              decoration: const BoxDecoration(
                color: AppColors.ink,
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: PrimaryButton(
                label: 'Send Emergency Alert',
                icon: Icons.sos_rounded,
                loading: _isSendingAlert,
                onPressed: _isSendingAlert ? null : _sendAlertToHospitals,
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
  final _api = ApiService();

  List<HospitalAlert> _remoteAlerts = [];
  bool _syncing = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _syncAlertHistory();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Future<void> _syncAlertHistory() async {
    if (!_api.isAuthenticated) return;
    setState(() {
      _syncing = true;
      _syncError = null;
    });

    final response = await _api.getAlertHistory();

    if (!mounted) return;
    setState(() => _syncing = false);

    if (response.success) {
      final alerts = (response.data?['alerts'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(_remoteAlertToLocal)
          .expand((entries) => entries)
          .toList();
      setState(() => _remoteAlerts = alerts);
    } else {
      setState(() => _syncError = response.error);
    }
  }

  List<HospitalAlert> _remoteAlertToLocal(Map<String, dynamic> alert) {
    final symptoms = ((alert['symptoms'] as String?) ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final message = (alert['message'] as String?) ?? '';
    final tier = (alert['tier'] as int?) ?? 1;
    final createdAt =
        DateTime.tryParse((alert['createdAt'] as String?) ?? '') ??
            DateTime.now();
    final lat = (alert['location'] is Map
            ? (alert['location']!['latitude'] as num?)?.toStringAsFixed(4)
            : null) ??
        '—';
    final lng = (alert['location'] is Map
            ? (alert['location']!['longitude'] as num?)?.toStringAsFixed(4)
            : null) ??
        '—';
    final locationText = '$lat, $lng';

    final hospitals =
        (alert['hospitals'] as List? ?? []).whereType<Map<String, dynamic>>();
    if (hospitals.isEmpty) {
      // Created but never dispatched (payment abandoned or dispatch failed)
      return [
        HospitalAlert(
          id: (alert['id'] as String?) ?? '',
          hospitalId: '',
          hospitalName: 'Not dispatched',
          timestamp: createdAt,
          symptoms: symptoms,
          message: message,
          chargeLevels: tier,
          messageDelivered: false,
          userLocation: locationText,
        ),
      ];
    }

    return hospitals
        .map((hospital) => HospitalAlert(
              id: '${alert['id']}_${hospital['name']}',
              alertId: (alert['id'] as String?) ?? '',
              hospitalId: (hospital['name'] as String?) ?? '',
              hospitalName: (hospital['name'] as String?) ?? 'Care unit',
              timestamp: createdAt,
              symptoms: symptoms,
              message: message,
              chargeLevels: tier,
              messageDelivered: hospital['notificationSent'] == true,
              userLocation: locationText,
              acknowledged: hospital['acknowledged'] == true,
              declined: hospital['declined'] == true,
              etaMinutes: (hospital['etaMinutes'] as num?)?.toInt(),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // One card per emergency (each fans out to several hospitals), newest first
    final sorted = [..._remoteAlerts]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final grouped = <String, List<HospitalAlert>>{};
    for (final dispatch in sorted) {
      grouped.putIfAbsent(dispatch.alertId, () => []).add(dispatch);
    }
    final alerts = grouped.values.toList();

    return AppBackground(
      glow: AppColors.alert,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Dispatch log',
              title: 'Hospital alerts',
              onBack: () => Navigator.of(context).pop(),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_syncing) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.alert),
                    ),
                    const SizedBox(width: 10),
                  ],
                  IconButton(
                    tooltip: 'Sync from server',
                    onPressed: _syncing ? null : _syncAlertHistory,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: AppColors.alert,
                  ),
                  if (alerts.isNotEmpty)
                    StatusBadge(
                      label: '${alerts.length}',
                      color: AppColors.alert,
                    ),
                ],
              ),
            ),
            if (_syncError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, 0, AppSpace.xl, AppSpace.sm),
                child:
                    ErrorBanner(message: 'Could not sync alerts from server'),
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
                        final dispatches = alerts[index];
                        return _AlertCard(
                          dispatches: dispatches,
                          time: _formatTime(dispatches.first.timestamp),
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

/// One emergency: what was reported once, then each hospital it reached and
/// how that hospital responded.
class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.dispatches, required this.time});
  final List<HospitalAlert> dispatches;
  final String time;

  HospitalAlert get _first => dispatches.first;

  /// Headline for the whole alert — the thing the sender most needs.
  (String, Color) get _summary {
    final coming = dispatches.where((d) => d.acknowledged).toList();
    if (coming.isNotEmpty) {
      final etas = coming.map((d) => d.etaMinutes).whereType<int>().toList()
        ..sort();
      return (
        etas.isEmpty ? 'Help is coming' : 'Help is coming · ${etas.first} min',
        AppColors.success,
      );
    }
    if (dispatches.every((d) => !d.messageDelivered && !d.declined)) {
      return ('Not delivered', AppColors.brand);
    }
    if (dispatches.every((d) => d.declined)) {
      return ('All declined — call 112', AppColors.brand);
    }
    return ('Awaiting reply', AppColors.warning);
  }

  static (String, Color) _hospitalStatus(HospitalAlert d) {
    if (d.acknowledged) {
      return (
        d.etaMinutes != null ? 'Coming · ${d.etaMinutes} min' : 'Acknowledged',
        AppColors.success,
      );
    }
    if (d.declined) return ('Declined', AppColors.textMuted);
    if (!d.messageDelivered) return ('Not delivered', AppColors.brand);
    return ('Awaiting reply', AppColors.warning);
  }

  @override
  Widget build(BuildContext context) {
    final (summary, summaryColor) = _summary;
    final textTheme = Theme.of(context).textTheme;
    final dispatched = dispatches.where((d) => d.hospitalId.isNotEmpty);

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
                icon: Icons.sos_rounded,
                color: summaryColor,
                size: 42,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary,
                        style: textTheme.titleMedium
                            ?.copyWith(color: summaryColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$time · Tier ${_first.chargeLevels} · ₹${_first.chargeLevels}',
                            style: textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_first.symptoms.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _first.symptoms
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
          if (_first.message.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Text(
                _first.message,
                style: textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Per-hospital responses
          for (final d in dispatched)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.local_hospital_rounded,
                      size: 16, color: AppColors.alert),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.hospitalName,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Builder(builder: (_) {
                    final (label, color) = _hospitalStatus(d);
                    return StatusBadge(label: label, color: color);
                  }),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _first.userLocation,
                  style: textTheme.bodySmall,
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

// ==================== HOSPITAL RECEIVER CONSOLE ====================

class ReceiverConsole extends StatefulWidget {
  const ReceiverConsole({super.key});

  @override
  State<ReceiverConsole> createState() => _ReceiverConsoleState();
}

class _ReceiverConsoleState extends State<ReceiverConsole> {
  final _receiver = ReceiverService();

  List<ReceiverAlert> _alerts = [];
  ReceiverHospital? _hospital;
  ReceiverStats _stats = const ReceiverStats();
  String _filter = 'all';
  bool _loading = true;
  bool _offline = false;
  bool _pendingApproval = false;
  String? _error;
  Timer? _poll;

  static const _pollInterval = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _poll = Timer.periodic(_pollInterval, (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Show the cached inbox immediately, then reconcile with the server.
    final cached = await _receiver.loadCache();
    if (!mounted) return;
    setState(() {
      _alerts = cached.alerts;
      _hospital = cached.hospital;
      _stats = cached.stats;
    });
    await _refresh();
  }

  Future<void> _refresh({bool silent = false}) async {
    final result = await _receiver.refreshInbox();
    if (!mounted) return;

    if (result.inbox != null) {
      setState(() {
        _alerts = result.inbox!.alerts;
        _hospital = result.inbox!.hospital ?? _hospital;
        _stats = result.inbox!.stats;
        _loading = false;
        _offline = false;
        _pendingApproval = false;
        _error = null;
      });
      return;
    }

    if (result.pendingApproval) {
      // Not approved (or access revoked): don't keep showing cached patient
      // alerts, and don't present it as a connection problem.
      await _receiver.clearCache();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pendingApproval = true;
        _alerts = [];
        _stats = const ReceiverStats();
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = false;
      _pendingApproval = false;
      if (_alerts.isEmpty) {
        _error = result.error;
      } else {
        _offline = true;
      }
    });

    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Could not reach the server')),
      );
    }
  }

  List<ReceiverAlert> get _visibleAlerts => _filter == 'all'
      ? _alerts
      : _alerts.where((a) => a.status.name == _filter).toList();

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${time.day}/${time.month}';
  }

  Future<void> _openDetail(ReceiverAlert alert) async {
    final updated = await openForResult<ReceiverAlert>(
      context,
      ReceiverAlertDetailScreen(alert: alert),
    );
    if (!mounted) return;

    if (updated != null) {
      setState(() {
        _alerts = _alerts.map((a) => a.id == updated.id ? updated : a).toList();
        _stats = _recount();
      });
    }
  }

  ReceiverStats _recount() {
    var pending = 0, acknowledged = 0, declined = 0;
    for (final alert in _alerts) {
      switch (alert.status) {
        case ReceiverAlertStatus.acknowledged:
          acknowledged++;
        case ReceiverAlertStatus.declined:
          declined++;
        case ReceiverAlertStatus.pending:
          pending++;
      }
    }
    return ReceiverStats(
      total: _alerts.length,
      pending: pending,
      acknowledged: acknowledged,
      declined: declined,
    );
  }

  Future<void> _acknowledge(ReceiverAlert alert) async {
    final choice = await _pickEta(context);
    if (choice == null || !mounted) return;

    final result =
        await _receiver.acknowledge(alert.id, etaMinutes: choice.minutes);
    if (!mounted) return;

    if (result.alert == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.error ?? 'Could not acknowledge the alert')),
      );
      return;
    }

    setState(() {
      _alerts =
          _alerts.map((a) => a.id == alert.id ? result.alert! : a).toList();
      _stats = _recount();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          choice.minutes == null
              ? 'Alert acknowledged — the patient has been notified'
              : 'Acknowledged · the patient was told to expect you in ~${choice.minutes} min',
        ),
      ),
    );
  }

  Future<void> _decline(ReceiverAlert alert) async {
    final reason = await _pickDeclineReason(context);
    if (reason == null || !mounted) return;

    final result = await _receiver.decline(alert.id, reason: reason);
    if (!mounted) return;

    if (result.alert == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Could not decline the alert')),
      );
      return;
    }

    setState(() {
      _alerts =
          _alerts.map((a) => a.id == alert.id ? result.alert! : a).toList();
      _stats = _recount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final staff = AuthService().currentLoggedInUser;

    return AppBackground(
      glow: AppColors.alert,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Receiver console',
              title: _hospital?.name ?? 'Duty desk',
              subtitle: staff?.email,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Facility',
                    onPressed: () =>
                        open(context, const ReceiverFacilityScreen()),
                    icon: const Icon(Icons.apartment_rounded, size: 20),
                    color: AppColors.alert,
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : () => _refresh(),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: AppColors.alert,
                  ),
                ],
              ),
            ),
            if (_offline)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(
                    AppSpace.xl, 0, AppSpace.xl, AppSpace.sm),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        size: 16, color: AppColors.warning),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Offline — showing the last alerts this desk received',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatValue(
                          label: 'Awaiting',
                          value: '${_stats.pending}',
                          color: _stats.pending > 0
                              ? AppColors.brand
                              : AppColors.textSecondary,
                          icon: Icons.notifications_active_rounded,
                        ),
                      ),
                      Expanded(
                        child: StatValue(
                          label: 'Accepted',
                          value: '${_stats.acknowledged}',
                          color: AppColors.success,
                          icon: Icons.check_circle_rounded,
                        ),
                      ),
                      Expanded(
                        child: StatValue(
                          label: 'Passed',
                          value: '${_stats.declined}',
                          color: AppColors.textSecondary,
                          icon: Icons.do_not_disturb_on_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  _FilterChips(
                    selected: _filter,
                    counts: {
                      'all': _stats.total,
                      'pending': _stats.pending,
                      'acknowledged': _stats.acknowledged,
                      'declined': _stats.declined,
                    },
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading && _alerts.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.alert),
                    )
                  : _pendingApproval
                  ? const EmptyState(
                      icon: Icons.hourglass_top_rounded,
                      title: 'Awaiting approval',
                      message:
                          'An administrator needs to approve your staff account '
                          'before alerts for this hospital appear here. This '
                          'page updates automatically once you are approved.',
                      color: AppColors.warning,
                    )
                  : _error != null && _alerts.isEmpty
                      ? EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Cannot reach Élan',
                          message: _error!,
                          color: AppColors.warning,
                        )
                      : RefreshIndicator(
                          onRefresh: () => _refresh(),
                          color: AppColors.alert,
                          backgroundColor: AppColors.surfaceRaised,
                          child: _visibleAlerts.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 60),
                                    EmptyState(
                                      icon: Icons.inbox_rounded,
                                      title: 'Inbox clear',
                                      message:
                                          'Cardiac alerts routed to this hospital will land here the moment a member sends one.',
                                      color: AppColors.alert,
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      AppSpace.xl,
                                      AppSpace.sm,
                                      AppSpace.xl,
                                      32),
                                  itemCount: _visibleAlerts.length,
                                  itemBuilder: (context, index) {
                                    final alert = _visibleAlerts[index];
                                    return _ReceiverAlertCard(
                                      alert: alert,
                                      time: _relativeTime(alert.createdAt),
                                      onOpen: () => _openDetail(alert),
                                      onAcknowledge: () => _acknowledge(alert),
                                      onDecline: () => _decline(alert),
                                    );
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status filter row for the receiver inbox.
class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  static const _labels = {
    'all': 'All',
    'pending': 'New',
    'acknowledged': 'Accepted',
    'declined': 'Passed',
  };

  @override
  Widget build(BuildContext context) {
    // Wrap rather than a sideways scroll: with four filters, a chip clipped
    // at the gutter just looks cut off.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _labels.entries.map((entry) {
        final isSelected = entry.key == selected;
        final color = switch (entry.key) {
          'pending' => AppColors.brand,
          'acknowledged' => AppColors.success,
          'declined' => AppColors.textSecondary,
          _ => AppColors.alert,
        };
        return GestureDetector(
          onTap: () => onChanged(entry.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.16)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.5)
                    : AppColors.hairline,
              ),
            ),
            child: Text(
              '${entry.value}  ${counts[entry.key] ?? 0}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReceiverAlertCard extends StatelessWidget {
  const _ReceiverAlertCard({
    required this.alert,
    required this.time,
    required this.onOpen,
    required this.onAcknowledge,
    required this.onDecline,
  });

  final ReceiverAlert alert;
  final String time;
  final VoidCallback onOpen;
  final VoidCallback onAcknowledge;
  final VoidCallback onDecline;

  (String, Color) get _statusStyle => switch (alert.status) {
        ReceiverAlertStatus.acknowledged => ('Accepted', AppColors.success),
        ReceiverAlertStatus.declined => ('Passed', AppColors.textSecondary),
        ReceiverAlertStatus.pending => ('New', AppColors.brand),
      };

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _statusStyle;

    return SurfaceCard(
      radius: AppRadius.md,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: onOpen,
      borderColor:
          alert.isPending ? AppColors.brand.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: Icons.monitor_heart_rounded,
                color: statusColor,
                size: 42,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.patientName,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(time,
                            style: Theme.of(context).textTheme.bodySmall),
                        if (alert.distanceKm != null) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.near_me_rounded,
                              size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(formatDistance(alert.distanceKm!),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
          if (alert.symptoms.isNotEmpty) ...[
            const SizedBox(height: 14),
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
          ],
          if (alert.status == ReceiverAlertStatus.acknowledged &&
              alert.etaMinutes != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.directions_car_rounded,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Text('Team en route · ~${alert.etaMinutes} min',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.success)),
              ],
            ),
          ],
          if (alert.status == ReceiverAlertStatus.declined &&
              alert.declineReason != null) ...[
            const SizedBox(height: 12),
            Text(alert.declineReason!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (alert.isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TonalButton(
                    label: 'Pass',
                    icon: Icons.do_not_disturb_on_rounded,
                    color: AppColors.textSecondary,
                    onPressed: onDecline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Accept',
                    icon: Icons.check_rounded,
                    color: AppColors.success,
                    onPressed: onAcknowledge,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Full detail view with the response actions.
class ReceiverAlertDetailScreen extends StatefulWidget {
  const ReceiverAlertDetailScreen({super.key, required this.alert});

  final ReceiverAlert alert;

  @override
  State<ReceiverAlertDetailScreen> createState() =>
      _ReceiverAlertDetailScreenState();
}

class _ReceiverAlertDetailScreenState extends State<ReceiverAlertDetailScreen> {
  late ReceiverAlert _alert = widget.alert;
  final _receiver = ReceiverService();
  bool _submitting = false;

  Future<void> _acknowledge() async {
    final choice = await _pickEta(context);
    if (choice == null || !mounted) return;

    setState(() => _submitting = true);
    final result =
        await _receiver.acknowledge(_alert.id, etaMinutes: choice.minutes);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.alert == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.error ?? 'Could not acknowledge the alert')),
      );
      return;
    }

    setState(() => _alert = result.alert!);
  }

  Future<void> _decline() async {
    final reason = await _pickDeclineReason(context);
    if (reason == null || !mounted) return;

    setState(() => _submitting = true);
    final result = await _receiver.decline(_alert.id, reason: reason);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.alert == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Could not decline the alert')),
      );
      return;
    }

    setState(() => _alert = result.alert!);
  }

  void _close() => Navigator.of(context).pop(_alert);

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (_alert.status) {
      ReceiverAlertStatus.acknowledged => ('Accepted', AppColors.success),
      ReceiverAlertStatus.declined => ('Passed', AppColors.textSecondary),
      ReceiverAlertStatus.pending => ('Awaiting response', AppColors.brand),
    };

    return AppBackground(
      glow: AppColors.alert,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Incoming alert',
              title: _alert.patientName,
              subtitle: _alert.createdAt.toLocal().toString().split('.').first,
              onBack: _close,
              trailing: StatusBadge(label: statusLabel, color: statusColor),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, 32),
                children: [
                  SurfaceCard(
                    borderColor: statusColor.withValues(alpha: 0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const EyebrowLabel(text: 'Reported symptoms'),
                        const SizedBox(height: 10),
                        if (_alert.symptoms.isEmpty)
                          Text('No symptoms recorded',
                              style: Theme.of(context).textTheme.bodyMedium)
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _alert.symptoms
                                .map((s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.brand
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(999),
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
                        if (_alert.message.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.ink.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: Text(
                              _alert.message,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  SurfaceCard(
                    child: Column(
                      children: [
                        // Full name here too: the header truncates long names
                        InfoRow(
                          icon: Icons.person_rounded,
                          label: 'Patient',
                          value: _alert.patientName,
                          color: AppColors.alert,
                        ),
                        Divider(height: 24, color: AppColors.hairline),
                        InfoRow(
                          icon: Icons.my_location_rounded,
                          label: 'Patient coordinates',
                          value:
                              '${_alert.latitude.toStringAsFixed(5)}, ${_alert.longitude.toStringAsFixed(5)}',
                          color: AppColors.brand,
                        ),
                        if (_alert.distanceKm != null) ...[
                          Divider(height: 24, color: AppColors.hairline),
                          InfoRow(
                            icon: Icons.near_me_rounded,
                            label: 'Distance from this hospital',
                            value:
                                formatDistance(_alert.distanceKm!),
                            color: AppColors.sky,
                          ),
                        ],
                        if (_alert.patientPhone.isNotEmpty) ...[
                          Divider(height: 24, color: AppColors.hairline),
                          InfoRow(
                            icon: Icons.phone_rounded,
                            label: 'Patient phone',
                            value: _alert.patientPhone,
                            color: AppColors.success,
                          ),
                        ],
                        Divider(height: 24, color: AppColors.hairline),
                        InfoRow(
                          icon: Icons.map_rounded,
                          label: 'Navigation',
                          value: _alert.mapsUrl.isEmpty
                              ? 'Unavailable'
                              : 'Copy the maps link to open directions',
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                  if (_alert.mapsUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TonalButton(
                      label: 'Copy navigation link',
                      icon: Icons.link_rounded,
                      color: AppColors.warning,
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: _alert.mapsUrl));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Navigation link copied to clipboard')),
                        );
                      },
                    ),
                  ],
                  if (_alert.status != ReceiverAlertStatus.pending) ...[
                    const SizedBox(height: AppSpace.lg),
                    SurfaceCard(
                      color: statusColor.withValues(alpha: 0.07),
                      borderColor: statusColor.withValues(alpha: 0.3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EyebrowLabel(
                              text: 'Your response', color: statusColor),
                          const SizedBox(height: 10),
                          Text(
                            _alert.status == ReceiverAlertStatus.acknowledged
                                ? (_alert.etaMinutes != null
                                    ? 'Accepted · team en route in about ${_alert.etaMinutes} min'
                                    : 'Accepted · team dispatched')
                                : 'Passed${_alert.declineReason != null ? ' · ${_alert.declineReason}' : ''}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () => _alert.status ==
                                        ReceiverAlertStatus.declined
                                    ? _acknowledge()
                                    : _decline(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.hairline),
                              minimumSize: const Size(0, 46),
                            ),
                            child: Text(
                              _alert.status == ReceiverAlertStatus.declined
                                  ? 'Change to accepted'
                                  : 'Change to passed',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_alert.isPending) ...[
                    const SizedBox(height: AppSpace.lg),
                    PrimaryButton(
                      label: 'Accept & dispatch team',
                      icon: Icons.check_rounded,
                      color: AppColors.success,
                      loading: _submitting,
                      onPressed: _submitting ? null : _acknowledge,
                    ),
                    const SizedBox(height: 12),
                    TonalButton(
                      label: 'Pass to other hospitals',
                      icon: Icons.do_not_disturb_on_rounded,
                      color: AppColors.textSecondary,
                      onPressed: _submitting ? null : _decline,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Facility details and sign-out for the receiving desk.
class ReceiverFacilityScreen extends StatefulWidget {
  const ReceiverFacilityScreen({super.key});

  @override
  State<ReceiverFacilityScreen> createState() => _ReceiverFacilityScreenState();
}

class _ReceiverFacilityScreenState extends State<ReceiverFacilityScreen> {
  final _receiver = ReceiverService();
  final _auth = AuthService();

  ReceiverHospital? _hospital;
  ReceiverStats _stats = const ReceiverStats();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _receiver.loadProfile();
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result.hospital == null) {
        _error = result.error;
        final cached = _receiver.cachedInbox;
        _hospital = cached?.hospital;
        _stats = cached?.stats ?? const ReceiverStats();
      } else {
        _hospital = result.hospital;
        _stats = _receiver.cachedInbox?.stats ?? const ReceiverStats();
      }
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon:
            const Icon(Icons.logout_rounded, color: AppColors.brand, size: 28),
        title: const Text('End this shift?'),
        content: const Text(
            'The receiver console will close and you will need to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen(hospitalMode: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = _auth.currentLoggedInUser;
    final hospital = _hospital;
    final address = hospital?.address.trim() ?? '';
    final phone = hospital?.phone.trim() ?? '';

    return AppBackground(
      glow: AppColors.alert,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Receiver console',
              title: 'Facility',
              onBack: () => Navigator.of(context).pop(),
              trailing: IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: AppColors.alert,
              ),
            ),
            Expanded(
              child: _loading && hospital == null
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.alert),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.xl, AppSpace.sm, AppSpace.xl, 32),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Column(
                            children: [
                              if (_error != null) ...[
                                ErrorBanner(
                                  message:
                                      'Showing cached facility details — $_error',
                                ),
                                const SizedBox(height: 14),
                              ],
                              const IconTile(
                                icon: Icons.local_hospital_rounded,
                                color: AppColors.alert,
                                size: 84,
                                iconSize: 38,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                hospital?.name ?? 'Hospital',
                                style:
                                    Theme.of(context).textTheme.displayMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                staff?.email ?? '—',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.alert),
                              ),
                              const SizedBox(height: 12),
                              const StatusBadge(
                                  label: 'DUTY DESK', color: AppColors.alert),
                              const SizedBox(height: AppSpace.xxl),
                              SurfaceCard(
                                child: Column(
                                  children: [
                                    InfoRow(
                                      icon: Icons.place_rounded,
                                      label: 'Address',
                                      value:
                                          address.isEmpty ? 'Not set' : address,
                                      color: AppColors.sky,
                                    ),
                                    Divider(
                                        height: 24, color: AppColors.hairline),
                                    InfoRow(
                                      icon: Icons.phone_rounded,
                                      label: 'Emergency line',
                                      value: phone.isEmpty ? 'Not set' : phone,
                                      color: AppColors.success,
                                    ),
                                    Divider(
                                        height: 24, color: AppColors.hairline),
                                    InfoRow(
                                      icon: Icons.inbox_rounded,
                                      label: 'Alerts received',
                                      value: '${_stats.total}',
                                      color: AppColors.brand,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpace.xl),
                              TonalButton(
                                label: 'Log out',
                                icon: Icons.logout_rounded,
                                color: AppColors.brand,
                                onPressed: _logout,
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

/// Ask the duty officer for an arrival estimate. Returns null when cancelled,
/// or `minutes: null` when they accept without committing to a time.
Future<({bool confirmed, int? minutes})?> _pickEta(BuildContext context) {
  const options = [5, 10, 15, 20, 30];
  return showDialog<({bool confirmed, int? minutes})>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Team arrival estimate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'The patient is told what to expect once you accept.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map((minutes) => ActionChip(
                      label: Text('~$minutes min'),
                      onPressed: () => Navigator.of(context)
                          .pop((confirmed: true, minutes: minutes)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop((confirmed: true, minutes: null)),
            child: const Text('No estimate'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

/// Ask why this hospital is passing. `null` means "cancelled".
Future<String?> _pickDeclineReason(BuildContext context) {
  const reasons = [
    'No cardiac team available',
    'Beds full — diverting',
    'Outside our catchment',
    'Wrong dispatch for this facility',
  ];

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Pass this alert?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'The patient sees that you could not take it, and the other notified hospitals keep standing by.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          ...reasons.map((reason) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(reason),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.hairline),
                    minimumSize: const Size(0, 46),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(reason),
                ),
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

// ==================== USER PROFILE ====================

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _auth = AuthService();
  bool _syncing = false;
  String? _syncError;
  String? _lastSyncMessage;

  @override
  void initState() {
    super.initState();
    _syncProfile();
  }

  Future<void> _syncProfile() async {
    setState(() {
      _syncing = true;
      _syncError = null;
      _lastSyncMessage = null;
    });

    final error = await _auth.syncProfileFromServer();

    if (!mounted) return;
    setState(() {
      _syncing = false;
      if (error != null) {
        _syncError = error;
      } else {
        _lastSyncMessage = 'Profile synced from server';
      }
    });
  }

  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon:
            const Icon(Icons.logout_rounded, color: AppColors.brand, size: 28),
        title: const Text('Log out?'),
        content: const Text(
            'You will need to sign in again to access your control centre.'),
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

    if (confirmed != true || !mounted) return;

    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _openEditForm() async {
    final changed = await openForResult<bool>(
      context,
      EditProfileScreen(),
    );
    if (changed == true && mounted) {
      await _syncProfile();
    }
  }

  Color _roleColor(String role) {
    if (role == 'admin') return AppColors.brand;
    if (role == 'physician' || role == 'doctor') return AppColors.success;
    return AppColors.sky;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentLoggedInUser;
    final role =
        (user?.role.isEmpty ?? true) ? 'member' : (user?.role ?? 'member');
    final phone = user?.phone ?? '';

    return AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Account',
              title: 'My profile',
              onBack: () => Navigator.of(context).pop(),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_syncing) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.brand),
                    ),
                    const SizedBox(width: 10),
                  ],
                  IconButton(
                    tooltip: 'Sync profile',
                    onPressed: _syncing ? null : _syncProfile,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: AppColors.brand,
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: _openEditForm,
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    color: AppColors.brand,
                  ),
                ],
              ),
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
                        if (_syncError != null) ...[
                          ErrorBanner(
                            message: 'Could not sync profile from server',
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (_lastSyncMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                  color:
                                      AppColors.success.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.cloud_done_rounded,
                                    size: 18, color: AppColors.success),
                                const SizedBox(width: 9),
                                Text(_lastSyncMessage!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.success)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
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
                            border:
                                Border.all(color: AppColors.hairline, width: 2),
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
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displayMedium),
                        const SizedBox(height: 6),
                        Text(user?.email ?? '—',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.alert)),
                        const SizedBox(height: 12),
                        StatusBadge(
                          label: role.toUpperCase(),
                          color: _roleColor(role),
                        ),
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
                              Divider(height: 1, color: AppColors.hairline),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 4),
                                child: InfoRow(
                                  icon: Icons.phone_outlined,
                                  label: 'Phone',
                                  value: phone.isEmpty ? 'Not set' : phone,
                                  color: AppColors.sky,
                                ),
                              ),
                              Divider(height: 1, color: AppColors.hairline),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 4),
                                child: InfoRow(
                                  icon: Icons.shield_outlined,
                                  label: 'Role',
                                  value: role.toUpperCase(),
                                  color: _roleColor(role),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        TonalButton(
                          label: 'Edit profile',
                          icon: Icons.edit_rounded,
                          color: AppColors.brand,
                          onPressed: _openEditForm,
                        ),

                        const SizedBox(height: 28),

                        TonalButton(
                          label: 'Log out',
                          icon: Icons.logout_rounded,
                          color: AppColors.brand,
                          onPressed: _confirmAndLogout,
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

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = AuthService();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentLoggedInUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await _auth.updateProfile(
      name: name,
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Account',
              title: 'Edit profile',
              onBack: () => Navigator.of(context).pop(),
              trailing: StatusBadge(
                label: 'Edit',
                color: AppColors.brand,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        ErrorBanner(message: _error!),
                        const SizedBox(height: 14),
                      ],
                      _AuthField(
                        controller: _nameController,
                        label: 'Full name',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 14),
                      _AuthField(
                        controller: _phoneController,
                        label: 'Phone (optional)',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Save changes',
                        icon: Icons.check_rounded,
                        loading: _submitting,
                        onPressed: _submitting ? null : _submit,
                      ),
                    ],
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

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final _api = ApiService();

  final List<VitalSigns> _remoteVitals = [];
  bool _syncing = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _syncVitals();
  }

  Future<void> _syncVitals() async {
    if (!_api.isAuthenticated) return;
    setState(() {
      _syncing = true;
      _syncError = null;
    });

    final response = await _api.getVitals();

    if (!mounted) return;
    setState(() => _syncing = false);

    if (response.success) {
      final vitals = (response.data?['vitals'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(_remoteVitalToLocal)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setState(() {
        _remoteVitals
          ..clear()
          ..addAll(vitals);
      });
    } else {
      setState(() => _syncError = response.error);
    }
  }

  VitalSigns _remoteVitalToLocal(Map<String, dynamic> v) {
    return VitalSigns(
      patientId: (v['patient_id'] as String?) ?? '',
      patientName: (v['patient_name'] as String?) ?? 'Unknown patient',
      heartRate: (v['heart_rate'] as num?)?.toInt() ?? 0,
      bloodPressure: (v['blood_pressure'] as String?) ?? '—',
      temperature: (v['temperature'] as num?)?.toDouble() ?? 0,
      oxygenLevel: (v['oxygen_level'] as num?)?.toInt() ?? 0,
      timestamp: (v['timestamp'] as String?) ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final vitals = _remoteVitals;

    return AppBackground(
      glow: AppColors.success,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Telemetry',
              title: 'Monitoring',
              onBack: () => Navigator.of(context).pop(),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_syncing) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.success),
                    ),
                    const SizedBox(width: 10),
                  ],
                  IconButton(
                    tooltip: 'Sync from server',
                    onPressed: _syncing ? null : _syncVitals,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: AppColors.success,
                  ),
                  IconButton(
                    tooltip: 'Add reading',
                    onPressed: () async {
                      final result = await openForResult<bool>(
                          context, const AddVitalScreen());
                      if (result == true && mounted) _syncVitals();
                    },
                    icon: const Icon(Icons.add_rounded, size: 20),
                    color: AppColors.success,
                  ),
                  if (vitals.isNotEmpty)
                    StatusBadge(
                      label: '${vitals.length}',
                      color: AppColors.success,
                    ),
                ],
              ),
            ),
            if (_syncError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, 0, AppSpace.xl, AppSpace.sm),
                child:
                    ErrorBanner(message: 'Could not sync readings from server'),
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
                      itemBuilder: (context, index) => _VitalsCard(
                        vitals: vitals[index],
                        onTap: () => open(
                          context,
                          VitalDetailScreen(vitals: vitals[index]),
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

/// Readings store an ISO timestamp; older ones only kept "10:15"-style times.
String formatVitalTimestamp(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.vitals, this.onTap});
  final VitalSigns vitals;
  final VoidCallback? onTap;

  Color _statusColor(BuildContext context) {
    if (vitals.heartRate > 120 ||
        vitals.heartRate < 60 ||
        vitals.oxygenLevel < 90 ||
        vitals.hasFever) {
      return AppColors.brand;
    }
    if (vitals.heartRate > 100 || vitals.oxygenLevel < 95) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  Widget _vitalBadge(BuildContext context, IconData icon, String label,
      String value, bool abnormal) {
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
                Flexible(
                  child: Text(label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 1.0,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
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
      onTap: onTap,
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
                label: formatVitalTimestamp(vitals.timestamp),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _vitalBadge(
                  context,
                  Icons.favorite_rounded,
                  'HEART RATE',
                  '${vitals.heartRate} bpm',
                  vitals.heartRate > 100 || vitals.heartRate < 60),
              const SizedBox(width: 10),
              _vitalBadge(context, Icons.air_rounded, 'OXYGEN',
                  '${vitals.oxygenLevel}%', vitals.oxygenLevel < 95),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _vitalBadge(context, Icons.thermostat_rounded, 'TEMP',
                  vitals.temperatureLabel, vitals.hasFever),
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

class VitalDetailScreen extends StatelessWidget {
  const VitalDetailScreen({super.key, required this.vitals});
  final VitalSigns vitals;

  Color get _statusColor {
    if (vitals.heartRate > 120 ||
        vitals.heartRate < 60 ||
        vitals.oxygenLevel < 90 ||
        vitals.hasFever) {
      return AppColors.brand;
    }
    if (vitals.heartRate > 100 || vitals.oxygenLevel < 95) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    return AppBackground(
      glow: color,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Telemetry record',
              title: vitals.patientName,
              onBack: () => Navigator.of(context).pop(),
              trailing: StatusBadge(
                  label: formatVitalTimestamp(vitals.timestamp), color: color),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vital signs',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _VitalDetailTile(
                          icon: Icons.favorite_rounded,
                          label: 'HEART RATE',
                          value: '${vitals.heartRate}',
                          unit: 'bpm',
                          color: vitals.heartRate > 100
                              ? AppColors.brand
                              : AppColors.success,
                        ),
                        const SizedBox(width: 12),
                        _VitalDetailTile(
                          icon: Icons.air_rounded,
                          label: 'OXYGEN',
                          value: '${vitals.oxygenLevel}',
                          unit: '%',
                          color: vitals.oxygenLevel < 95
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _VitalDetailTile(
                          icon: Icons.thermostat_rounded,
                          label: 'TEMPERATURE',
                          value: vitals.temperature.toStringAsFixed(1),
                          unit: vitals.isCelsius ? '°C' : '°F',
                          color: vitals.hasFever
                              ? AppColors.brand
                              : AppColors.success,
                        ),
                        const SizedBox(width: 12),
                        _VitalDetailTile(
                          icon: Icons.compress_rounded,
                          label: 'BLOOD PRESS',
                          value: vitals.bloodPressure,
                          unit: 'mmHg',
                          color: AppColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SurfaceCard(
                      padding: const EdgeInsets.all(16),
                      radius: AppRadius.md,
                      child: Row(
                        children: [
                          Icon(Icons.person_pin_circle_rounded,
                              size: 20, color: color),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Patient ID  •  ${vitals.patientId}',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VitalDetailTile extends StatelessWidget {
  const _VitalDetailTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                        )),
              ],
            ),
            const SizedBox(height: 10),
            _RecordedValueText(value: value, unit: unit, color: color),
          ],
        ),
      ),
    );
  }
}

class _RecordedValueText extends StatelessWidget {
  const _RecordedValueText({
    required this.value,
    required this.unit,
    required this.color,
  });
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        children: [
          TextSpan(text: value),
          TextSpan(
            text: ' $unit',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class AddVitalScreen extends StatefulWidget {
  const AddVitalScreen({super.key});

  @override
  State<AddVitalScreen> createState() => _AddVitalScreenState();
}

class _AddVitalScreenState extends State<AddVitalScreen> {
  final _api = ApiService();
  final _patientNameController = TextEditingController();
  final _patientIdController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _oxygenController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientIdController.dispose();
    _heartRateController.dispose();
    _oxygenController.dispose();
    _temperatureController.dispose();
    _bloodPressureController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _patientNameController.text.trim();
    final patientId = _patientIdController.text.trim();
    final heartRate = int.tryParse(_heartRateController.text.trim());
    final oxygen = int.tryParse(_oxygenController.text.trim());
    final temperature = double.tryParse(_temperatureController.text.trim());
    final bloodPressure = _bloodPressureController.text.trim();

    if (name.isEmpty ||
        patientId.isEmpty ||
        heartRate == null ||
        oxygen == null ||
        temperature == null ||
        bloodPressure.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final now = DateTime.now();
    final response = await _api.createVital(
      patientId: patientId,
      patientName: name,
      heartRate: heartRate,
      bloodPressure: bloodPressure,
      temperature: temperature,
      oxygenLevel: oxygen,
      // Full ISO date so readings sort correctly across days
      timestamp: now.toUtc().toIso8601String(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (response.success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = response.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _patientNameController.text.isNotEmpty &&
        _patientIdController.text.isNotEmpty &&
        _heartRateController.text.isNotEmpty &&
        _oxygenController.text.isNotEmpty &&
        _temperatureController.text.isNotEmpty &&
        _bloodPressureController.text.isNotEmpty;

    return AppBackground(
      glow: AppColors.success,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Telemetry',
              title: 'Add reading',
              onBack: () => Navigator.of(context).pop(),
              trailing: StatusBadge(
                label: 'Live',
                color: AppColors.success,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      ErrorBanner(message: _error!),
                      const SizedBox(height: 14),
                    ],
                    _AuthField(
                      controller: _patientNameController,
                      label: 'Patient name',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    _AuthField(
                      controller: _patientIdController,
                      label: 'Patient ID',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _AuthField(
                            controller: _heartRateController,
                            label: 'Heart rate',
                            icon: Icons.favorite_outline_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AuthField(
                            controller: _oxygenController,
                            label: 'Oxygen %',
                            icon: Icons.air_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _AuthField(
                            controller: _temperatureController,
                            label: 'Temp °C/°F',
                            icon: Icons.thermostat_rounded,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AuthField(
                            controller: _bloodPressureController,
                            label: 'BP 120/80',
                            icon: Icons.compress_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Save reading',
                      icon: Icons.check_rounded,
                      color: AppColors.success,
                      loading: _submitting,
                      onPressed: canSubmit && !_submitting ? _submit : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== PATIENTS ====================

class PatientScreen extends StatefulWidget {
  const PatientScreen({super.key});

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  final _api = ApiService();

  final List<PatientRecord> _remotePatients = [];
  bool _syncing = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _syncPatients();
  }

  Future<void> _syncPatients() async {
    if (!_api.isAuthenticated) return;
    setState(() {
      _syncing = true;
      _syncError = null;
    });

    final response = await _api.getPatients();

    if (!mounted) return;
    setState(() => _syncing = false);

    if (response.success) {
      final patients = (response.data?['patients'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(_remotePatientToLocal)
          .toList()
        ..sort((a, b) => b.admissionDate.compareTo(a.admissionDate));
      setState(() {
        _remotePatients
          ..clear()
          ..addAll(patients);
      });
    } else {
      setState(() => _syncError = response.error);
    }
  }

  PatientRecord _remotePatientToLocal(Map<String, dynamic> p) {
    return PatientRecord(
      id: (p['id'] as String?) ?? '',
      name: (p['name'] as String?) ?? 'Unknown patient',
      age: (p['age'] as num?)?.toInt() ?? 0,
      bloodType: (p['blood_type'] as String?) ?? '—',
      condition: (p['condition'] as String?) ?? '—',
      admissionDate: (p['admission_date'] as String?) ?? '',
      roomNumber: (p['room_number'] as String?) ?? '—',
    );
  }

  Color _getConditionColor(String condition) {
    if (condition.contains('Critical')) return AppColors.brand;
    if (condition.contains('Monitoring')) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final patients = _remotePatients;

    return AppBackground(
      glow: AppColors.sky,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Registry',
              title: 'Patients',
              onBack: () => Navigator.of(context).pop(),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_syncing) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.sky),
                    ),
                    const SizedBox(width: 10),
                  ],
                  IconButton(
                    tooltip: 'Sync from server',
                    onPressed: _syncing ? null : _syncPatients,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: AppColors.sky,
                  ),
                  IconButton(
                    tooltip: 'Add patient',
                    onPressed: () async {
                      final result = await openForResult<bool>(
                          context, const AddPatientScreen());
                      if (result == true && mounted) _syncPatients();
                    },
                    icon: const Icon(Icons.add_rounded, size: 20),
                    color: AppColors.sky,
                  ),
                  if (patients.isNotEmpty)
                    StatusBadge(
                      label: '${patients.length}',
                      color: AppColors.sky,
                    ),
                ],
              ),
            ),
            if (_syncError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, 0, AppSpace.xl, AppSpace.sm),
                child:
                    ErrorBanner(message: 'Could not sync patients from server'),
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
                          color: _getConditionColor(patients[index].condition),
                          onTap: () async {
                            final result = await openForResult<bool>(
                              context,
                              PatientDetailScreen(
                                patient: patients[index],
                              ),
                            );
                            if (result == true && mounted) _syncPatients();
                          }),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient, required this.color, this.onTap});
  final PatientRecord patient;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      radius: AppRadius.md,
      onTap: onTap,
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
              Flexible(
                child: Text('${patient.age} yrs  •  ${patient.bloodType}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 14),
              Icon(Icons.calendar_today_rounded,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(patient.admissionDate,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
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
                Icon(Icons.medical_services_rounded, size: 16, color: color),
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

class PatientDetailScreen extends StatelessWidget {
  const PatientDetailScreen({super.key, required this.patient});
  final PatientRecord patient;

  Color get _conditionColor {
    if (patient.condition.contains('Critical')) return AppColors.brand;
    if (patient.condition.contains('Monitoring')) return AppColors.warning;
    return AppColors.success;
  }

  Widget _infoTile(
      BuildContext context, IconData icon, String label, String value) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.sm,
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.sky),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted, letterSpacing: 1.2)),
                const SizedBox(height: 3),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _conditionColor;
    return AppBackground(
      glow: color,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Patient registry',
              title: patient.name,
              onBack: () => Navigator.of(context).pop(),
              trailing: StatusBadge(
                label: 'Room ${patient.roomNumber}',
                color: color,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.medical_services_rounded,
                              size: 18, color: color),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              patient.condition,
                              style: TextStyle(
                                color: color,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _infoTile(context, Icons.person_rounded, 'Age',
                        '${patient.age} years'),
                    _infoTile(context, Icons.water_drop_outlined, 'Blood type',
                        patient.bloodType),
                    _infoTile(context, Icons.calendar_today_rounded,
                        'Admission date', patient.admissionDate),
                    _infoTile(context, Icons.meeting_room_outlined, 'Room',
                        patient.roomNumber),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: 'Edit patient',
                      icon: Icons.edit_rounded,
                      color: AppColors.sky,
                      onPressed: () async {
                        final result = await openForResult<bool>(
                          context,
                          AddPatientScreen(patient: patient),
                        );
                        if (result == true && context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key, this.patient});
  final PatientRecord? patient;

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _api = ApiService();
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _bloodTypeController;
  late final TextEditingController _conditionController;
  late final TextEditingController _admissionDateController;
  late final TextEditingController _roomController;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.patient != null;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _nameController = TextEditingController(text: p?.name ?? '');
    _ageController = TextEditingController(text: p != null ? '${p.age}' : '');
    _bloodTypeController = TextEditingController(text: p?.bloodType ?? '');
    _conditionController = TextEditingController(text: p?.condition ?? '');
    _admissionDateController =
        TextEditingController(text: p?.admissionDate ?? '');
    _roomController = TextEditingController(text: p?.roomNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bloodTypeController.dispose();
    _conditionController.dispose();
    _admissionDateController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    final bloodType = _bloodTypeController.text.trim();
    final condition = _conditionController.text.trim();
    final admissionDate = _admissionDateController.text.trim();
    final room = _roomController.text.trim();

    if (name.isEmpty ||
        age == null ||
        bloodType.isEmpty ||
        condition.isEmpty ||
        admissionDate.isEmpty ||
        room.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final ApiResponse response;
    if (_isEditing && widget.patient!.id.isNotEmpty) {
      response = await _api.updatePatient(
        widget.patient!.id,
        name: name,
        age: age,
        bloodType: bloodType,
        condition: condition,
        admissionDate: admissionDate,
        roomNumber: room,
      );
    } else {
      response = await _api.createPatient(
        name: name,
        age: age,
        bloodType: bloodType,
        condition: condition,
        admissionDate: admissionDate,
        roomNumber: room,
      );
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (response.success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = response.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _nameController.text.isNotEmpty &&
        _ageController.text.isNotEmpty &&
        _bloodTypeController.text.isNotEmpty &&
        _conditionController.text.isNotEmpty &&
        _admissionDateController.text.isNotEmpty &&
        _roomController.text.isNotEmpty;

    return AppBackground(
      glow: AppColors.sky,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Registry',
              title: _isEditing ? 'Edit patient' : 'Add patient',
              onBack: () => Navigator.of(context).pop(),
              trailing: StatusBadge(
                label: _isEditing ? 'Edit' : 'New',
                color: AppColors.sky,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      ErrorBanner(message: _error!),
                      const SizedBox(height: 14),
                    ],
                    _AuthField(
                      controller: _nameController,
                      label: 'Full name',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _AuthField(
                            controller: _ageController,
                            label: 'Age',
                            icon: Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AuthField(
                            controller: _bloodTypeController,
                            label: 'Blood type',
                            icon: Icons.water_drop_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _AuthField(
                      controller: _conditionController,
                      label: 'Condition (e.g. Stable - Post MI)',
                      icon: Icons.medical_services_outlined,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _AuthField(
                            controller: _admissionDateController,
                            label: 'Admitted',
                            icon: Icons.calendar_today_rounded,
                            onTap: () async {
                              if (await pickDateInto(
                                      context, _admissionDateController) &&
                                  mounted) {
                                setState(() {});
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AuthField(
                            controller: _roomController,
                            label: 'Room',
                            icon: Icons.meeting_room_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: _isEditing ? 'Save changes' : 'Add patient',
                      icon: Icons.check_rounded,
                      color: AppColors.sky,
                      loading: _submitting,
                      onPressed: canSubmit && !_submitting ? _submit : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== REPORTS ====================

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _api = ApiService();

  final List<MedicalReport> _remoteReports = [];
  bool _syncing = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _syncReports();
  }

  Future<void> _syncReports() async {
    if (!_api.isAuthenticated) return;
    setState(() {
      _syncing = true;
      _syncError = null;
    });

    final response = await _api.getReports();

    if (!mounted) return;
    setState(() => _syncing = false);

    if (response.success) {
      final reports = (response.data?['reports'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(_remoteReportToLocal)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _remoteReports
          ..clear()
          ..addAll(reports);
      });
    } else {
      setState(() => _syncError = response.error);
    }
  }

  MedicalReport _remoteReportToLocal(Map<String, dynamic> r) {
    return MedicalReport(
      id: (r['id'] as String?) ?? '',
      patientName: (r['patient_name'] as String?) ?? 'Unknown patient',
      reportType: (r['report_type'] as String?) ?? 'Report',
      date: (r['date'] as String?) ?? '',
      summary: (r['summary'] as String?) ?? '',
      doctor: (r['doctor'] as String?) ?? '—',
    );
  }

  @override
  Widget build(BuildContext context) {
    final reports = _remoteReports;

    return AppBackground(
      glow: AppColors.warning,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Documents',
              title: 'Reports',
              onBack: () => Navigator.of(context).pop(),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_syncing) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.warning),
                    ),
                    const SizedBox(width: 10),
                  ],
                  IconButton(
                    tooltip: 'Sync from server',
                    onPressed: _syncing ? null : _syncReports,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: AppColors.warning,
                  ),
                  IconButton(
                    tooltip: 'Add report',
                    onPressed: () async {
                      final result = await openForResult<bool>(
                          context, const AddReportScreen());
                      if (result == true && mounted) _syncReports();
                    },
                    icon: const Icon(Icons.add_rounded, size: 20),
                    color: AppColors.warning,
                  ),
                  if (reports.isNotEmpty)
                    StatusBadge(
                      label: '${reports.length}',
                      color: AppColors.warning,
                    ),
                ],
              ),
            ),
            if (_syncError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, 0, AppSpace.xl, AppSpace.sm),
                child:
                    ErrorBanner(message: 'Could not sync reports from server'),
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
                      itemBuilder: (context, index) => _ReportCard(
                        report: reports[index],
                        onTap: () => open(
                          context,
                          ReportDetailScreen(report: reports[index]),
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

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, this.onTap});
  final MedicalReport report;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      radius: AppRadius.md,
      onTap: onTap,
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
                    Text(report.doctor,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
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
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key, required this.report});
  final MedicalReport report;

  Widget _metaTile(
      BuildContext context, IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.warning),
            const SizedBox(height: 8),
            Text(label.toUpperCase(),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textMuted, letterSpacing: 1.2)),
            const SizedBox(height: 3),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      glow: AppColors.warning,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Document',
              title: report.reportType,
              onBack: () => Navigator.of(context).pop(),
              trailing: IconTile(
                icon: Icons.description_outlined,
                color: AppColors.warning,
                size: 34,
                iconSize: 17,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(report.patientName,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _metaTile(context, Icons.person_rounded, 'Patient',
                            report.patientName),
                        const SizedBox(width: 12),
                        _metaTile(context, Icons.calendar_today_rounded, 'Date',
                            report.date),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _metaTile(context, Icons.medical_services_rounded,
                            'Type', report.reportType),
                        const SizedBox(width: 12),
                        _metaTile(context, Icons.badge_outlined, 'Doctor',
                            report.doctor),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Summary',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Text(
                        report.summary,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary, height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final _api = ApiService();
  final _patientNameController = TextEditingController();
  final _reportTypeController = TextEditingController();
  final _dateController = TextEditingController();
  final _summaryController = TextEditingController();
  final _doctorController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _patientNameController.dispose();
    _reportTypeController.dispose();
    _dateController.dispose();
    _summaryController.dispose();
    _doctorController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final patientName = _patientNameController.text.trim();
    final reportType = _reportTypeController.text.trim();
    final date = _dateController.text.trim();
    final summary = _summaryController.text.trim();
    final doctor = _doctorController.text.trim();

    if (patientName.isEmpty ||
        reportType.isEmpty ||
        date.isEmpty ||
        summary.isEmpty ||
        doctor.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final response = await _api.createReport(
      patientName: patientName,
      reportType: reportType,
      date: date,
      summary: summary,
      doctor: doctor,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (response.success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = response.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _patientNameController.text.isNotEmpty &&
        _reportTypeController.text.isNotEmpty &&
        _dateController.text.isNotEmpty &&
        _summaryController.text.isNotEmpty &&
        _doctorController.text.isNotEmpty;

    return AppBackground(
      glow: AppColors.warning,
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              eyebrow: 'Documents',
              title: 'Add report',
              onBack: () => Navigator.of(context).pop(),
              trailing: StatusBadge(
                label: 'New',
                color: AppColors.warning,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      ErrorBanner(message: _error!),
                      const SizedBox(height: 14),
                    ],
                    _AuthField(
                      controller: _patientNameController,
                      label: 'Patient name',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    _AuthField(
                      controller: _reportTypeController,
                      label: 'Report type',
                      icon: Icons.description_outlined,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _AuthField(
                            controller: _dateController,
                            label: 'Date',
                            icon: Icons.calendar_today_rounded,
                            onTap: () async {
                              if (await pickDateInto(
                                      context, _dateController) &&
                                  mounted) {
                                setState(() {});
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AuthField(
                            controller: _doctorController,
                            label: 'Doctor',
                            icon: Icons.badge_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _AuthField(
                      controller: _summaryController,
                      label: 'Summary',
                      icon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Save report',
                      icon: Icons.check_rounded,
                      color: AppColors.warning,
                      loading: _submitting,
                      onPressed: canSubmit && !_submitting ? _submit : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== PAYMENT RESULT ====================

class _RazorpayPaymentResult {
  const _RazorpayPaymentResult({
    required this.success,
    this.paymentId,
    this.signature,
    this.error,
  });

  final bool success;
  final String? paymentId;
  final String? signature;
  final String? error;
}
