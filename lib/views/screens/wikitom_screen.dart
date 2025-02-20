import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_session.dart';
import '../../models/guess_result.dart';
import '../widgets/custom_bottom_bar.dart';
import 'lexitom_screen.dart';
import 'settings_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/daily_timer_service.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../../services/auth_service.dart';
import '../../services/multiplayer_service.dart';
import '../../services/wiki_service.dart';
import '../../services/single_player_service.dart';
import 'package:http/http.dart' as http;
import '../widgets/word_history_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class WikiGameScreen extends StatefulWidget {
  final bool fromContainer;
  const WikiGameScreen({super.key, this.fromContainer = false});

  @override
  State<WikiGameScreen> createState() => _WikiGameScreenState();
}

class _WikiGameScreenState extends State<WikiGameScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Color pastelYellow = const Color(0xFFF1E173);
  bool _isLoading = false;
  final List<String> _lastSubmittedWords = [];
  int _currentSubmittedWordIndex = 0;
  String _timeLeft = '';
  DateTime? _wordExpiryTime;
  Timer? _timer;
  String? currentWiki;
  final BehaviorSubject<String?> _currentWikiSubject = BehaviorSubject<String?>();
  String? _gameCode;
  GameSession? _gameSession;
  StreamSubscription? _gameSubscription;
  final TextEditingController _codeController = TextEditingController();
  String? _joinError;
  String? _currentArticleTitle;
  String? _currentArticleContent;
  bool _isLoadingArticle = true;
  final Set<String> _revealedWords = {};
  bool _hasShownWordFoundDialog = false;
  bool _isPageRevealed = false;
  String? _lastGuessResult;
  Color? _lastGuessColor;
  String? _lastArticleTimestamp;
  List<Map<String, dynamic>> _lastArticles = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _loadLastArticles();
  }

  Future<void> _initializeApp() async {
    await _updateCurrentWiki();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft();
    });

    final savedGuesses = await SinglePlayerService.loadGuesses(gameType: 'wikitomGuesses');
    if (mounted) {
      setState(() {
        for (final guess in savedGuesses) {
          _revealedWords.add(guess.word.toLowerCase());
        }
        _hasShownWordFoundDialog = _isTitleFullyRevealed();
      });
    }

    await _loadCurrentArticle();
    await _checkForActiveGame();
  }

  Future<void> _loadCurrentArticle() async {
    setState(() {
      _isLoadingArticle = true;
    });

    try {
      final article = await WikiService.instance.getCurrentArticle();
      if (article != null && mounted) {
        if (_lastArticleTimestamp != article['timestamp'].toString()) {
          _hasShownWordFoundDialog = false;
          _lastArticleTimestamp = article['timestamp'].toString();
        }
        setState(() {
          _currentArticleTitle = article['title'];
          _currentArticleContent = article['extract'];
          _isLoadingArticle = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading current article: $e');
      }
      if (mounted) {
        setState(() {
          _isLoadingArticle = false;
        });
      }
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
      final activeGame = activeGames['wikitom'];
      
      if (activeGame != null) {
        final gameDoc = await FirebaseFirestore.instance
            .collection('game_sessions')
            .doc(activeGame)
            .get();

        if (gameDoc.exists) {
          final gameData = gameDoc.data()!;
          final session = GameSession.fromJson(gameData);
          
          if (session.gameType != 'wikitom') return;

          if (mounted) {
            setState(() {
              _gameCode = activeGame;
              _gameSession = session;

              final fullText = '${_currentArticleTitle ?? ''} ${_currentArticleContent ?? ''}'.toLowerCase();
              for (var guesses in session.playerGuesses.values) {
                for (final guess in guesses) {
                  final occurrences = _countWordOccurrences(fullText, guess.word);
                  final isLastWord = _currentArticleTitle != null && 
                      _currentArticleTitle!.toLowerCase().split(RegExp(r'\s+')).last == guess.word.toLowerCase();
                  
                  if (occurrences > 0 && (!isLastWord || guess.isCorrect)) {
                    _revealedWords.add(guess.word.toLowerCase());
                  }
                }
              }
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

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _currentWikiSubject.close();
    _codeController.dispose();
    _gameSubscription?.cancel();
    super.dispose();
  }

  void _handleGuess() {
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

    final fullText = '${_currentArticleTitle ?? ''} ${_currentArticleContent ?? ''}'.toLowerCase();
    final occurrences = _countWordOccurrences(fullText, guess);
    
    setState(() {
      if (occurrences > 0) {
        _lastGuessResult = 'Le mot "$guess" apparaît $occurrences fois';
        _lastGuessColor = Colors.green;
        _revealedWords.add(guess);

        final guessResult = GuessResult(
          word: guess,
          similarity: 1.0,
          isCorrect: _isTitleFullyRevealed(),
        );

        if (_gameCode != null) {
          MultiplayerService.addGuess(
            _gameCode!,
            AuthService.currentUser?.uid ?? '',
            guessResult,
          );
        } else {
          SinglePlayerService.addGuess(guessResult, gameType: 'wikitomGuesses');
        }
      } else {
        _lastGuessResult = 'Le mot "$guess" n\'apparaît pas dans l\'article';
        _lastGuessColor = Colors.red;

        final guessResult = GuessResult(
          word: guess,
          similarity: 0.0,
          isCorrect: false,
        );

        if (_gameCode != null) {
          MultiplayerService.addGuess(
            _gameCode!,
            AuthService.currentUser?.uid ?? '',
            guessResult,
          );
        }
      }
    });

    if (mounted) {
      _focusNode.requestFocus();
    }

    if (_isTitleFullyRevealed() && !_hasShownWordFoundDialog) {
      setState(() {
        _hasShownWordFoundDialog = true;
      });
      try {
        http.post(
          Uri.parse('${WikiService.baseUrl}/increment-wiki-found-count'),
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error incrementing found count: $e');
        }
      }
      if (_gameCode != null) {
        MultiplayerService.notifyWordFound(_gameCode!, AuthService.currentUser?.uid ?? '');
      }
      _showCongratulationsDialog();
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _cleanWord(String word) {
    return word
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9àâäéèêëîïôöùûüÿçæœ\-]'), '');
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
                      'Comment jouer à WikiTom ?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '• Un nouvel article Wikipédia est disponible chaque jour\n\n'
                      '• Le texte est flouté pour masquer le sujet\n\n'
                      '• Proposez des mots pour deviner le sujet de l\'article\n\n'
                      '• Trouvez le sujet avec le moins d\'essais possible !',
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

  void _updateTimeLeft() {
    if (!mounted || _wordExpiryTime == null) return;

    final now = DateTime.now();
    final difference = _wordExpiryTime!.difference(now);

    if (difference.isNegative) {
      setState(() {
        _timeLeft = '00:00:00';
        _isPageRevealed = false;
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        _updateCurrentWiki();
      });
    } else {
      setState(() {
        _timeLeft = DailyTimerService.formatDuration(difference);
        if (difference.inSeconds <= 5 && _isPageRevealed) {
          _isPageRevealed = false;
        }
      });
    }
  }

  Future<void> _updateCurrentWiki() async {
    try {
      final wikiData = await WikiService.instance.getCurrentArticle();
      if (wikiData != null && mounted) {
        final timeRemaining = Duration(milliseconds: wikiData['timeRemaining']);
        
        if (mounted) {
          setState(() {
            _wordExpiryTime = DateTime.now().add(timeRemaining);
            if (_timeLeft == '00:00:00') {
              _timeLeft = DailyTimerService.formatDuration(timeRemaining);
            }
          });
          await _loadCurrentArticle();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating current wiki: $e');
      }
    }
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Partie en cours',
                            style: const TextStyle(
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
                              playerId == AuthService.currentUser?.uid
                                  ? 'Vous'
                                  : 'Joueur ${playerId.substring(0, 4)}',
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
                            await MultiplayerService.leaveGame(_gameCode!, gameType: 'wikitom');
                            if (mounted) {
                              setState(() {
                                _gameSession = null;
                                _gameCode = null;
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
      final session = await MultiplayerService.createGameSession(gameType: 'wikitom');
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

  Future<void> _joinMultiplayerGame(BuildContext context, String code, StateSetter setDialogState) async {
    final userId = AuthService.currentUser?.uid;
    if (userId == null) return;

    try {
      final session = await MultiplayerService.joinGameSession(code, userId, gameType: 'wikitom');
      if (!mounted) return;

      if (session != null) {
        final savedGuesses = await SinglePlayerService.loadGuesses(gameType: 'wikitomGuesses');
        for (final guess in savedGuesses) {
          final fullText = '${_currentArticleTitle ?? ''} ${_currentArticleContent ?? ''}'.toLowerCase();
          final occurrences = _countWordOccurrences(fullText, guess.word);
          if (occurrences > 0) {
            await MultiplayerService.addGuess(code, userId, guess);
          }
        }

        setState(() {
          _gameCode = code;
          _gameSession = session;
          _joinError = null;

          final fullText = '${_currentArticleTitle ?? ''} ${_currentArticleContent ?? ''}'.toLowerCase();
          for (var entry in session.playerGuesses.entries) {
            final playerId = entry.key;
            if (playerId == userId) continue;
            
            for (final guess in entry.value) {
              final occurrences = _countWordOccurrences(fullText, guess.word);
              if (occurrences > 0 && _shouldRevealWord(guess.word, guess.isCorrect, playerId)) {
                _revealedWords.add(guess.word.toLowerCase());
                _lastSubmittedWords.insert(0, guess.word);
                if (_lastSubmittedWords.length > 10) {
                  _lastSubmittedWords.removeLast();
                }
              }
            }
          }
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
          bool shouldShowDialog = false;
          
          setState(() {
            _gameSession = session;
            
            if (session.gameType != 'wikitom') return;
            
            for (var entry in session.playerGuesses.entries) {
              final playerId = entry.key;
              final guesses = entry.value;
              
              for (final guess in guesses) {
                final fullText = '${_currentArticleTitle ?? ''} ${_currentArticleContent ?? ''}'.toLowerCase();
                final occurrences = _countWordOccurrences(fullText, guess.word);
                
                if (occurrences > 0 && _shouldRevealWord(guess.word, guess.isCorrect, playerId)) {
                  _revealedWords.add(guess.word.toLowerCase());
                  
                  if (playerId != AuthService.currentUser?.uid &&
                      guess.word != _controller.text && 
                      !_lastSubmittedWords.contains(guess.word)) {
                    _lastGuessResult = 'Le mot "${guess.word}" apparaît $occurrences fois';
                    _lastGuessColor = Colors.green;
                    _lastSubmittedWords.insert(0, guess.word);
                    if (_lastSubmittedWords.length > 10) {
                      _lastSubmittedWords.removeLast();
                    }
                  }
                }
              }
            }

            if (session.wordFound && 
                session.winners.isNotEmpty && 
                !session.winners.contains(AuthService.currentUser?.uid) &&
                !_hasShownWordFoundDialog) {
              shouldShowDialog = true;
            }
            
            if (session.wordFound && 
                session.winners.isNotEmpty && 
                !session.winners.contains(AuthService.currentUser?.uid)) {
              _hasShownWordFoundDialog = true;
            }
          });

          if (shouldShowDialog) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
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
                            'Article trouvé !',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Un joueur a trouvé l\'article !',
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
                  ),
                );
              }
            });
          }
        } else if (mounted && session == null) {
          setState(() {
            _gameSession = null;
            _gameCode = null;
          });
        }
      });
    }
  }

  Widget _buildEyeIcon() {
    if (_wordExpiryTime == null) return const SizedBox.shrink();
    
    final difference = _wordExpiryTime!.difference(DateTime.now());
    final isDisabled = difference.inSeconds <= 5;

    return IconButton(
      icon: Icon(
        _isPageRevealed ? Icons.visibility_off : Icons.visibility,
        color: isDisabled ? Colors.grey : pastelYellow,
      ),
      onPressed: isDisabled ? null : () {
        setState(() {
          _isPageRevealed = !_isPageRevealed;
        });
      },
      tooltip: isDisabled 
        ? 'Article bientôt indisponible' 
        : (_isPageRevealed ? 'Masquer l\'article' : 'Révéler l\'article'),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final sortedArticles = List<Map<String, dynamic>>.from(_lastArticles)
          ..sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

        return WordHistoryWidget(
          title: 'Historique des articles',
          lastWords: sortedArticles.map((article) => {
            'word': article['title'],
            'timestamp': DateTime.fromMillisecondsSinceEpoch(article['timestamp']),
            'found_count': article['found_count'] ?? 0,
          }).toList(),
          fetchWordWiki: (title) => launchUrl(Uri.parse('https://fr.wikipedia.org/wiki/$title')),
          currentWordStream: _currentWikiSubject.stream,
        );
      },
    );
  }

  bool _isTitleFullyRevealed() {
    if (_currentArticleTitle == null) return false;
    final titleWords = _currentArticleTitle!.split(RegExp(r'\s+'));
    return titleWords.every((word) => 
      _revealedWords.contains(word.toLowerCase()) || 
      !RegExp(r'[a-zA-Z0-9àâäéèêëîïôöùûüÿçæœ]').hasMatch(word)
    );
  }

  void _showCongratulationsDialog() {
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
                  'Vous avez trouvé l\'article : $_currentArticleTitle',
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

  int _countWordOccurrences(String text, String word) {
    final pattern = RegExp('\\b$word\\b', caseSensitive: false);
    return pattern.allMatches(text).length;
  }

  bool _shouldRevealWord(String word, bool isCorrect, String? playerId) {
    if (_currentArticleTitle == null) return false;
    
    final titleWords = _currentArticleTitle!.toLowerCase().split(RegExp(r'\s+')).toList();
    final wordLower = word.toLowerCase();
    
    if (titleWords.contains(wordLower)) {
      final unrevealedWords = titleWords.where((w) => !_revealedWords.contains(w)).toList();
      if (unrevealedWords.length == 1 && unrevealedWords.first == wordLower) {
        return playerId == AuthService.currentUser?.uid && isCorrect;
      }
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
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
          title: const Padding(
            padding: EdgeInsets.only(top: 50.0),
            child: Text(
              'WIKITOM',
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
                      "Article d'hier",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_lastArticles.isNotEmpty)
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            final title = _lastArticles.last['title'];
                            launchUrl(Uri.parse('https://fr.wikipedia.org/wiki/${Uri.encodeComponent(title)}'));
                          },
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
                                  _lastArticles.last['title'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Voir l\'article complet',
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
                              _timeLeft.isNotEmpty
                                  ? 'Prochain article dans $_timeLeft'
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
                    if (_isTitleFullyRevealed() || 
                        (_gameSession?.wordFound ?? false) && 
                        (_gameSession?.winners.isNotEmpty ?? false))
                      _buildEyeIcon(),
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
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9àâäéèêëîïôöùûüÿçæœ\-]')),
                          ],
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _handleGuess(),
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
                      onPressed: _retrieveLastGuess,
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
                            horizontal: 20,
                            vertical: 12,
                          ),
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
              if (_lastGuessResult != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _lastGuessColor?.withOpacity(0.3) ?? Colors.transparent,
                    ),
                  ),
                  child: Text(
                    _lastGuessResult!,
                    style: TextStyle(
                      color: _lastGuessColor,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: pastelYellow.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        if (_isLoadingArticle)
                          const Center(
                            child: CircularProgressIndicator(),
                          )
                        else if (_currentArticleContent != null)
                          ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white,
                                  Colors.white,
                                ],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.modulate,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RedactedText(
                                      text: _currentArticleTitle ?? '',
                                      revealedWords: _revealedWords,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.bold,
                                      ),
                                      forceReveal: _isPageRevealed,
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      height: 1,
                                      color: pastelYellow.withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    RedactedText(
                                      text: _currentArticleContent!,
                                      revealedWords: _revealedWords,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontFamily: 'Poppins',
                                        height: 1.5,
                                      ),
                                      selectable: true,
                                      forceReveal: _isPageRevealed,
                                      textAlign: TextAlign.justify,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          const Center(
                            child: Text(
                              'Erreur de chargement',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: widget.fromContainer ? null : CustomBottomBar(
        currentIndex: 1,
        onTap: (index) {
          if (index != 1) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => 
                  switch (index) {
                    0 => const MainScreen(),
                    2 => const SettingsScreen(),
                    _ => const WikiGameScreen(),
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

  Stream<int> _getPlayersFoundCount() {
    return FirebaseFirestore.instance
        .collection('game')
        .doc('currentWiki')
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return 0;
          return snapshot.data()?['found_count'] ?? 0;
        });
  }

  Future<void> _loadLastArticles() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('game')
          .doc('last_wiki_articles')
          .get();

      if (snapshot.exists) {
        setState(() {
          _lastArticles = List<Map<String, dynamic>>.from(
            snapshot.data()?['articles'] ?? [],
          );
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading last articles: $e');
      }
    }
  }
}

class RedactedText extends StatefulWidget {
  final String text;
  final Set<String> revealedWords;
  final TextStyle style;
  final bool selectable;
  final bool forceReveal;
  final TextAlign textAlign;

  const RedactedText({
    super.key,
    required this.text,
    required this.revealedWords,
    required this.style,
    this.selectable = false,
    this.forceReveal = false,
    this.textAlign = TextAlign.left,
  });

  @override
  State<RedactedText> createState() => _RedactedTextState();
}

class _RedactedTextState extends State<RedactedText> {
  final RegExp _wordSplitPattern = RegExp("([a-zA-Z0-9\\p{L}]+|[/+*!§:;,?°\\]@_\\\\|\\[\\](){}\"\"#~&\\s\\-'.])", unicode: true);
  final Set<String> _tappedInstances = {};
  final Map<String, Timer> _tapTimers = {};

  void _handleWordTap(String uniqueKey) {
    // Cancel any existing timer for this instance
    _tapTimers[uniqueKey]?.cancel();
    
    setState(() {
      _tappedInstances.add(uniqueKey);
    });

    // Set timer to remove the tapped state after 3 seconds
    _tapTimers[uniqueKey] = Timer(const Duration(seconds: 1), () {
      setState(() {
        _tappedInstances.remove(uniqueKey);
      });
    });
  }

  @override
  void dispose() {
    _tapTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _wordSplitPattern.allMatches(widget.text);
    final spans = <InlineSpan>[];

    for (final match in matches) {
      final segment = match.group(0)!;
      
      if (RegExp("[/+*!§:;,?°\\]@_\\\\|\\[\\](){}\"\"#~&\\s\\-'.]").hasMatch(segment)) {
        spans.add(TextSpan(text: segment));
        continue;
      }

      if (widget.forceReveal || widget.revealedWords.contains(segment.toLowerCase())) {
        spans.add(TextSpan(text: segment));
      } else {
        final uniqueKey = '${segment.toLowerCase()}-${match.start}';
        final isTapped = _tappedInstances.contains(uniqueKey);
        
        // Calculate a fixed width per character
        final charWidth = widget.style.fontSize! * 0.65; // Adjust this multiplier as needed
        final boxWidth = segment.length * charWidth;

        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => _handleWordTap(uniqueKey),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isTapped 
                    ? const Color(0xFFF1E173).withOpacity(0.2)
                    : const Color(0xFF303030),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isTapped
                      ? const Color(0xFFF1E173)
                      : Colors.grey[800]!,
                  width: 1,
                ),
              ),
              child: Container(
                // Use fixed width based on character count instead of text measurement
                width: boxWidth,
                height: widget.style.fontSize! * (widget.style.height ?? 1.2),
                alignment: Alignment.center,
                child: Text(
                  isTapped ? segment.length.toString() : ' ',
                  style: widget.style.copyWith(
                    color: isTapped 
                        ? const Color(0xFFF1E173)
                        : Colors.grey[400],
                    height: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ));
      }
    }

    final textSpan = TextSpan(
      children: spans,
      style: widget.style,
    );

    return widget.selectable
        ? SelectableText.rich(
            textSpan,
            textAlign: widget.textAlign,
          )
        : Text.rich(
            textSpan,
            textAlign: widget.textAlign,
          );
  }
} 