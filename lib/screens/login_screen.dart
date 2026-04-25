// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:presensi_app/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _nimController  = TextEditingController();
  final _passController = TextEditingController();
  bool  _obscurePass    = true;

  @override
  void dispose() {
    _nimController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth    = context.read<AuthProvider>();
    final success = await auth.login(
      _nimController.text.trim(),
      _passController.text,
    );

    // On failure show error snackbar
    // On success GoRouter redirect guard handles navigation automatically
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content        : Text(auth.errorMessage ?? 'Login failed'),
          backgroundColor: Colors.red.shade700,
          behavior       : SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── App icon ──────────────────────────────────
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color : Colors.white.withOpacity(0.15),
                    shape : BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural,
                    size : 56,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Presensi SKS',
                  style: TextStyle(
                    fontSize  : 28,
                    fontWeight: FontWeight.bold,
                    color     : Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Face Recognition Attendance System',
                  style: TextStyle(
                    fontSize: 14,
                    color   : Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 40),

                // ── Login card ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color        : Colors.white,
                    borderRadius : BorderRadius.circular(20),
                    boxShadow    : [
                      BoxShadow(
                        color : Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize  : 20,
                            fontWeight: FontWeight.bold,
                            color     : Color(0xFF1E3A5F),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // NIM / NIDN field
                        TextFormField(
                          controller   : _nimController,
                          keyboardType : TextInputType.number,
                          decoration   : InputDecoration(
                            labelText  : 'NIM / NIDN',
                            hintText   : 'Enter your NIM or NIDN',
                            prefixIcon : const Icon(Icons.badge_outlined),
                            border     : OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide  : const BorderSide(
                                color: Color(0xFF1E3A5F),
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'NIM/NIDN is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        TextFormField(
                          controller : _passController,
                          obscureText: _obscurePass,
                          decoration : InputDecoration(
                            labelText : 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePass = !_obscurePass,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide  : const BorderSide(
                                color: Color(0xFF1E3A5F),
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password is required';
                            }
                            if (v.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),

                        // Login button
                        SizedBox(
                          height: 52,
                          child : ElevatedButton(
                            onPressed: isLoading ? null : _login,
                            style    : ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A5F),
                              foregroundColor: Colors.white,
                              shape          : RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width : 24,
                                    height: 24,
                                    child : CircularProgressIndicator(
                                      color      : Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize  : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'Forgot password? Contact campus admin',
                  style: TextStyle(
                    color   : Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}