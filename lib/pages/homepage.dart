// ignore_for_file: unused_field, deprecated_member_use, unused_element, duplicate_ignore, unnecessary_null_comparison, empty_catches, unrelated_type_equality_checks, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wortis/class/CustomPageTransition.dart';
import 'package:wortis/class/dataprovider.dart';
import 'package:wortis/class/webviews.dart';
import 'package:wortis/pages/allservice.dart';
import 'package:wortis/class/form_service.dart';
import 'package:wortis/class/catalog_service.dart';
import 'package:wortis/pages/reservation_service.dart';
import 'package:wortis/pages/connexion/gestionCompte.dart' hide AppConfig;
import 'package:wortis/pages/homepage_dias.dart';
import 'package:wortis/pages/moncompte.dart';
import 'package:wortis/pages/notifications.dart';
import 'package:wortis/pages/news.dart';
import 'package:wortis/class/icon_utils.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../class/class.dart';
// ignore: unused_shown_name
import 'dart:io' show File, Platform;
import 'package:wortis/pages/transaction.dart';
import 'package:wortis/main.dart' show sendLocalPlayerIdToBackend;

class HomePage extends StatefulWidget {
  final RouteObserver<PageRoute> routeObserver;
  const HomePage({super.key, required this.routeObserver});

  @override
  // ignore: library_private_types_in_public_api
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with
        TickerProviderStateMixin,
        RouteAware,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  bool _isPinLocked = false;
  DateTime? _lockUntil;
  int _balance = 0;
  String _currency = 'XAF';
  final List<String> _preloadedImageUrls = [];
  bool _isBalanceVisible = false;
  final String _pin = '';
  late int _selectedIndex = 0;
  final PageController _pageController = PageController();
  late Timer _timer;
  int _currentPage = 0;
  // ignore: duplicate_ignore
  // ignore: unused_field
  final bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _filteredServices = [];
  bool _showAllServices = false;
  bool _isTokenPresent = false;
  bool _isFirstLoad = true;
  int _unreadNotificationCount = 0;
  List<Map<String, dynamic>> _selectedServices = [];
  late RouteObserver<PageRoute> routeObserver;
  int _pinAttempts = 0;

  bool _showTimeoutPopup = false;
  Timer? _loadingTimeoutTimer;

  // ========== VARIABLES POUR LE CHANGEMENT DE PAYS ==========
  bool _isCountryChanging = false;
  bool _showCountryChangeOverlay = false;
  String? _newSelectedCountry;
  int _currentStep = 0;
  final List<String> _progressSteps = [
    'Mise à jour serveur',
    'Sauvegarde locale',
    'Rechargement données',
    'Finalisation',
  ];

  // Variables pour la gestion des pays (si pas déjà présentes)
  String _selectedCountry = "";
  String _selectedFlag = "";
  List<Map<String, dynamic>> _availableCountries = [];
  bool _hasRestoredCountry = false;

  // Animation controllers
  late AnimationController _bannerAnimationController;
  late AnimationController _sectorsAnimationController;
  late AnimationController _balanceAnimationController;
  late AnimationController _servicesAnimationController;
  late AnimationController _searchAnimationController;
  late AnimationController _bottomNavAnimationController;
  late AnimationController _fullscreenServicesController;
  late AnimationController _searchResultsController;

  // Animations
  late Animation<Offset> _bannerSlideAnimation;
  late Animation<double> _bannerFadeAnimation;
  late Animation<double> _sectorsScaleAnimation;
  late Animation<double> _balanceSlideAnimation;
  late Animation<double> _servicesFadeAnimation;
  late Animation<Offset> _bottomNavSlideAnimation;
  late Animation<double> _searchScaleAnimation;
  late Animation<double> _fullscreenServicesScale;
  late Animation<double> _fullscreenServicesOpacity;
  late Animation<double> _searchResultsScale;
  late Animation<double> _searchResultsOpacity;

  @override
  bool get wantKeepAlive => true; // Gardez l'état en vie

