import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'home.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (_auth.currentUser != null) {
      _authenticateBiometrically();
    }
  }

  Future<void> _authenticateBiometrically() async {
    try {
      bool canCheck = await _localAuth.canCheckBiometrics;
      bool isSupported = await _localAuth.isDeviceSupported();

      if (canCheck && isSupported) {
        bool authenticated = await _localAuth.authenticate(
          localizedReason: 'Authenticate to access your account',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );

        if (authenticated && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeView()),
          );
        }
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<String?> _getEmailFromIdentifier(String identifier) async {
    if (identifier.contains('@')) return identifier;

    final query = await _db
        .collection('users')
        .where('username', isEqualTo: identifier.trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first.data()['email'] as String?;
  }

  Future<void> _submit() async {
    if (!_isLogin &&
        _passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        String? email = await _getEmailFromIdentifier(
          _identifierController.text.trim(),
        );
        if (email == null) {
          _showError('User not found');
          return;
        }
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: _passwordController.text.trim(),
        );
      } else {
        UserCredential res = await _auth.createUserWithEmailAndPassword(
          email: _identifierController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await _db.collection('users').doc(res.user!.uid).set({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'username': _usernameController.text.trim(),
          'email': _identifierController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeView()),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_identifierController.text.isEmpty) {
      _showError('Enter email or username first');
      return;
    }
    try {
      String? email = await _getEmailFromIdentifier(
        _identifierController.text.trim(),
      );
      if (email == null) {
        _showError('User not found');
        return;
      }
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset link sent to your email')),
        );
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isLogin ? 'Login' : 'Sign Up',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                if (!_isLogin) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _firstNameController,
                          style: const TextStyle(fontSize: 13),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            isDense: true,
                            prefixIcon: Icon(Icons.person_outline, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lastNameController,
                          style: const TextStyle(fontSize: 13),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            isDense: true,
                            prefixIcon: Icon(Icons.person_outline, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(fontSize: 13),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      isDense: true,
                      prefixIcon: Icon(Icons.alternate_email, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _identifierController,
                  style: const TextStyle(fontSize: 13),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _isLogin ? 'Email or Username' : 'Email',
                    isDense: true,
                    prefixIcon: const Icon(Icons.email_outlined, size: 18),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  style: const TextStyle(fontSize: 13),
                  textInputAction: _isLogin
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onSubmitted: (_) {
                    if (_isLogin) _submit();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    isDense: true,
                    prefixIcon: Icon(Icons.lock_outline, size: 18),
                  ),
                  obscureText: true,
                ),
                if (!_isLogin) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordController,
                    style: const TextStyle(fontSize: 13),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      isDense: true,
                      prefixIcon: Icon(Icons.lock_reset, size: 18),
                    ),
                    obscureText: true,
                  ),
                ],
                if (_isLogin) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _authenticateBiometrically,
                    icon: const Icon(
                      Icons.fingerprint,
                      size: 40,
                      color: Colors.white54,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            _isLogin ? 'Login' : 'Create Account',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin
                        ? "Don't have an account? Sign Up"
                        : "Already have an account? Login",
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
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
