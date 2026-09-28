import 'package:flutter/material.dart';
import 'api_service.dart';

class AuthPage extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthPage({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  bool obscurePassword = true;
  bool loading = false;

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _submit() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty) {
      _showMessage('Please enter a username.');
      return;
    }

    if (password.isEmpty) {
      _showMessage('Please enter a password.');
      return;
    }

    // Password rules are checked when registering.
    if (!isLogin) {
      final passwordValid = RegExp(
        r'^(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).+$',
      ).hasMatch(password);

      if (!passwordValid) {
        _showMessage(
          'Password must contain 1 uppercase letter, 1 number, '
          'and 1 special character.',
        );
        return;
      }
    }

    setState(() {
      loading = true;
    });

    try {
      if (isLogin) {
        await ApiService.login(
          username: username,
          password: password,
        );
      } else {
        await ApiService.register(
          username: username,
          password: password,
        );
      }

      if (!mounted) return;

      widget.onAuthenticated();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      String message = e.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }

      _showMessage(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090611),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 450,
            ),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF120D1B),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFF2A2134),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9B5CFF).withOpacity(.12),
                    blurRadius: 35,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LOGO
                  Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF8E4DFF),
                            Color(0xFFE35BFF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9B5CFF)
                                .withOpacity(.3),
                            blurRadius: 25,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'PRODUCTIVITY HUB',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    isLogin
                        ? 'Welcome back. Let’s get things done.'
                        : 'Create your account and start achieving.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF756C82),
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // LOGIN / REGISTER SWITCH
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0914),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _modeButton(
                            text: 'LOGIN',
                            selected: isLogin,
                            onTap: () {
                              setState(() {
                                isLogin = true;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: _modeButton(
                            text: 'REGISTER',
                            selected: !isLogin,
                            onTap: () {
                              setState(() {
                                isLogin = false;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  TextField(
                    controller: usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      'Username',
                      Icons.person_outline_rounded,
                    ),
                  ),

                  const SizedBox(height: 15),

                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    onSubmitted: (_) {
                      if (!loading) {
                        _submit();
                      }
                    },
                    decoration: _inputDecoration(
                      'Password',
                      Icons.lock_outline_rounded,
                    ).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF756C82),
                        ),
                      ),
                    ),
                  ),

                  if (!isLogin) ...[
                    const SizedBox(height: 12),

                    const Text(
                      'Password must contain:',
                      style: TextStyle(
                        color: Color(0xFF91889E),
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      '• 1 uppercase letter\n'
                      '• 1 number\n'
                      '• 1 special character',
                      style: TextStyle(
                        color: Color(0xFF756C82),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],

                  const SizedBox(height: 25),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8D4FFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isLogin
                                  ? 'LOGIN'
                                  : 'CREATE ACCOUNT',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            setState(() {
                              isLogin = !isLogin;
                            });
                          },
                    child: Text(
                      isLogin
                          ? "Don't have an account? Register"
                          : 'Already have an account? Login',
                      style: const TextStyle(
                        color: Color(0xFFC084FF),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeButton({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF8D4FFF)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? Colors.white
                : const Color(0xFF756C82),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF756C82),
      ),
      labelStyle: const TextStyle(
        color: Color(0xFF91889E),
      ),
      filled: true,
      fillColor: const Color(0xFF0D0914),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xFF2A2134),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xFF2A2134),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xFF9B5CFF),
        ),
      ),
    );
  }
}