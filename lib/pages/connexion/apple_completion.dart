// ignore_for_file: use_build_context_synchronously, unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wortis/class/class.dart';
import 'package:wortis/pages/connexion/gestionCompte.dart';

// ========== PAGE DE COMPLÉTION DU PROFIL APPLE ==========
class AppleProfileCompletionPage extends StatefulWidget {
  final String completionToken;
  final Map<String, dynamic> userData;

  const AppleProfileCompletionPage({
    super.key,
    required this.completionToken,
    required this.userData,
  });

  @override
  _AppleProfileCompletionPageState createState() =>
      _AppleProfileCompletionPageState();
}

class _AppleProfileCompletionPageState
    extends State<AppleProfileCompletionPage> with KeyboardAwareState {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _nomController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _prenomFocusNode = FocusNode();
  final FocusNode _nomFocusNode = FocusNode();
  bool _isLoading = false;

  bool get _needsName {
    final nom = (widget.userData['nom'] ?? '').toString().trim();
    return nom.isEmpty;
  }

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

      print('📱 [AppleProfile] Géolocalisation chargée: ${result.country.name}');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _prenomController.dispose();
    _nomController.dispose();
    _phoneFocusNode.dispose();
    _prenomFocusNode.dispose();
    _nomFocusNode.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Icône Apple avec fond
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.apple,
            size: 50,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'Bienvenue ${widget.userData['nom'] ?? widget.userData['given_name'] ?? ''}!',
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

        // Email de l'utilisateur Apple (si disponible)
        if (widget.userData['email'] != null && widget.userData['email'].toString().isNotEmpty)
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
        // ── Champs Prénom / Nom si Apple ne les a pas fournis ──
        if (_needsName) ...[
          TextField(
            controller: _prenomController,
            focusNode: _prenomFocusNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_nomFocusNode),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Prénom',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon:
                  Icon(Icons.person_outline, color: Colors.white.withOpacity(0.7)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withOpacity(0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nomController,
            focusNode: _nomFocusNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_phoneFocusNode),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Nom de famille',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon:
                  Icon(Icons.badge_outlined, color: Colors.white.withOpacity(0.7)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withOpacity(0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

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
      if (!phoneWithCode.startsWith('+')) {
        phoneWithCode = selectedCountry.dialCode + phoneWithCode;
      }

      // Construire le nom complet
      String nom;
      if (_needsName) {
        final prenom = _prenomController.text.trim();
        final nomFamille = _nomController.text.trim();
        nom = '$prenom $nomFamille'.trim();
      } else {
        nom = (widget.userData['nom'] ?? '').toString().trim();
      }

      print('🔵 [AppleProfile] Finalisation — tél: $phoneWithCode, nom: $nom');

      final authService = AuthService(context);
      await authService.completeAppleProfile(
          widget.completionToken, phoneWithCode, nom: nom);
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _validateInput() {
    // Vérifier les champs nom/prénom si nécessaire
    if (_needsName) {
      if (_prenomController.text.trim().isEmpty) {
        _showErrorSnackBar('Le prénom est requis');
        return false;
      }
      if (_nomController.text.trim().isEmpty) {
        _showErrorSnackBar('Le nom de famille est requis');
        return false;
      }
    }

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
                  // Header avec icône Apple
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
