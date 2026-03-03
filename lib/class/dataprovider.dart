// ignore_for_file: unused_field, avoid_print, unused_element

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wortis/class/class.dart';
import 'package:wortis/pages/news.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wortis/pages/notifications.dart';

// NOUVEAU IMPORT FIREBASE

class AppDataProvider with ChangeNotifier {
  // ========== VARIABLES D'ÉTAT CORE ==========
  bool _isLoading = true;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String _error = '';
  String? _currentUserId;

  // ========== DONNÉES PRINCIPALES ==========
  List<Accueil> _banners = [];
  List<SecteurActivite> _secteurs = [];
  List<dynamic> _services = [];
  List<dynamic> _displayedServices = [];
  UserData? _userData;
  Map<String, dynamic> _userProfile = {};

  // ========== ACTUALITÉS ==========
  List<NewsItem> _news = [];
  bool _isNewsLoading = false;
  DateTime? _lastRefresh;
  static const refreshThreshold = Duration(minutes: 5);

  // ========== PROFIL UTILISATEUR ==========
  final Map<String, TextEditingController> _profileControllers = {};
  bool _isEditingProfile = false;
  String? _profileImagePath;

  // ========== PORTEFEUILLE ==========
  bool _isWalletLocked = true;
  double _walletBalance = 0.0;
  String _walletCurrency = 'XAF';
  bool _isWalletLoading = false;
  String? _walletError;

  // ========== TRANSACTIONS ==========
  List<Transaction> _transactions = [];
  bool _isTransactionsLoading = false;
  bool _hasLoadedTransactions = false;
  String? _transactionsError;
  DateTime? _lastTransactionsRefresh;
  static const transactionsRefreshThreshold = Duration(minutes: 5);

  // ========== NOTIFICATIONS ==========
  List<NotificationData> _notifications = [];
  bool _isNotificationsLoading = false;
  bool _isNotificationLoadingInProgress = false;
  String? _notificationsError;
  DateTime? _lastNotificationsRefresh;
  bool _hasLoadedNotifications = false;
  static const notificationsRefreshThreshold = Duration(minutes: 5);

  // ========== MILES ==========
  int _miles = 0;
  bool _milesLoading = false;
  String? _milesError;
  DateTime? _lastMilesRefresh;
  static const milesRefreshThreshold = Duration(seconds: 5);

  // ========== PAYS ÉLIGIBLES ==========
  List<String> _eligibleCountries = [];
  bool _isEligibleCountriesLoading = false;
  String? _eligibleCountriesError;
  DateTime? _lastEligibleCountriesRefresh; // ✅ OPTIMISATION: Cache timestamp
  static const eligibleCountriesRefreshThreshold = Duration(minutes: 10);

  // ========== NOUVELLES VARIABLES FIREBASE ==========
  String? _fcmToken;
  final bool _isFirebaseInitialized = false;
  final bool _isFirebaseInitializing = false;

  // ========== SERVICES ==========
  final PushNotificationService _pushNotificationService;
  Timer? _loadingTimer;

  // ========== CONSTRUCTEUR ==========
  AppDataProvider({required GlobalKey<NavigatorState> navigatorKey})
    : _pushNotificationService = PushNotificationService(
        navigatorKey: navigatorKey,
      );

  // ========== GETTERS UTILISÉS DANS LE PROJET ==========
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String get error => _error;
  List<Accueil> get banners => _banners;
  List<Accueil> get bannersALaUne => _banners.where((b) => b.aLaUne).toList();
  List<SecteurActivite> get secteurs => _secteurs;
  List<dynamic> get services => _services;
  List<dynamic> get displayedServices => _displayedServices;
  UserData? get userData => _userData;
  List<NewsItem> get news => _news;
  bool get isUserLoggedIn => _userData != null;
  bool get isDataReady => _isInitialized && !_isLoading && _error.isEmpty;
  bool get isNewsLoading => _isNewsLoading;
  bool get isAllDataLoaded =>
      _userData != null &&
      _banners.isNotEmpty &&
      _secteurs.isNotEmpty &&
      _miles >= 0;
  bool get needsRefresh =>
      _lastRefresh == null ||
      DateTime.now().difference(_lastRefresh!) > refreshThreshold;

  // Getters Portefeuille
  bool get isWalletLocked => _isWalletLocked;
  double get walletBalance => _walletBalance;
  String get walletCurrency => _walletCurrency;
  bool get isWalletLoading => _isWalletLoading;
  String? get walletError => _walletError;

  // Getters Profil
  String? get profileImagePath => _profileImagePath;
  Map<String, dynamic> get userProfile => _userProfile;
  Map<String, TextEditingController> get profileControllers =>
      _profileControllers;
  bool get isEditingProfile => _isEditingProfile;

  // Getters Transactions
  List<Transaction> get transactions => _transactions;
  bool get isTransactionsLoading => _isTransactionsLoading;
  String? get transactionsError => _transactionsError;

  // Getters Notifications
  List<NotificationData> get notifications => _notifications;
  bool get isNotificationsLoading => _isNotificationsLoading;
  String? get notificationsError => _notificationsError;
  int get unreadNotificationCount =>
      _notifications.where((n) => n.statut != 'lu').length;
  int get unreadNotificationsCount =>
      _notifications.where((n) => n.statut != 'lu').length; // Alias

