import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utilities/validators.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/repositories/app_controller.dart';

// ------------------------------------------------------------------ Splash
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await ref.read(appControllerProvider.notifier).bootstrap();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final signedIn = ref.read(appControllerProvider).isSignedIn;
    context.go(signedIn ? '/' : '/onboarding');
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: AppColors.forestGreen,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: reduceMotion
                  ? const AlwaysStoppedAnimation(1)
                  : CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
              child: const OrbitalLogo(size: 92, color: AppColors.white),
            ),
            const SizedBox(height: 22),
            FadeTransition(
              opacity: reduceMotion
                  ? const AlwaysStoppedAnimation(1)
                  : _anim,
              child: const Column(
                children: [
                  Text('ORBITAL OFFICE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3)),
                  SizedBox(height: 6),
                  Text('Work Smarter. Create Better.',
                      style: TextStyle(color: AppColors.premiumGold, fontSize: 13, letterSpacing: 1.2)),
                  SizedBox(height: 4),
                  Text('BY ORBITAL.STUDIO.3',
                      style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const CircularProgressIndicator(color: AppColors.premiumGold),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- Onboarding
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _pages = [
    ('Ideas Into Impact.', 'Documents, spreadsheets and presentations — designed the ORBITAL way.', Icons.lightbulb_outline),
    ('Run Your Business', 'Invoices in INR, customer CRM, inventory and projects in one workspace.', Icons.business_center_outlined),
    ('Works Offline', 'Create anywhere. Your work is saved on-device and syncs when you are back online.', Icons.cloud_off_outlined),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final (title, body, icon) = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (i == 0) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/branding/orbital_poster.png',
                              height: 250,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const OrbitalLogo(size: 90),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ] else ...[
                          Icon(icon, size: 84, color: AppColors.deepGreen),
                          const SizedBox(height: 28),
                        ],
                        Text(title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 10),
                        Text(body,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: AppColors.mutedText)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _page == i ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _page == i ? AppColors.deepGreen : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (_page < _pages.length - 1) {
                          _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut);
                        } else {
                          context.go('/login');
                        }
                      },
                      child: Text(_page < _pages.length - 1 ? 'Next' : 'Get Started'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Skip — I already have an account'),
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

// ------------------------------------------------------------------- Login
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    final err = await ref.read(appControllerProvider.notifier).signIn(
          email: _email.text, password: _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      context.go('/');
    } else {
      setState(() => _error = err);
    }
  }

  Future<void> _demo() async {
    setState(() => _busy = true);
    await ref.read(appControllerProvider.notifier).signInDemo();
    if (mounted) context.go('/');
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OrbitalLogo(size: 56),
                const SizedBox(height: 18),
                Text('Welcome back',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                const Text('Sign in to your ORBITAL OFFICE workspace.'),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  _ErrorBox(_error!),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: Validators.email,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Password is required' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot'),
                    child: const Text('Forgot password?'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _demo,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Explore Demo Workspace'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('New to ORBITAL OFFICE?'),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Register
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    final err = await ref.read(appControllerProvider.notifier).register(
          name: _name.text, email: _email.text, password: _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      context.go('/');
    } else {
      setState(() => _error = err);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            children: [
              if (_error != null) ...[_ErrorBox(_error!), const SizedBox(height: 14)],
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline), helperText: 'At least 8 characters, with letters and numbers'),
                validator: Validators.password,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account'),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Without a configured Supabase backend, your account is stored only on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- Forgot password
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  String? _message;
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _message = null; });
    final err = await ref
        .read(appControllerProvider.notifier)
        .resetPassword(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = err ??
          'If an account exists for this email, a password-reset link has been sent.';
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your account email and we will send a secure reset link.'),
              const SizedBox(height: 18),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: Validators.email,
              ),
              const SizedBox(height: 18),
              if (_message != null) ...[
                _ErrorBox(_message!, isError: false),
                const SizedBox(height: 14),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: const Text('Send Reset Link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.text, {this.isError = true});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red.shade700 : AppColors.deepGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}
