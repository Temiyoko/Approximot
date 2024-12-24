import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/game_session.dart';
import '../../services/auth_service.dart';
import 'wikitom_screen.dart';
import 'settings_screen.dart';
import '../widgets/custom_bottom_bar.dart';
import '../../services/daily_timer_service.dart';
import '../../services/word_embedding_service.dart';
import '../../services/multiplayer_service.dart';
import '../../models/guess_result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MainScreen extends StatefulWidget {
  final bool fromContainer;
  const MainScreen({super.key, this.fromContainer = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _timer;
  String _timeLeft = '';
  final Color pastelYellow = const Color(0xFFF1E173);
  final List<GuessResult> _guesses = [];
  bool _isLoading = false;
  String? _errorMessage;
  GuessResult? _lastGuessResult;
  String? _gameCode;
  GameSession? _gameSession;
  StreamSubscription? _gameSubscription;
  final TextEditingController _codeController = TextEditingController();
  String? _joinError;
  String? currentWord;
  DateTime? _wordExpiryTime;
  bool _showRevealButton = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _updateCurrentWord();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft();
    });

    _checkForActiveGame();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showGameRules(context);
    });
  }

  Future<void> _checkForActiveGame() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final activeGame = userDoc.data()?['activeGame'];
      if (activeGame != null) {
        if (mounted) {
          setState(() {
            _gameCode = activeGame;
          });
          _subscribeToGameSession();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking for active game: $e');
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _gameSubscription?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateTimeLeft() {
    if (!mounted || _wordExpiryTime == null) return;
    
    final now = DateTime.now();
    final difference = _wordExpiryTime!.difference(now);
    
    if (difference.isNegative) {
      _updateCurrentWord();
      setState(() {
        _timeLeft = '00:00:00';
      });
    } else {
      setState(() {
        _timeLeft = DailyTimerService.formatDuration(difference);
      });
    }
  }

  String _cleanWord(String word) {
    return word
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-zàäéèêëîïôöùûüÿçæœ\-]'), '');
  }

  Future<void> _handleGuess() async {
    final guess = _cleanWord(_controller.text);
    if (guess.isEmpty) return;

    _controller.clear();
    FocusScope.of(context).requestFocus(_focusNode);

    setState(() {
      _isLoading = true;
    });

    try {
      final similarity = await WordEmbeddingService.instance.getSimilarity(
          guess, currentWord ?? '');

      if (!mounted) return;

      if (similarity != null) {
        final guessResult = GuessResult(
          word: guess,
          similarity: similarity,
          isCorrect: guess == currentWord,
        );

        if (!_guesses.any((g) => g.word == guess)) {
          _guesses.insert(0, guessResult);
        }

        setState(() {
          _lastGuessResult = guessResult;
        });

        if (guess == currentWord) {
          final isAlreadyWinner = _gameSession?.winners.contains(AuthService.currentUser?.uid) ?? false;
          
          if (_gameCode != null && !isAlreadyWinner) {
            await MultiplayerService.notifyWordFound(_gameCode!, AuthService.currentUser?.uid ?? '');
          }
          if (!isAlreadyWinner) {
            final dialogContext = context;
            
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  showDialog(
                    context: dialogContext,
                    barrierDismissible: false,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('Félicitations !'),
                        content: Text('Vous avez trouvé le mot : $currentWord'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              if (mounted) {
                                FocusScope.of(dialogContext).requestFocus(_focusNode);
                              }
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                }
              });
            }
          }
        } else {
          if (_gameCode != null && _lastGuessResult != null) {
            await MultiplayerService.addGuess(
              _gameCode!,
              AuthService.currentUser?.uid ?? '',
              _lastGuessResult!,
            );
          }
        }
      }
    } on WordNotFoundException {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Ce mot n\'existe pas dans le dictionnaire';
        _isLoading = false;
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error checking guess: $e');
      }
      if (mounted) {
        setState(() {
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showGameRules(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF303030),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comment jouer à LexiTom ?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '• Un nouveau mot est disponible chaque jour\n\n'
                          '• Proposez des mots pour deviner le mot mystère\n\n'
                          '• Le pourcentage indique la proximité sémantique avec le mot à trouver\n\n'
                          '• Plus le pourcentage est élevé, plus vous êtes proche du mot mystère\n\n'
                          '• Trouvez le mot avec le moins d\'essais possible !',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.3,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withOpacity(0.5),
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  splashRadius: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMultiplayerDialog() {
    _joinError = null;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return StreamBuilder<GameSession?>(
            stream: _gameCode != null 
                ? MultiplayerService.watchGameSession(_gameCode!)
                : const Stream.empty(),
            initialData: _gameSession,
            builder: (context, snapshot) {
              if (_gameCode == null) {
                return Dialog(
                  backgroundColor: const Color(0xFF303030),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Mode Multijoueur',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => _createMultiplayerGame(dialogContext, setDialogState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: pastelYellow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Créer une partie',
                            style: TextStyle(
                              color: Color(0xFF303030),
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextSelectionTheme(
                          data: TextSelectionThemeData(
                            selectionHandleColor: pastelYellow,
                            cursorColor: pastelYellow,
                            selectionColor: pastelYellow.withOpacity(0.3),
                          ),
                          child: TextField(
                            controller: _codeController,
                            style: const TextStyle(color: Colors.white),
                            cursorColor: pastelYellow,
                            decoration: InputDecoration(
                              hintText: 'Entrer un code de partie',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        if (_joinError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _joinError!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            final code = _codeController.text;
                            if (code.trim().isEmpty) {
                              setDialogState(() {
                                _joinError = 'Veuillez entrer un code de partie';
                              });
                              return;
                            }
                            _joinMultiplayerGame(dialogContext, code, setDialogState);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Rejoindre une partie',
                            style: TextStyle(
                              color: Color(0xFF303030),
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final session = snapshot.data;
              if (session == null) return const SizedBox.shrink();

              return Dialog(
                backgroundColor: const Color(0xFF303030),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Partie en cours',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SelectableText(
                            'Code: ${session.code}',
                            style: TextStyle(
                              color: pastelYellow,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ...session.playerIds.map((playerId) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: playerId == AuthService.currentUser?.uid
                                  ? pastelYellow
                                  : Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              playerId == AuthService.currentUser?.uid ? 'Vous' : 'Joueur ${playerId.substring(0, 4)}',
                              style: TextStyle(
                                color: playerId == AuthService.currentUser?.uid
                                    ? pastelYellow
                                    : Colors.white,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          if (_gameCode != null) {
                            await MultiplayerService.leaveGame(_gameCode!);
                            if (mounted) {
                              setState(() {
                                _gameSession = null;
                                _gameCode = null;
                                _showRevealButton = false;
                              });
                              setDialogState(() {
                                _gameSession = null;
                                _gameCode = null;
                              });
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Quitter la partie',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createMultiplayerGame(BuildContext context, StateSetter setDialogState) async {
    final userId = AuthService.currentUser?.uid;
    if (userId == null) return;

    try {
      final session = await MultiplayerService.createGameSession(userId);
      if (!mounted) return;

      setState(() {
        _gameCode = session.code;
        _gameSession = session;
      });
      _subscribeToGameSession();

      setDialogState(() {
        _gameSession = session;
        _joinError = null;
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la création de la partie'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _joinMultiplayerGame(
    BuildContext context, 
    String code,
    StateSetter setDialogState
  ) async {
    final userId = AuthService.currentUser?.uid;
    if (userId == null) return;

    try {
      final session = await MultiplayerService.joinGameSession(code, userId);
      if (!mounted) return;

      if (session != null) {
        setState(() {
          _gameCode = code;
          _gameSession = session;
          _joinError = null;
        });
        _subscribeToGameSession();

        setDialogState(() {
          _gameSession = session;
        });
      } else {
        setDialogState(() {
          _joinError = 'Code de partie invalide';
        });
      }
    } catch (e) {
      if (mounted) {
        setDialogState(() {
          _joinError = 'Erreur lors de la connexion à la partie';
        });
      }
    }
  }

  void _subscribeToGameSession() {
    _gameSubscription?.cancel();
    if (_gameCode != null) {
      _gameSubscription = MultiplayerService.watchGameSession(_gameCode!)
          .listen((session) {
        if (mounted && session != null) {
          setState(() {
            _gameSession = session;
            
            _showRevealButton = session.wordFound && 
                session.winners.isNotEmpty &&
                !session.winners.contains(AuthService.currentUser?.uid) &&
                _lastGuessResult?.isCorrect != true;
          });
          
          if (session.wordFound &&
              session.winners.isNotEmpty &&
              !session.winners.contains(AuthService.currentUser?.uid)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('Mot trouvé !'),
                      content: Text('Un joueur a trouvé le mot secret !',),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            if (mounted) {
                              FocusScope.of(context).requestFocus(_focusNode);
                            }
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    );
                  },
                );
              }
            });
          }
          
          final otherPlayersGuesses = session.playerGuesses.entries
              .where((entry) => entry.key != AuthService.currentUser?.uid)
              .expand((entry) => entry.value)
              .toList();
              
          for (final guess in otherPlayersGuesses) {
            if (!_guesses.any((g) => g.word == guess.word)) {
              _guesses.insert(0, guess);
            }
          }
        } else if (mounted && session == null) {
          setState(() {
            _gameSession = null;
            _gameCode = null;
            _showRevealButton = false;
          });
        }
      });
    }
  }

  Future<void> _updateCurrentWord() async {
    try {
      final wordData = await WordEmbeddingService.instance.getCurrentWord();
      if (wordData != null && mounted) {
        setState(() {
          final newWord = wordData['word'];
          if (currentWord != newWord) {
            _guesses.clear();
            _lastGuessResult = null;
          }
          
          currentWord = newWord;
          final timeRemaining = Duration(milliseconds: wordData['timeRemaining']);
          _wordExpiryTime = DateTime.now().add(timeRemaining);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating current word: $e');
      }
    }
  }

  void setDialogState(Function update) {
    setState(() {
      update();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 100,
        title: Padding(
          padding: const EdgeInsets.only(top: 50.0),
          child: const Text(
            'LEXITOM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 50.0),
            child: IconButton(
              icon: const Icon(Icons.group, color: Colors.white),
              onPressed: _showMultiplayerDialog,
              tooltip: 'Multijoueur',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 50.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                splashColor: pastelYellow.withOpacity(0.3),
                highlightColor: pastelYellow.withOpacity(0.1),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.help_outline,
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showGameRules(context);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 50.0),
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                // Show menu options
              },
              tooltip: 'Menu',
            ),
          ),
        ],
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mots Précédents',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        500,
                            (index) =>
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: pastelYellow.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Jour ${index + 1}',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Fleur',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w500,
                                    ),
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

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.white,
                            size: 20),
                        const SizedBox(width: 8),
                        Text(
                          currentWord != null
                              ? 'Prochain mot dans $_timeLeft'
                              : 'Chargement...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: pastelYellow.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  if (_showRevealButton)
                    IconButton(
                      icon: Icon(
                        Icons.visibility,
                        color: pastelYellow,
                      ),
                      onPressed: () {
                        setState(() {
                          _controller.text = currentWord ?? '';
                        });
                      },
                      tooltip: 'Révéler le mot',
                    ),
                  Expanded(
                    child: TextSelectionTheme(
                      data: TextSelectionThemeData(
                        selectionHandleColor: pastelYellow,
                        cursorColor: pastelYellow,
                        selectionColor: pastelYellow.withOpacity(0.3),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: pastelYellow,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _handleGuess(),
                        decoration: InputDecoration(
                          hintText: 'Entrez votre proposition...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(4),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleGuess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pastelYellow.withOpacity(0.9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text(
                        'Proposer',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(
                    bottom: 17.0),
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red[400],
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _lastGuessResult?.isCorrect == true
                      ? Colors.green
                      : pastelYellow.withOpacity(0.3),
                  width: _lastGuessResult?.isCorrect == true ? 2 : 1,
                ),
              ),
              child: _lastGuessResult != null
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _lastGuessResult!.word,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${(_lastGuessResult!.similarity * 100).toStringAsFixed(
                        1)}%',
                    style: TextStyle(
                      color: _lastGuessResult!.isCorrect ? Colors.green : Colors
                          .white,
                      fontSize: 18,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Votre dernière proposition',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Divider(
              color: pastelYellow,
              thickness: 1,
              height: 1,
              indent: 16,
              endIndent: 16,
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _guesses.isEmpty
                  ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text(
                        'Commencez à jouer !',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 18,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: pastelYellow.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _guesses.length,
                  itemBuilder: (context, index) {
                    final sortedGuesses = List<GuessResult>.from(_guesses)
                      ..sort((a, b) => b.similarity.compareTo(a.similarity));
                    final guess = sortedGuesses[index];

                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: pastelYellow.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              guess.word,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              '${(guess.similarity * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: guess.isCorrect ? Colors.green : Colors.white,
                                fontSize: 16,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: widget.fromContainer ? null : CustomBottomBar(
        currentIndex: 0,
        onTap: (index) {
          if (index != 0 && mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                switch (index) {
                  1 => const WikiGameScreen(),
                  2 => const SettingsScreen(),
                  _ => const MainScreen(),
                },
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          }
        },
      ),
    );
  }
}