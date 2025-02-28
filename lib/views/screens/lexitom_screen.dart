import 'dart:async';
import 'dart:convert';
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
import '../../services/single_player_service.dart';
import 'package:http/http.dart' as http;
import '../widgets/word_info_dialog.dart';
import '../widgets/word_history_widget.dart';
import 'package:rxdart/rxdart.dart';

class MainScreen extends StatefulWidget {
  final bool fromContainer;
  const MainScreen({super.key, this.fromContainer = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _controller = TextEditingController();
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
  final List<String> _lastSubmittedWords = [];
  int _currentSubmittedWordIndex = 0;
  List<Map<String, dynamic>> _lastWords = [];
  final BehaviorSubject<String?> _currentWordSubject = BehaviorSubject<String?>();
  bool _hasShownWordFoundDialog = false;
  final FocusNode _focusNode = FocusNode();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _fetchLastWords();
  }

  Future<void> _initializeApp() async {
    await _updateCurrentWord();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft();
    });

    if (_gameCode == null) {
      final savedGuesses = await SinglePlayerService.loadGuesses(gameType: 'lexitomGuesses');
      if (mounted) {
        setState(() {
          _guesses.addAll(savedGuesses);
          _guesses.sort((a, b) => b.similarity.compareTo(a.similarity));
        });
      }
    }