  @override
  void initState() {
    super.initState();

    // ✅ NOUVEAU: Envoyer le Player ID OneSignal au backend
    sendLocalPlayerIdToBackend();

    // NOUVEAU: Timer de debug pour surveiller l'état
    _debugTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (mounted) {
        final provider = Provider.of<AppDataProvider>(context, listen: false);
        //print( '🔍 [DEBUG Periodic] isDataReady: ${provider.isDataReady}, isLoading: ${provider.isLoading}');
      }
    });
    _searchController.addListener(() {
      setState(() {
        // Force le rebuild pour mettre à jour l'affichage de l'icône
      });
    });

    routeObserver = widget.routeObserver;
    WidgetsBinding.instance.addObserver(this);

    // 2. Initialisation des contrôleurs d'animation
    _initializeAnimationControllers();

    // 3. Configuration des animations
    _configureAnimations();

    // 4. Vérification du premier chargement avant les données
    _checkFirstLoad().then((_) {
      // 5. Chargement des données
      _initializeBasicSetup();
      _selectRandomServices();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreCountryOnce();
      _preloadBannerImages();
      ConnectivityManager(context).initConnectivity();
    });

    // 6. Rafraîchissement des notifications
    Future.microtask(() {
      if (mounted) {
        final appDataProvider = Provider.of<AppDataProvider>(
          context,
          listen: false,
        );
        appDataProvider.refreshNotifications();
        appDataProvider.startPeriodicNotificationRefresh();
      }
    });
  }

  @override
  void didPush() {
    super.didPush();
    _getUnreadNotificationCount();
  }

  @override
  void didPopNext() {
    super.didPopNext();

    Future.microtask(() {
      if (mounted) {
        final appDataProvider = Provider.of<AppDataProvider>(
          context,
          listen: false,
        );
        appDataProvider.refreshNotifications();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.microtask(() {
        if (mounted) {
          final appDataProvider = Provider.of<AppDataProvider>(
            context,
            listen: false,
          );
          appDataProvider.refreshNotifications();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _startAutoScroll() {
    // Attendre que le widget soit complètement construit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!mounted) return;

        final appDataProvider = Provider.of<AppDataProvider>(
          context,
          listen: false,
        );
        if (_currentPage < appDataProvider.banners.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }

        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  // Méthode pour précharger les images
  void _preloadBannerImages() {
    if (!mounted) return;

    final appDataProvider = Provider.of<AppDataProvider>(
      context,
      listen: false,
    );

    // Préchargez toutes les images de bannière
    for (var banner in appDataProvider.banners) {
      if (banner.hasLocalImage) {
        continue; // Pas besoin de précharger les images locales
      }

      final imageUrl = banner.imageUrl;
      if (!_preloadedImageUrls.contains(imageUrl)) {
        // Précacher l'image
        precacheImage(NetworkImage(Uri.encodeFull(imageUrl)), context).then((
          _,
        ) {
          if (mounted) {
            setState(() {
              _preloadedImageUrls.add(imageUrl);
            });
          }
        });
      }
    }
  }

  void _selectRandomServices() {
    if (!mounted) return;

    final appDataProvider = Provider.of<AppDataProvider>(
      context,
      listen: false,
    );

    // Vérifier que les services sont disponibles
    if (appDataProvider.services.isEmpty) {
      return;
    }

    try {
      final random = Random();
      final servicesCopy = List.from(appDataProvider.services);
      _selectedServices = [];

      while (_selectedServices.length < 4 && servicesCopy.isNotEmpty) {
        final index = random.nextInt(servicesCopy.length);
        final service = servicesCopy[index] as Map<String, dynamic>;

        // S'assurer que le service a tous les champs nécessaires
        if (service.containsKey('name') && service.containsKey('icon')) {
          _selectedServices.add(service);
        }

        servicesCopy.removeAt(index);
      }

      // Forcer la mise à jour de l'UI si des services ont été trouvés
      if (_selectedServices.isNotEmpty) {
        setState(() {});
      }
    } catch (e) {}
  }

  Future<void> _getUnreadNotificationCount() async {
    try {
      final token = await SessionManager.getToken();
      if (token != null) {
        final response = await http.get(
          Uri.parse('$baseUrl/notifications_test/$token'),
          headers: {"Content-Type": "application/json"},
        );

        if (response.statusCode == 200 && mounted) {
          final List<dynamic> data = jsonDecode(response.body);
          final unreadCount = data.where((n) => n['statut'] == 'non lu').length;
          setState(() {
            _unreadNotificationCount = unreadCount;
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _initializeBasicSetup() async {
    if (!mounted) return;

    setState(() {
      _isBalanceVisible = false;
      _filteredServices = [];
    });

    _startAutoScroll();
    await _checkToken();

    if (!mounted) return;
    await _getUnreadNotificationCount();

    if (!mounted) return;

    // CORRECTION: Utiliser Consumer au lieu d'accéder directement au provider
    // Le provider sera automatiquement mis à jour via Consumer
    //print('✅ [HomePage] Configuration de base terminée');
  }

  Future<void> _checkFirstLoad() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isFirstLoad = prefs.getBool('first_load_home') ?? true;
    });

    if (_isFirstLoad) {
      // Utiliser WidgetsBinding.instance.addPostFrameCallback pour s'assurer que le build est terminé
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startAnimationSequence();
      });
      await prefs.setBool('first_load_home', false);
    } else {
      _setAnimationsToEnd();
    }
  }

  void _setAnimationsToEnd() {
    _bannerAnimationController.value = 1.0;
    _sectorsAnimationController.value = 1.0;
    _balanceAnimationController.value = 1.0;
    _servicesAnimationController.value = 1.0;
    _bottomNavAnimationController.value = 1.0;
    _searchAnimationController.value = 1.0;
  }

  // Méthode pour vérifier le token
  Future<void> _checkToken() async {
    final token = await SessionManager.getToken();
    setState(() {
      _isTokenPresent = token != null && token.isNotEmpty;
    });
  }

  Future<void> _restoreCountryOnce() async {
    // Ne faire la restauration qu'une seule fois
    if (_hasRestoredCountry) {
      //print('🔒 [HomePage] Restauration déjà effectuée, ignorée');
      return;
    }

    try {
      //print('🔄 [HomePage] Restauration initiale du pays...');

      final zoneBenefCode = await ZoneBenefManager.getZoneBenef();
      //print('📱 zone_benef_code: $zoneBenefCode');

      if (zoneBenefCode != null && zoneBenefCode.isNotEmpty) {
        final matchingCountry = countries.firstWhere(
          (country) =>
              country.code.toUpperCase() == zoneBenefCode.toUpperCase(),
          orElse: () => const Country(
            name: 'Congo',
            code: 'CG',
            dialCode: '+242',
            flag: '🇨🇬',
            region: 'Afrique Centrale',
          ),
        );

        // Mise à jour SANS setState pour éviter le flash visuel
        _selectedCountry = matchingCountry.name;
        _selectedFlag = matchingCountry.flag;

        print(
          '✅ Pays restauré silencieusement: ${matchingCountry.name} ${matchingCountry.flag}',
        );
      } else {
        // Fallback discret vers Congo (logique par défaut pour HomePage)
        _selectedCountry = "Congo";
        _selectedFlag = "🇨🇬";
        //print('⚠️ Fallback vers Congo');
      }

      // Marquer comme fait pour éviter les répétitions
      _hasRestoredCountry = true;
    } catch (e) {
      //print('❌ Erreur restauration pays: $e');
      // En cas d'erreur, utiliser Congo par défaut
      _selectedCountry = "Congo";
      _selectedFlag = "🇨🇬";
      _hasRestoredCountry = true;
    }
  }

  void _initializeAnimationControllers() {
    _bannerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _sectorsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _balanceAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _servicesAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _bottomNavAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fullscreenServicesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _searchResultsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  void _configureAnimations() {
    _bannerSlideAnimation =
        Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _bannerAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _bannerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bannerAnimationController, curve: Curves.easeIn),
    );

    _sectorsScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sectorsAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _balanceSlideAnimation = Tween<double>(begin: -100.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _balanceAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    _servicesFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _servicesAnimationController,
        curve: Curves.easeIn,
      ),
    );

    _bottomNavSlideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _bottomNavAnimationController,
            curve: Curves.easeOutExpo,
          ),
        );

    _searchScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _searchAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    _fullscreenServicesScale = CurvedAnimation(
      parent: _fullscreenServicesController,
      curve: Curves.easeInOut,
    );

    _fullscreenServicesOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fullscreenServicesController,
        curve: Curves.easeIn,
      ),
    );

    _searchResultsScale = CurvedAnimation(
      parent: _searchResultsController,
      curve: Curves.easeInOut,
    );

    _searchResultsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _searchResultsController, curve: Curves.easeIn),
    );
  }

  Future<void> _startAnimationSequence() async {
    if (!_isFirstLoad) {
      return; // On ne lance les animations que si c'est le premier chargement
    }

    await Future.delayed(const Duration(milliseconds: 100));
    _bannerAnimationController.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    _sectorsAnimationController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    _balanceAnimationController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    _servicesAnimationController.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    _bottomNavAnimationController.forward();

    if (_isSearching) {
      await Future.delayed(const Duration(milliseconds: 600));
      _searchAnimationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<AppDataProvider>(
      builder: (context, appDataProvider, child) {
        // NOUVEAU: Debug des états
        // print( '🏠 [DEBUG HomePage] isDataReady: ${appDataProvider.isDataReady}');
        //print('🏠 [DEBUG HomePage] isLoading: ${appDataProvider.isLoading}');
        //print( '🏠 [DEBUG HomePage] isInitialized: ${appDataProvider.isInitialized}');
        //print('🏠 [DEBUG HomePage] error: "${appDataProvider.error}"');
        //print('🏠 [DEBUG HomePage] banners: ${appDataProvider.banners.length}');
        // print(  '🏠 [DEBUG HomePage] secteurs: ${appDataProvider.secteurs.length}');
        //print('🏠 [DEBUG HomePage] _isReloadingData: $_isReloadingData');

        final screenWidth = MediaQuery.of(context).size.width;
        final cardWidth = screenWidth * 0.4;

        // ✅ CORRECTION: Ne pas afficher la modal si on est en train de recharger les données
        if ((!appDataProvider.isDataReady || appDataProvider.isLoading) &&
            !_isReloadingData) {
          // Démarrer le timer pour le timeout si pas encore démarré
          _loadingTimeoutTimer ??= Timer(const Duration(seconds: 30), () {
            if (mounted &&
                (!appDataProvider.isDataReady || appDataProvider.isLoading)) {
              //print('⚠️ [DEBUG HomePage] Timeout détecté - forçage refresh');

              // NOUVEAU: Forcer un refresh et réessayer
              setState(() {
                _showTimeoutPopup = true;
              });

              // Auto-refresh après 3 secondes
              Timer(Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _showTimeoutPopup = false;
                  });
                  appDataProvider.refreshAllData();
                }
              });
            }
          });
          return Scaffold(
            backgroundColor: const Color(0xFF006699),
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF006699), Color(0xFF004466)],
                ),
              ),
              child: Stack(
                children: [
                  // Interface de base (optionnel - structure vide)
                  Scaffold(
                    backgroundColor: Colors.transparent,
                    appBar: AppBar(
                      backgroundColor: const Color(0xFF006699),
                      elevation: 0,
                      title: Row(
                        children: [
                          Image.asset(
                            'assets/wortisapp.png',
                            height: 50,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text(
                                    'W',
                                    style: TextStyle(
                                      color: Color(0xFF006699),
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(40),
                        ),
                      ),
                    ),
                    body: const SizedBox.shrink(),
                  ),

                  // Overlay de chargement
                  LoadingOverlay(
                    mainText: 'Chargement des données',
                    subText: 'Préparation de votre espace personnel',
                    isVisible: true,
                  ),

                  // Pop-up de timeout
                  if (_showTimeoutPopup)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wifi_off,
                                color: Colors.orange,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Problème de connexion',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Vérifiez votre connexion internet et réessayez',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showTimeoutPopup = false;
                                  });
                                  _loadingTimeoutTimer?.cancel();
                                  _loadingTimeoutTimer = null;
                                  // Forcer le rechargement des données
                                  appDataProvider.refreshAllData();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF006699),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Réessayer',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
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
          );
        }

        // NOUVEAU: Afficher les erreurs s'il y en a
        if (appDataProvider.error.isNotEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF006699),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur: ${appDataProvider.error}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Forcer le rechargement
                      appDataProvider.refreshAllData();
                    },
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        return WillPopScope(
          onWillPop: () async {
            // ✅ CORRECTION: Empêcher le retour pendant le changement de pays
            if (_showCountryChangeOverlay) return false;

            if (_showAllServices) {
              setState(() => _showAllServices = false);
              return false;
            }
            if (_isSearching) {
              setState(() => _isSearching = false);
              return false;
            }
            return true;
          },
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: _buildAnimatedAppBar(appDataProvider),
            body: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // Banner animé
                          SlideTransition(
                            position: _bannerSlideAnimation,
                            child: FadeTransition(
                              opacity: _bannerFadeAnimation,
                              child: _buildBannerSlider(appDataProvider),
                            ),
                          ),

                          // Secteurs d'activité animés
                          ScaleTransition(
                            scale: _sectorsScaleAnimation,
                            child: _buildActivitySectors(appDataProvider),
                          ),

                          // Solde du compte animé
                          AnimatedBuilder(
                            animation: _balanceSlideAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _balanceSlideAnimation.value),
                                child: child,
                              );
                            },
                            child: buildMilesWidget(context),
                          ),

                          // Services animés
                          FadeTransition(
                            opacity: _servicesFadeAnimation,
                            child: _buildServices(appDataProvider, cardWidth),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  if (_showAllServices)
                    Positioned.fill(
                      child: _buildFullscreenServices(appDataProvider),
                    ),
                  if (_isSearching && _searchController.text.isNotEmpty)
                    Positioned.fill(
                      child: _buildAnimatedSearchOverlay(appDataProvider),
                    ),

                  // ✅ NOUVEAU: OVERLAY DE CHANGEMENT DE PAYS
                  if (_showCountryChangeOverlay)
                    Positioned.fill(child: _buildCountryChangeOverlay()),
                ],
              ),
            ),
            bottomNavigationBar: SlideTransition(
              position: _bottomNavSlideAnimation,
              child: _buildBottomNavigationBar(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildServices(AppDataProvider appDataProvider, double cardWidth) {
    if (appDataProvider.isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (appDataProvider.services.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _onServicesPressed(context),
                  label: const Text(
                    'Voir',
                    style: TextStyle(color: Color(0xFF006699)),
                  ),
                  icon: const Icon(Icons.add, color: Color(0xFF006699)),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 48),
                    SizedBox(height: 8),
                    Text(
                      "Aucun service disponible",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Si aucun service n'est sélectionné, essayer d'en sélectionner maintenant
    if (_selectedServices.isEmpty) {
      // CORRECTION: Ne pas appeler setState dans build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectRandomServices();
      });
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _onServicesPressed(context),
                label: const Text(
                  'Voir',
                  style: TextStyle(color: Color(0xFF006699)),
                ),
                icon: const Icon(Icons.add, color: Color(0xFF006699)),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 360;
              final screenWidth = MediaQuery.of(context).size.width;
              final itemWidth = screenWidth / (isSmallScreen ? 4.5 : 4.2);
              final iconSize = itemWidth * 0.25;
              final fontSize = itemWidth * 0.1;

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
                child: _selectedServices.isEmpty
                    ? Center(
                        child: Text(
                          "Chargement des services...",
                          style: TextStyle(
                            fontSize: fontSize * 1.2,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _selectedServices.map((service) {
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 4 : 8,
                              ),
                              child: SizedBox(
                                width: itemWidth,
                                child: _buildServiceCard(
                                  iconName: service['icon'],
                                  label: service['name'],
                                  logo: service['logo'],
                                  iconSize: iconSize,
                                  cardWidth: itemWidth,
                                  fontSize: fontSize,
                                  status: service['status'],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required String iconName,
    required String label,
    required double iconSize,
    required double cardWidth,
    required double fontSize,
    bool? status, // status est optionnel avec une valeur par défaut true
    String? logo, // Ajout du paramètre logo
  }) {
    final bool isActive =
        status ?? true; // Valeur par défaut true si status est null
    final bool hasLogo = logo != null && logo.isNotEmpty;
    final cardOpacity = isActive ? 1.0 : 0.5;
    final iconColor = isActive ? const Color(0xFF006699) : Colors.grey;

    return Opacity(
      opacity: cardOpacity,
      child: GestureDetector(
        onTap: isActive
            ? () async {
                print('👆 [HomePage] CLIC DÉTECTÉ sur: $label');
                if (!mounted) return;

                final service =
                    Provider.of<AppDataProvider>(
                      context,
                      listen: false,
                    ).services.firstWhere(
                      (s) => s['name'] == label,
                      orElse: () => {'Type_Service': '', 'link_view': ''},
                    );

                if (!mounted) return;

                // Debug: afficher les données du service
                print('🔍 [HomePage] Service: $label');
                print(
                  '🔍 [HomePage] Type_Service: "${service['Type_Service']}"',
                );
                print('🔍 [HomePage] Service complet: $service');

                try {
                  final String typeService = (service['Type_Service'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();

                  if (typeService == "webview") {
                    print('➡️ [HomePage] Navigation vers WebView');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ServiceWebView(url: service['link_view'] ?? ''),
                      ),
                    );
                  } else if (typeService == "catalog") {
                    print('➡️ [HomePage] Navigation vers CatalogService');
                    await SessionManager.checkSessionAndNavigate(
                      context: context,
                      authenticatedRoute: ServicePageTransition(
                        page: CatalogService(serviceName: label),
                      ),
                      unauthenticatedRoute: const AuthentificationPage(),
                    );
                  } else if (typeService == "reservationservice") {
                    print('➡️ [HomePage] Navigation vers ReservationService');
                    await SessionManager.checkSessionAndNavigate(
                      context: context,
                      authenticatedRoute: ServicePageTransition(
                        page: ReservationService(serviceName: label),
                      ),
                      unauthenticatedRoute: const AuthentificationPage(),
                    );
                  } else {
                    print(
                      '➡️ [HomePage] Navigation vers FormService (default)',
                    );
                    await SessionManager.checkSessionAndNavigate(
                      context: context,
                      authenticatedRoute: ServicePageTransition(
                        page: FormService(serviceName: label),
                      ),
                      unauthenticatedRoute: const AuthentificationPage(),
                    );
                  }
                } catch (e) {
                  print('❌ [HomePage] Erreur navigation: $e');
                }
              }
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: iconSize * 1.5,
                height: iconSize * 1.5,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF006699).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: hasLogo
                      ? Image.network(
                          Uri.encodeFull(logo),
                          width: iconSize,
                          height: iconSize,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;

                            // Animation de pulsation subtile pendant le chargement
                            return TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.6, end: 1.0),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeInOut,
                              builder: (context, value, _) {
                                return Opacity(
                                  opacity: 0.7,
                                  child: Icon(
                                    IconUtils.getIconData(iconName),
                                    size:
                                        iconSize *
                                        value, // Effet subtil de pulsation
                                    color: iconColor.withOpacity(value),
                                  ),
                                );
                              },
                              // Répéter l'animation
                              // ignore: unnecessary_null_comparison
                              onEnd: () => loadingProgress != null
                                  ? null
                                  : setState(() {}),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback à l'icône en cas d'erreur
                            return Icon(
                              IconUtils.getIconData(iconName),
                              size: iconSize,
                              color: iconColor,
                            );
                          },
                        )
                      : Icon(
                          IconUtils.getIconData(iconName),
                          size: iconSize,
                          color: iconColor,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: isActive ? null : Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToBannerService(String serviceName) async {
    final appDataProvider = Provider.of<AppDataProvider>(context, listen: false);
    final service = appDataProvider.services.firstWhere(
      (s) => s['name'] == serviceName,
      orElse: () => {'Type_Service': '', 'link_view': ''},
    );

    final String typeService = (service['Type_Service'] ?? '').toString().trim().toLowerCase();

    if (!mounted) return;

    if (typeService == 'webview') {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ServiceWebView(url: service['link_view'] ?? ''),
      ));
    } else if (typeService == 'catalog') {
      await SessionManager.checkSessionAndNavigate(
        context: context,
        authenticatedRoute: ServicePageTransition(page: CatalogService(serviceName: serviceName)),
        unauthenticatedRoute: const AuthentificationPage(),
      );
    } else if (typeService == 'reservationservice') {
      await SessionManager.checkSessionAndNavigate(
        context: context,
        authenticatedRoute: ServicePageTransition(page: ReservationService(serviceName: serviceName)),
        unauthenticatedRoute: const AuthentificationPage(),
      );
    } else {
      await SessionManager.checkSessionAndNavigate(
        context: context,
        authenticatedRoute: ServicePageTransition(page: FormService(serviceName: serviceName)),
        unauthenticatedRoute: const AuthentificationPage(),
      );
    }
  }

  void _preloadSpecificBannerImage(Accueil banner) {
    if (banner.hasLocalImage || _preloadedImageUrls.contains(banner.imageUrl)) {
      return; // Déjà préchargée ou image locale
    }

    precacheImage(NetworkImage(Uri.encodeFull(banner.imageUrl)), context).then((
      _,
    ) {
      if (mounted) {
        setState(() {
          _preloadedImageUrls.add(banner.imageUrl);
        });
      }
    });
  }

  Widget _buildEmptyBannerSlider() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF006699),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Chargement...",
                      style: TextStyle(
                        color: Color(0xFF006699),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildImageWithLoaderIfNeeded(String imageUrl, bool isPreloaded) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fond gris
        Container(color: Colors.grey[200]),

        // Indicateur de chargement (seulement si l'image n'est pas préchargée)
        if (!isPreloaded)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006699)),
            ),
          ),

        // Image
        Image.network(
          Uri.encodeFull(imageUrl),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.error_outline, color: Colors.red, size: 40),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBannerSlider(AppDataProvider appDataProvider) {
    // Vérifier si nous avons des bannières
    if (appDataProvider.banners.isEmpty) {
      return _buildEmptyBannerSlider();
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: PageView.builder(
                controller: _pageController,
                itemCount: appDataProvider.banners.length,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });

                  // Précharger les images de la page suivante et précédente
                  if (page < appDataProvider.banners.length - 1) {
                    _preloadSpecificBannerImage(
                      appDataProvider.banners[page + 1],
                    );
                  }
                  if (page > 0) {
                    _preloadSpecificBannerImage(
                      appDataProvider.banners[page - 1],
                    );
                  }
                },
                itemBuilder: (context, index) {
                  final banner = appDataProvider.banners[index];
                  final isPreloaded =
                      banner.hasLocalImage ||
                      _preloadedImageUrls.contains(banner.imageUrl);

                  return GestureDetector(
                    onTap: banner.serviceName != null && banner.serviceName!.trim().isNotEmpty
                        ? () => _navigateToBannerService(banner.serviceName!.trim())
                        : null,
                    child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Fond de couleur pour l'arrière-plan
                        Container(color: Colors.grey[200]),

                        // Image avec ou sans indicateur de chargement
                        banner.hasLocalImage
                            ? Image.file(
                                File(banner.localImagePath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildImageWithLoaderIfNeeded(
                                    banner.imageUrl,
                                    isPreloaded,
                                  );
                                },
                              )
                            : _buildImageWithLoaderIfNeeded(
                                banner.imageUrl,
                                isPreloaded,
                              ),

                        // Icône tap pulsante (bannières cliquables uniquement)
                        if (banner.serviceName != null && banner.serviceName!.trim().isNotEmpty)
                          const Positioned(
                            top: 10,
                            right: 10,
                            child: _PulsingTapIcon(),
                          ),

                        // Indicateurs de pages en bas
                        Positioned(
                          bottom: 10,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              appDataProvider.banners.length,
                              (i) => Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: i == index ? 16 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: i == index
                                      ? const Color(0xFF006699)
                                      : Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ));
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFullscreenServices(AppDataProvider appDataProvider) {
    final screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount;
    if (screenWidth < 600) {
      crossAxisCount = 3;
    } else if (screenWidth < 900) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 5;
    }

    return ScaleTransition(
      scale: _fullscreenServicesScale,
      child: FadeTransition(
        opacity: _fullscreenServicesOpacity,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tous les services',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          _fullscreenServicesController.reverse().then((_) {
                            setState(() {
                              _showAllServices = false;
                            });
                          });
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(top: 16.0),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16.0,
                        mainAxisSpacing: 16.0,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: appDataProvider.services.length,
                      itemBuilder: (context, index) {
                        final service = appDataProvider.services[index];
                        return _buildServiceGridItem(service);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSearchOverlay(AppDataProvider appDataProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Définir les breakpoints
        final isSmallScreen = constraints.maxWidth < 360;
        final isMediumScreen = constraints.maxWidth < 480;

        // Calculer les dimensions responsives
        final padding = isSmallScreen ? 12.0 : 16.0;
        final fontSize = isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 24.0);
        final iconSize = isSmallScreen ? 20.0 : 24.0;
        final gridSpacing = isSmallScreen
            ? 8.0
            : (isMediumScreen ? 12.0 : 16.0);
        final topPadding = isSmallScreen ? 12.0 : 16.0;

        // Calculer le nombre de colonnes en fonction de la largeur
        int crossAxisCount;
        if (constraints.maxWidth < 300) {
          crossAxisCount = 1; // Très petits écrans
        } else if (constraints.maxWidth < 400) {
          crossAxisCount = 2; // Petits écrans
        } else if (constraints.maxWidth < 600) {
          crossAxisCount = 3; // Écrans moyens
        } else {
          crossAxisCount = 4; // Grands écrans
        }

        return ScaleTransition(
          scale: _searchResultsScale,
          child: FadeTransition(
            opacity: _searchResultsOpacity,
            child: Stack(
              children: [
                // Fond flouté
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: isSmallScreen ? 3 : 5,
                    sigmaY: isSmallScreen ? 3 : 5,
                  ),
                  child: Container(color: Colors.black.withOpacity(0.2)),
                ),
                // Contenu
                Container(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    children: [
                      // En-tête avec bouton de fermeture
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Résultats de la recherche',
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: iconSize,
                            ),
                            padding: EdgeInsets.all(padding / 2),
                            constraints: BoxConstraints(
                              minWidth: iconSize * 1.5,
                              minHeight: iconSize * 1.5,
                            ),
                            onPressed: () {
                              _searchResultsController.reverse().then((_) {
                                setState(() {
                                  _isSearching = false;
                                  _searchController.clear();
                                  _filteredServices.clear();
                                });
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: padding),
                      // Message si aucun résultat
                      if (_filteredServices.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: iconSize * 2,
                                  color: Colors.white70,
                                ),
                                SizedBox(height: padding),
                                Text(
                                  'Aucun résultat trouvé',
                                  style: TextStyle(
                                    fontSize: fontSize * 0.8,
                                    color: Colors.white70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        // Résultats de recherche
                        Expanded(
                          child: GridView.builder(
                            padding: EdgeInsets.only(top: topPadding),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: gridSpacing,
                                  mainAxisSpacing: gridSpacing,
                                  childAspectRatio: isSmallScreen ? 0.75 : 0.85,
                                ),
                            itemCount: _filteredServices.length,
                            itemBuilder: (context, index) {
                              final service = _filteredServices[index];
                              return _buildResponsiveServiceGridItem(
                                service,
                                isSmallScreen,
                                isMediumScreen,
                                constraints.maxWidth,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget auxiliaire pour les éléments de la grille
  Widget _buildResponsiveServiceGridItem(
    Map<String, dynamic> service,
    bool isSmallScreen,
    bool isMediumScreen,
    double screenWidth,
  ) {
    final iconSize =
        screenWidth * (isSmallScreen ? 0.06 : (isMediumScreen ? 0.05 : 0.04));
    final fontSize = isSmallScreen ? 11.0 : (isMediumScreen ? 13.0 : 15.0);
    final padding = isSmallScreen ? 8.0 : 12.0;

    return Card(
      elevation: isSmallScreen ? 2 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
      ),
      child: InkWell(
        onTap: () async {
          if (!mounted) return;

          setState(() {
            _searchController.text = service['name'];
            _filteredServices.clear();
            _isSearching = false;
          });

          if (!mounted) return;

          if (service['Type_Service'] == "WebView") {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ServiceWebView(url: service['link_view'] ?? ''),
              ),
            );
          } else if (service['Type_Service'] == "Catalog") {
            await SessionManager.checkSessionAndNavigate(
              context: context,
              authenticatedRoute: ServicePageTransition(
                page: CatalogService(serviceName: service['name']),
              ),
              unauthenticatedRoute: const AuthentificationPage(),
            );
          } else if (service['Type_Service'] == "ReservationService") {
            await SessionManager.checkSessionAndNavigate(
              context: context,
              authenticatedRoute: ServicePageTransition(
                page: ReservationService(serviceName: service['name']),
              ),
              unauthenticatedRoute: const AuthentificationPage(),
            );
          } else {
            await SessionManager.checkSessionAndNavigate(
              context: context,
              authenticatedRoute: ServicePageTransition(
                page: FormService(serviceName: service['name']),
              ),
              unauthenticatedRoute: const AuthentificationPage(),
            );
          }
        },
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
        child: Container(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: const Color(0xFF006699).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconUtils.getIconData(service['icon']),
                  size: iconSize,
                  color: const Color(0xFF006699),
                ),
              ),
              SizedBox(height: padding / 2),
              Flexible(
                child: Text(
                  service['name'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavBarItem(
                0,
                Icons.list,
                "Services",
                const AllServicesPage(),
              ),
              _buildNavBarItem(
                1,
                Icons.article,
                "Actualités",
                const NewsPage(),
              ),
              _buildNavBarItem(
                2,
                Icons.history,
                "Historique",
                const TransactionHistoryPage(sourcePageType: 'homepage'),
              ),
              _buildNavBarItem(
                3,
                Icons.person,
                "Compte",
                const MonComptePage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData icon, String label, Widget page) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () async {
        setState(() => _selectedIndex = index);

        if (page is! HomePage) {
          Navigator.pushAndRemoveUntil(
            context,
            CustomPageTransition(page: page),
            (route) => route.isFirst,
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3), // Réduit de 10 à 8
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF006699)
                  : const Color(0xFF006699),
              size: 24,
            ),
          ),
          const SizedBox(height: 2), // Réduit de 4 à 2
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF006699)
                  : const Color(0xFF006699),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildNavItem(
    int index,
    IconData icon,
    Widget page, {
    required bool requiresAuth,
  }) {
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedIndex = index;
        });

        if (requiresAuth) {
          // Pour les pages qui ne nécessitent pas d'authentification
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => page),
            (route) => false,
          );
        } else {
          // Pour les pages qui ne nécessitent pas d'authentification
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => page),
            (route) => false,
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, color: const Color(0xFF006699), size: 24)],
      ),
    );
  }

  void _onServicesPressed(BuildContext context) {
    setState(() {
      _showAllServices = true;
    });
    _fullscreenServicesController.forward();
  }

  PreferredSizeWidget _buildAnimatedAppBar(AppDataProvider appDataProvider) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: AnimatedBuilder(
        animation: _bannerAnimationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -80 * (1 - _bannerAnimationController.value)),
            child: _buildAppBar(appDataProvider),
          );
        },
      ),
    );
  }

  Timer? _debounce;
  @override
  void dispose() {
    _debugTimer?.cancel();
    // Arrêter toutes les animations avant de disposer les contrôleurs
    _bannerAnimationController.stop();
    _sectorsAnimationController.stop();
    _balanceAnimationController.stop();
    _servicesAnimationController.stop();
    _searchAnimationController.stop();
    _bottomNavAnimationController.stop();
    _fullscreenServicesController.stop();
    _searchResultsController.stop();

    _timer.cancel();
    _pageController.dispose();
    _searchController.dispose();
    _bannerAnimationController.dispose();
    _sectorsAnimationController.dispose();
    _balanceAnimationController.dispose();
    _servicesAnimationController.dispose();
    _searchAnimationController.dispose();
    _bottomNavAnimationController.dispose();
    _fullscreenServicesController.dispose();
    _searchResultsController.dispose();
    _debounce?.cancel();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _loadingTimeoutTimer?.cancel();
    super.dispose();
  }

  Widget _buildSearchResults(AppDataProvider appDataProvider) {
    if (!mounted || _searchResultsController.isDismissed) {
      return Container(); // Ou retourner un widget de remplacement approprié
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Résultats de la recherche',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
              ),
              itemCount: _filteredServices.length,
              itemBuilder: (context, index) {
                final service = _filteredServices[index];
                return GestureDetector(
                  onTap: () async {
                    if (!mounted) return; // Vérification supplémentaire

                    setState(() {
                      _searchController.text = service['name'];
                      _filteredServices.clear();
                      _isSearching = false;
                    });

                    if (!mounted) return;

                    if (service['Type_Service'] == "WebView") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ServiceWebView(url: service['link_view'] ?? ''),
                        ),
                      );
                    } else if (service['Type_Service'] == "Catalog") {
                      await SessionManager.checkSessionAndNavigate(
                        context: context,
                        authenticatedRoute: ServicePageTransition(
                          page: CatalogService(serviceName: service['name']),
                        ),
                        unauthenticatedRoute: const AuthentificationPage(),
                      );
                    } else if (service['Type_Service'] ==
                        "ReservationService") {
                      await SessionManager.checkSessionAndNavigate(
                        context: context,
                        authenticatedRoute: ServicePageTransition(
                          page: ReservationService(
                            serviceName: service['name'],
                          ),
                        ),
                        unauthenticatedRoute: const AuthentificationPage(),
                      );
                    } else {
                      await SessionManager.checkSessionAndNavigate(
                        context: context,
                        authenticatedRoute: ServicePageTransition(
                          page: FormService(serviceName: service['name']),
                        ),
                        unauthenticatedRoute: const AuthentificationPage(),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      gradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFFF8F9FA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF006699).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            IconUtils.getIconData(service['icon']),
                            size: 28,
                            color: const Color(0xFF006699),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            service['name'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF333333),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySectors(AppDataProvider appDataProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double screenWidth = MediaQuery.of(context).size.width;
                int crossAxisCount = 4;
                double spacing = screenWidth > 600 ? 16 : 8;
                double padding = screenWidth > 600 ? 16 : 8;
                double iconSize = screenWidth > 600 ? 30 : 24;
                double fontSize = screenWidth > 600 ? 12 : 10;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.all(padding),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  itemCount: appDataProvider.secteurs.length,
                  itemBuilder: (context, index) {
                    return _buildSectorItem(
                      appDataProvider.secteurs[index],
                      iconSize,
                      fontSize,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSectorModal(BuildContext context, String name, String icon) {
    final appDataProvider = Provider.of<AppDataProvider>(
      context,
      listen: false,
    );
    final sectorServices = appDataProvider.services
        .where(
          (service) =>
              (service as Map<String, dynamic>)['SecteurActivite'] == name,
        )
        .map((service) => service as Map<String, dynamic>)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: const Duration(milliseconds: 800),
      ),
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF006699).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            IconUtils.getIconData(icon),
                            size: 24,
                            color: const Color(0xFF006699),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sectorServices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun service disponible\npour ce secteur',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: sectorServices.length,
                        itemBuilder: (context, index) {
                          return _buildServiceGridItem(sectorServices[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceGridItem(Map<String, dynamic> service) {
    final bool isActive = service['status'] ?? true;
    final bool hasLogo =
        service['logo'] != null && service['logo'].toString().isNotEmpty;

    return GestureDetector(
      onTap: isActive
          ? () async {
              if (_showAllServices) {
                setState(() => _showAllServices = false);
              }

              if (service['Type_Service'] == "WebView") {
                if (mounted && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ServiceWebView(url: service['link_view'] ?? ''),
                    ),
                  );
                }
              } else if (service['Type_Service'] == "Catalog") {
                if (mounted && context.mounted) {
                  await SessionManager.checkSessionAndNavigate(
                    context: context,
                    authenticatedRoute: ServicePageTransition(
                      page: CatalogService(serviceName: service['name']),
                    ),
                    unauthenticatedRoute: const AuthentificationPage(),
                  );
                }
              } else if (service['Type_Service'] == "ReservationService") {
                if (mounted && context.mounted) {
                  await SessionManager.checkSessionAndNavigate(
                    context: context,
                    authenticatedRoute: ServicePageTransition(
                      page: ReservationService(serviceName: service['name']),
                    ),
                    unauthenticatedRoute: const AuthentificationPage(),
                  );
                }
              } else {
                if (mounted && context.mounted) {
                  await SessionManager.checkSessionAndNavigate(
                    context: context,
                    authenticatedRoute: ServicePageTransition(
                      page: FormService(serviceName: service['name']),
                    ),
                    unauthenticatedRoute: const AuthentificationPage(),
                  );
                }
              }
            }
          : null,
      child: Opacity(
        opacity: isActive ? 1.0 : 0.5,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
            gradient: isActive
                ? const LinearGradient(
                    colors: [Colors.white, Color(0xFFF8F9FA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Utiliser un Container avec une taille fixe pour assurer une cohérence visuelle
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF006699).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: hasLogo
                    ? Image.network(
                        Uri.encodeFull(service['logo']),
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;

                          // Utiliser une animation de pulsation subtile pendant le chargement
                          return TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.6, end: 1.0),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeInOut,
                            builder: (context, value, _) {
                              return Opacity(
                                opacity: 0.7,
                                child: Icon(
                                  IconUtils.getIconData(service['icon']),
                                  size: 28 * value, // Effet subtil de pulsation
                                  color: const Color(
                                    0xFF006699,
                                  ).withOpacity(value),
                                ),
                              );
                            },
                            // Répéter l'animation
                            onEnd: () => loadingProgress != null
                                ? null
                                : setState(() {}),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback à l'icône en cas d'erreur de chargement du logo
                          return Icon(
                            IconUtils.getIconData(service['icon']),
                            size: 28,
                            color: isActive
                                ? const Color(0xFF006699)
                                : Colors.grey,
                          );
                        },
                      )
                    : Icon(
                        IconUtils.getIconData(service['icon']),
                        size: 28,
                        color: isActive ? const Color(0xFF006699) : Colors.grey,
                      ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  service['name'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isActive ? const Color(0xFF333333) : Colors.grey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(AppDataProvider appDataProvider) {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: 'Rechercher un service...',
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.search, color: Color(0xFF006699)),
        // Condition pour afficher le suffixIcon
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Color(0xFF006699)),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _filteredServices.clear();
                  });
                },
              )
            : null,
      ),
      onChanged: (value) {
        setState(() {
          if (value.isEmpty) {
            _filteredServices.clear();
            _searchResultsController.reverse();
          } else {
            if (value.length == 1) {
              _filteredServices = appDataProvider.services
                  .map((service) => service as Map<String, dynamic>)
                  .where((service) => service['status'] ?? true)
                  .toList();
              _searchResultsController.forward();
            } else {
              _filteredServices = appDataProvider.services
                  .map((service) => service as Map<String, dynamic>)
                  .where((service) {
                    final serviceName = service['name']
                        .toString()
                        .toLowerCase();
                    final isActive = service['status'] ?? true;
                    return serviceName.contains(value.toLowerCase()) &&
                        isActive;
                  })
                  .toList();
            }
          }
        });
      },
    );
  }

  PreferredSizeWidget _buildAppBar(AppDataProvider appDataProvider) {
    return AppBar(
      toolbarHeight: 80,
      backgroundColor: const Color(0xFF006699),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isSearching ? 0 : 50,
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _isSearching ? 0.0 : 1.0,
              child: Image.asset('assets/wortisapp.png', height: 50),
            ),
          ),
          if (_isSearching)
            Expanded(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 800),
                offset: Offset(_isSearching ? 0.0 : 1.0, 0.0),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 800),
                  opacity: _isSearching ? 1.0 : 0.0,
                  child: _buildSearchField(appDataProvider),
                ),
              ),
            ),
        ],
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      actions: _buildAppBarActions(),
    );
  }

  // les incones en haut sur la page d'accueil
  List<Widget> _buildAppBarActions() {
    return _isTokenPresent
        ? [
            // Icône de recherche (existante)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {
                setState(() => _isSearching = !_isSearching);
              },
            ),

            // Icône de notifications (existante)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationPage(),
                      ),
                    );
                  },
                ),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$_unreadNotificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),

            // ========== LOGO PAYS  ==========
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: _showCountrySwitcherModal,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '🇨🇬', // Drapeau Congo par défaut pour HomePage
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ),
            ),
          ]
        : [
            // Actions non connecté (existantes)
          ];
  }

  void _showCountryChangeError(String error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Erreur: $error',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showCountryChangeSuccess(String newCountry) {
    if (!mounted) return;

    final selectedCountryData = _availableCountries.firstWhere(
      (country) => country["name"] == newCountry,
      orElse: () => {},
    );

    final flag = selectedCountryData["flag"] ?? "🌍";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$newCountry sélectionné avec succès',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showCountrySwitcherModal() async {
    // Récupérer les pays disponibles depuis le DataProvider
    final appDataProvider = Provider.of<AppDataProvider>(
      context,
      listen: false,
    );

    _buildAvailableCountriesList(appDataProvider);
    await _prioritizeStoredCountryInList();

    if (_availableCountries.isEmpty) {
      CustomOverlay.showError(context, message: "Aucun pays disponible");
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      transitionAnimationController: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      ),
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, (1 - value) * 400),
            child: Opacity(
              opacity: value,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF006699), Color(0xFF004d7a)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Column(
                  children: [
                    // En-tête
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sélectionnez votre pays',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Handle de drag
                    Container(
                      width: 50,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Liste des pays avec la nouvelle logique
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _availableCountries.length,
                        itemBuilder: (context, index) {
                          final country = _availableCountries[index];
                          final isSelected =
                              country["name"] == _selectedCountry;

                          return _buildAdvancedCountryOption(
                            flag: country["flag"] ?? "🌍",
                            name: country["name"] ?? "Inconnu",
                            dialCode: country["dialCode"] ?? "",
                            countryCode: country["code"] ?? "",
                            isSelected: isSelected,
                            onTap: () {
                              Navigator.pop(context);
                              // ✅ UTILISER LA NOUVELLE LOGIQUE AVANCÉE
                              _handleCountryChange(country["name"]);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdvancedCountryOption({
    required String flag,
    required String name,
    required String dialCode,
    required String countryCode,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // ✅ LOGIQUE AMÉLIORÉE: Vérifier si c'est le Congo ou le pays déjà sélectionné
    final isCurrentHomePage = countryCode.toUpperCase() == 'CG';
    final isCurrentSelection = name == _selectedCountry;
    final isDisabled = isCurrentHomePage || isCurrentSelection;
    final displayAsSelected =
        isCurrentHomePage; // Toujours montrer le Congo comme sélectionné sur HomePage

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // ✅ Désactiver le tap si c'est le pays actuel
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: displayAsSelected
                  ? Colors.white.withOpacity(0.2)
                  : (isDisabled
                        ? Colors.white.withOpacity(0.05) // Style désactivé
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: displayAsSelected
                    ? Colors.white.withOpacity(0.5)
                    : (isDisabled
                          ? Colors.white.withOpacity(0.2) // Bordure désactivée
                          : Colors.white.withOpacity(0.1)),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  flag,
                  style: TextStyle(
                    fontSize: 28,
                    // ✅ Réduire l'opacité si désactivé
                    color: isDisabled ? Colors.white.withOpacity(0.5) : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: isDisabled
                                  ? Colors.white.withOpacity(
                                      0.5,
                                    ) // Texte désactivé
                                  : Colors.white,
                              fontSize: 16,
                              fontWeight: displayAsSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          // ✅ Indicateurs contextuels
                          if (isCurrentHomePage) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Actuel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ] else if (isCurrentSelection) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Sélectionné',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (dialCode.isNotEmpty)
                        Text(
                          dialCode,
                          style: TextStyle(
                            color: isDisabled
                                ? Colors.white.withOpacity(0.3)
                                : Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (displayAsSelected)
                  const Icon(Icons.check_circle, color: Colors.white, size: 20)
                else if (isDisabled)
                  Icon(
                    Icons.location_on,
                    color: Colors.white.withOpacity(0.5),
                    size: 20,
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withOpacity(0.6),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _prioritizeCongoInList() {
    if (_availableCountries.isEmpty) return;

    try {
      // Trouver l'index du Congo dans la liste
      final congoIndex = _availableCountries.indexWhere(
        (country) => country["code"]?.toUpperCase() == 'CG',
      );

      if (congoIndex != -1 && congoIndex != 0) {
        // Extraire le Congo et le mettre en première position
        final congoCountry = _availableCountries.removeAt(congoIndex);
        _availableCountries.insert(0, congoCountry);

        //print('🇨🇬 [HomePage] Congo déplacé en première position de la liste');
      }
    } catch (e) {
      //print('❌ [HomePage] Erreur réorganisation liste: $e');
    }
  }

  // ========== OVERLAY DE CHANGEMENT DE PAYS ==========
  Widget _buildCountryChangeOverlay() {
    if (!_showCountryChangeOverlay) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animation de chargement
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF006699).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF006699),
                    ),
                    strokeWidth: 3,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Titre
              const Text(
                'Changement de pays',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Description
              Text(
                'Mise à jour vers ${_newSelectedCountry ?? "nouveau pays"}...',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Indicateur de progression
              Column(
                children: List.generate(_progressSteps.length, (index) {
                  final isActive = index <= _currentStep;
                  final isCompleted = index < _currentStep;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? Colors.green
                                : (isActive
                                      ? const Color(0xFF006699)
                                      : Colors.grey[300]),
                            shape: BoxShape.circle,
                          ),
                          child: isCompleted
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                )
                              : (isActive
                                    ? Container(
                                        margin: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : null),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _progressSteps[index],
                            style: TextStyle(
                              fontSize: 13,
                              color: isActive
                                  ? const Color(0xFF2D3748)
                                  : Colors.grey[500],
                              fontWeight: isActive
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== NOUVELLE MÉTHODE PRINCIPALE POUR CHANGER DE PAYS ==========
  Future<void> _handleCountryChange(String newCountry) async {
    if (_isCountryChanging) return;

    //print('🌍 [HomePage] Changement de pays: $_selectedCountry → $newCountry');

    // Récupérer le code du pays
    final selectedCountryData = _availableCountries.firstWhere(
      (country) => country["name"] == newCountry,
      orElse: () => {},
    );

    final countryCode = selectedCountryData["code"] as String? ?? '';

    if (countryCode.isEmpty) {
      _showCountryChangeError('Code pays non trouvé pour: $newCountry');
      return;
    }

    // ✅ LOGIQUE AMÉLIORÉE: Vérifier si on essaie de sélectionner le pays actuel
    // Sur HomePage, le Congo est toujours le pays "actuel", donc on vérifie aussi le nom
    if (countryCode.toUpperCase() == 'CG' || newCountry == _selectedCountry) {
      print(
        '🇨🇬 [HomePage] $newCountry déjà sélectionné ou Congo choisi - Aucune action nécessaire',
      );

      // Message de confirmation plus contextuel
      final isAlreadyCongo = countryCode.toUpperCase() == 'CG';
      final message = isAlreadyCongo
          ? 'Vous êtes déjà au Congo'
          : 'Pays déjà sélectionné';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(
                selectedCountryData["flag"] ?? '🌍',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF006699),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // Mettre à jour l'état local pour la cohérence visuelle
      setState(() {
        _selectedCountry = newCountry;
        _selectedFlag = selectedCountryData["flag"] ?? "🌍";
      });

      return; // ✅ ARRÊTER ICI - Aucune autre action
    }

    // ✅ Pour les autres pays, continuer le processus normal
    print(
      '🚀 [HomePage] Démarrage du changement vers: $newCountry ($countryCode)',
    );

    // Démarrer l'overlay de progression
    setState(() {
      _isCountryChanging = true;
      _showCountryChangeOverlay = true;
      _newSelectedCountry = newCountry;
      _currentStep = 0;
    });

    try {
      // Étape 1: Mise à jour via API
      await _updateProgressStep(0, 'Mise à jour du serveur...');
      await _updateUserZoneViaAPI(newCountry, countryCode);

      // Étape 2: Sauvegarde locale
      await _updateProgressStep(1, 'Sauvegarde locale...');
      await ZoneBenefManager.saveZoneBenef(countryCode);

      // Étape 3: Rechargement des données
      await _updateProgressStep(2, 'Rechargement des données...');
      await _reloadPageDataForNewCountry(newCountry);

      // Étape 4: Finalisation
      await _updateProgressStep(3, 'Finalisation...');
      setState(() {
        _selectedCountry = newCountry;
        _selectedFlag = selectedCountryData["flag"] ?? "🌍";
      });

      // Petit délai pour voir la completion
      await Future.delayed(const Duration(milliseconds: 800));

      // Masquer l'overlay
      if (mounted) {
        setState(() {
          _isCountryChanging = false;
          _showCountryChangeOverlay = false;
          _newSelectedCountry = null;
          _currentStep = 0;
        });
      }

      // Attendre que l'overlay disparaisse
      await Future.delayed(const Duration(milliseconds: 500));

      // Redirection vers HomePageDias (puisque ce n'est pas le Congo)
      if (mounted && context.mounted) {
        //print('🌍 Redirection vers HomePageDias (Code: $countryCode)');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                HomePageDias(routeObserver: widget.routeObserver),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      //print('❌ [HomePage] Erreur changement pays: $e');
      _showCountryChangeError(e.toString());

      // Masquer overlay en cas d'erreur
      if (mounted) {
        setState(() {
          _isCountryChanging = false;
          _showCountryChangeOverlay = false;
          _newSelectedCountry = null;
          _currentStep = 0;
        });
      }
    }
  }

  // ========== MÉTHODES DE SUPPORT ==========

  Future<void> _updateProgressStep(int step, String message) async {
    if (mounted) {
      setState(() {
        _currentStep = step;
      });
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }

  Future<void> _updateUserZoneViaAPI(
    String newCountry,
    String countryCode,
  ) async {
    try {
      final token = await SessionManager.getToken();
      if (token == null) throw Exception('Token manquant');

      //print('📡 [HomePage] Appel API update_user_zone');
      //print('🔑 Token: $token');
      //print('🌍 Zone: $newCountry');
      //print('🏷️ Code: $countryCode');

      // ✅ CORRECTION: Utiliser la bonne URL et les bons paramètres
      final response = await http
          .post(
            Uri.parse('$baseUrl/update_user_zone'), // ✅ URL corrigée
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              // ✅ Paramètres corrigés pour correspondre au serveur
              'user_id': token,
              'zone_benef': newCountry,
              'zone_benef_code': countryCode,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print(
        '📡 [HomePage] Réponse API mise à jour zone: ${response.statusCode}',
      );
      //print('📄 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Code'] == 200) {
          //print('✅ [HomePage] Mise à jour serveur réussie');

          // Mettre à jour les infos utilisateur locales
          if (data['user'] != null) {
            await _updateLocalUserInfo(data['user']);
          }
        } else {
          throw Exception(
            data['message'] ?? 'Échec de la mise à jour côté serveur',
          );
        }
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
    } catch (e) {
      //print('❌ Erreur lors de la mise à jour: $e');
      throw Exception('Erreur: ${e.toString()}');
    }
  }

  Future<void> _updateLocalUserInfo(Map<String, dynamic> updatedUser) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingInfosJson = prefs.getString('user_infos');
      Map<String, dynamic> userInfos = {};

      if (existingInfosJson != null) {
        userInfos = jsonDecode(existingInfosJson);
      }

      userInfos.addAll(updatedUser);
      await prefs.setString('user_infos', jsonEncode(userInfos));

      //print('💾 [HomePage] Infos utilisateur mises à jour localement');
    } catch (e) {
      //print('❌ [HomePage] Erreur mise à jour infos locales: $e');
    }
  }

  bool _isReloadingData = false; // ✅ Nouvelle variable
  Timer? _debugTimer;

  // ========== SOLUTION 2: MODIFIER LA MÉTHODE _reloadPageDataForNewCountry ==========
  Future<void> _reloadPageDataForNewCountry(String newCountry) async {
    try {
      //print('🔄 [HomePage] Rechargement des données pour: $newCountry');

      // ✅ CORRECTION: Indiquer qu'on est en train de recharger
      setState(() {
        _isReloadingData = true;
      });

      final appDataProvider = Provider.of<AppDataProvider>(
        context,
        listen: false,
      );

      // ✅ UTILISER refreshAll AU LIEU DE initializeApp pour éviter la modal
      await appDataProvider.refreshAll().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print(
            '⚠️ [HomePage] Timeout DataProvider - continuation avec données partielles',
          );
        },
      );

      // Recharger les miles
      await appDataProvider.refreshMiles().timeout(
        const Duration(seconds: 3),
        onTimeout: () => print('⚠️ [HomePage] Timeout miles'),
      );

      // Mettre à jour l'UI
      if (mounted) {
        setState(() {
          _isReloadingData = false; // ✅ Fin du rechargement
        });

        _buildAvailableCountriesList(appDataProvider);
        _prioritizeCongoInList();
      }

      //print('✅ [HomePage] TOUTES les données rechargées pour: $newCountry');
    } catch (e) {
      //print('❌ [HomePage] Erreur rechargement optimisé: $e');

      // ✅ S'assurer de remettre _isReloadingData à false même en cas d'erreur
      if (mounted) {
        setState(() {
          _isReloadingData = false;
        });
      }

      // En cas d'erreur, au moins essayer le minimum
      try {
        final appDataProvider = Provider.of<AppDataProvider>(
          context,
          listen: false,
        );
        await appDataProvider.refreshAll();
        if (mounted) setState(() {});
      } catch (fallbackError) {
        //print('❌ [HomePage] Erreur fallback: $fallbackError');
      }

      rethrow;
    }
  }

  void _buildAvailableCountriesList(AppDataProvider appDataProvider) {
    final eligibleCountries = appDataProvider.eligibleCountries;
    _availableCountries.clear();

    //print('🔍 [HomePage] Mapping des codes pays avec la liste countries');
    //print('📋 Codes pays éligibles reçus: $eligibleCountries');

    // Mapping avec la liste des pays de class.dart
    for (String countryCode in eligibleCountries) {
      final matchingCountry = countries.firstWhere(
        (country) => country.code.toUpperCase() == countryCode.toUpperCase(),
        orElse: () => const Country(
          name: '',
          code: '',
          dialCode: '',
          flag: '',
          region: '',
        ),
      );

      if (matchingCountry.name.isNotEmpty) {
        _availableCountries.add({
          "name": matchingCountry.name,
          "flag": matchingCountry.flag,
          "dialCode": matchingCountry.dialCode,
          "code": matchingCountry.code,
        });

        print(
          '✅ Pays trouvé: ${matchingCountry.name} (${matchingCountry.code}) ${matchingCountry.flag}',
        );
      } else {
        //print('⚠️ Pays non trouvé pour le code: $countryCode');
      }
    }

    // ========== NOUVELLE LOGIQUE : RESPECTER LA RESTAURATION ==========
    if (!_hasRestoredCountry && _availableCountries.isNotEmpty) {
      // Seulement si aucune restauration n'a eu lieu, utiliser le Congo par défaut
      final congoCountry = _availableCountries.firstWhere(
        (country) => country["code"]?.toUpperCase() == 'CG',
        orElse: () => {
          "name": "Congo",
          "flag": "🇨🇬",
          "dialCode": "+242",
          "code": "CG",
        },
      );

      _selectedCountry = congoCountry["name"];
      _selectedFlag = congoCountry["flag"];
      print(
        '🇨🇬 [HomePage] Congo défini par défaut (pas de restauration): ${congoCountry["name"]} ${congoCountry["flag"]}',
      );
    } else if (_hasRestoredCountry) {
      print(
        '🔒 [HomePage] Pays déjà restauré, conservation des valeurs: $_selectedCountry $_selectedFlag',
      );
    }

    //print('🌍 Pays disponibles: ${_availableCountries.length}');
  }

  Future<void> _prioritizeStoredCountryInList() async {
    try {
      // 1. Récupérer le code pays stocké
      final storedCountryCode = await ZoneBenefManager.getZoneBenef();

      if (storedCountryCode == null ||
          storedCountryCode.isEmpty ||
          _availableCountries.isEmpty) {
        //print('⚠️ [HomePage] Aucun pays stocké ou liste vide');
        return;
      }

      //print('🔍 [HomePage] Code pays stocké: $storedCountryCode');

      // 2. Trouver le pays correspondant dans la liste
      final storedCountryIndex = _availableCountries.indexWhere(
        (country) =>
            country["code"]?.toUpperCase() == storedCountryCode.toUpperCase(),
      );

      if (storedCountryIndex != -1) {
        // 3. Extraire le pays trouvé
        final storedCountry = _availableCountries[storedCountryIndex];

        // 4. Réorganiser la liste : pays stocké en premier
        final reorganizedList = <Map<String, dynamic>>[];

        // Ajouter le pays stocké en premier
        reorganizedList.add(storedCountry);

        // Ajouter tous les autres pays (en excluant celui déjà ajouté)
        for (int i = 0; i < _availableCountries.length; i++) {
          if (i != storedCountryIndex) {
            reorganizedList.add(_availableCountries[i]);
          }
        }

        // 5. Remplacer la liste
        _availableCountries = reorganizedList;

        print(
          '✅ [HomePage] ${storedCountry["name"]} ${storedCountry["flag"]} mis en premier',
        );
      } else {
        //print('⚠️ [HomePage] Pays stocké non trouvé dans la liste éligible');
      }
    } catch (e) {
      //print('❌ [HomePage] Erreur priorité pays stocké: $e');
    }
  }

  Widget _buildSimpleCountryOption({
    required String flag,
    required String name,
    required String dialCode,
    required String countryCode, // On garde le code pour la navigation
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withOpacity(0.4)
                    : Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Drapeau
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8), // Carré arrondi
                  ),
                  child: Center(
                    child: Text(flag, style: const TextStyle(fontSize: 24)),
                  ),
                ),

                const SizedBox(width: 16),

                // Nom du pays
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),

                // Indicatif téléphonique
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    dialCode,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Indicateur
                Icon(
                  isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(isSelected ? 1.0 : 0.6),
                  size: isSelected ? 20 : 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _switchToHomePageDias({String? targetCountry}) async {
    if (!mounted) return;

    try {
      //print('🔄 [HomePage] Basculement vers HomePageDias');

      // Sauvegarder le code pays
      final countryCode = targetCountry ?? 'SN';
      await ZoneBenefManager.saveZoneBenef(countryCode);

      // Mettre à jour le NavigationManager
      NavigationManager.setCurrentHomePage('HomePageDias');

      // Navigation avec animation fluide
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomePageDias(),
            transitionDuration: const Duration(milliseconds: 800),
            reverseTransitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  var slideAnimation =
                      Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );

                  var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
                      .animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeIn,
                        ),
                      );

                  return SlideTransition(
                    position: slideAnimation,
                    child: FadeTransition(opacity: fadeAnimation, child: child),
                  );
                },
          ),
        );
      }

      //print('✅ [HomePage] Basculement vers HomePageDias réussi');
    } catch (e) {
      //print('❌ [HomePage] Erreur basculement: $e');
    }
  }

  Widget _buildQuickCountryOption(String flag, String name, String code) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _switchToHomePageDias(targetCountry: code);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.6),
              size: 12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryOption({
    required String flag,
    required String name,
    required String code,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.4)
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Flag/Icône
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(flag, style: const TextStyle(fontSize: 24)),
              ),
            ),

            const SizedBox(width: 16),

            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      if (code != 'DIASPORA') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Indicateur
            Icon(
              isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(isSelected ? 1.0 : 0.6),
              size: isSelected ? 20 : 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorServiceCard(Map service) {
    final serviceName = service['name'];
    final serviceIcon = service['icon'];

    Future<bool> checkInternetConnection() async {
      final connectivityResult = await (Connectivity().checkConnectivity());
      return connectivityResult != ConnectivityResult.none;
    }

    void showNoInternetDialog() {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Center(
              // Ajout du widget Center
              child: Text(
                'Pas de connexion',
                textAlign: TextAlign.center, // Ajout de l'alignement du texte
              ),
            ),
            content: const Text(
              'Veuillez vérifier votre connexion internet avant de continuer',
              textAlign:
                  TextAlign.center, // Optionnel : centre aussi le contenu
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFF006699)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
            actionsAlignment: MainAxisAlignment.center, // Centre le bouton OK
          );
        },
      );
    }

    // void navigateToForm() {
    //   Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //       builder: (context) => FormService(serviceName: serviceName),
    //     ),
    //   );
    // }

    return GestureDetector(
      onTap: () async {
        try {
          final hasInternet = await checkInternetConnection();

          if (!context.mounted) return;

          if (hasInternet) {
            if (service['Type_Service'] == "WebView") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ServiceWebView(url: service['link_view'] ?? ''),
                ),
              );
            } else if (service['Type_Service'] == "Catalog") {
              await SessionManager.checkSessionAndNavigate(
                context: context,
                authenticatedRoute: ServicePageTransition(
                  page: CatalogService(serviceName: serviceName),
                ),
                unauthenticatedRoute: const AuthentificationPage(),
              );
            } else if (service['Type_Service'] == "ReservationService") {
              await SessionManager.checkSessionAndNavigate(
                context: context,
                authenticatedRoute: ServicePageTransition(
                  page: ReservationService(serviceName: serviceName),
                ),
                unauthenticatedRoute: const AuthentificationPage(),
              );
            } else {
              await SessionManager.checkSessionAndNavigate(
                context: context,
                authenticatedRoute: FormService(serviceName: serviceName),
                unauthenticatedRoute: const AuthentificationPage(),
              );
            }
          } else {
            showNoInternetDialog();
          }
        } catch (e) {}
      },
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              IconUtils.getIconData(serviceIcon),
              size: 50,
              color: const Color(0xFF006699),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                serviceName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorItem(
    SecteurActivite secteur,
    double iconSize,
    double fontSize,
  ) {
    return GestureDetector(
      onTap: () => _showSectorModal(context, secteur.name, secteur.icon),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              IconUtils.getIconData(secteur.icon),
              size: iconSize,
              color: const Color(0xFF006699),
            ),
            const SizedBox(height: 4),
            Text(
              secteur.name,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMilesWidget(BuildContext context) {
    return Consumer<AppDataProvider>(
      builder: (context, provider, child) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF006699), Color(0xFF006699)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mes Mile',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    IconButton(
                      icon: Icon(
                        provider.milesLoading
                            ? Icons.hourglass_empty
                            : Icons.refresh,
                        color: Colors.white70,
                      ),
                      onPressed: provider.milesLoading
                          ? null
                          : () => provider.refreshMiles(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: provider.milesLoading
                      ? Container(
                          key: const ValueKey('loading'),
                          height: 24,
                          alignment: Alignment.centerLeft,
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        )
                      : provider.milesError != null
                      ? Container(
                          key: const ValueKey('error'),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Erreur de chargement',
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : Container(
                          key: ValueKey<int>(provider.miles),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${NumberFormat("#,###", "fr_FR").format(provider.miles).replaceAll(',', ' ')} Mls',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildAccountBalance() {
    return GestureDetector(
      onTap: () {
        if (!_isBalanceVisible && !_isPinLocked) {
          _showPinDialog();
        } else if (_isPinLocked && _lockUntil != null) {
          final remaining = _lockUntil!.difference(DateTime.now());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Trop de tentatives. Réessayez dans ${remaining.inMinutes} minutes',
                textAlign: TextAlign.center,
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF006699), Color(0xFF0088cc)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF006699).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Solde disponible',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_isBalanceVisible) {
                        setState(() {
                          _isBalanceVisible = false;
                        });
                      }
                    },
                    child: Icon(
                      _isBalanceVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _isBalanceVisible
                  ? Text(
                      '${_formatBalance(_balance)} $_currency',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: Colors.white.withOpacity(0.9),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Appuyez pour déverrouiller',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 15),
              const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBalance(int balance) {
    final format = NumberFormat("#,###", "fr_FR");
    return format.format(balance).replaceAll(',', ' ');
  }

  late Future<int> _milesFuture;

  Future<void> _showPinDialog() async {
    if (_isPinLocked) {
      if (_lockUntil != null && DateTime.now().isBefore(_lockUntil!)) {
        final remaining = _lockUntil!.difference(DateTime.now());
        CustomOverlay.showError(
          context,
          message:
              'Trop de tentatives. Réessayez dans ${remaining.inMinutes} minutes',
        );
        return;
      } else {
        setState(() {
          _isPinLocked = false;
          _pinAttempts = 0;
          _lockUntil = null;
        });
      }
    }
    final controllers = List.generate(4, (index) => TextEditingController());
    final focusNodes = List.generate(4, (index) => FocusNode());

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Entrez votre code PIN',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_pinAttempts > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tentatives restantes: ${3 - _pinAttempts}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _pinAttempts >= 2 ? Colors.red : Colors.orange,
                      ),
                    ),
                  ],
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (index) {
                      return SizedBox(
                        width: 50,
                        child: TextField(
                          controller: controllers[index],
                          focusNode: focusNodes[index],
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          obscureText: true,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            letterSpacing: 2,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '*',
                            hintStyle: const TextStyle(
                              fontSize: 24,
                              color: Colors.grey,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF006699),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF006699),
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) async {
                            if (value.isNotEmpty) {
                              if (index < 3) {
                                focusNodes[index + 1].requestFocus();
                              } else {
                                String pin = controllers
                                    .map((c) => c.text)
                                    .join();
                                try {
                                  final token = await SessionManager.getToken();
                                  if (token != null) {
                                    final response = await http.post(
                                      Uri.parse(
                                        'https://api.live.wortis.cg/api/wallet/balance',
                                      ),
                                      headers: {
                                        'Authorization': token,
                                        'Content-Type': 'application/json',
                                      },
                                      body: jsonEncode({"pin": pin}),
                                    );

                                    if (response.statusCode == 200) {
                                      if (!mounted) return;
                                      setState(() {
                                        _pinAttempts = 0;
                                        _isBalanceVisible = true;
                                        final data = jsonDecode(response.body);
                                        _balance = data['balance'];
                                        _currency = data['currency'];
                                      });
                                      Navigator.of(dialogContext).pop();
                                    } else {
                                      if (!mounted) return;
                                      setState(() {
                                        _pinAttempts++;
                                        if (_pinAttempts >= 3) {
                                          _isPinLocked = true;
                                          _lockUntil = DateTime.now().add(
                                            const Duration(minutes: 30),
                                          );
                                          CustomOverlay.showError(
                                            context,
                                            message:
                                                'Compte bloqué pendant 30 minutes',
                                          );
                                          Navigator.of(dialogContext).pop();
                                        } else {
                                          CustomOverlay.showError(
                                            context,
                                            message:
                                                'Code PIN incorrect (${3 - _pinAttempts} tentatives restantes)',
                                          );
                                          for (var controller in controllers) {
                                            controller.clear();
                                          }
                                          focusNodes[0].requestFocus();
                                        }
                                      });
                                    }
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  CustomOverlay.showError(
                                    context,
                                    message: 'Erreur de connexion',
                                  );
                                }
                              }
                            }
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text(
                    'Annuler',
                    style: TextStyle(color: Color(0xFF006699)),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
          );
        },
      );
    } finally {
      for (final controller in controllers) {
        controller.dispose();
      }
      for (final node in focusNodes) {
        node.dispose();
      }
    }
  }
}

class _PulsingTapIcon extends StatefulWidget {
  const _PulsingTapIcon();

  @override
  State<_PulsingTapIcon> createState() => _PulsingTapIconState();
}

class _PulsingTapIconState extends State<_PulsingTapIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.touch_app_rounded,
              color: Color(0xFF006699),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}
