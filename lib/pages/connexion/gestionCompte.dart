// ignore_for_file: unused_field, file_names, deprecated_member_use, library_private_types_in_public_api, control_flow_in_finally, unused_element, use_build_context_synchronously

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/pages/connexion/verification_forgot.dart';

// ========== CONFIGURATION ==========
class AppConfig {
  static const primaryColor = Color(0xFF006699);
  static const animationDuration = Duration(milliseconds: 300);

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;

  static final phoneRegex = RegExp(r'^(06|05|04)[0-9]{7}$');
  static final emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  static final passwordUpperCase = RegExp(r'[A-Z]');
  static final passwordLowerCase = RegExp(r'[a-z]');
  static final passwordNumber = RegExp(r'[0-9]');
}

// ========== WIDGET D'INDICATEUR DE GÉOLOCALISATION ==========
class GlobalLocationIndicator extends StatefulWidget {
  final Function(Country)? onLocationUpdate;
  final bool showDetectionStatus;

  const GlobalLocationIndicator({
    super.key,
    this.onLocationUpdate,
    this.showDetectionStatus = true,
  });

  @override
  _GlobalLocationIndicatorState createState() =>
      _GlobalLocationIndicatorState();
}

class _GlobalLocationIndicatorState extends State<GlobalLocationIndicator> {
  LocationResult? _currentResult;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _initializeFromGlobalService();
    });
  }

  void _initializeFromGlobalService() {
    final locationService = LocationService();
    if (locationService.currentLocation != null) {
      _currentResult = locationService.currentLocation;
      if (_currentResult != null && widget.onLocationUpdate != null) {
        widget.onLocationUpdate!(_currentResult!.country);
      }
    } else if (locationService.isDetecting) {
      _monitorGlobalDetection();
    }

    if (mounted) setState(() {});
  }

  void _monitorGlobalDetection() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    final locationService = LocationService();

    // Attendre que la détection se termine
    int attempts = 0;
    while (locationService.isDetecting && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }

    if (mounted && locationService.currentLocation != null) {
      _currentResult = locationService.currentLocation;
      if (_currentResult != null && widget.onLocationUpdate != null) {
        widget.onLocationUpdate!(_currentResult!.country);
      }
      setState(() {});
    }

    _isMonitoring = false;
  }

  void _forceRefresh() async {
    // Cette méthode doit être supprimée ou modifiée car LocationService n'a pas de refreshLocation()
    final locationService = LocationService();

    try {
      // LocationService n'a pas de méthode refreshLocation, donc on initialise à nouveau
      final result = await locationService.initializeLocationOptional();

      if (mounted) {
        setState(() {
          _currentResult = result;
        });

        if (widget.onLocationUpdate != null) {
          widget.onLocationUpdate!(result.country);
        }

        _showRefreshStatus(result);
      }
    } catch (e) {
      print('❌ Erreur refresh géolocalisation: $e');
    }
  }

  void _showRefreshStatus(LocationResult result) {
    if (!mounted || !widget.showDetectionStatus) return;

    String message;
    Color color;

    if (result.isDetected) {
      message = '🌍 ${result.country.flag} ${result.country.name} mis à jour';
      color = Colors.green;
    } else {
      message = '📍 ${result.message ?? "Localisation mise à jour"}';
      color = Colors.orange;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showDetectionStatus) return const SizedBox.shrink();

    if (_currentResult == null) {
      return _buildLoadingIndicator();
    }

    return _buildLocationDisplay();
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[600]!),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Détection en cours...',
            style: TextStyle(
              color: Colors.orange[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDisplay() {
    final result = _currentResult!;

    // ✅ Si détecté -> ne rien afficher
    if (result.isDetected) {
      return const SizedBox.shrink();
    }

    print(result.isDetected);

    Color statusColor = _getStatusColor(result);
    IconData statusIcon = _getStatusIcon(result);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Indicateur principal - CENTRÉ
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${result.country.flag} ${result.country.name}',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Détails si demandés - CENTRÉS
        if (widget.showDetectionStatus) ...[
          const SizedBox(height: 4),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getStatusMessage(result),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _forceRefresh,
                  child: Icon(
                    Icons.refresh,
                    color: Colors.grey[400],
                    size: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _getStatusColor(LocationResult result) {
    if (result.isDetected) return Colors.green;
    if (result.isError) return Colors.red;
    return Colors.orange;
  }

  IconData _getStatusIcon(LocationResult result) {
    if (result.isDetected) return Icons.location_on;
    if (result.isError) return Icons.location_off;
    return Icons.location_searching;
  }

  String _getStatusMessage(LocationResult result) {
    if (result.isDetected) {
      return 'Détecté automatiquement';
    } else if (result.isError) {
      return result.message ?? 'Erreur';
    } else {
      return 'Pays par défaut';
    }
  }
}

// ========== CHAMP DE SÉLECTION DE PAYS OPTIMISÉ ==========
// ========== CHAMP DE SÉLECTION DE PAYS OPTIMISÉ CORRIGÉ ==========
class GlobalCountryPickerField extends StatefulWidget {
  final TextEditingController phoneController;
  final FocusNode phoneFocusNode;
  final Function(Country) onCountrySelected;

  const GlobalCountryPickerField({
    super.key,
    required this.phoneController,
    required this.phoneFocusNode,
    required this.onCountrySelected,
  });

  @override
  _GlobalCountryPickerFieldState createState() =>
      _GlobalCountryPickerFieldState();
}

class _GlobalCountryPickerFieldState extends State<GlobalCountryPickerField> {
  Country _selectedCountry = countries.isNotEmpty
      ? countries[0]
      : const Country(
          name: 'Congo',
          code: 'CG',
          dialCode: '+242',
          flag: '🇨🇬',
          region: "Afrique centrale");

  bool _isInternalChange = false;
  bool _hasInitializedFromGlobal = false;

  // ✅ NOUVEAU: Variable pour stocker la subscription du stream
  StreamSubscription<LocationResult>? _locationSubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });

    // Initialiser depuis le service global
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _initializeFromGlobalLocation();
      _setupLocationStream(); // ✅ NOUVEAU: Écouter les mises à jour
    });

    // Écouter les changements du numéro de téléphone
    widget.phoneController.addListener(_handlePhoneNumberChange);
  }

  // ✅ NOUVELLE MÉTHODE: Écouter le stream de géolocalisation
  void _setupLocationStream() {
    final locationService = LocationService();

    _locationSubscription =
        locationService.locationStream.listen((LocationResult result) {
      if (mounted) {
        print('🔄 [CountryPicker] Mise à jour reçue: ${result.country.name}');
        _updateSelectedCountry(result.country);
      }
    });

    print('📡 [CountryPicker] Stream de géolocalisation configuré');
  }

  void _initializeFromGlobalLocation() {
    if (_hasInitializedFromGlobal) return;

    final locationService = LocationService();

    if (locationService.currentLocation != null) {
      final detectedCountry = locationService.currentLocation!.country;
      print(
          '📱 [CountryPicker] Utilisation pays détecté: ${detectedCountry.name}');

      _updateSelectedCountry(detectedCountry);
      _hasInitializedFromGlobal = true;
    } else if (locationService.isDetecting) {
      // Attendre que la détection se termine
      _waitForGlobalDetection();
    }
  }

  void _waitForGlobalDetection() async {
    final locationService = LocationService();

    int attempts = 0;
    while (locationService.isDetecting && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }

    if (mounted && locationService.currentLocation != null) {
      final detectedCountry = locationService.currentLocation!.country;
      _updateSelectedCountry(detectedCountry);
      _hasInitializedFromGlobal = true;
    }
  }

  void _updateSelectedCountry(Country country) {
    if (country.code == _selectedCountry.code) return;

    print(
        '🔄 [CountryPicker] Mise à jour pays: ${_selectedCountry.name} -> ${country.name}');

    _isInternalChange = true;
    setState(() {
      _selectedCountry = country;
    });

    // Mettre à jour le numéro de téléphone si nécessaire
    _updatePhoneNumberWithCountry(country);

    // Notifier le parent
    widget.onCountrySelected(country);

    _isInternalChange = false;

    print('✅ [CountryPicker] Pays mis à jour avec succès: ${country.name}');
  }

  void _updatePhoneNumberWithCountry(Country country) {
    String currentNumber = widget.phoneController.text;

    if (currentNumber.isNotEmpty && !currentNumber.startsWith('+')) {
      // Si le numéro n'a pas d'indicatif, ajouter celui du pays détecté
      widget.phoneController.text = '${country.dialCode}$currentNumber';
    } else if (currentNumber.startsWith('+')) {
      // Si le numéro a déjà un indicatif, le remplacer
      String localNumber = _extractLocalNumber(currentNumber);
      widget.phoneController.text = '${country.dialCode}$localNumber';
    }
  }

  String _extractLocalNumber(String fullNumber) {
    for (var country in countries) {
      if (fullNumber.startsWith(country.dialCode)) {
        return fullNumber.substring(country.dialCode.length);
      }
    }
    return fullNumber;
  }

  void _handlePhoneNumberChange() {
    if (_isInternalChange) return;

    String fullNumber = widget.phoneController.text;

    if (fullNumber.startsWith('+') && countries.isNotEmpty) {
      // Trouver le pays correspondant à l'indicatif
      Country? matchingCountry;
      String longestMatch = '';

      for (var country in countries) {
        String dialCode = country.dialCode;
        if (fullNumber.startsWith(dialCode) &&
            dialCode.length > longestMatch.length) {
          matchingCountry = country;
          longestMatch = dialCode;
        }
      }

      if (matchingCountry != null && matchingCountry != _selectedCountry) {
        _updateSelectedCountry(matchingCountry);
      }
    }
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppConfig.primaryColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(0.9),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sélectionnez un pays',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
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
            Expanded(
              child: countries.isNotEmpty
                  ? ListView.builder(
                      itemCount: countries.length,
                      itemBuilder: (context, index) {
                        final country = countries[index];
                        final isSelected =
                            country.code == _selectedCountry.code;

                        return Container(
                          color:
                              isSelected ? Colors.white.withOpacity(0.1) : null,
                          child: ListTile(
                            leading: Text(
                              country.flag,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(
                              country.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  country.dialCode,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check, color: Colors.white),
                                ],
                              ],
                            ),
                            onTap: () {
                              _updateSelectedCountry(country);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text(
                        'Aucun pays disponible',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100000),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Row(
        children: [
          // ✅ CORRIGÉ: Bouton de sélection du pays avec mise à jour automatique
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(100000)),
              onTap: _showCountryPicker,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      _selectedCountry
                          .flag, // ✅ Se met à jour automatiquement grâce au setState()
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedCountry
                          .dialCode, // ✅ Se met à jour automatiquement grâce au setState()
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.white),
                    Container(
                      height: 24,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Champ numéro de téléphone
          Expanded(
            child: TextFormField(
              controller: widget.phoneController,
              focusNode: widget.phoneFocusNode,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Numéro Whatsapp',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // ✅ NOUVEAU: Nettoyer la subscription du stream
    _locationSubscription?.cancel();
    widget.phoneController.removeListener(_handlePhoneNumberChange);
    super.dispose();
  }
}

// ========== MIXIN KEYBOARD AWARE ==========
mixin KeyboardAwareState<T extends StatefulWidget> on State<T> {
  late ScrollController scrollController;
  bool isKeyboardVisible = false;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });
    super.initState();
    scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupKeyboardListener();
    });
  }

  void _setupKeyboardListener() {
    if (!mounted) return;

    final window = WidgetsBinding.instance.window;
    window.onMetricsChanged = () {
      if (!mounted) return;

      final bottomInset = MediaQuery.of(context).viewInsets.bottom;
      setState(() {
        isKeyboardVisible = bottomInset > 0;
      });
    };
  }

  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: AppConfig.animationDuration,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.window.onMetricsChanged = null;
    super.dispose();
  }
}

