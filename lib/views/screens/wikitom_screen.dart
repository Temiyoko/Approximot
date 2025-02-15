import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_session.dart';
import '../widgets/custom_bottom_bar.dart';
import 'lexitom_screen.dart';
import 'settings_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/daily_timer_service.dart';
import 'dart:async';
import '../../services/word_embedding_service.dart';
import 'package:rxdart/rxdart.dart';
import '../../services/auth_service.dart';
import '../../services/multiplayer_service.dart';
import '../../services/wiki_service.dart';

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
  bool _hasShownCongratulationsDialog = false;
  bool _isPageRevealed = false;
  String? _lastGuessResult;
  Color? _lastGuessColor;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _loadRandomArticle();
  }

  Future<void> _initializeApp() async {
    await _updateCurrentWiki();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft();
    });
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
      } else {
        _lastGuessResult = 'Le mot "$guess" n\'apparaît pas dans l\'article';
        _lastGuessColor = Colors.red;
      }
    });

    if (_isTitleFullyRevealed() && !_hasShownCongratulationsDialog) {
      _hasShownCongratulationsDialog = true;
      _showCongratulationsDialog();
    }
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
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        _updateCurrentWiki();
      });
    } else {
      setState(() {
        _timeLeft = DailyTimerService.formatDuration(difference);
      });
    }
  }

  Future<void> _updateCurrentWiki() async {
    try {
      final wikiData = await WordEmbeddingService.instance.getCurrentWord();
      if (wikiData != null && mounted) {
        final newWiki = wikiData['word'];
        final timeRemaining = Duration(milliseconds: wikiData['timeRemaining']);
        
        if (mounted) {
          setState(() {
            currentWiki = newWiki;
            _wordExpiryTime = DateTime.now().add(timeRemaining);
            if (_timeLeft == '00:00:00') {
              _timeLeft = DailyTimerService.formatDuration(timeRemaining);
            }
          });
          _currentWikiSubject.add(newWiki);
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
                            await MultiplayerService.leaveGame(_gameCode!);
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

  Future<void> _joinMultiplayerGame(BuildContext context, String code, StateSetter setDialogState) async {
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
      _gameSubscription = MultiplayerService.watchGameSession(_gameCode!).listen((session) {
        if (mounted && session != null) {
          setState(() {
            _gameSession = session;
          });
        } else if (mounted && session == null) {
          setState(() {
            _gameSession = null;
            _gameCode = null;
          });
        }
      });
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
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Articles précédents',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF303030),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pastelYellow.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Flower',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '100 joueurs',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Voir l\'article complet',
                      style: TextStyle(
                        color: pastelYellow,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadRandomArticle() async {
    setState(() {
      _isLoadingArticle = true;
    });

    try {
      final article = await WikiService.getRandomArticle();
      if (mounted) {
        if (kDebugMode) {
          print('Wikipedia Title: ${article['title']}');
        }
        setState(() {
          _currentArticleTitle = article['title'];
          _currentArticleContent = article['content'];
          _isLoadingArticle = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading article: $e');
      }
      if (mounted) {
        setState(() {
          _isLoadingArticle = false;
        });
      }
    }
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
                      'Article d\'hier',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: pastelYellow.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Flower',
                              style: TextStyle(
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
                    if (_isTitleFullyRevealed())
                      IconButton(
                        icon: Icon(
                          _isPageRevealed ? Icons.visibility_off : Icons.visibility,
                          color: pastelYellow,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPageRevealed = !_isPageRevealed;
                          });
                        },
                        tooltip: _isPageRevealed ? 'Masquer l\'article' : 'Révéler l\'article',
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
                          SingleChildScrollView(
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
                                      fontSize: 16,
                                      fontFamily: 'Poppins',
                                      height: 1.5,
                                    ),
                                    selectable: true,
                                    forceReveal: _isPageRevealed,
                                  ),
                                ],
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
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                          child: Container(
                            color: Colors.black.withOpacity(0.1),
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
        .doc('currentWord')
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return 0;
          return snapshot.data()?['found_count'] ?? 0;
        });
  }
}

class RedactedText extends StatefulWidget {
  final String text;
  final Set<String> revealedWords;
  final TextStyle style;
  final bool selectable;
  final bool forceReveal;

  const RedactedText({
    super.key,
    required this.text,
    required this.revealedWords,
    required this.style,
    this.selectable = false,
    this.forceReveal = false,
  });

  @override
  State<RedactedText> createState() => _RedactedTextState();
}

class _RedactedTextState extends State<RedactedText> {
  final RegExp _wordSplitPattern = RegExp(r'([a-zA-Z0-9àâäéèêëîïôöùûüÿçæœ]+|[^\s]+|\s+)');

  @override
  Widget build(BuildContext context) {
    final matches = _wordSplitPattern.allMatches(widget.text);
    final spans = <InlineSpan>[];

    for (final match in matches) {
      final segment = match.group(0)!;
      
      if (!RegExp(r'[a-zA-Z0-9àâäéèêëîïôöùûüÿçæœ]').hasMatch(segment)) {
        spans.add(TextSpan(text: segment));
        continue;
      }

      if (widget.forceReveal || widget.revealedWords.contains(segment.toLowerCase())) {
        spans.add(TextSpan(text: segment));
      } else {
        final textPainter = TextPainter(
          text: TextSpan(text: segment, style: widget.style),
          textDirection: TextDirection.ltr,
        )..layout();

        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF303030),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.grey[800]!,
                width: 1,
              ),
            ),
            child: Container(
              width: textPainter.width,
              height: widget.style.fontSize! * (widget.style.height ?? 1.2),
              alignment: Alignment.center,
              child: Text(
                segment.length.toString(),
                style: widget.style.copyWith(
                  color: Colors.grey[400],
                  height: 1,
                ),
                textAlign: TextAlign.center,
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
        ? SelectableText.rich(textSpan)
        : Text.rich(textSpan);
  }
} 