    await _checkForActiveGame();

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGameRules(context);
      });
    }
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

      final activeGames = Map<String, String>.from(userDoc.data()?['activeGames'] ?? {});
      final activeGame = activeGames['lexitom'];
      
      if (activeGame != null) {
        final gameDoc = await FirebaseFirestore.instance
            .collection('game_sessions')
            .doc(activeGame)
            .get();

        if (gameDoc.exists) {
          final gameData = gameDoc.data()!;
          final session = GameSession.fromJson(gameData);
          
          if (session.gameType != 'lexitom') return;

          if (mounted) {
            setState(() {
              _gameCode = activeGame;
              _gameSession = session;

              _guesses.clear();

              for (var guesses in session.playerGuesses.values) {
                for (final guess in guesses) {
                  if (!_guesses.any((g) => g.word == guess.word)) {
                    _guesses.add(guess);
                  }
                }
              }

              _guesses.sort((a, b) => b.similarity.compareTo(a.similarity));
            });
            
            _subscribeToGameSession();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking for active game: $e');
      }
    }
  }

  Future<void> _fetchLastWords() async {
    try {
        final gameDoc = await FirebaseFirestore.instance
            .collection('game')
            .doc('last_words')
            .get();

        if (!gameDoc.exists) return;

        final lastWords = gameDoc.data()?['last_words'] as List<dynamic>? ?? [];
        
        _lastWords = lastWords.map((wordData) => {
            'word': wordData['word'],
            'timestamp': DateTime.fromMillisecondsSinceEpoch(wordData['timestamp']),
            'found_count': wordData['found_count'] ?? 0,
        }).toList();

        _lastWords.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        
        setState(() {});
    } catch (e) {
        if (kDebugMode) {
            print('Error fetching last words: $e');
        }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _gameSubscription?.cancel();
    _codeController.dispose();
    _currentWordSubject.close();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateTimeLeft() {
    if (!mounted || _wordExpiryTime == null) return;

    final now = DateTime.now();
    final difference = _wordExpiryTime!.difference(now);

    if (difference.isNegative) {
      setState(() {
        _timeLeft = '00:00:00';
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        _updateCurrentWord();
        _fetchLastWords();
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

    setState(() {
      _isLoading = true;
      _lastSubmittedWords.insert(0, guess);
      if (_lastSubmittedWords.length > 10) {
        _lastSubmittedWords.removeLast();
      }
      _currentSubmittedWordIndex = 0;
    });
    _controller.clear();

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

        final userGuesses = await SinglePlayerService.loadGuesses(gameType: 'lexitomGuesses');

        final isAlreadyWinner = (_gameSession?.winners.contains(
            AuthService.currentUser?.uid) ?? false) || userGuesses.any((g) => g.isCorrect);
        
        if (_gameCode == null) {
          await SinglePlayerService.addGuess(guessResult, gameType: 'lexitomGuesses');
        } else {
          await MultiplayerService.addGuess(
            _gameCode!,
            AuthService.currentUser?.uid ?? '',
            guessResult,
          );
        }

        if (guessResult.isCorrect) {
          if (!isAlreadyWinner) {
            try {
              await http.post(
                Uri.parse('${WordEmbeddingService.baseUrl}/increment-found-count'),
              );
            } catch (e) {
              if (kDebugMode) {
                print('Error incrementing found count: $e');
              }
            }
          }

          if (_gameCode != null && !isAlreadyWinner) {
            await MultiplayerService.notifyWordFound(
                _gameCode!, AuthService.currentUser?.uid ?? '');
          }
          if (!isAlreadyWinner) {
            final dialogContext = context;

            if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                        showDialog(
                            context: dialogContext,
                            builder: (context) {
                                return Dialog(
                                    backgroundColor: const Color(0xFF303030),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                const Text(
                                                    'Félicitations !',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 22,
                                                        fontWeight: FontWeight.bold,
                                                        fontFamily: 'Poppins',
                                                    ),
                                                ),
                                                const SizedBox(height: 20),
                                                Text(
                                                    'Vous avez trouvé le mot : $currentWord',
                                                    style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 16,
                                                        height: 1.3,
                                                        fontFamily: 'Poppins',
                                                    ),
                                                    textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 20),
                                                TextButton(
                                                    onPressed: () {
                                                        Navigator.pop(dialogContext);
                                                    },
                                                    style: TextButton.styleFrom(
                                                        backgroundColor: pastelYellow,
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(30),
                                                        ),
                                                    ),
                                                    child: const Text(
                                                        'OK',
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
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _focusNode.requestFocus();
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

    if (AuthService.currentUser == null) {
        showDialog(
            context: context,
            builder: (context) {
                return Dialog(
                    backgroundColor: const Color(0xFF303030),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                const Text(
                                    'Accès refusé',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                    ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                    'Vous devez être connecté pour accéder à cette fonctionnalité.',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        height: 1.3,
                                        fontFamily: 'Poppins',
                                    ),
                                    textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                TextButton(
                                    onPressed: () {
                                        Navigator.of(context).pop();
                                    },
                                    style: TextButton.styleFrom(
                                        backgroundColor: pastelYellow,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                        ),
                                    ),
                                    child: const Text(
                                        'OK',
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
            },
        );
        return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) =>
          StatefulBuilder(
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
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
                              onPressed: () =>
                                  _createMultiplayerGame(
                                  dialogContext, setDialogState),
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
                                  hintStyle: const TextStyle(
                                      color: Colors.white54),
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
                                if (code
                                    .trim()
                                    .isEmpty) {
                                  setDialogState(() {
                                    _joinError =
                                    'Veuillez entrer un code de partie';
                                  });
                                  return;
                                }
                                _joinMultiplayerGame(
                                    dialogContext, code, setDialogState);
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
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
                          ...session.playerIds.map((playerId) =>
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      color: playerId ==
                                          AuthService.currentUser?.uid
                                          ? pastelYellow
                                          : Colors.white70,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      playerId == AuthService.currentUser?.uid
                                          ? 'Vous'
                                          : 'Joueur ${playerId.substring(
                                          0, 4)}',
                                      style: TextStyle(
                                        color: playerId ==
                                            AuthService.currentUser?.uid
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
                                if (_guesses.isNotEmpty) {
                                  for (final guess in _guesses) {
                                    if (!guess.isCorrect || (guess.isCorrect && _gameSession!.winners.contains(AuthService.currentUser?.uid))) {
                                      await SinglePlayerService.addGuess(guess, gameType: 'lexitomGuesses');
                                    }
                                  }
                                }
                                
                                await MultiplayerService.leaveGame(_gameCode!, gameType: 'lexitom');
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
      final session = await MultiplayerService.createGameSession(gameType: 'lexitom');
      if (!mounted) return;

      final savedGuesses = await SinglePlayerService.loadGuesses(gameType: 'lexitomGuesses');
      if (savedGuesses.isNotEmpty) {
        for (final guess in savedGuesses) {
          if (!guess.isCorrect) {
            try {
              await MultiplayerService.addGuess(
                session.code,
                userId,
                GuessResult(
                  word: guess.word,
                  similarity: guess.similarity,
                  isCorrect: false,
                ),
              );
            } catch (e) {
              if (kDebugMode) {
                print('Error adding guess to session: $e');
              }
            }
          }
        }
      }

      setState(() {
        _gameCode = session.code;
        _gameSession = session;
        _guesses.clear();
        for (final guess in savedGuesses) {
          if (!guess.isCorrect) {
            _guesses.add(guess);
          }
        }
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
      final session = await MultiplayerService.joinGameSession(code, userId, gameType: 'lexitom');
      if (!mounted) return;

      if (session != null) {
        final savedGuesses = await SinglePlayerService.loadGuesses(gameType: 'lexitomGuesses');
        for (final guess in savedGuesses) {
          if (!guess.isCorrect) {
            await MultiplayerService.addGuess(
              code,
              userId,
              guess,
            );
          }
        }

        setState(() {
          _gameCode = code;
          _gameSession = session;
          _joinError = null;

          session.playerGuesses.forEach((playerId, guesses) {
            for (final guess in guesses) {
              if (!_guesses.any((g) => g.word == guess.word)) {
                _guesses.add(guess);
              }
            }
          });

          _guesses.sort((a, b) => b.similarity.compareTo(a.similarity));
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
      _gameSubscription = MultiplayerService.watchGameSession(_gameCode!).listen((session) {
        if (mounted && session != null) {
          setState(() {
            _gameSession = session;

            _showRevealButton = session.wordFound && 
                session.winners.isNotEmpty &&
                !session.winners.contains(AuthService.currentUser?.uid) &&
                _lastGuessResult?.isCorrect != true;

            final currentWords = _guesses.map((g) => g.word).toSet();
            
            for (final playerGuesses in session.playerGuesses.values) {
              for (final guess in playerGuesses) {
                if (!guess.isCorrect && !currentWords.contains(guess.word)) {
                  _guesses.add(guess);
                  currentWords.add(guess.word);
                }
              }
            }
          });

          if (session.wordFound &&
              session.winners.isNotEmpty &&
              !session.winners.contains(AuthService.currentUser?.uid) &&
              !_hasShownWordFoundDialog) {
            _hasShownWordFoundDialog = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                    showDialog(
                        context: context,
                        builder: (context) {
                            return Dialog(
                                backgroundColor: const Color(0xFF303030),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            const Text(
                                                'Mot trouvé !',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'Poppins',
                                                ),
                                            ),
                                            const SizedBox(height: 20),
                                            const Text(
                                                'Un joueur a trouvé le mot secret !',
                                                style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 16,
                                                    height: 1.3,
                                                    fontFamily: 'Poppins',
                                                ),
                                                textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 20),
                                            TextButton(
                                                onPressed: () {
                                                    Navigator.pop(context);
                                                },
                                                style: TextButton.styleFrom(
                                                    backgroundColor: pastelYellow,
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(30),
                                                    ),
                                                ),
                                                child: const Text(
                                                    'OK',
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
                        },
                    );
                }
            });
          }
        } else if (mounted && session == null) {
          setState(() {
            _gameSession = null;
            _gameCode = null;
            _showRevealButton = false;
            _hasShownWordFoundDialog = false;
          });
        }
      });
    }
  }

  Future<void> _updateCurrentWord() async {
    try {
      final wordData = await WordEmbeddingService.instance.getCurrentWord();
      if (wordData != null && mounted) {
        _hasShownWordFoundDialog = false;
        final newWord = wordData['word'];
        final timeRemaining = Duration(milliseconds: wordData['timeRemaining']);
        
        if (mounted) {
          setState(() {
            currentWord = newWord;
            _wordExpiryTime = DateTime.now().add(timeRemaining);
            if (_timeLeft == '00:00:00') {
              _timeLeft = DailyTimerService.formatDuration(timeRemaining);
            }
            _guesses.clear();
            _lastGuessResult = null;
          });
          _currentWordSubject.add(newWord);
        }
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

  void _retrieveLastGuess() {
    if (_lastSubmittedWords.isNotEmpty) {
        _controller.text = _lastSubmittedWords[_currentSubmittedWordIndex];

        _currentSubmittedWordIndex++;
        
        if (_currentSubmittedWordIndex >= _lastSubmittedWords.length) {
            _currentSubmittedWordIndex = _lastSubmittedWords.length - 1;
        }

        setState(() {});
    }
  }

  Future<void> _fetchWordWiki(String word) async {
    final url = Uri.parse('https://fr.wiktionary.org/w/api.php?action=query&format=json&titles=$word&prop=extracts&explaintext');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final pages = data['query']['pages'];
      if (pages.isNotEmpty) {
        final page = pages.values.first;
        final extract = page['extract'] ?? 'Aucune définition trouvée.';
        final directLink = 'https://fr.wiktionary.org/wiki/$word';

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => WordInfoDialog(
              word: word,
              directLink: directLink,
              nature: [], // Vous pouvez ajouter des informations supplémentaires si nécessaire
              genre: [],
              natureDef: [
                [{'Définition': extract}]
              ],
            ),
          );
        }
      } else {
        if (kDebugMode) {
          print('No definition found for $word.');
        }
      }
    } else {
      if (kDebugMode) {
        print('Error fetching data: ${response.statusCode}');
      }
    }
  }

  String _getTemperatureEmoji(double score) {
    if (score < 0) {
      return '🧊';
    } else if (score >= 0 && score < 25) {
      return '❄️';
    } else {
      return '🔥';
    }
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return WordHistoryWidget(
          lastWords: _lastWords,
          fetchWordWiki: _fetchWordWiki,
          currentWordStream: _currentWordSubject.stream,
        );
      },
    );
  }

  Stream<int> _getPlayersFoundCount() {
    return FirebaseFirestore.instance
        .collection('game')
        .doc('currentWord')
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return 0;
          return snapshot.data()?['found_count'] ?? 0;
        });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
      },
      child: Scaffold(
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
              child: _gameSession != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showMultiplayerDialog,
                        borderRadius: BorderRadius.circular(20),
                        child: Row(
                          children: [
                            const Icon(Icons.people_outline, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${_gameSession!.playerIds.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : IconButton(
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
                onPressed: () => _showMenu(context),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Mot d\'hier',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_lastWords.isNotEmpty)
                      GestureDetector(
                        onTap: () => _fetchWordWiki(_lastWords.first['word']),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: pastelYellow.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _lastWords.first['word'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Voir les mots les plus proches',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
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
                      const SizedBox(width: 10),
                      StreamBuilder<int>(
                        stream: _getPlayersFoundCount(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.people_outline, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${snapshot.data} ${snapshot.data == 1 ? 'joueur' : 'joueurs'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
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
                          onEditingComplete: _handleGuess,
                          decoration: InputDecoration(
                            hintText: 'Entrez votre mot...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: pastelYellow),
                      onPressed: () {
                        _retrieveLastGuess();
                      },
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0)
                      .copyWith(
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
                      '${(_lastGuessResult!.similarity * 100).toStringAsFixed(2)}° ${_getTemperatureEmoji(_lastGuessResult!.similarity * 100)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

                      final originalIndex = _guesses.length - _guesses.indexOf(guess);

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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => _fetchWordWiki(guess.word),
                                child: Row(
                                  children: [
                                    Text(
                                      '$originalIndex • ',
                                      style: TextStyle(
                                        color: pastelYellow,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      guess.word,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${(guess.similarity * 100).toStringAsFixed(2)}° ${_getTemperatureEmoji(guess.similarity * 100)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
      ),
    );
  }
}