// ========== CHAMP DE FORMULAIRE RÉUTILISABLE ==========
class AuthFormField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final VoidCallback? onEditingComplete;
  final Widget? suffixIcon;

  const AuthFormField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onEditingComplete,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onEditingComplete: onEditingComplete,
      enableInteractiveSelection: true,
      cursorColor: Colors.white,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(prefixIcon, color: Colors.white),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100000),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100000),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100000),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
      ),
    );
  }
}

// ========== PAGE D'AUTHENTIFICATION ==========
class AuthentificationPage extends StatefulWidget {
  const AuthentificationPage({super.key});

  @override
  _AuthentificationPageState createState() => _AuthentificationPageState();
}

class _AuthentificationPageState extends State<AuthentificationPage>
    with KeyboardAwareState {
  // Variables de géolocalisation
  Country selectedCountry = countries.isNotEmpty
      ? countries[0]
      : const Country(
          name: 'Congo',
          code: 'CG',
          dialCode: '+242',
          flag: '🇨🇬',
          region: "Afrique centrale");

  LocationResult? _globalLocationResult;

  // Contrôleurs et focus
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });

    // Récupérer la géolocalisation du service global de manière sécurisée
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadGlobalLocationSafe();
    });

    // AJOUT: Forcer rebuild quand clavier change
    _phoneFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _passwordFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _loadGlobalLocationSafe() {
    if (!mounted) return;

    final locationService = LocationService();

    // Écouter le stream de géolocalisation pour les mises à jour automatiques
    locationService.locationStream.listen((LocationResult result) {
      if (mounted) {
        setState(() {
          _globalLocationResult = result;
          selectedCountry = result.country;
        });

        print(
            '📱 [AuthPage] Géolocalisation mise à jour: ${result.country.name}');
        _showLocationMessage(result);
      }
    });

    // Vérifier l'état actuel
    if (locationService.currentLocation != null) {
      final result = locationService.currentLocation!;

      setState(() {
        _globalLocationResult = result;
        selectedCountry = result.country;
      });

      print('📱 [AuthPage] Géolocalisation chargée: ${result.country.name}');
      _showLocationMessage(result);
    } else if (!locationService.isDetecting) {
      // Lancer la détection si pas encore faite
      print('🚀 [AuthPage] Lancement de la géolocalisation...');
      _initializeLocationForAuth();
    }
  }

  // AJOUTER cette méthode pour initialiser la géolocalisation
  void _initializeLocationForAuth() async {
    final locationService = LocationService();

    try {
      final result = await locationService.initializeLocationOptional();

      if (mounted) {
        setState(() {
          _globalLocationResult = result;
          selectedCountry = result.country;
        });

        _showLocationMessage(result);
      }
    } catch (e) {
      print('❌ [AuthPage] Erreur initialisation géolocalisation: $e');
    }
  }

  void _showLocationMessage(LocationResult result) {
    if (!mounted) return;

    String message;
    Color color;

    // if (result.isDetected) {
    //   message = '📍 ${result.country.flag} Indicatif ${result.country.dialCode} détecté automatiquement';
    //   color = Colors.green.withOpacity(0.8);
    // } else {
    if (!result.isDetected) {
      message = 'Géolocalisation impossible';
      color = const Color.fromARGB(255, 255, 40, 40).withOpacity(0.8);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            left: 20,
            right: 20,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Widget _buildForm(BuildContext context, double formWidth) {
    return Column(
      children: [
        // Boutons sociaux compacts
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (Platform.isIOS) ...[
              AppleSignInButton(
                onPressed: _signInWithApple,
                isLoading: _isAppleLoading,
              ),
              const SizedBox(width: 20),
            ],
            GoogleSignInButton(
              onPressed: _signInWithGoogle,
              isLoading: _isGoogleLoading,
            ),
          ],
        ),

        // Séparateur "OU"
        const OrDivider(),

        // Géolocalisation active en arrière-plan (indicateur masqué)
        if (_globalLocationResult != null)
          GlobalLocationIndicator(
            onLocationUpdate: (country) {
              setState(() {
                selectedCountry = country;
              });
            },
            showDetectionStatus: false,
          ),

        // Champ de téléphone avec pays auto-détecté
        GlobalCountryPickerField(
          phoneController: _phoneController,
          phoneFocusNode: _phoneFocusNode,
          onCountrySelected: (Country country) {
            setState(() {
              selectedCountry = country;
            });
          },
        ),
        const SizedBox(height: 16),

        // Champ mot de passe
        AuthFormField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          hintText: 'Entrez votre mot de passe',
          prefixIcon: Icons.lock,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onEditingComplete: () {
            _passwordFocusNode.unfocus();
            _authenticate();
          },
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo(
      bool isKeyboardVisible, double screenWidth, double screenHeight) {
    return AnimatedContainer(
      duration: AppConfig.animationDuration,
      width: isKeyboardVisible ? screenWidth * 0.2 : screenWidth * 0.4,
      height: isKeyboardVisible ? screenHeight * 0.1 : screenHeight * 0.2,
      child: Image.asset(
        'assets/wortisapp.png',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildAuthButton(double width) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _authenticate,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppConfig.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100000),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppConfig.primaryColor),
                ),
              )
            : const Text(
                'Se connecter',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _authenticate() async {
    if (!_validateInput()) return;

    setState(() => _isLoading = true);

    try {
      final authService = AuthService(context);

      // Formatage du numéro avec l'indicatif détecté/sélectionné
      String phoneNumber = _phoneController.text.trim();

      // Si le numéro ne commence pas par +, ajouter l'indicatif du pays
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = selectedCountry.dialCode + phoneNumber;
      }

      print('📞 [AuthPage] Tentative de connexion avec: $phoneNumber');
      print(
          '🌍 Pays utilisé: ${selectedCountry.name} (${selectedCountry.dialCode})');

      if (_globalLocationResult?.isDetected == true) {
        print('✅ Indicatif détecté automatiquement par géolocalisation');
        print(
            '🎯 Redirection attendue vers: ${selectedCountry.name == "Congo" ? "HomePage" : "HomePageDias"}');
      } else {
        print('📍 Indicatif sélectionné manuellement ou par défaut');
      }

      await authService.login(phoneNumber, _passwordController.text);
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateInput() {
    final String phone = _phoneController.text.trim();
    final String password = _passwordController.text;

    if (phone.isEmpty) {
      _showErrorSnackBar('Le numéro de téléphone est requis');
      return false;
    }

    // Validation du numéro selon le pays
    final cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    if (!_isValidPhoneNumber(cleanPhone)) {
      CustomOverlay.showError(context,
          message:
              'Format de numéro de téléphone invalide pour ${selectedCountry.name}');
      return false;
    }

    if (!AppConfig.passwordUpperCase.hasMatch(password)) {
      CustomOverlay.showError(context, message: 'Mot de passe incorrect');

      return false;
    }

    return true;
  }

  bool _isValidPhoneNumber(String phone) {
    // Nettoyer le numéro de téléphone
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    switch (selectedCountry.code) {
      // ========== AFRIQUE CENTRALE ==========
      case 'CG': // Congo-Brazzaville
        return RegExp(r'^(\+?242|0)?[0-9]{8}$').hasMatch(phone);
      case 'CD': // RDC
        return RegExp(r'^(\+?243|0)?[0-9]{9}$').hasMatch(phone);
      case 'CM': // Cameroun
        return RegExp(r'^(\+?237|0)?[0-9]{9}$').hasMatch(phone);
      case 'GA': // Gabon
        return RegExp(r'^(\+?241|0)?[0-9]{8}$').hasMatch(phone);
      case 'TD': // Tchad
        return RegExp(r'^(\+?235|0)?[0-9]{8}$').hasMatch(phone);
      case 'CF': // République centrafricaine
        return RegExp(r'^(\+?236|0)?[0-9]{8}$').hasMatch(phone);
      case 'GQ': // Guinée équatoriale
        return RegExp(r'^(\+?240|0)?[0-9]{8}$').hasMatch(phone);
      case 'ST': // São Tomé-et-Príncipe
        return RegExp(r'^(\+?239|0)?[0-9]{7}$').hasMatch(phone);

      // ========== AFRIQUE DE L'OUEST ==========
      case 'CI': // Côte d'Ivoire
        return RegExp(r'^(\+?225|0)?[0-9]{8}$').hasMatch(phone);
      case 'SN': // Sénégal
        return RegExp(r'^(\+?221|0)?[0-9]{9}$').hasMatch(phone);
      case 'ML': // Mali
        return RegExp(r'^(\+?223|0)?[0-9]{8}$').hasMatch(phone);
      case 'BF': // Burkina Faso
        return RegExp(r'^(\+?226|0)?[0-9]{8}$').hasMatch(phone);
      case 'NE': // Niger
        return RegExp(r'^(\+?227|0)?[0-9]{8}$').hasMatch(phone);
      case 'NG': // Nigeria
        return RegExp(r'^(\+?234|0)?[0-9]{10}$').hasMatch(phone);
      case 'GH': // Ghana
        return RegExp(r'^(\+?233|0)?[0-9]{9}$').hasMatch(phone);
      case 'BJ': // Bénin
        return RegExp(r'^(\+?229|0)?[0-9]{8}$').hasMatch(phone);
      case 'TG': // Togo
        return RegExp(r'^(\+?228|0)?[0-9]{8}$').hasMatch(phone);
      case 'GN': // Guinée
        return RegExp(r'^(\+?224|0)?[0-9]{8}$').hasMatch(phone);
      case 'GW': // Guinée-Bissau
        return RegExp(r'^(\+?245|0)?[0-9]{7}$').hasMatch(phone);
      case 'SL': // Sierra Leone
        return RegExp(r'^(\+?232|0)?[0-9]{8}$').hasMatch(phone);
      case 'LR': // Liberia
        return RegExp(r'^(\+?231|0)?[0-9]{7}$').hasMatch(phone);
      case 'MR': // Mauritanie
        return RegExp(r'^(\+?222|0)?[0-9]{8}$').hasMatch(phone);
      case 'CV': // Cap-Vert
        return RegExp(r'^(\+?238|0)?[0-9]{7}$').hasMatch(phone);
      case 'GM': // Gambie
        return RegExp(r'^(\+?220|0)?[0-9]{7}$').hasMatch(phone);

      // ========== AFRIQUE DU NORD ==========
      case 'MA': // Maroc
        return RegExp(r'^(\+?212|0)?[0-9]{9}$').hasMatch(phone);
      case 'DZ': // Algérie
        return RegExp(r'^(\+?213|0)?[0-9]{9}$').hasMatch(phone);
      case 'TN': // Tunisie
        return RegExp(r'^(\+?216|0)?[0-9]{8}$').hasMatch(phone);
      case 'LY': // Libye
        return RegExp(r'^(\+?218|0)?[0-9]{9}$').hasMatch(phone);
      case 'EG': // Égypte
        return RegExp(r'^(\+?20|0)?[0-9]{10}$').hasMatch(phone);
      case 'SD': // Soudan
        return RegExp(r'^(\+?249|0)?[0-9]{9}$').hasMatch(phone);

      // ========== AFRIQUE DE L'EST ==========
      case 'ET': // Éthiopie
        return RegExp(r'^(\+?251|0)?[0-9]{9}$').hasMatch(phone);
      case 'KE': // Kenya
        return RegExp(r'^(\+?254|0)?[0-9]{9}$').hasMatch(phone);
      case 'TZ': // Tanzanie
        return RegExp(r'^(\+?255|0)?[0-9]{9}$').hasMatch(phone);
      case 'UG': // Ouganda
        return RegExp(r'^(\+?256|0)?[0-9]{9}$').hasMatch(phone);
      case 'RW': // Rwanda
        return RegExp(r'^(\+?250|0)?[0-9]{9}$').hasMatch(phone);
      case 'BI': // Burundi
        return RegExp(r'^(\+?257|0)?[0-9]{8}$').hasMatch(phone);
      case 'DJ': // Djibouti
        return RegExp(r'^(\+?253|0)?[0-9]{8}$').hasMatch(phone);
      case 'ER': // Érythrée
        return RegExp(r'^(\+?291|0)?[0-9]{7}$').hasMatch(phone);
      case 'SO': // Somalie
        return RegExp(r'^(\+?252|0)?[0-9]{8}$').hasMatch(phone);

      // ========== AFRIQUE AUSTRALE ==========
      case 'ZA': // Afrique du Sud
        return RegExp(r'^(\+?27|0)?[0-9]{9}$').hasMatch(phone);
      case 'ZW': // Zimbabwe
        return RegExp(r'^(\+?263|0)?[0-9]{9}$').hasMatch(phone);
      case 'BW': // Botswana
        return RegExp(r'^(\+?267|0)?[0-9]{8}$').hasMatch(phone);
      case 'NA': // Namibie
        return RegExp(r'^(\+?264|0)?[0-9]{8}$').hasMatch(phone);
      case 'ZM': // Zambie
        return RegExp(r'^(\+?260|0)?[0-9]{9}$').hasMatch(phone);
      case 'MW': // Malawi
        return RegExp(r'^(\+?265|0)?[0-9]{8}$').hasMatch(phone);
      case 'MZ': // Mozambique
        return RegExp(r'^(\+?258|0)?[0-9]{9}$').hasMatch(phone);
      case 'MG': // Madagascar
        return RegExp(r'^(\+?261|0)?[0-9]{9}$').hasMatch(phone);
      case 'MU': // Maurice
        return RegExp(r'^(\+?230|0)?[0-9]{8}$').hasMatch(phone);
      case 'SC': // Seychelles
        return RegExp(r'^(\+?248|0)?[0-9]{7}$').hasMatch(phone);
      case 'KM': // Comores
        return RegExp(r'^(\+?269|0)?[0-9]{7}$').hasMatch(phone);
      case 'LS': // Lesotho
        return RegExp(r'^(\+?266|0)?[0-9]{8}$').hasMatch(phone);
      case 'SZ': // Eswatini
        return RegExp(r'^(\+?268|0)?[0-9]{8}$').hasMatch(phone);
      case 'AO': // Angola
        return RegExp(r'^(\+?244|0)?[0-9]{9}$').hasMatch(phone);

      // ========== EUROPE OCCIDENTALE ==========
      case 'FR': // France
        return RegExp(r'^(\+?33|0)?[1-9][0-9]{8}$').hasMatch(phone);
      case 'BE': // Belgique
        return RegExp(r'^(\+?32|0)?[0-9]{9}$').hasMatch(phone);
      case 'DE': // Allemagne
        return RegExp(r'^(\+?49|0)?[0-9]{10,11}$').hasMatch(phone);
      case 'ES': // Espagne
        return RegExp(r'^(\+?34|0)?[0-9]{9}$').hasMatch(phone);
      case 'IT': // Italie
        return RegExp(r'^(\+?39|0)?[0-9]{9,10}$').hasMatch(phone);
      case 'GB': // Royaume-Uni
        return RegExp(r'^(\+?44|0)?[0-9]{10}$').hasMatch(phone);
      case 'CH': // Suisse
        return RegExp(r'^(\+?41|0)?[0-9]{9}$').hasMatch(phone);
      case 'PT': // Portugal
        return RegExp(r'^(\+?351|0)?[0-9]{9}$').hasMatch(phone);
      case 'NL': // Pays-Bas
        return RegExp(r'^(\+?31|0)?[0-9]{9}$').hasMatch(phone);
      case 'AT': // Autriche
        return RegExp(r'^(\+?43|0)?[0-9]{10,11}$').hasMatch(phone);
      case 'IE': // Irlande
        return RegExp(r'^(\+?353|0)?[0-9]{9}$').hasMatch(phone);
      case 'LU': // Luxembourg
        return RegExp(r'^(\+?352|0)?[0-9]{9}$').hasMatch(phone);

      // ========== EUROPE DU NORD ==========
      case 'SE': // Suède
        return RegExp(r'^(\+?46|0)?[0-9]{9}$').hasMatch(phone);
      case 'NO': // Norvège
        return RegExp(r'^(\+?47|0)?[0-9]{8}$').hasMatch(phone);
      case 'DK': // Danemark
        return RegExp(r'^(\+?45|0)?[0-9]{8}$').hasMatch(phone);
      case 'FI': // Finlande
        return RegExp(r'^(\+?358|0)?[0-9]{8,9}$').hasMatch(phone);
      case 'IS': // Islande
        return RegExp(r'^(\+?354|0)?[0-9]{7}$').hasMatch(phone);

      // ========== EUROPE DE L'EST ==========
      case 'RU': // Russie
        return RegExp(r'^(\+?7|8)?[0-9]{10}$').hasMatch(phone);
      case 'PL': // Pologne
        return RegExp(r'^(\+?48|0)?[0-9]{9}$').hasMatch(phone);
      case 'CZ': // République tchèque
        return RegExp(r'^(\+?420|0)?[0-9]{9}$').hasMatch(phone);
      case 'HU': // Hongrie
        return RegExp(r'^(\+?36|0)?[0-9]{9}$').hasMatch(phone);
      case 'SK': // Slovaquie
        return RegExp(r'^(\+?421|0)?[0-9]{9}$').hasMatch(phone);
      case 'RO': // Roumanie
        return RegExp(r'^(\+?40|0)?[0-9]{9}$').hasMatch(phone);
      case 'BG': // Bulgarie
        return RegExp(r'^(\+?359|0)?[0-9]{8,9}$').hasMatch(phone);
      case 'HR': // Croatie
        return RegExp(r'^(\+?385|0)?[0-9]{8,9}$').hasMatch(phone);
      case 'RS': // Serbie
        return RegExp(r'^(\+?381|0)?[0-9]{8,9}$').hasMatch(phone);
      case 'UA': // Ukraine
        return RegExp(r'^(\+?380|0)?[0-9]{9}$').hasMatch(phone);

      // ========== AMÉRIQUES ==========
      case 'US': // États-Unis
      case 'CA': // Canada
        return RegExp(r'^(\+?1)?[2-9][0-9]{2}[2-9][0-9]{2}[0-9]{4}$')
            .hasMatch(phone);
      case 'MX': // Mexique
        return RegExp(r'^(\+?52|0)?[0-9]{10}$').hasMatch(phone);
      case 'BR': // Brésil
        return RegExp(r'^(\+?55|0)?[0-9]{10,11}$').hasMatch(phone);
      case 'AR': // Argentine
        return RegExp(r'^(\+?54|0)?[0-9]{10}$').hasMatch(phone);
      case 'CL': // Chili
        return RegExp(r'^(\+?56|0)?[0-9]{9}$').hasMatch(phone);
      case 'PE': // Pérou
        return RegExp(r'^(\+?51|0)?[0-9]{9}$').hasMatch(phone);
      case 'CO': // Colombie
        return RegExp(r'^(\+?57|0)?[0-9]{10}$').hasMatch(phone);
      case 'VE': // Venezuela
        return RegExp(r'^(\+?58|0)?[0-9]{10}$').hasMatch(phone);
      case 'EC': // Équateur
        return RegExp(r'^(\+?593|0)?[0-9]{9}$').hasMatch(phone);
      case 'BO': // Bolivie
        return RegExp(r'^(\+?591|0)?[0-9]{8}$').hasMatch(phone);
      case 'PY': // Paraguay
        return RegExp(r'^(\+?595|0)?[0-9]{9}$').hasMatch(phone);
      case 'UY': // Uruguay
        return RegExp(r'^(\+?598|0)?[0-9]{8}$').hasMatch(phone);

      // ========== ASIE ==========
      case 'CN': // Chine
        return RegExp(r'^(\+?86|0)?[0-9]{11}$').hasMatch(phone);
      case 'JP': // Japon
        return RegExp(r'^(\+?81|0)?[0-9]{10,11}$').hasMatch(phone);
      case 'KR': // Corée du Sud
        return RegExp(r'^(\+?82|0)?[0-9]{10,11}$').hasMatch(phone);
      case 'IN': // Inde
        return RegExp(r'^(\+?91|0)?[0-9]{10}$').hasMatch(phone);
      case 'TH': // Thaïlande
        return RegExp(r'^(\+?66|0)?[0-9]{9}$').hasMatch(phone);
      case 'VN': // Vietnam
        return RegExp(r'^(\+?84|0)?[0-9]{9,10}$').hasMatch(phone);
      case 'MY': // Malaisie
        return RegExp(r'^(\+?60|0)?[0-9]{9,10}$').hasMatch(phone);
      case 'SG': // Singapour
        return RegExp(r'^(\+?65|0)?[0-9]{8}$').hasMatch(phone);
      case 'ID': // Indonésie
        return RegExp(r'^(\+?62|0)?[0-9]{9,11}$').hasMatch(phone);
      case 'PH': // Philippines
        return RegExp(r'^(\+?63|0)?[0-9]{10}$').hasMatch(phone);

      // ========== MOYEN-ORIENT ==========
      case 'SA': // Arabie saoudite
        return RegExp(r'^(\+?966|0)?[0-9]{9}$').hasMatch(phone);
      case 'AE': // Émirats arabes unis
        return RegExp(r'^(\+?971|0)?[0-9]{9}$').hasMatch(phone);
      case 'QA': // Qatar
        return RegExp(r'^(\+?974|0)?[0-9]{8}$').hasMatch(phone);
      case 'KW': // Koweït
        return RegExp(r'^(\+?965|0)?[0-9]{8}$').hasMatch(phone);
      case 'BH': // Bahreïn
        return RegExp(r'^(\+?973|0)?[0-9]{8}$').hasMatch(phone);
      case 'OM': // Oman
        return RegExp(r'^(\+?968|0)?[0-9]{8}$').hasMatch(phone);
      case 'IL': // Israël
        return RegExp(r'^(\+?972|0)?[0-9]{9}$').hasMatch(phone);
      case 'LB': // Liban
        return RegExp(r'^(\+?961|0)?[0-9]{8}$').hasMatch(phone);
      case 'JO': // Jordanie
        return RegExp(r'^(\+?962|0)?[0-9]{9}$').hasMatch(phone);
      case 'TR': // Turquie
        return RegExp(r'^(\+?90|0)?[0-9]{10}$').hasMatch(phone);

      // ========== OCÉANIE ==========
      case 'AU': // Australie
        return RegExp(r'^(\+?61|0)?[0-9]{9}$').hasMatch(phone);
      case 'NZ': // Nouvelle-Zélande
        return RegExp(r'^(\+?64|0)?[0-9]{8,9}$').hasMatch(phone);
      case 'FJ': // Fidji
        return RegExp(r'^(\+?679|0)?[0-9]{7}$').hasMatch(phone);
      case 'PG': // Papouasie-Nouvelle-Guinée
        return RegExp(r'^(\+?675|0)?[0-9]{8}$').hasMatch(phone);

      // ========== VALIDATION PAR DÉFAUT ==========
      default:
        // Standard ITU-T E.164 : entre 4 et 15 chiffres après le code pays
        final cleanNumber = phone.replaceAll(
            RegExp(r'^\+?${selectedCountry.dialCode.replaceAll(' ', ' ')}'),
            '');
        return cleanNumber.length >= 4 &&
            cleanNumber.length <= 15 &&
            RegExp(r'^[0-9]+$').hasMatch(cleanNumber);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Erreur"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    CustomOverlay.showError(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final formWidth =
        size.width > AppConfig.mobileBreakpoint ? 500.0 : size.width * 0.9;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardOpen = keyboardHeight > 0;

    return Scaffold(
      backgroundColor: AppConfig.primaryColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: size.height - MediaQuery.of(context).padding.top - keyboardHeight,
                  ),
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.05,
                      vertical: isKeyboardOpen ? size.height * 0.01 : size.height * 0.04,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo avec animation de réduction
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: isKeyboardOpen ? 60 : size.height * 0.15,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            scale: isKeyboardOpen ? 0.6 : 1.0,
                            child: Image.asset(
                              'assets/wortisapp.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        // Espacement animé
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: isKeyboardOpen ? 12 : 24,
                        ),

                        // Formulaire avec slide
                        AnimatedSlide(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          offset: isKeyboardOpen ? const Offset(0, -0.1) : Offset.zero,
                          child: SizedBox(
                            width: formWidth,
                            child: _buildForm(context, formWidth),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Bouton de connexion
                        SizedBox(
                          width: formWidth,
                          child: _buildAuthButton(formWidth),
                        ),

                        // Liens additionnels (masqués quand clavier ouvert)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: !isKeyboardOpen
                              ? Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ForgotPasswordPage(),
                                        ),
                                      ),
                                      child: const Text(
                                        'Mot de passe oublié ?',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "N'avez-vous pas un compte ?",
                                          style: TextStyle(color: Colors.grey[300]),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const SignupPage(),
                                            ),
                                          ),
                                          child: const Text(
                                            'Créer un compte',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final authService = AuthService(context);
      await authService.loginWithGoogle();
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isAppleLoading = true);

    try {
      final authService = AuthService(context);
      await authService.loginWithApple();
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isAppleLoading = false);
      }
    }
  }
}

// ========== PAGE D'INSCRIPTION ==========
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with KeyboardAwareState {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _fullNameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  // Variables de géolocalisation
  Country selectedCountry = countries.isNotEmpty
      ? countries.first
      : const Country(
          name: 'Congo',
          code: 'CG',
          dialCode: '+242',
          flag: '🇨🇬',
          region: "Afrique centrale");
  LocationResult? _globalLocationResult;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });

    // AJOUTER : Écouter les changements de géolocalisation
    final locationService = LocationService();
    locationService.locationStream.listen((LocationResult result) {
      if (mounted) {
        setState(() {
          _globalLocationResult = result;
          selectedCountry = result.country;
        });

        print(
            '📝 [InscriptionPage] Géolocalisation mise à jour: ${result.country.name}');
        _showLocationMessage(result);
      }
    });
    // Charger la géolocalisation globale de manière sécurisée
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadGlobalLocationSafe();
    });

    // AJOUT: Forcer rebuild quand clavier change
    _fullNameFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _phoneFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _passwordFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _loadGlobalLocationSafe() {
    if (!mounted) return;

    final locationService = LocationService();

    // CORRECTION: Vérifier d'abord si le service est initialisé
    if (locationService.currentLocation != null) {
      final result = locationService.currentLocation!;

      setState(() {
        _globalLocationResult = result;
        selectedCountry = result.country;
      });

      print('📱 [AuthPage] Géolocalisation chargée: ${result.country.name}');

      // Afficher un message discret de confirmation
      _showLocationMessage(result);
    } else if (locationService.isDetecting) {
      // Attendre que la détection se termine
      print('⏳ [AuthPage] Géolocalisation en cours...');
      _waitForLocationDetection();
    } else {
      // NOUVEAU: Lancer la détection si pas encore faite
      print('🚀 [AuthPage] Lancement de la géolocalisation...');
      _initializeLocationForAuth();
    }
  }

  void _showLocationMessage(LocationResult result) {
    if (!mounted) return;

    String message;
    Color color;

    // if (result.isDetected) {
    //   message = '📍 ${result.country.flag} Indicatif ${result.country.dialCode} détecté automatiquement';
    //   color = Colors.green.withOpacity(0.8);
    // } else {
    if (!result.isDetected) {
      message = 'Echec de la géolocalisation';
      color = Colors.orange.withOpacity(0.8);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            left: 20,
            right: 20,
          ),
        ),
      );
    }
  }

  void _waitForLocationDetection() async {
    final locationService = LocationService();

    int attempts = 0;
    while (locationService.isDetecting && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }

    if (mounted && locationService.currentLocation != null) {
      final result = locationService.currentLocation!;

      setState(() {
        _globalLocationResult = result;
        selectedCountry = result.country;
      });

      print('📱 [AuthPage] Géolocalisation terminée: ${result.country.name}');
      _showLocationMessage(result);
    }
  }

