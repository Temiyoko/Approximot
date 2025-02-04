import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import 'lexitom_screen.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final Color pastelYellow = const Color(0xFFF1E173);
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPasswordField = false;
  bool _obscurePassword = true;
  bool _isNewUser = false;

  String generateSecureDefaultPassword() {
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String password = "Ap@$timestamp";
    return password;
  }

  Future<void> _continueWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      try {
        String securePassword = generateSecureDefaultPassword();
        await AuthService.createUserWithEmail(
          _emailController.text,
          securePassword,
        );
        _isNewUser = true;
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: _emailController.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Un email vous a été envoyé pour définir votre mot de passe'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height - 130,
                right: 20,
                left: 20,
              ),
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          _isNewUser = false;
        } else {
          rethrow;
        }
      }

      setState(() {
        _showPasswordField = true;
        _isLoading = false;
      });
    } on FirebaseAuthException {
      setState(() {
        _errorMessage = 'Une erreur est survenue lors de la création du compte. Veuillez réessayer';
        _isLoading = false;
      });
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isLocked = await AuthService.isAccountLocked(_emailController.text);
      if (isLocked) {
        setState(() {
          _errorMessage = 'Compte bloqué suite à trop de tentatives.';
          _isLoading = false;
        });
        return;
      }

      await AuthService.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );

      await AuthService.updateLoginAttempts(_emailController.text, reset: true);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      await AuthService.updateLoginAttempts(_emailController.text);
      
      setState(() {
        if (_isNewUser && e.code == 'invalid-credential') {
          _errorMessage = 'Veuillez utiliser le lien reçu par email afin de réinitialiser votre mot de passe';
        } else {
          _errorMessage = switch (e.code) {
            'invalid-credential' => 'Le mot de passe est incorrect',
            'user-disabled' => 'Ce compte a été désactivé',
            'too-many-requests' => 'Trop de tentatives de connexion. Veuillez réessayer plus tard',
            'network-request-failed' => 'Problème de connexion internet. Veuillez vérifier votre connexion',
            _ => 'Une erreur est survenue. Veuillez réessayer'
          };
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text,
      );

      if (mounted) {
        setState(() {
          _errorMessage = 'Un email vous a été envoyé pour réinitialiser votre mot de passe.';
        });
      }
    } on FirebaseAuthException {
      setState(() {
        _errorMessage = 'Une erreur est survenue lors de l\'envoi de l\'email. Veuillez réessayer';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unlockAccount() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Send password reset email as verification
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text,
      );
      
      // Unlock the account
      await AuthService.unlockAccount(_emailController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Un email vous a été envoyé pour débloquer votre compte et réinitialiser votre mot de passe'
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 130,
              right: 20,
              left: 20,
            ),
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Une erreur est survenue lors du déblocage du compte';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: pastelYellow.withOpacity(0.3),
          selectionHandleColor: pastelYellow,
          cursorColor: pastelYellow,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          toolbarHeight: 100,
          leading: Padding(
            padding: const EdgeInsets.only(top: 50.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Text(
                      'Connexion par email',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Entrez votre adresse email pour créer ou accéder à votre compte',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 38),
                  TextFormField(
                    controller: _emailController,
                    enabled: !_showPasswordField,
                    style: TextStyle(
                      color: _showPasswordField ? Colors.white38 : Colors.white,
                    ),
                    cursorColor: pastelYellow,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: _showPasswordField 
                          ? const Color(0xFF252525)
                          : const Color(0xFF303030),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(
                        Icons.email,
                        color: _showPasswordField ? Colors.white38 : Colors.white54,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre email';
                      }
                      if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Veuillez entrer un email valide';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (!_showPasswordField) ...[
                    const SizedBox(height: 38),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _continueWithEmail,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF303030)),
                                ),
                              )
                            : const Text(
                                'Continuer',
                                style: TextStyle(
                                  color: Color(0xFF303030),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                  if (_showPasswordField) ...[
                    const SizedBox(height: 38),
                    TextSelectionTheme(
                      data: TextSelectionThemeData(
                        selectionHandleColor: pastelYellow,
                        cursorColor: pastelYellow,
                        selectionColor: pastelYellow.withOpacity(0.3),
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: pastelYellow,
                        decoration: InputDecoration(
                          hintText: 'Mot de passe',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF303030),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.lock, color: Colors.white54),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white54,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Veuillez entrer le mot de passe'
                            : null,
                      ),
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (!_isNewUser)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextButton(
                          onPressed: _isLoading ? null : 
                            _errorMessage?.contains('bloqué') == true ? _unlockAccount : _resetPassword,
                          child: Text(
                            _errorMessage?.contains('bloqué') == true 
                                ? 'Débloquer mon compte'
                                : 'Mot de passe oublié ?',
                            style: TextStyle(
                              color: _errorMessage?.contains('bloqué') == true 
                                  ? pastelYellow
                                  : Colors.white70,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 38),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF303030)),
                                ),
                              )
                            : Text(
                                _isNewUser ? 'Définir le mot de passe' : 'Se connecter',
                                style: const TextStyle(
                                  color: Color(0xFF303030),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 