  // Getters Miles
  int get miles => _miles;
  bool get milesLoading => _milesLoading;
  String? get milesError => _milesError;

  // Getters Pays
  List<String> get eligibleCountries => _eligibleCountries;
  bool get isEligibleCountriesLoading => _isEligibleCountriesLoading;
  String? get eligibleCountriesError => _eligibleCountriesError;

  // ========== NOUVEAUX GETTERS FIREBASE ==========
  String? get fcmToken => _fcmToken;
  bool get isFirebaseInitialized => _isFirebaseInitialized;

  // ========== MÉTHODES UTILISÉES DANS LE PROJET ==========

  Future<String?> _getUserToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_token');
    } catch (e) {
      //print('❌ [DataProvider] Erreur récupération token: $e');
      return null;
    }
  }

  // Initialisation principale (utilisée dans main.dart) - MODIFIÉE AVEC FIREBASE
  Future<void> initializeApp(BuildContext context) async {
    if (_isInitializing) return;

    String? token; // ✅ On déclare ici pour l'utiliser aussi après

    try {
      _isInitializing = true;
      _isLoading = true;
      _error = '';
      notifyListeners();

      //print('🔄 [DEBUG] Début initializeApp');

      // ✅ Timeout global de 30s
      await Future.delayed(Duration.zero).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('⏱️ Timeout global dépassé (30s)');
        },
      );

      // Récupération du token utilisateur
      token = await _getUserToken();
      if (token == null) {
        throw Exception('Token utilisateur non trouvé');
      }
      //print('🔄 [DEBUG] Token récupéré: ${token.substring(0, 20)}...');

      // Initialiser les notifications
      //print('🔄 [DEBUG] Début init notifications');
      await _pushNotificationService.initNotification();
      //print('✅ [DEBUG] Notifications initialisées');

      // Initialiser Firebase avec timeout séparé
      //print('🔄 [DEBUG] Début init Firebase');
      // await _initializeFirebase().timeout(
      //   const Duration(seconds: 10),
      //   onTimeout: () {
      //     throw Exception('⏱️ Timeout Firebase dépassé (10s)');
      //   },
      // );
      //print('✅ [DEBUG] Firebase initialisé');

      // Charger les données critiques
      //print('🔄 [DEBUG] Début chargement données critiques');
      await _loadCriticalData(token);
      //print('✅ [DEBUG] Données critiques chargées');

      _isInitialized = true;
      //print('✅ [DEBUG] Initialisation terminée avec succès');

      // Charger les données secondaires en arrière-plan
      _loadSecondaryDataInBackground(token);
    } catch (e, stack) {
      //print('❌ [DEBUG] Erreur initialisation: $e');
      print(stack);
      _error = e.toString();
      _isInitialized = false;

      // Forcer l'état cohérent même en cas d'erreur
      _isLoading = false;
      _isInitializing = false;
    } finally {
      print(
        '🔄 [DEBUG] Finally bloc - isLoading: $_isLoading, isInitialized: $_isInitialized',
      );
      _isLoading = false;
      _isInitializing = false;
      notifyListeners();
    }
  }
  // ========== NOUVELLES MÉTHODES FIREBASE ==========

  // Initialiser Firebase
  // Future<void> _initializeFirebase() async {
  //   if (_isFirebaseInitialized || _isFirebaseInitializing) return;

  //   try {
  //     _isFirebaseInitializing = true;
  //     //print('🔥 [DEBUG] Début initialisation Firebase...');

  //     // ✅ Timeout de 8s avec gestion claire d'erreur
  //     await (() async {
  //       await FirebaseMessagingService.initialize();
  //       _fcmToken = await FirebaseMessagingService.getCurrentToken();

  //       if (_fcmToken != null) {
  //         await _subscribeToTopics();
  //         _isFirebaseInitialized = true;
  //         print(
  //             '✅ [DEBUG] Firebase initialisé avec token: ${_fcmToken!.substring(0, 20)}...');
  //       } else {
  //         //print('⚠️ [DEBUG] Aucun FCM token récupéré');
  //       }
  //     })()
  //         .timeout(
  //       const Duration(seconds: 8),
  //       onTimeout: () {
  //         throw Exception('⏱️ Timeout Firebase (8s) dépassé');
  //       },
  //     );
  //   } catch (e, stack) {
  //     //print('❌ [DEBUG] Erreur Firebase (non-bloquante): $e');
  //     print(stack);
  //     // Ne pas bloquer l’init générale si Firebase échoue
  //     _isFirebaseInitialized = false;
  //   } finally {
  //     _isFirebaseInitializing = false;
  //   }
  // }

  // Envoyer le token FCM au serveur
  Future<void> _sendFCMTokenToServer(String fcmToken) async {
    try {
      final userToken = await _getUserToken();
      if (userToken == null) return;

      //print('🔥 [DataProvider] Envoi token FCM au serveur...');

      final response = await http.post(
        Uri.parse('https://api.live.wortis.cg/firebase/api/user/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': userToken,
        },
        body: jsonEncode({
          'fcm_token': fcmToken,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'app_version': '1.0.0',
        }),
      );

      if (response.statusCode == 200) {
        //print('✅ [DataProvider] Token FCM envoyé avec succès');
      } else {
        print(
          '❌ [DataProvider] Erreur envoi token FCM: ${response.statusCode}',
        );
      }
    } catch (e) {
      //print('❌ [DataProvider] Erreur envoi token FCM: $e');
    }
  }

  // S'abonner aux topics Firebase
  // Future<void> _subscribeToTopics() async {
  //   try {
  //     // Topics généraux
  //     await FirebaseMessagingService.subscribeToTopic('all_users');

  //     // Topic basé sur la plateforme
  //     final platform = Platform.isIOS ? 'ios_users' : 'android_users';
  //     await FirebaseMessagingService.subscribeToTopic(platform);

  //     //print('✅ [DataProvider] Abonné aux topics Firebase');
  //   } catch (e) {
  //     //print('❌ [DataProvider] Erreur abonnement topics: $e');
  //   }
  // }

  // Nettoyer Firebase
  // Future<void> _cleanupFirebase() async {
  //   try {
  //     if (!_isFirebaseInitialized) return;

  //     //print('🔥 [DataProvider] Nettoyage Firebase...');

  //     // Se désabonner des topics
  //     await FirebaseMessagingService.unsubscribeFromTopic('all_users');
  //     await FirebaseMessagingService.unsubscribeFromTopic(
  //         Platform.isIOS ? 'ios_users' : 'android_users');

  //     // Supprimer le token du serveur
  //     if (_fcmToken != null) {
  //       await _removeFCMTokenFromServer(_fcmToken!);
  //     }

  //     _fcmToken = null;
  //     _isFirebaseInitialized = false;

  //     //print('✅ [DataProvider] Firebase nettoyé');
  //   } catch (e) {
  //     //print('❌ [DataProvider] Erreur nettoyage Firebase: $e');
  //   }
  // }

  // // Supprimer le token FCM du serveur
  // Future<void> _removeFCMTokenFromServer(String fcmToken) async {
  //   try {
  //     final userToken = await _getUserToken();
  //     if (userToken == null) return;

  //     final response = await http.delete(
  //       Uri.parse('https://api.live.wortis.cg/firebase/api/user/fcm-token'),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': userToken,
  //       },
  //       body: jsonEncode({
  //         'fcm_token': fcmToken,
  //       }),
  //     );

  //     if (response.statusCode == 200) {
  //       //print('✅ [DataProvider] Token FCM supprimé du serveur');
  //     }
  //   } catch (e) {
  //     //print('❌ [DataProvider] Erreur suppression token FCM: $e');
  //   }
  // }

  // // Rafraîchir le token FCM
  // Future<void> refreshFCMToken() async {
  //   try {
  //     final newToken = await FirebaseMessagingService.getCurrentToken();

  //     if (newToken != null && newToken != _fcmToken) {
  //       // Supprimer l'ancien token
  //       if (_fcmToken != null) {
  //         await _removeFCMTokenFromServer(_fcmToken!);
  //       }

  //       // Envoyer le nouveau token
  //       _fcmToken = newToken;
  //       await _sendFCMTokenToServer(newToken);

  //       notifyListeners();
  //     }
  //   } catch (e) {
  //     //print('❌ [DataProvider] Erreur rafraîchissement token FCM: $e');
  //   }
  // }

  // Envoyer une notification de test Firebase
  // Future<void> sendTestFirebaseNotification() async {
  //   try {
  //     final success = await FirebaseMessagingService.sendTestNotification();

  //     if (success) {
  //       //print('✅ [DataProvider] Notification de test envoyée');
  //     } else {
  //       throw Exception('Échec envoi notification test');
  //     }
  //   } catch (e) {
  //     //print('❌ [DataProvider] Erreur envoi notification test: $e');
  //     rethrow;
  //   }
  // }

  // Charger les données critiques pour l'UI
  Future<void> _loadCriticalData(String token) async {
    try {
      // Paralléliser les appels critiques
      final futures = <Future>[];

      // 1. Bannières et secteurs
      futures.add(_loadBannersAndSecteurs(token));

      // 2. Miles (maintenant critique)
      futures.add(_loadMilesCritical(token));

      // Attendre que toutes les données critiques soient chargées
      await Future.wait(futures).timeout(const Duration(seconds: 10));

      //print( '✅ [DataProvider] Données critiques chargées: ${_banners.length} bannières, ${_secteurs.length} secteurs, $_miles miles');
    } catch (e) {
      //print('❌ [DEBUG] Erreur _loadCriticalData: $e');

      // NOUVEAU: Permettre de continuer même si certaines données échouent
      if (_banners.isEmpty && _secteurs.isEmpty) {
        rethrow; // Seulement si TOUT a échoué
      }
    }
  }

  // Nouvelle méthode pour charger bannières et secteurs
  Future<void> _loadBannersAndSecteurs(String token) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/acceuil_apk_wpay_v2_test/$token'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        _banners = (jsonData['banner'] as List?)
                ?.map((item) => Accueil.fromJson(item))
                .toList() ??
            [];
        _secteurs =
            (jsonData['SecteurActivite'] as List?)
                ?.map((item) => SecteurActivite.fromJson(item))
                .toList() ??
            [];
      }
    } catch (e) {
      //print('❌ [DataProvider] Erreur chargement bannières/secteurs: $e');
      Future.delayed(Duration(seconds: 10), () {
        _loadBannersAndSecteurs(token);
      });
      rethrow;
    }
  }

  // Nouvelle méthode pour charger les miles en tant que donnée critique
  Future<void> _loadMilesCritical(String token) async {
    try {
      _milesLoading = true;
      _milesError = null;

      final miles = await UserService.getbalanceMiles(token);
      _miles = miles;
      _lastMilesRefresh = DateTime.now();

      //print('✅ [DataProvider] Miles critiques chargés: $_miles');
    } catch (e) {
      _milesError = e.toString();
      //print('❌ [DataProvider] Erreur chargement miles critiques: $e');
      // Les miles restent à 0 en cas d'erreur mais on ne fait pas échouer l'initialisation
    } finally {
      _milesLoading = false;
    }
  }

  // Charger les données secondaires en arrière-plan
  void _loadSecondaryDataInBackground(String token) {
    Future.microtask(() async {
      try {
        final futures = <Future>[];
        futures.add(_loadServicesWithRetry(token));
        futures.add(_loadNewsWithRetry(token));
        futures.add(_loadUserProfile(token));

        await Future.wait(futures).timeout(const Duration(seconds: 15));

        Timer(const Duration(seconds: 3), () => loadNotificationsIfNeeded());
        Timer(const Duration(seconds: 5), () => loadTransactionsIfNeeded());

        //print('✅ [DataProvider] Chargement arrière-plan terminé');
      } catch (e) {
        //print('⚠️ [DataProvider] Erreur chargement arrière-plan: $e');
      }
    });
  }

  Future<void> _loadServicesWithRetry(String token) async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/get_services_test/$token'))
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          _services = jsonData['all_services'] ?? [];
          _displayedServices = jsonData['random_services'] ?? [];
          print('✅ [DataProvider] Services chargés: ${_services.length}');
          // Debug: afficher les Type_Service de chaque service
          for (var service in _services) {
            print(
              '   📦 Service: ${service['name']} | Type: ${service['Type_Service']}',
            );
          }
          // ✅ CORRECTION: Différer notifyListeners
          Future.microtask(() => notifyListeners());
          return;
        }
      } catch (e) {
        attempts++;
        //print( '⚠️ [DataProvider] Tentative $attempts/$maxAttempts services échouée: $e');
        if (attempts < maxAttempts) {
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      }
    }
  }

  Future<void> _loadNewsWithRetry(String token) async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/apk_news_test/$token'))
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          _news =
              (jsonData['enregistrements'] as List?)
                  ?.map((item) => NewsItem.fromJson(item))
                  .toList() ??
              [];
          //print('✅ [DataProvider] Actualités chargées: ${_news.length}');
          // ✅ CORRECTION: Différer notifyListeners
          Future.microtask(() => notifyListeners());
          return;
        }
      } catch (e) {
        attempts++;
        // print('⚠️ [DataProvider] Tentative $attempts/$maxAttempts actualités échouée: $e');
        if (attempts < maxAttempts) {
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      }
    }
  }

  Future<void> _loadUserProfile(String token) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/get_user_apk_wpay_v2/$token'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _userData = UserData.fromJson(data);
        _userProfile = data;
        _initializeProfileControllers();
        //print('✅ [DataProvider] Profil utilisateur chargé');
        // ✅ CORRECTION: Différer notifyListeners
        Future.microtask(() => notifyListeners());
      }
    } catch (e) {
      //print('❌ [DataProvider] Erreur chargement profil: $e');
    }
  }

  void _safeNotifyListeners() {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // Si nous sommes dans la phase de build, différer l'appel
      Future.microtask(() => notifyListeners());
    } else {
      // Sinon, appeler directement
      notifyListeners();
    }
  }

  void _initializeProfileControllers() {
    _profileControllers.clear();
    if (_userProfile['enregistrement'] != null) {
      (_userProfile['enregistrement'] as Map<String, dynamic>).forEach((
        key,
        value,
      ) {
        _profileControllers[key] = TextEditingController(
          text: value?.toString() ?? '',
        );
      });
    }
  }

  // Méthodes pays éligibles (utilisées dans homepage_dias.dart)
  Future<void> loadEligibleCountries() async {
    // ✅ OPTIMISATION: Vérifier si déjà en cours de chargement
    if (_isEligibleCountriesLoading) return;

    // ✅ OPTIMISATION: Utiliser le cache si disponible et récent
    if (_eligibleCountries.isNotEmpty &&
        _lastEligibleCountriesRefresh != null &&
        DateTime.now().difference(_lastEligibleCountriesRefresh!) <
            eligibleCountriesRefreshThreshold) {
      //print('✅ [DataProvider] Utilisation du cache pour les pays éligibles');
      return;
    }

    try {
      _isEligibleCountriesLoading = true;
      _eligibleCountriesError = null;
      // ✅ CORRECTION: Différer notifyListeners
      Future.microtask(() => notifyListeners());

      // ✅ OPTIMISATION: Ajout d'un timeout de 10 secondes
      final response = await http
          .get(Uri.parse('$baseUrl/liste_pays_apk'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        _eligibleCountries = List<String>.from(
          jsonData['eligible_countries'] ?? [],
        );
        _lastEligibleCountriesRefresh =
            DateTime.now(); // ✅ OPTIMISATION: Timestamp du cache
        //print( '✅ [DataProvider] Pays éligibles chargés: ${_eligibleCountries.length}');
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      _eligibleCountriesError = e.toString();
      //print('❌ [DataProvider] Erreur chargement pays: $e');
    } finally {
      _isEligibleCountriesLoading = false;
      // ✅ CORRECTION: Différer notifyListeners
      Future.microtask(() => notifyListeners());
    }
  }

  // Méthodes transactions (utilisées dans transaction.dart)
  Future<void> loadTransactionsIfNeeded() async {
    if (_isTransactionsLoading ||
        (_hasLoadedTransactions &&
            _lastTransactionsRefresh != null &&
            DateTime.now().difference(_lastTransactionsRefresh!) <
                transactionsRefreshThreshold)) {
      return;
    }

    try {
      _isTransactionsLoading = true;
      Future.microtask(() => notifyListeners());

      final token = await _getUserToken();
      if (token == null) throw Exception('Token non trouvé');

      //print('🔄 [DataProvider] Chargement transactions unifiées...');

      // ✅ OPTIMISATION: Ajout d'un timeout de 15 secondes
      final response = await http
          .get(
            Uri.parse('$baseUrl/get_user_apk_wpay_v3_test/$token'),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // L'API retourne maintenant une liste unifiée dans 'transac'
        final List<dynamic> transactionsData = data['transac'] ?? [];

        final transactions = transactionsData
            .map((json) => Transaction.fromJson(json))
            .toList();

        _transactions = transactions;
        _lastTransactionsRefresh = DateTime.now();
        _hasLoadedTransactions = true;

        //print('✅ [DataProvider] Transactions chargées: ${transactions.length}');
        print(
          '📱 Mobile Money: ${transactions.where((t) => t.typeTransaction == 'momo').length}',
        );
        print(
          '💳 Carte Bancaire: ${transactions.where((t) => t.typeTransaction == 'carte').length}',
        );
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      _transactionsError = e.toString();
      //print('❌ [DataProvider] Erreur transactions: $e');
    } finally {
      _isTransactionsLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<bool> deleteTransaction(String transactionId) async {
    try {
      final token = await _getUserToken();
      if (token == null) throw Exception('Token non trouvé');

      final success = await UserService.deleteTransaction(token, transactionId);
      if (success) {
        _transactions.removeWhere((t) => t.clientTransID == transactionId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      //print('❌ [DataProvider] Erreur suppression transaction: $e');
      return false;
    }
  }

  void removeTransactionLocally(String transactionId) {
    _transactions.removeWhere((t) => t.clientTransID == transactionId);
    notifyListeners();
  }

  void restoreTransaction(Transaction transaction, int? index) {
    if (index != null && index >= 0 && index <= _transactions.length) {
      _transactions.insert(index, transaction);
      notifyListeners();
    }
  }

  // Remplacez la section de traitement des notifications dans dataprovider.dart
  Future<void> loadNotificationsIfNeeded() async {
    if (_isNotificationLoadingInProgress ||
        (_hasLoadedNotifications &&
            _lastNotificationsRefresh != null &&
            DateTime.now().difference(_lastNotificationsRefresh!) <
                notificationsRefreshThreshold)) {
      return;
    }

    try {
      _isNotificationLoadingInProgress = true;
      _isNotificationsLoading = true;
      Future.microtask(() => notifyListeners());

      final token = await _getUserToken();
      if (token == null) throw Exception('Token non trouvé');

      //print('🔄 [DataProvider] Chargement notifications pour token: $token');

      final response = await http
          .get(
            Uri.parse('$baseUrl/notifications_test/$token'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      //print('📡 [DataProvider] Réponse API: ${response.statusCode}');
      //print('🔄 [DataProvider] Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        List<NotificationData> loadedNotifications = [];

        // 🔧 CORRECTION: Gérer les deux structures possibles
        if (jsonData is Map && jsonData.containsKey('notifications')) {
          // Structure: { "notifications": [...] }
          final notificationsData = jsonData['notifications'] as List?;
          loadedNotifications =
              notificationsData
                  ?.map((item) => NotificationData.fromJson(item))
                  .toList() ??
              [];
          //print('✅ [DataProvider] Structure avec clé "notifications": ${loadedNotifications.length} items');
        } else if (jsonData is List) {
          // Structure: [...]
          loadedNotifications = jsonData
              .map((item) => NotificationData.fromJson(item))
              .toList();
          //print('✅ [DataProvider] Structure tableau direct: ${loadedNotifications.length} items');
        } else if (jsonData is Map && jsonData.containsKey('data')) {
          // Structure alternative: { "data": [...] }
          final notificationsData = jsonData['data'] as List?;
          loadedNotifications =
              notificationsData
                  ?.map((item) => NotificationData.fromJson(item))
                  .toList() ??
              [];
          //print( '✅ [DataProvider] Structure avec clé "data": ${loadedNotifications.length} items');
        } else {
          //print('⚠️ [DataProvider] Structure de réponse inconnue: ${jsonData.runtimeType}');
          loadedNotifications = [];
        }

        _notifications = loadedNotifications;
        //print('✅ [DataProvider] Total notifications chargées: ${_notifications.length}');
      } else if (response.statusCode == 404) {
        _notifications = [];
        //print('📭 [DataProvider] Aucune notification trouvée (404)');
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}: ${response.body}');
      }

      _hasLoadedNotifications = true;
      _lastNotificationsRefresh = DateTime.now();
    } catch (e) {
      _notificationsError = e.toString();
      //print('❌ [DataProvider] Erreur notifications: $e');

      if (!_hasLoadedNotifications) {
        _notifications = [];
        _hasLoadedNotifications = true;
        _lastNotificationsRefresh = DateTime.now();
      }
    } finally {
      _isNotificationsLoading = false;
      _isNotificationLoadingInProgress = false;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> refreshNotifications() async {
    _hasLoadedNotifications = false;
    _lastNotificationsRefresh = null;
    await loadNotificationsIfNeeded();

    // // NOUVEAU : Vérifier si Firebase est bien initialisé
    // if (!_isFirebaseInitialized && await _getUserToken() != null) {
    //   await _initializeFirebase();
    // }
  }

  Future<void> startPeriodicNotificationRefresh() async {
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      await refreshNotifications();
    });
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      if (_notifications.isEmpty) return;

      // ✅ CORRIGÉ: Sauvegarder avec getter public
      final originalStatuses = <String, String>{};
      for (var notification in _notifications) {
        originalStatuses[notification.id] =
            notification.statut; // ✅ Utilise le getter
        notification.markAsRead(); // ✅ Utilise la méthode publique
      }
      notifyListeners();

      // 2. Appel API via NotificationService
      final token = await _getUserToken();
      if (token == null) throw Exception('Token non trouvé');

      final success = await NotificationService.markAllAsRead(token);

      if (!success) {
        // ✅ CORRIGÉ: Restaurer avec setter public
        for (var notification in _notifications) {
          notification.statut =
              originalStatuses[notification.id] ??
              "non lu"; // ✅ Utilise le setter
        }
        notifyListeners();
        throw Exception('Échec du marquage global côté serveur');
      }
    } catch (e) {
      //print('❌ [DataProvider] Erreur marquage global: $e');
      _notificationsError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Marquer une notification individuelle comme lue
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      //print('🔍 [DataProvider] Marquage notification: $notificationId');

      // 1. Mise à jour locale immédiate pour l'UX
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      String? oldStatus;

      if (index != -1) {
        oldStatus = _notifications[index].statut;
        _notifications[index].markAsRead(); // ✅ Utilise la méthode publique
        notifyListeners();
      }

      // 2. Appel API via NotificationService
      final token = await _getUserToken();
      if (token == null) throw Exception('Token non trouvé');

      final success = await NotificationService.markAsRead(
        token,
        notificationId,
      );

      if (!success) {
        // ✅ CORRIGÉ: Restaurer avec setter public
        if (index != -1 && oldStatus != null) {
          _notifications[index].statut = oldStatus; // ✅ Utilise le setter
          notifyListeners();
        }
        throw Exception('Échec du marquage côté serveur');
      }

      //print('✅ [DataProvider] Notification $notificationId marquée comme lue');
    } catch (e) {
      //print('❌ [DataProvider] Erreur marquage: $e');
      // ✅ CORRIGÉ: Restaurer avec méthode publique
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index].markAsUnread(); // ✅ Utilise la méthode publique
        notifyListeners();
      }
      rethrow;
    }
  }

  // Supprimer une notification individuelle
  Future<bool> deleteNotification(NotificationData notification) async {
    try {
      //print('🗑️ [DataProvider] Suppression: ${notification.id}');

      // 1. Retirer immédiatement de la liste pour l'UX
      final originalIndex = _notifications.indexWhere(
        (n) => n.id == notification.id,
      );
      if (originalIndex == -1) return true;

      final removedNotification = _notifications.removeAt(originalIndex);
      notifyListeners();

      // 2. Appel API via NotificationService
      final success = await NotificationService.deleteNotification(
        notification.userId,
        notification.id,
      );

      if (!success) {
        // Restaurer en cas d'échec
        _notifications.insert(originalIndex, removedNotification);
        notifyListeners();
      }

      return success;
    } catch (e) {
      //print('❌ [DataProvider] Erreur suppression: $e');
      return false;
    }
  }

  // Supprimer toutes les notifications
  Future<void> deleteAllNotifications() async {
    try {
      if (_notifications.isEmpty) return;

      // 1. Sauvegarder et vider la liste
      final oldNotifications = List<NotificationData>.from(_notifications);
      _notifications.clear();
      notifyListeners();

      // 2. Appel API via NotificationService
      final token = await _getUserToken();
      if (token == null) throw Exception('Token non trouvé');

      final success = await NotificationService.deleteAllNotifications(token);

      if (!success) {
        // Restaurer en cas d'échec
        _notifications.addAll(oldNotifications);
        notifyListeners();
        throw Exception('Échec de la suppression globale côté serveur');
      }
    } catch (e) {
      //print('❌ [DataProvider] Erreur suppression globale: $e');
      _notificationsError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Basculer l'expansion d'une notification
  void toggleNotificationExpansion(NotificationData notification) {
    final index = _notifications.indexWhere((n) => n.id == notification.id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(
        isExpanded: !_notifications[index].isExpanded,
      );
      notifyListeners();
    }
  }

  // Méthodes portefeuille
  Future<void> unlockWallet(String pin) async {
    try {
      _isWalletLoading = true;
      // ✅ CORRECTION: Différer notifyListeners
      Future.microtask(() => notifyListeners());

      final token = await _getUserToken();
      if (token == null) throw Exception('Token non trouvé');

      final response = await http.post(
        Uri.parse('$baseUrl/api/wallet/balance'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: json.encode({"pin": pin}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _walletBalance = data['balance'].toDouble();
        _walletCurrency = data['currency'];
        _isWalletLocked = false;
        _walletError = null;
      } else {
        throw Exception('Erreur lors du chargement du solde');
      }
    } catch (e) {
      _walletError = e.toString();
    } finally {
      _isWalletLoading = false;
      // ✅ CORRECTION: Différer notifyListeners
      Future.microtask(() => notifyListeners());
    }
  }

  void lockWallet() {
    _isWalletLocked = true;
    notifyListeners();
  }

  // Méthodes profil
  void setEditingProfile(bool isEditing) {
    _isEditingProfile = isEditing;
    notifyListeners();
  }

  void cancelProfileEditing() {
    _isEditingProfile = false;
    _initializeProfileControllers();
    notifyListeners();
  }

  Future<void> updateUserProfile(Map<String, dynamic> updatedData) async {
    try {
      _isLoading = true;
      // ✅ CORRECTION: Différer notifyListeners
      Future.microtask(() => notifyListeners());

      final token = await _getUserToken();
      if (token == null) throw Exception('Token non trouvé');

      final response = await http.post(
        Uri.parse('$baseUrl/update_user_apk_wpay_v2_test'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(updatedData),
      );

      if (response.statusCode == 200) {
        await _loadUserProfile(token);
        _isEditingProfile = false;
      } else {
        throw Exception('Erreur lors de la mise à jour du profil');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      // ✅ CORRECTION: Différer notifyListeners
      Future.microtask(() => notifyListeners());
    }
  }

  // Méthodes refresh (utilisées dans homepage.dart et class.dart)
  Future<void> refreshAll() async {
    try {
      _isLoading = true;
      Future.microtask(() => notifyListeners());

      final token = await _getUserToken();
      if (token == null) throw Exception('Token non trouvé');

      // Recharger toutes les données critiques (bannières, secteurs, miles)
      await Future.wait([_loadCriticalData(token), refreshNotifications()]);

      // ⚠️ IMPORTANT: Charger SEULEMENT les données secondaires (pas les miles)
      _loadSecondaryDataInBackgroundExcludingMiles(token);
      _lastRefresh = DateTime.now();
    } catch (e) {
      _error = e.toString();
      //print('❌ [DataProvider] Erreur refresh: $e');
    } finally {
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  // Nouvelle méthode pour charger les données secondaires SANS les miles
  void _loadSecondaryDataInBackgroundExcludingMiles(String token) {
    Future.microtask(() async {
      try {
        final futures = <Future>[];
        futures.add(_loadServicesWithRetry(token));
        futures.add(_loadNewsWithRetry(token));
        futures.add(_loadUserProfile(token));

        await Future.wait(futures).timeout(const Duration(seconds: 15));

        Timer(const Duration(seconds: 3), () => loadNotificationsIfNeeded());
        Timer(const Duration(seconds: 5), () => loadTransactionsIfNeeded());
        // ✅ PAS de chargement des miles ici - déjà fait en critique

        //print('✅ [DataProvider] Chargement arrière-plan terminé (sans miles)');
      } catch (e) {
        //print('⚠️ [DataProvider] Erreur chargement arrière-plan: $e');
      }
    });
  }

  // Refresh all data (alias pour refreshAll)
  Future<void> refreshAllData() async {
    await refreshAll();
  }

  Future<void> refreshNews() async {
    try {
      _isNewsLoading = true;
      // ✅ CORRECTION: Différer notifyListeners
      Future.microtask(() => notifyListeners());

      final token = await _getUserToken();
      if (token == null) throw Exception('Token non trouvé');

      await _loadNewsWithRetry(token);
      _lastRefresh = DateTime.now();
    } finally {
      _isNewsLoading = false;
      // ✅ CORRECTION: Différer notifyListeners
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> refreshBanners() async {
    if (!needsRefresh) return;

    try {
      final userToken = await _getUserToken();
      if (userToken == null) {
        //print('Aucun token trouvé - rafraîchissement bannières annulé');
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/acceuil_apk_wpay_v2_test/$userToken'),
      );
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        _banners = (jsonData['banner'] as List?)
                ?.map((item) => Accueil.fromJson(item))
                .toList() ??
            [];
      }
    } catch (e) {
      print("Erreur bannières: $e");
      Future.delayed(Duration(seconds: 10), () {
        refreshBanners();
      });
    }
    notifyListeners();
  }

  // Méthodes Miles (utilisées dans homepage.dart et homepage_dias.dart)
  Future<void> refreshMiles() async {
    if (_milesLoading ||
        (_lastMilesRefresh != null &&
            DateTime.now().difference(_lastMilesRefresh!) <
                milesRefreshThreshold)) {
      return;
    }

    try {
      _milesLoading = true;
      _milesError = null;
      Future.microtask(() => notifyListeners());

      final token = await _getUserToken();
      if (token == null) throw Exception('Token non trouvé');

      final miles = await UserService.getbalanceMiles(token);
      _miles = miles;
      _lastMilesRefresh = DateTime.now();
      //print('✅ [DataProvider] Miles actualisés: $_miles');
    } catch (e) {
      _milesError = e.toString();
      //print('❌ [DataProvider] Erreur actualisation miles: $e');
    } finally {
      _milesLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  // Méthodes utilisées dans class.dart pour l'initialisation après registration
  Future<void> loadPublicData() async {
    try {
      final userToken = await _getUserToken();
      if (userToken == null) {
        //print('Aucun token trouvé - chargement des données annulé');
        return;
      }

      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/acceuil_apk_wpay_v2_test/$userToken')),
        http.get(Uri.parse('$baseUrl/get_services_test/$userToken')),
        http.get(Uri.parse('$baseUrl/apk_news_test/$userToken')),
        http.get(Uri.parse('$baseUrl/liste_pays_apk')),
      ]);

      await _processResponses(responses);
    } catch (e) {
      _error = e.toString();
      Future.delayed(Duration(seconds: 10), () {
        loadPublicData();
      });
      //print('Erreur lors du chargement des données publiques: $e');
      rethrow;
    }
  }

  Future<void> _processResponses(List<http.Response> responses) async {
    if (responses[0].statusCode == 200) {
      final jsonData = json.decode(responses[0].body);
      _banners = (jsonData['banner'] as List?)
              ?.map((item) => Accueil.fromJson(item))
              .toList() ??
          [];
      _banners.shuffle();
      _secteurs =
          (jsonData['SecteurActivite'] as List?)
              ?.map((item) => SecteurActivite.fromJson(item))
              .toList() ??
          [];
    }

    if (responses[1].statusCode == 200) {
      final jsonData = json.decode(responses[1].body);
      _services = jsonData['all_services'] ?? [];
      _displayedServices = jsonData['random_services'] ?? [];
    }

    if (responses[2].statusCode == 200) {
      final jsonData = json.decode(responses[2].body);
      _news =
          (jsonData['enregistrements'] as List?)
              ?.map((item) => NewsItem.fromJson(item))
              .toList() ??
          [];
    }

    if (responses[3].statusCode == 200) {
      final jsonData = json.decode(responses[3].body);
      _eligibleCountries = List<String>.from(
        jsonData['eligible_countries'] ?? [],
      );
      _eligibleCountriesError = null;
    }
  }

  // Méthodes pour post-registration
  void setPostRegistrationMode(String token) {
    _currentUserId = token;
  }

  Future<void> initializeForPostRegistration(
    BuildContext context,
    String token,
  ) async {
    await initializeApp(context);
  }

  Future<void> initializeAfterRegistration(
    BuildContext context,
    String token,
  ) async {
    if (_isInitializing || _isInitialized) {
      //print( '✅ [DataProvider] Déjà initialisé - mise à jour avec nouveau token');
      _currentUserId = token;
      setPostRegistrationMode(token);

      // NOUVEAU : Initialiser Firebase après registration avec token
      // await _initializeFirebase();

      notifyListeners();
      return;
    }

    try {
      _isInitializing = true;
      _isLoading = true;
      _error = '';
      _currentUserId = token;
      setPostRegistrationMode(token);
      notifyListeners();

      await _pushNotificationService.initNotification();

      // NOUVEAU : Initialiser Firebase
      // await _initializeFirebase();

      await initializeForPostRegistration(context, token);
    } catch (e) {
      _error = e.toString();
      _isInitialized = false;
      //print('❌ [DataProvider] Erreur initialisation post-registration: $e');
    } finally {
      _isLoading = false;
      _isInitializing = false;
      notifyListeners();
    }
  }

  // Nettoyage - MODIFIÉ AVEC FIREBASE
  @override
  void dispose() {
    _loadingTimer?.cancel();
    _profileControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  // Logout - MODIFIÉ AVEC FIREBASE
  void logout() async {
    // NOUVEAU : Nettoyer Firebase avant logout
    // await _cleanupFirebase();

    _userData = null;
    _userProfile = {};
    _transactions = [];
    _notifications = [];
    _services = [];
    _news = [];
    _miles = 0;
    _isInitialized = false;
    _hasLoadedTransactions = false;
    _hasLoadedNotifications = false;
    _profileControllers.forEach((_, controller) => controller.dispose());
    _profileControllers.clear();
    lockWallet();
    notifyListeners();
  }
}