// NOUVELLE MÉTHODE: Initialiser la géolocalisation pour l'auth
  void _initializeLocationForAuth() async {
    try {
      final locationService = LocationService();
      final result = await locationService.initializeLocationOptional();

      if (mounted) {
        setState(() {
          _globalLocationResult = result;
          selectedCountry = result.country;
        });

        print(
            '📱 [AuthPage] Géolocalisation initialisée: ${result.country.name}');
        _showLocationMessage(result);
      }
    } catch (e) {
      print('❌ [AuthPage] Erreur géolocalisation: $e');
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _fullNameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Widget _buildLogo(
      bool isKeyboardVisible, double screenWidth, double screenHeight) {
    return AnimatedContainer(
      duration: AppConfig.animationDuration,
      width: isKeyboardVisible ? screenWidth * 0.15 : screenWidth * 0.3,
      height: isKeyboardVisible ? screenHeight * 0.08 : screenHeight * 0.15,
      child: Image.asset(
        'assets/wortisapp.png',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildHeader(double screenWidth) {
    return AnimatedOpacity(
      duration: AppConfig.animationDuration,
      opacity: isKeyboardVisible ? 0.0 : 1.0,
      child: Column(
        children: [
          Text(
            "Création du compte",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: screenWidth * 0.06,
              color: Colors.white,
            ),
          ),
          Text(
            "Merci de remplir les champs suivants",
            style: TextStyle(
              fontSize: screenWidth * 0.03,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, double formWidth) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Boutons sociaux compacts
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (Platform.isIOS) ...[
                AppleSignInButton(
                  onPressed: _signInWithApple,
                  isLoading: _isAppleLoading,
                ),
                const SizedBox(width: 20),
              ],
              GoogleSignInButton(
                onPressed: _signUpWithGoogle,
                isLoading: _isGoogleLoading,
              ),
            ],
          ),

          // Séparateur "OU"
          const OrDivider(),

          // Champ nom complet
          AuthFormField(
            controller: _fullNameController,
            focusNode: _fullNameFocusNode,
            hintText: 'Entrez votre nom complet',
            prefixIcon: Icons.person,
            textInputAction: TextInputAction.next,
            onEditingComplete: () {
              FocusScope.of(context).requestFocus(_phoneFocusNode);
            },
          ),
          const SizedBox(height: 16),

          // Géolocalisation active en arrière-plan (indicateur masqué)
          if (_globalLocationResult != null)
            GlobalLocationIndicator(
              onLocationUpdate: (country) {
                setState(() {
                  selectedCountry = country;
                });
              },
              showDetectionStatus: false,
            ),

          // Champ téléphone avec pays auto-détecté
          GlobalCountryPickerField(
            phoneController: _phoneController,
            phoneFocusNode: _phoneFocusNode,
            onCountrySelected: (Country country) {
              setState(() {
                selectedCountry = country;
              });
            },
          ),
          const SizedBox(height: 16),

          // Champ mot de passe
          AuthFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            hintText: 'Entrez votre mot de passe',
            prefixIcon: Icons.lock,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onEditingComplete: () {
              _passwordFocusNode.unfocus();
              _continueSignup();
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _continueSignup() async {
    if (!_validateInput()) return;

    setState(() => _isLoading = true);

    try {
      // Préparer le numéro avec l'indicatif
      String phoneWithCode = _phoneController.text.trim();

      // Si le numéro ne commence pas par +, ajouter l'indicatif du pays
      if (!phoneWithCode.startsWith('+')) {
        phoneWithCode = selectedCountry.dialCode + phoneWithCode;
      }

      print('📝 [SignupPage] Inscription avec:');
      print('- Nom: ${_fullNameController.text.trim()}');
      print('- Téléphone: $phoneWithCode');
      print('- Pays: ${selectedCountry.name}');
      print('- Code pays: ${selectedCountry.code}');

      // NOUVEAU: Appeler register avec le countryName
      final authService = AuthService(context);
      await authService.register(
        _fullNameController.text.trim(), // nomEtPrenom
        phoneWithCode, // tel
        _passwordController.text, // password
        countryName: selectedCountry.name, // NOUVEAU: countryName
        // referralCode: null             // optionnel
      );

      // Le succès sera géré dans la méthode register qui redirige vers Welcome
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessMessage() {
    String message = 'Compte créé avec succès!';

    if (_globalLocationResult?.isDetected == true) {
      message += '\n🌍 Localisation détectée: ${selectedCountry.name}';
    } else {
      message += '\n📍 Pays sélectionné: ${selectedCountry.name}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text("Succès", style: TextStyle(color: Colors.green)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Naviguer vers la page de vérification ou connexion
            },
            child: const Text("Continuer"),
          ),
        ],
      ),
    );
  }

  bool _validateInput() {
    String password = _passwordController.text;
    final String phone = _phoneController.text;

    if (_fullNameController.text.trim().isEmpty) {
      _showErrorSnackBar("Le nom complet est requis.");
      return false;
    }

    if (password.length < 8) {
      _showErrorSnackBar(
          "Le mot de passe doit contenir au moins 8 caractères.");
      return false;
    }

    if (!AppConfig.passwordUpperCase.hasMatch(password) ||
        !AppConfig.passwordLowerCase.hasMatch(password) ||
        !AppConfig.passwordNumber.hasMatch(password)) {
      _showErrorSnackBar(
          "Le mot de passe doit contenir au moins une lettre majuscule, une lettre minuscule et un chiffre.");
      return false;
    }

    if (phone.isEmpty) {
      _showErrorSnackBar("Le numéro de téléphone est requis.");
      return false;
    }

    // Validation du numéro selon le pays détecté/sélectionné
    final cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    if (!_isValidPhoneNumber(cleanPhone)) {
      _showErrorSnackBar(
          "Format de numéro de téléphone invalide pour ${selectedCountry.name}");
      return false;
    }

    return true;
  }

  bool _isValidPhoneNumber(String phone) {
    // Utiliser la même logique que dans AuthentificationPage
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    switch (selectedCountry.code) {
      case 'CG':
        return RegExp(r'^(0|242)?[0-9]{9}$').hasMatch(phone);
      case 'CD':
        return RegExp(r'^(0|243)?[0-9]{9}$').hasMatch(phone);
      case 'CM':
        return RegExp(r'^(0|237)?[0-9]{9}$').hasMatch(phone);
      case 'CI':
        return RegExp(r'^(0|225)?[0-9]{8}$').hasMatch(phone);
      case 'GA':
        return RegExp(r'^(0|241)?[0-9]{8}$').hasMatch(phone);
      case 'SN':
        return RegExp(r'^(0|221)?[0-9]{9}$').hasMatch(phone);
      case 'FR':
        return RegExp(r'^(0|\+33|33)?[1-9][0-9]{8}$').hasMatch(phone);
      case 'BE':
        return RegExp(r'^(0|\+32|32)?[0-9]{9}$').hasMatch(phone);
      case 'US':
      case 'CA':
        return RegExp(r'^(\+?1)?[0-9]{10}$').hasMatch(phone);
      default:
        final cleanNumber = phone.replaceAll(
            RegExp(r'^\+?${selectedCountry.dialCode.replaceAll(' ', ' ')}'),
            '');
        return cleanNumber.length >= 8 &&
            cleanNumber.length <= 15 &&
            RegExp(r'^[0-9]+$').hasMatch(cleanNumber);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text("Erreur", style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    CustomOverlay.showError(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final formWidth =
        size.width > AppConfig.mobileBreakpoint ? 500.0 : size.width * 0.9;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardOpen = keyboardHeight > 0;

    return Scaffold(
      backgroundColor: AppConfig.primaryColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: size.height - MediaQuery.of(context).padding.top - keyboardHeight,
                  ),
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.05,
                      vertical: isKeyboardOpen ? size.height * 0.01 : size.height * 0.04,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo avec animation de réduction
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: isKeyboardOpen ? 50 : size.height * 0.12,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            scale: isKeyboardOpen ? 0.5 : 1.0,
                            child: Image.asset(
                              'assets/wortisapp.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        // Espacement animé
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: isKeyboardOpen ? 8 : 16,
                        ),

                        // Header avec animation
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: !isKeyboardOpen
                              ? Column(
                                  children: [
                                    Text(
                                      "Création du compte",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: size.width * 0.06,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Merci de remplir les champs suivants",
                                      style: TextStyle(
                                        fontSize: size.width * 0.03,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),

                        // Formulaire avec animation
                        AnimatedSlide(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          offset: isKeyboardOpen ? const Offset(0, -0.1) : Offset.zero,
                          child: _buildForm(context, formWidth),
                        ),

                        const SizedBox(height: 24),

                        // Bouton Continuer
                        SizedBox(
                          width: formWidth,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _continueSignup,
                            style: ButtonStyle(
                              backgroundColor:
                                  MaterialStateProperty.resolveWith<Color>(
                                      (states) {
                                return states.contains(MaterialState.disabled)
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.white;
                              }),
                              foregroundColor: MaterialStateProperty.all(
                                  AppConfig.primaryColor),
                              padding: MaterialStateProperty.all(
                                const EdgeInsets.symmetric(
                                  vertical: 15,
                                  horizontal: 40,
                                ),
                              ),
                              shape: MaterialStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100000),
                                ),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          AppConfig.primaryColor),
                                    ),
                                  )
                                : const Text(
                                    'Continuer',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        // Lien de connexion (masqué quand clavier ouvert)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: !isKeyboardOpen
                              ? Column(
                                  children: [
                                    const SizedBox(height: 20),
                                    Text(
                                      "Vous avez déjà un compte ?",
                                      style: TextStyle(color: Colors.grey[300]),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AuthentificationPage(),
                                        ),
                                      ),
                                      child: const Text(
                                        'Connectez-vous',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final authService = AuthService(context);
      await authService.loginWithGoogle();
    } catch (e) {
      if (mounted) _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isAppleLoading = true);
    try {
      final authService = AuthService(context);
      await authService.loginWithApple();
    } catch (e) {
      if (mounted) _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }
}

// ========== PAGE MOT DE PASSE OUBLIÉ ==========
class ForgotPasswordPage extends StatefulWidget {
  final bool fromUserAccount;

  const ForgotPasswordPage({super.key, this.fromUserAccount = false});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with KeyboardAwareState {
  // Contrôleurs et focus
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final _passwordResetService = PasswordResetService();
  bool _isLoading = false;

  // NOUVEAU: Variable pour le pays sélectionné (pas de géolocalisation)
  Country selectedCountry = countries.isNotEmpty
      ? countries[0]
      : const Country(
          name: 'Congo',
          code: 'CG',
          dialCode: '+242',
          flag: '🇨🇬',
          region: "Afrique centrale");

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityManager(context).initConnectivity();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> resendCode(String token, String tel) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // MODIFIÉ: Préparer le numéro avec l'indicatif
      String phoneWithCode = tel.trim();

      // Si le numéro ne commence pas par +, ajouter l'indicatif du pays
      if (!phoneWithCode.startsWith('+')) {
        phoneWithCode = selectedCountry.dialCode + phoneWithCode;
      }

      print('📞 [ForgotPassword] Envoi code vers: $phoneWithCode');
      print(
          '🌍 Pays utilisé: ${selectedCountry.name} (${selectedCountry.dialCode})');

      final response = await http.post(
        Uri.parse('https://api.live.wortis.cg/resend_code_apk_wpay_v2_test'),
        body: json.encode({'token': token, 'tel': phoneWithCode}),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        String updatedToken = jsonResponse['token'];

        CustomOverlay.showSuccess(context,
            message: 'Un nouveau code a été envoyé');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationScreen_Forgot(
              data: updatedToken,
              datatel: phoneWithCode,
            ),
          ),
        );
      } else {
        throw Exception(
            'Erreur lors du renvoi du code: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;

      CustomOverlay.showError(context,
          message: 'Erreur lors du renvoi du code: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    CustomOverlay.showError(context, message: message);
  }

  Widget _buildHeader(double titleSize) {
    return AnimatedOpacity(
      duration: AppConfig.animationDuration,
      opacity: isKeyboardVisible ? 0.8 : 1.0,
      child: Text(
        "Réinitialisation du mot de passe",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: titleSize,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // MODIFIÉ: Formulaire avec sélecteur de pays simple
  Widget _buildForm(double formWidth) {
    return GlobalCountryPickerField(
      phoneController: _phoneController,
      phoneFocusNode: _phoneFocusNode,
      onCountrySelected: (Country country) {
        setState(() {
          selectedCountry = country;
        });
      },
    );
  }

  Widget _buildInstructions(double messageSize) {
    return AnimatedOpacity(
      duration: AppConfig.animationDuration,
      opacity: isKeyboardVisible ? 0.8 : 1.0,
      child: Text(
        "Vous allez recevoir un code de vérification sur WhatsApp au numéro spécifié.",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: messageSize,
        ),
      ),
    );
  }

  // MODIFIÉ: Validation avec le pays sélectionné
  bool _validatePhone() {
    final String phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showErrorSnackBar('Le numéro de téléphone est requis');
      return false;
    }

    // Validation du numéro selon le pays sélectionné
    final cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    if (!_isValidPhoneNumber(cleanPhone)) {
      _showErrorSnackBar(
          'Format de numéro de téléphone invalide pour ${selectedCountry.name}');
      return false;
    }

    return true;
  }

  // NOUVEAU: Validation des numéros par pays (version simplifiée)
  bool _isValidPhoneNumber(String phone) {
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    switch (selectedCountry.code) {
      // Afrique centrale
      case 'CG':
        return RegExp(r'^(\+?242|0)?[0-9]{8}$').hasMatch(phone);
      case 'CD':
        return RegExp(r'^(\+?243|0)?[0-9]{9}$').hasMatch(phone);
      case 'CM':
        return RegExp(r'^(\+?237|0)?[0-9]{9}$').hasMatch(phone);
      case 'GA':
        return RegExp(r'^(\+?241|0)?[0-9]{8}$').hasMatch(phone);

      // Afrique de l'ouest
      case 'CI':
        return RegExp(r'^(\+?225|0)?[0-9]{8}$').hasMatch(phone);
      case 'SN':
        return RegExp(r'^(\+?221|0)?[0-9]{9}$').hasMatch(phone);
      case 'ML':
        return RegExp(r'^(\+?223|0)?[0-9]{8}$').hasMatch(phone);
      case 'BF':
        return RegExp(r'^(\+?226|0)?[0-9]{8}$').hasMatch(phone);
      case 'NG':
        return RegExp(r'^(\+?234|0)?[0-9]{10}$').hasMatch(phone);

      // Europe
      case 'FR':
        return RegExp(r'^(\+?33|0)?[1-9][0-9]{8}$').hasMatch(phone);
      case 'BE':
        return RegExp(r'^(\+?32|0)?[0-9]{9}$').hasMatch(phone);
      case 'DE':
        return RegExp(r'^(\+?49|0)?[0-9]{10,11}$').hasMatch(phone);
      case 'ES':
        return RegExp(r'^(\+?34|0)?[0-9]{9}$').hasMatch(phone);
      case 'IT':
        return RegExp(r'^(\+?39|0)?[0-9]{9,10}$').hasMatch(phone);
      case 'GB':
        return RegExp(r'^(\+?44|0)?[0-9]{10}$').hasMatch(phone);
      case 'CH':
        return RegExp(r'^(\+?41|0)?[0-9]{9}$').hasMatch(phone);

      // Amériques
      case 'US':
      case 'CA':
        return RegExp(r'^(\+?1)?[2-9][0-9]{2}[2-9][0-9]{2}[0-9]{4}$')
            .hasMatch(phone);
      case 'BR':
        return RegExp(r'^(\+?55|0)?[0-9]{10,11}$').hasMatch(phone);
      case 'MX':
        return RegExp(r'^(\+?52|0)?[0-9]{10}$').hasMatch(phone);

      // Asie
      case 'CN':
        return RegExp(r'^(\+?86|0)?[0-9]{11}$').hasMatch(phone);
      case 'IN':
        return RegExp(r'^(\+?91|0)?[0-9]{10}$').hasMatch(phone);
      case 'JP':
        return RegExp(r'^(\+?81|0)?[0-9]{10,11}$').hasMatch(phone);

      // Validation par défaut
      default:
        final cleanNumber = phone.replaceAll(
            RegExp(r'^\+?${selectedCountry.dialCode.replaceAll(' ', ' ')}'),
            '');
        return cleanNumber.length >= 4 &&
            cleanNumber.length <= 15 &&
            RegExp(r'^[0-9]+$').hasMatch(cleanNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final formWidth =
        size.width > AppConfig.mobileBreakpoint ? 500.0 : size.width * 0.9;
    final titleSize = isKeyboardVisible ? size.width * 0.04 : size.width * 0.05;
    final messageSize =
        isKeyboardVisible ? size.width * 0.03 : size.width * 0.035;

    return Scaffold(
      backgroundColor: AppConfig.primaryColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.05,
                vertical:
                    isKeyboardVisible ? size.height * 0.02 : size.height * 0.05,
              ),
              constraints: BoxConstraints(
                minHeight: size.height - MediaQuery.of(context).padding.top,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isKeyboardVisible) SizedBox(height: size.height * 0.1),
                  _buildHeader(titleSize),
                  SizedBox(height: size.height * 0.04),

                  // MODIFIÉ: Formulaire simplifié avec juste le sélecteur de pays
                  SizedBox(
                    width: formWidth,
                    child: _buildForm(formWidth),
                  ),
                  SizedBox(height: size.height * 0.02),

                  Container(
                    width: formWidth,
                    margin: EdgeInsets.symmetric(vertical: size.height * 0.02),
                    child: _buildInstructions(messageSize),
                  ),
                  SizedBox(height: size.height * 0.04),

                  if (!isKeyboardVisible || size.height > 500)
                    SizedBox(
                      width: formWidth,
                      child: ElevatedButton(
                        onPressed: () async {
                          // MODIFIÉ: Valider avant d'envoyer
                          if (_validatePhone()) {
                            await resendCode('azerty', _phoneController.text);
                          }
                        },
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color>((states) {
                            return states.contains(WidgetState.disabled)
                                ? Colors.white.withOpacity(0.7)
                                : Colors.white;
                          }),
                          foregroundColor:
                              WidgetStateProperty.all(AppConfig.primaryColor),
                          padding: WidgetStateProperty.all(
                            EdgeInsets.symmetric(
                              vertical: size.height * 0.02,
                              horizontal: size.width * 0.08,
                            ),
                          ),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100000),
                            ),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppConfig.primaryColor),
                                ),
                              )
                            : const Text(
                                'Obtenir le code',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  // N'afficher le lien "Créer un compte" que si on ne vient PAS de "Mon compte"
                  if (!isKeyboardVisible && !widget.fromUserAccount) ...[
                    SizedBox(height: size.height * 0.04),
                    Container(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "N'avez-vous pas un compte ?",
                            style: TextStyle(color: Colors.grey[300]),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupPage(),
                              ),
                            ),
                            child: const Text(
                              'Créer un compte',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
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

// ========== SERVICES ET EXTENSIONS ==========
class PasswordResetService {
  static const String baseUrl = 'https://api.live.wortis.cg';

  Future<Map<String, dynamic>> requestPasswordReset(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/password-reset/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phoneNumber}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Une erreur est survenue');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<bool> verifyResetCode(String phoneNumber, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/password-reset/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phoneNumber,
          'code': code,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Code invalide');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<bool> resetPassword(
      String phoneNumber, String newPassword, String resetToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/password-reset/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phoneNumber,
          'new_password': newPassword,
          'token': resetToken,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Échec de la réinitialisation');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
}

// ========== CLASSE GLOBALOFFLINEGEOCODING (VERSION SIMPLIFIÉE) ==========
class GlobalOfflineGeocoding {
  /// Détection géographique basée sur les coordonnées
  static Country? detectCountryFromCoordinates(
      double latitude, double longitude) {
    try {
      print('🌍 Détection géographique hors ligne: $latitude, $longitude');

      // Zone Congo/RDC (très spécifique)
      if (latitude >= -5.0 &&
          latitude <= -3.5 &&
          longitude >= 14.5 &&
          longitude <= 16.0) {
        print('🇨🇬🇨🇩 Zone Congo/RDC détectée');
        // Brazzaville vs Kinshasa (basé sur la longitude)
        if (longitude < 15.3) {
          print('🇨🇬 Plus proche de Brazzaville (Congo)');
          return countries.firstWhere((c) => c.code == 'CG',
              orElse: () => countries.first);
        } else {
          print('🇨🇩 Plus proche de Kinshasa (RDC)');
          return countries.firstWhere((c) => c.code == 'CD',
              orElse: () => countries.first);
        }
      }

      // Zone France métropolitaine
      if (latitude >= 41.0 &&
          latitude <= 51.1 &&
          longitude >= -5.0 &&
          longitude <= 9.6) {
        print('🇫🇷 Zone France détectée');
        return countries.firstWhere((c) => c.code == 'FR',
            orElse: () => countries.first);
      }

      // Zone États-Unis (étendue pour inclure Alaska et Hawaii)
      if (latitude >= 18.0 &&
          latitude <= 72.0 &&
          longitude >= -180.0 &&
          longitude <= -65.0) {
        print('🇺🇸 Zone États-Unis détectée');
        return countries.firstWhere((c) => c.code == 'US',
            orElse: () => countries.first);
      }

      // Zone Canada
      if (latitude >= 41.0 &&
          latitude <= 84.0 &&
          longitude >= -141.0 &&
          longitude <= -52.0) {
        print('🇨🇦 Zone Canada détectée');
        return countries.firstWhere((c) => c.code == 'CA',
            orElse: () => countries.first);
      }

      // Zone Royaume-Uni
      if (latitude >= 49.5 &&
          latitude <= 61.0 &&
          longitude >= -8.5 &&
          longitude <= 2.0) {
        print('🇬🇧 Zone Royaume-Uni détectée');
        return countries.firstWhere((c) => c.code == 'GB',
            orElse: () => countries.first);
      }

      // Zone Allemagne
      if (latitude >= 47.0 &&
          latitude <= 55.5 &&
          longitude >= 5.5 &&
          longitude <= 15.5) {
        print('🇩🇪 Zone Allemagne détectée');
        return countries.firstWhere((c) => c.code == 'DE',
            orElse: () => countries.first);
      }

      // Zone Espagne
      if (latitude >= 35.0 &&
          latitude <= 44.0 &&
          longitude >= -10.0 &&
          longitude <= 5.0) {
        print('🇪🇸 Zone Espagne détectée');
        return countries.firstWhere((c) => c.code == 'ES',
            orElse: () => countries.first);
      }

      // Zone Italie
      if (latitude >= 36.0 &&
          latitude <= 47.5 &&
          longitude >= 6.0 &&
          longitude <= 19.0) {
        print('🇮🇹 Zone Italie détectée');
        return countries.firstWhere((c) => c.code == 'IT',
            orElse: () => countries.first);
      }

      // Zone Brésil
      if (latitude >= -34.0 &&
          latitude <= 6.0 &&
          longitude >= -74.0 &&
          longitude <= -32.0) {
        print('🇧🇷 Zone Brésil détectée');
        return countries.firstWhere((c) => c.code == 'BR',
            orElse: () => countries.first);
      }

      // Zone Chine
      if (latitude >= 18.0 &&
          latitude <= 54.0 &&
          longitude >= 73.0 &&
          longitude <= 135.0) {
        print('🇨🇳 Zone Chine détectée');
        return countries.firstWhere((c) => c.code == 'CN',
            orElse: () => countries.first);
      }

      // Zone Inde
      if (latitude >= 6.0 &&
          latitude <= 37.0 &&
          longitude >= 68.0 &&
          longitude <= 97.5) {
        print('🇮🇳 Zone Inde détectée');
        return countries.firstWhere((c) => c.code == 'IN',
            orElse: () => countries.first);
      }

      // Zone Australie
      if (latitude >= -44.0 &&
          latitude <= -10.0 &&
          longitude >= 112.0 &&
          longitude <= 154.0) {
        print('🇦🇺 Zone Australie détectée');
        return countries.firstWhere((c) => c.code == 'AU',
            orElse: () => countries.first);
      }

      // Zone Afrique du Sud
      if (latitude >= -35.0 &&
          latitude <= -22.0 &&
          longitude >= 16.0 &&
          longitude <= 33.0) {
        print('🇿🇦 Zone Afrique du Sud détectée');
        return countries.firstWhere((c) => c.code == 'ZA',
            orElse: () => countries.first);
      }

      // Zones d'Afrique centrale élargie
      if (latitude >= -10.0 &&
          latitude <= 15.0 &&
          longitude >= 8.0 &&
          longitude <= 30.0) {
        print('🌍 Zone Afrique centrale détectée');

        // Cameroun
        if (latitude >= 2.0 &&
            latitude <= 13.0 &&
            longitude >= 8.5 &&
            longitude <= 16.5) {
          return countries.firstWhere((c) => c.code == 'CM',
              orElse: () => countries.first);
        }

        // Gabon
        if (latitude >= -4.0 &&
            latitude <= 2.5 &&
            longitude >= 8.5 &&
            longitude <= 15.0) {
          return countries.firstWhere((c) => c.code == 'GA',
              orElse: () => countries.first);
        }

        // République centrafricaine
        if (latitude >= 2.0 &&
            latitude <= 11.0 &&
            longitude >= 14.0 &&
            longitude <= 27.5) {
          return countries.firstWhere((c) => c.code == 'CF',
              orElse: () => countries.first);
        }

        // Tchad
        if (latitude >= 7.0 &&
            latitude <= 23.5 &&
            longitude >= 13.5 &&
            longitude <= 24.0) {
          return countries.firstWhere((c) => c.code == 'TD',
              orElse: () => countries.first);
        }
      }

      print('❌ Aucun pays trouvé pour ces coordonnées');
      return null;
    } catch (e) {
      print('❌ Erreur détection géographique hors ligne: $e');
      return null;
    }
  }
}

// ========== PAGE FINALISATION PROFIL GOOGLE À AJOUTER DANS gestionCompte.dart ==========

class GoogleProfileCompletionPage extends StatefulWidget {
  final String completionToken;
  final Map<String, dynamic> userData;

  const GoogleProfileCompletionPage({
    super.key,
    required this.completionToken,
    required this.userData,
  });

  @override
  _GoogleProfileCompletionPageState createState() =>
      _GoogleProfileCompletionPageState();
}

class _GoogleProfileCompletionPageState
    extends State<GoogleProfileCompletionPage> with KeyboardAwareState {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  bool _isLoading = false;

  // Variables de géolocalisation
  Country selectedCountry = countries.isNotEmpty
      ? countries.first
      : const Country(
          name: 'Congo',
          code: 'CG',
          dialCode: '+242',
          flag: '🇨🇬',
          region: "Afrique centrale");
  LocationResult? _globalLocationResult;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadGlobalLocationSafe();
    });
  }

  void _loadGlobalLocationSafe() {
    if (!mounted) return;

    final locationService = LocationService();

    if (locationService.currentLocation != null) {
      final result = locationService.currentLocation!;

      setState(() {
        _globalLocationResult = result;
        selectedCountry = result.country;
      });

      print(
          '📱 [GoogleProfile] Géolocalisation chargée: ${result.country.name}');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Avatar Google
        if (widget.userData['picture'] != null)
          CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage(widget.userData['picture']),
            backgroundColor: Colors.white.withOpacity(0.2),
          )
        else
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(
              Icons.person,
              size: 40,
              color: Colors.white.withOpacity(0.8),
            ),
          ),

        const SizedBox(height: 16),

        Text(
          'Bienvenue ${widget.userData['nom'] ?? ''}!',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Text(
          'Finalisez votre inscription en ajoutant votre numéro de téléphone',
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        // Email de l'utilisateur Google
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.email, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                widget.userData['email'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        // Géolocalisation active en arrière-plan (indicateur masqué)
        if (_globalLocationResult != null)
          GlobalLocationIndicator(
            onLocationUpdate: (country) {
              setState(() {
                selectedCountry = country;
              });
            },
            showDetectionStatus: false,
          ),

        // Champ de téléphone avec pays auto-détecté
        GlobalCountryPickerField(
          phoneController: _phoneController,
          phoneFocusNode: _phoneFocusNode,
          onCountrySelected: (Country country) {
            setState(() {
              selectedCountry = country;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCompleteButton(double width) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _completeProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppConfig.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100000),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppConfig.primaryColor),
                ),
              )
            : const Text(
                'Finaliser l\'inscription',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _completeProfile() async {
    if (!_validateInput()) return;

    setState(() => _isLoading = true);

    try {
      // Préparer le numéro avec l'indicatif
      String phoneWithCode = _phoneController.text.trim();

      // Si le numéro ne commence pas par +, ajouter l'indicatif du pays
      if (!phoneWithCode.startsWith('+')) {
        phoneWithCode = selectedCountry.dialCode + phoneWithCode;
      }

      print('🔵 [GoogleProfile] Finalisation avec téléphone: $phoneWithCode');

      final authService = AuthService(context);
      await authService.completeGoogleProfile(
          widget.completionToken, phoneWithCode);
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _validateInput() {
    final String phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showErrorSnackBar('Le numéro de téléphone est requis');
      return false;
    }

    // Validation du numéro selon le pays
    final cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    if (!_isValidPhoneNumber(cleanPhone)) {
      CustomOverlay.showError(context,
          message:
              'Format de numéro de téléphone invalide pour ${selectedCountry.name}');
      return false;
    }

    return true;
  }

  bool _isValidPhoneNumber(String phone) {
    // Utiliser la même logique que dans AuthentificationPage
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    switch (selectedCountry.code) {
      case 'CG':
        return RegExp(r'^(\+?242|0)?[0-9]{8}$').hasMatch(phone);
      case 'CD':
        return RegExp(r'^(\+?243|0)?[0-9]{9}$').hasMatch(phone);
      case 'CM':
        return RegExp(r'^(\+?237|0)?[0-9]{9}$').hasMatch(phone);
      case 'CI':
        return RegExp(r'^(\+?225|0)?[0-9]{8}$').hasMatch(phone);
      case 'GA':
        return RegExp(r'^(\+?241|0)?[0-9]{8}$').hasMatch(phone);
      case 'FR':
        return RegExp(r'^(\+?33|0)?[1-9][0-9]{8}$').hasMatch(phone);
      case 'BE':
        return RegExp(r'^(\+?32|0)?[0-9]{9}$').hasMatch(phone);
      case 'US':
      case 'CA':
        return RegExp(r'^(\+?1)?[0-9]{10}$').hasMatch(phone);
      default:
        final cleanNumber = phone.replaceAll(
            RegExp(r'^\+?${selectedCountry.dialCode.replaceAll(' ', ' ')}'),
            '');
        return cleanNumber.length >= 4 &&
            cleanNumber.length <= 15 &&
            RegExp(r'^[0-9]+$').hasMatch(cleanNumber);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text("Erreur", style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    CustomOverlay.showError(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final formWidth =
        size.width > AppConfig.mobileBreakpoint ? 500.0 : size.width * 0.9;

    return Scaffold(
      backgroundColor: AppConfig.primaryColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.05,
                vertical:
                    isKeyboardVisible ? size.height * 0.02 : size.height * 0.05,
              ),
              constraints: BoxConstraints(
                minHeight: size.height - MediaQuery.of(context).padding.top,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header avec photo Google
                  _buildHeader(),
                  const SizedBox(height: 40),

                  // Formulaire
                  SizedBox(
                    width: formWidth,
                    child: _buildForm(),
                  ),
                  const SizedBox(height: 32),

                  // Bouton finaliser
                  _buildCompleteButton(formWidth),

                  const SizedBox(height: 20),

                  // Lien retour
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AuthentificationPage(),
                      ),
                    ),
                    child: const Text(
                      'Retour à la connexion',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
}

// ========== BOUTONS SOCIAUX COMPACTS ==========

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  // text gardé pour compatibilité mais non utilisé
  final String text;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.text = '',
  });

  @override
  Widget build(BuildContext context) {
    return _SocialCircleButton(
      onPressed: onPressed,
      isLoading: isLoading,
      backgroundColor: Colors.white,
      borderColor: Colors.white,
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppConfig.primaryColor),
              ),
            )
          : Image.network(
              'https://developers.google.com/identity/images/g-logo.png',
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) => const Text(
                'G',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4285F4),
                ),
              ),
            ),
    );
  }
}

class AppleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final String text;

  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.text = '',
  });

  @override
  Widget build(BuildContext context) {
    return _SocialCircleButton(
      onPressed: onPressed,
      isLoading: isLoading,
      backgroundColor: Colors.white,
      borderColor: Colors.white,
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
          : const Icon(Icons.apple, size: 28, color: Colors.black),
    );
  }
}

class _SocialCircleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final Color backgroundColor;
  final Color borderColor;
  final Widget child;

  const _SocialCircleButton({
    required this.onPressed,
    required this.isLoading,
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ========== WIDGET SÉPARATEUR "OU" ==========
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'OU',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}
