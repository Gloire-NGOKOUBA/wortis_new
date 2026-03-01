// ignore_for_file: unused_local_variable, non_constant_identifier_names, avoid_print, use_build_context_synchronously, duplicate_ignore, unrelated_type_equality_checks, deprecated_member_use, unused_import

import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wortis/main.dart';
import 'package:wortis/pages/connexion/verification.dart';
import 'package:wortis/pages/connexion/gestionCompte.dart';
import 'package:wortis/pages/homepage.dart';
import 'package:wortis/pages/homepage_dias.dart';
import 'package:wortis/pages/notifications.dart';
import 'package:wortis/pages/no_connection_page.dart';
import 'package:wortis/class/dataprovider.dart';
import 'dart:async';
import 'package:wortis/class/class.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wortis/pages/welcome.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:wortis/pages/connexion/apple_completion.dart';

// Configuration globale
const String baseUrl = "https://api.live.wortis.cg";

// Enums
enum PaymentMethod {
  mobileMoney,
  cardPayment,
}

// Modèles de données
class UserRegistration {
  final Map<String, dynamic> _data;

  UserRegistration(this._data);

  factory UserRegistration.fromJson(Map<String, dynamic> json) {
    return UserRegistration(json);
  }

  dynamic operator [](String key) => _data[key];

  Map<String, dynamic> toJson() => _data;

  bool hasField(String fieldName) => _data.containsKey(fieldName);

  dynamic getFieldValue(String fieldName) => _data[fieldName];

  @override
  String toString() => _data.toString();
}

/// ************************ Début du Bloc qui gères les notifications ******************
// Modèle pour les notifications
class NotificationData {
  final String id;
  final String contenu;
  final DateTime dateCreation;
  final String icone;
  String _statut;
  final String link_get_info;
  final String title;
  final String type;
  final String userId;
  bool isExpanded;
  final bool button;
  final bool link_get;

  NotificationData({
    required this.id,
    required this.contenu,
    required this.dateCreation,
    required this.icone,
    required String statut,
    required this.title,
    this.link_get_info = '',
    required this.type,
    required this.userId,
    this.button = false,
    this.link_get = false,
    this.isExpanded = false,
  }) : _statut = statut;

  // ✅ AJOUT: Getter pour statut
  String get statut => _statut;

  // ✅ AJOUT: Setter pour statut
  set statut(String value) {
    _statut = value;
  }

  // ✅ AJOUT: Méthode pour marquer comme lu
  void markAsRead() {
    _statut = "lu";
  }

  // ✅ AJOUT: Méthode pour marquer comme non lu
  void markAsUnread() {
    _statut = "non lu";
  }

  // ✅ AJOUT: Méthode pour définir un statut personnalisé
  void setStatus(String status) {
    _statut = status;
  }

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    // Fonction pour parser la date avec différents formats
    DateTime parseDate(String dateStr) {
      try {
        // Essayer d'abord le format HTTP
        return HttpDate.parse(dateStr);
      } catch (e) {
        try {
          // Essayer le format ISO
          return DateTime.parse(dateStr);
        } catch (e) {
          // Si aucun format ne fonctionne, retourner la date actuelle
          //print('Erreur parsing date: $dateStr');
          return DateTime.now();
        }
      }
    }

    return NotificationData(
        id: json['_id']?.toString() ?? '',
        contenu: json['contenu']?.toString() ?? '',
        dateCreation: json['date_creation'] != null
            ? parseDate(json['date_creation'].toString())
            : DateTime.now(),
        icone: json['icone']?.toString() ?? '',
        statut: json['statut']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        button: json['button'] ?? false,
        link_get_info: json['link_get_info']?.toString() ?? '');
  }

  Null get action => null;

  Null get linkGetInfo => null;

  // Méthode pour créer une copie avec des modifications
  NotificationData copyWith({
    String? id,
    String? contenu,
    DateTime? dateCreation,
    String? icone,
    String? statut,
    String? title,
    String? type,
    String? userId,
    bool? isExpanded,
    bool? button,
    String? link_get_info,
  }) {
    return NotificationData(
      id: id ?? this.id,
      contenu: contenu ?? this.contenu,
      dateCreation: dateCreation ?? this.dateCreation,
      icone: icone ?? this.icone,
      statut: statut ?? _statut,
      title: title ?? this.title,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      isExpanded: isExpanded ?? this.isExpanded,
      button: button ?? this.button,
      link_get_info: link_get_info ?? this.link_get_info,
    );
  }

  // Convertir le type de notification en NotificationType
  NotificationType getNotificationType() {
    switch (type.toLowerCase()) {
      case 'paiement':
        return NotificationType.payment;
      case 'demande de paiement':
        return NotificationType.payment;
      case 'maj':
        return NotificationType.system;
      case 'promotions':
        return NotificationType.promotion;
      case 'kdo':
        return NotificationType.success;
      default:
        return NotificationType.system;
    }
  }

  // Méthode pour obtenir le temps écoulé depuis la création
  String getTimeAgo() {
    final now = DateTime.now();
    final difference =
        now.difference(dateCreation.subtract(const Duration(hours: 1)));

    final minutes = difference.inMinutes;
    final hours = difference.inHours;
    final days = difference.inDays;

    if (minutes < 60) {
      return 'Il y a $minutes minute${minutes > 1 ? 's' : ''}';
    } else if (hours < 24) {
      return 'Il y a $hours heure${hours > 1 ? 's' : ''}';
    } else {
      return 'Il y a $days jour${days > 1 ? 's' : ''}';
    }
  }

  // Convertir en Map pour le JSON
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'contenu': contenu,
      'date_creation': dateCreation.toIso8601String(),
      'icone': icone,
      'statut': _statut,
      'title': title,
      'type': type,
      'user_id': userId,
      'button': button,
      'link_get_info': link_get_info,
      'link_get': link_get,
    };
  }

  @override
  String toString() {
    return 'NotificationData(id: $id, title: $title, type: $type, statut: $_statut)';
  }
}

// Classe contenant les fonctions de bases pour les notifications...
class NotificationService {
  static const String baseUrl = "https://api.live.wortis.cg";

  /* Obtenir toutes les notifications */
  static Future<List<NotificationData>> getNotifications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications_test/$token'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => NotificationData.fromJson(json)).toList();
      } else {
        throw Exception('Erreur lors de la récupération des notifications');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  /* Marquer une notification comme lue */
  static Future<bool> markAsRead(String userId, String notificationId) async {
    try {
      //print('📝 [API] Marquage notification: $notificationId');

      // ✅ URL corrigée selon votre endpoint Python
      final response = await http.post(
        Uri.parse('$baseUrl/lu_notifications_test'), // SANS userId dans l'URL
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id_notification": notificationId}),
      );

      //print('📡 [API] Réponse marquage: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['code'] == 200;
      }
      return false;
    } catch (e) {
      //print('❌ [API] Erreur marquage: $e');
      return false;
    }
  }

  /* Supprimer une notification */
  static Future<bool> deleteNotification(
      String userId, String notificationId) async {
    try {
      //print('🗑️ [API] Suppression notification: $notificationId');

      // ✅ URL corrigée selon votre endpoint Python
      final response = await http.post(
        Uri.parse(
            '$baseUrl/notifications_delete_test'), // SANS userId dans l'URL
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id_notification": notificationId}),
      );

      //print('📡 [API] Réponse suppression: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['code'] == 200;
      }
      return false;
    } catch (e) {
      //print('❌ [API] Erreur suppression: $e');
      return false;
    }
  }

  /* Marquer toutes les notifications comme lues */
  static Future<bool> markAllAsRead(String token) async {
    try {
      //print('📝 [API] Marquage global pour token: $token');

      // ✅ URL corrigée selon votre endpoint Python
      final response = await http.post(
        Uri.parse('$baseUrl/all_non_lu_notifications_test/$token'),
        headers: {"Content-Type": "application/json"},
      );

      //print('📡 [API] Réponse marquage global: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['code'] == 200;
      }
      return false;
    } catch (e) {
      //print('❌ [API] Erreur marquage global: $e');
      return false;
    }
  }

  /* Supprimer toutes les notifications */
  static Future<bool> deleteAllNotifications(String token) async {
    try {
      //print('🗑️ [API] Suppression globale pour token: $token');

      // Pour l'instant, supprimer une par une car pas d'endpoint global
      final notifications = await getNotifications(token);
      if (notifications.isEmpty) return true;

      for (var notification in notifications) {
        final success = await deleteNotification(token, notification.id);
        if (!success) return false;
      }
      return true;
    } catch (e) {
      //print('❌ [API] Erreur suppression globale: $e');
      return false;
    }
  }
}

/// **************************** Fin du Bloc qui gères les notifications *************************

class FieldValidation {
  final String message;
  final String type;

  FieldValidation({
    required this.message,
    required this.type,
  });

  factory FieldValidation.fromJson(Map<String, dynamic> json) {
    return FieldValidation(
      message: json['message'] ?? '',
      type: json['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'message': message,
        'type': type,
      };
}

class FormField {
  final String icon;
  final String label;
  final String name;
  final bool required;
  final String section;
  final String type;
  final List<FieldValidation> validations;

  FormField({
    required this.icon,
    required this.label,
    required this.name,
    required this.required,
    required this.section,
    required this.type,
    required this.validations,
  });

  factory FormField.fromJson(Map<String, dynamic> json) {
    var validationsList = (json['validations'] as List?)
            ?.map((v) => FieldValidation.fromJson(v))
            .toList() ??
        [];

    return FormField(
      icon: json['icon'] ?? '',
      label: json['label'] ?? '',
      name: json['name'] ?? '',
      required: json['required'] ?? false,
      section: json['section'] ?? '',
      type: json['type'] ?? '',
      validations: validationsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'icon': icon,
        'label': label,
        'name': name,
        'required': required,
        'section': section,
        'type': type,
        'validations': validations.map((v) => v.toJson()).toList(),
      };
}

// Modèle pour les bannières
class Accueil {
  final String imageUrl;
  String? localImagePath;

  Accueil({
    required this.imageUrl,
    this.localImagePath,
  });

  // Getter pour obtenir l'image (locale ou distante)
  String get image => imageUrl;

  // Vérifie si une image locale existe et est valide
  bool get hasLocalImage =>
      localImagePath != null && File(localImagePath!).existsSync();

  factory Accueil.fromJson(Map<String, dynamic> json) {
    return Accueil(
      imageUrl: json['image'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'image': imageUrl,
      };

  // Méthode copyWith pour créer une copie modifiée
  Accueil copyWith({
    String? imageUrl,
    String? localImagePath,
  }) {
    return Accueil(
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }

  @override
  String toString() =>
      'Accueil(imageUrl: $imageUrl, localImagePath: $localImagePath)';
}

// Modèle pour les secteurs d'activité
class SecteurActivite {
  final String icon;
  final String name;

  const SecteurActivite({
    required this.icon,
    required this.name,
  });

  factory SecteurActivite.fromJson(Map<String, dynamic> json) {
    return SecteurActivite(
      icon: json['icon'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'icon': icon,
        'name': name,
      };

  @override
  String toString() => 'SecteurActivite(icon: $icon, name: $name)';
}

class UserData {
  final UserRegistration enregistrement;
  final List<FormField> fields;
  final double? solde;

  UserData({
    required this.enregistrement,
    required this.fields,
    this.solde,
  });

  // Ajout de la méthode copyWith
  UserData copyWith({
    UserRegistration? enregistrement,
    List<FormField>? fields,
    double? solde,
  }) {
    return UserData(
      enregistrement: enregistrement ?? this.enregistrement,
      fields: fields ?? this.fields,
      solde: solde ?? this.solde,
    );
  }

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      enregistrement: UserRegistration.fromJson(json['enregistrement'] ?? {}),
      fields: (json['fields'] as List?)
              ?.map((field) => FormField.fromJson(field))
              .toList() ??
          [],
      solde: double.tryParse(json['solde']?.toString() ?? '0'),
    );
  }

  Map<String, dynamic> toJson() => {
        'enregistrement': enregistrement.toJson(),
        'fields': fields.map((field) => field.toJson()).toList(),
        'solde': solde,
      };

  String? getFieldValue(String fieldName) {
    final value = enregistrement.getFieldValue(fieldName);
    return value?.toString();
  }
}

class Transaction {
  final String clientTransID;
  final String createdAt;
  final String amount;
  final String status;
  final String liens;
  final String typeTransaction; // 'momo' ou 'carte'

  // Champs optionnels pour Mobile Money
  final String? inite;

  // Champs optionnels pour Carte Bancaire
  final String? typePaiement;
  final double? tauxConversion;

  // Champs communs optionnels
  final String? beneficiaire;

  Transaction({
    required this.clientTransID,
    required this.createdAt,
    required this.amount,
    required this.status,
    required this.liens,
    required this.typeTransaction,
    this.inite,
    this.typePaiement,
    this.tauxConversion,
    this.beneficiaire,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      clientTransID: json['clientTransID']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      status: json['status']?.toString() ?? '',
      liens: json['liens']?.toString() ?? '',
      typeTransaction:
          json['type_transaction']?.toString() ?? 'momo', // 'source' dans l'API

      // Champs Mobile Money
      inite: json['inite']?.toString(),

      // Champs Carte Bancaire
      typePaiement: json['type_paiement']?.toString(),
      tauxConversion: json['taux_conversion'] != null
          ? double.tryParse(json['taux_conversion'].toString())
          : null,

      // Champs communs
      beneficiaire: json['beneficiaire']?.toString(),
    );
  }

  // Méthode pour obtenir le montant en double
  double getAmount() {
    try {
      return double.parse(amount.replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (e) {
      //print('Erreur de conversion du montant: $e');
      return 0.0;
    }
  }

  // Méthode pour formater le montant pour l'affichage
  String getFormattedAmount() {
    final amt = getAmount();
    return NumberFormat.currency(
      symbol: '',
      decimalDigits: 0,
      locale: 'fr_FR',
    ).format(amt);
  }

  // Méthode pour obtenir l'icône appropriée
  IconData getIcon() {
    return typeTransaction == 'carte' ? Icons.credit_card : Icons.smartphone;
  }

  // Méthode pour obtenir la couleur appropriée
  Color getTypeColor() {
    return typeTransaction == 'carte'
        ? const Color(0xFF28a745) // Vert pour carte
        : const Color(0xFF006699); // Bleu pour mobile
  }

  // Méthode pour obtenir le label du type
  String getTypeLabel() {
    return typeTransaction == 'carte' ? 'CARTE' : 'MOMO';
  }

  // Méthode pour vérifier si c'est une transaction carte
  bool get isCardTransaction => typeTransaction == 'carte';

  // Méthode pour vérifier si c'est une transaction mobile
  bool get isMobileTransaction => typeTransaction == 'momo';

  // Méthode pour obtenir le montant en EUR (pour les cartes)
  double? getAmountInEur() {
    if (tauxConversion != null && tauxConversion! > 0) {
      return getAmount() / tauxConversion!;
    }
    return null;
  }

  // Méthode pour formater le montant EUR
  String? getFormattedAmountEur() {
    final amountEur = getAmountInEur();
    if (amountEur != null) {
      return NumberFormat.currency(
        symbol: '€',
        decimalDigits: 2,
        locale: 'fr_FR',
      ).format(amountEur);
    }
    return null;
  }

  @override
  String toString() {
    return 'Transaction{clientTransID: $clientTransID, amount: $amount, status: $status, type: $typeTransaction, date: $createdAt}';
  }

  // Méthode pour créer une copie avec des modifications
  Transaction copyWith({
    String? clientTransID,
    String? createdAt,
    String? amount,
    String? status,
    String? liens,
    String? typeTransaction,
    String? inite,
    String? typePaiement,
    double? tauxConversion,
    String? beneficiaire,
  }) {
    return Transaction(
      clientTransID: clientTransID ?? this.clientTransID,
      createdAt: createdAt ?? this.createdAt,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      liens: liens ?? this.liens,
      typeTransaction: typeTransaction ?? this.typeTransaction,
      inite: inite ?? this.inite,
      typePaiement: typePaiement ?? this.typePaiement,
      tauxConversion: tauxConversion ?? this.tauxConversion,
      beneficiaire: beneficiaire ?? this.beneficiaire,
    );
  }

  // Méthode pour convertir en JSON
  Map<String, dynamic> toJson() {
    return {
      'clientTransID': clientTransID,
      'createdAt': createdAt,
      'amount': amount,
      'status': status,
      'liens': liens,
      'type_transaction': typeTransaction,
      if (inite != null) 'inite': inite,
      if (typePaiement != null) 'type_paiement': typePaiement,
      if (tauxConversion != null) 'taux_conversion': tauxConversion,
      if (beneficiaire != null) 'beneficiaire': beneficiaire,
    };
  }
}

// ========== CLASSE LOCATIONRESULT ==========
class LocationResult {
  final Country country;
  final Position? position;
  final String? detectionMethod;
  final String? reason;
  final bool isSuccess;

  LocationResult._({
    required this.country,
    this.position,
    this.detectionMethod,
    this.reason,
    required this.isSuccess,
  });

  factory LocationResult.success({
    required Country country,
    Position? position,
    String? detectionMethod,
  }) {
    return LocationResult._(
      country: country,
      position: position,
      detectionMethod: detectionMethod,
      isSuccess: true,
    );
  }

  factory LocationResult.fallback({
    required Country country,
    String? reason,
  }) {
    return LocationResult._(
      country: country,
      reason: reason,
      detectionMethod: 'Fallback',
      isSuccess: false,
    );
  }

  // ========== PROPRIÉTÉS COMPATIBLES AVEC gestionCompte.dart ==========

  /// Indique si la détection a réussi (GPS/réseau)
  bool get isDetected => isSuccess;

  /// Indique s'il y a eu une erreur lors de la détection
  bool get isError => !isSuccess && reason != null;

  /// Message descriptif du résultat
  String? get message {
    if (isDetected) {
      return detectionMethod ?? 'Détection réussie';
    } else if (isError) {
      return reason ?? 'Erreur de détection';
    } else {
      return reason ?? 'Pays par défaut';
    }
  }
}

// ========== CLASSE LOCATIONSERVICE INTÉGRÉE ==========
// ========== CLASSE LOCATIONSERVICE CORRIGÉE ==========
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  LocationResult? _currentLocation;
  Completer<LocationResult>? _initializationCompleter;
  bool _isDetecting = false;

  // ✅ AJOUT: Variables pour le stream et la surveillance
  Timer? _permissionCheckTimer;
  StreamController<LocationResult>? _locationStreamController;
  Stream<LocationResult>? _locationStream;

  // ✅ AJOUT: Getter pour isDetecting
  bool get isDetecting => _isDetecting;

  LocationResult? get currentLocation => _currentLocation;

  // ✅ NOUVEAU: Stream pour écouter les changements
  Stream<LocationResult> get locationStream {
    _locationStreamController ??= StreamController<LocationResult>.broadcast();
    _locationStream ??= _locationStreamController!.stream;
    return _locationStream!;
  }

  Future<LocationResult> initializeLocationOptional() async {
    if (_currentLocation != null && _currentLocation!.isDetected) {
      return _currentLocation!;
    }

    if (_isDetecting && _initializationCompleter != null) {
      return await _initializationCompleter!.future;
    }

    _isDetecting = true;
    _initializationCompleter = Completer<LocationResult>();

    try {
      //print('🌍 [LocationService] Initialisation géolocalisation...');

      final result = await _detectLocationWithPermissionRetry();
      _currentLocation = result;

      // ✅ NOUVEAU: Émettre le résultat dans le stream
      _locationStreamController?.add(result);

      // ✅ NOUVEAU: Démarrer la surveillance des autorisations si pas de détection
      if (!result.isDetected) {
        _startPermissionMonitoring();
      }

      _initializationCompleter!.complete(result);
      return result;
    } catch (e) {
      //print('❌ [LocationService] Erreur initialisation: $e');
      final fallback = _getDefaultLocationResult();
      _currentLocation = fallback;

      _locationStreamController?.add(fallback);
      _initializationCompleter!.complete(fallback);

      // ✅ NOUVEAU: Surveiller les permissions même en cas d'erreur
      _startPermissionMonitoring();

      return fallback;
    } finally {
      _isDetecting = false;
      _initializationCompleter = null;
    }
  }

  // ✅ NOUVELLE MÉTHODE: Surveillance des permissions
  void _startPermissionMonitoring() {
    // Arrêter le timer existant s'il y en a un
    _permissionCheckTimer?.cancel();

    //print('👁️ [LocationService] Surveillance des permissions démarrée');

    // Vérifier les permissions toutes les 2 secondes
    _permissionCheckTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final permission = await Geolocator.checkPermission();
        //print('🔍 [LocationService] Vérification permission: $permission');

        // Si permission accordée et pas encore détecté
        if ((permission == LocationPermission.whileInUse ||
                permission == LocationPermission.always) &&
            (_currentLocation == null || !_currentLocation!.isDetected)) {
          print(
              '✅ [LocationService] Permission accordée - LANCEMENT nouvelle détection');
          timer.cancel(); // Arrêter la surveillance

          // Lancer une nouvelle détection
          await _retryLocationDetection();
        }
      } catch (e) {
        //print('❌ [LocationService] Erreur vérification permission: $e');
      }
    });

    // Arrêter après 30 secondes pour éviter une surveillance infinie
    Future.delayed(const Duration(seconds: 30), () {
      _permissionCheckTimer?.cancel();
      //print('⏹️ [LocationService] Fin surveillance permissions (timeout)');
    });
  }

  // ✅ NOUVELLE MÉTHODE: Relancer la détection
  Future<void> _retryLocationDetection() async {
    try {
      //print('🔄 [LocationService] === DÉBUT RETRY DÉTECTION ===');
      _isDetecting = true;

      // Attendre un peu pour que le système soit prêt
      await Future.delayed(const Duration(milliseconds: 1000));

      final result = await _performLocationDetection();
      _currentLocation = result;

      print(
          '🎯 [LocationService] RETRY terminé: ${result.country.name} - Détecté: ${result.isDetected}');

      // ✅ CRUCIAL: Émettre le nouveau résultat dans le stream
      _locationStreamController?.add(result);
      //print('📡 [LocationService] Résultat émis dans le stream');
    } catch (e) {
      //print('❌ [LocationService] Erreur RETRY détection: $e');

      // Envoyer un fallback dans le stream même en cas d'erreur
      final fallback = _getDefaultLocationResult();
      _currentLocation = fallback;
      _locationStreamController?.add(fallback);
    } finally {
      _isDetecting = false;
      //print('🔄 [LocationService] === FIN RETRY DÉTECTION ===');
    }
  }

  Future<LocationResult> _detectLocationWithPermissionRetry() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      // Si la permission n'est pas encore accordée, la demander
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        // Si deniedForever, ne pas redemander et retourner résultat par défaut
        if (permission == LocationPermission.deniedForever) {
          //print('🚫 [LocationService] Permissions refusées définitivement');
          return _getDefaultLocationResult();
        }

        // Demander la permission (fonctionne pour denied et unableToDetermine)
        //print('📱 [LocationService] Demande d\'autorisation...');
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          print(
              '✅ [LocationService] Permission accordée, détection en cours...');
          await Future.delayed(const Duration(milliseconds: 500));
          return await _performLocationDetection();
        } else {
          //print('🚫 [LocationService] Permissions refusées');
          return _getDefaultLocationResult();
        }
      }

      // Permission déjà accordée
      return await _performLocationDetection();
    } catch (e) {
      //print('❌ [LocationService] Erreur détection: $e');
      return _getDefaultLocationResult();
    }
  }

  Future<LocationResult> _performLocationDetection() async {
    try {
      // Essayer la dernière position connue d'abord
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        final country = _detectCountryFromPosition(lastPosition);
        if (country != null) {
          //print('📍 [LocationService] Position cache: ${country.name}');
          return LocationResult.success(
            country: country,
            position: lastPosition,
            detectionMethod: 'Dernière position connue',
          );
        }
      }

      // Obtenir une nouvelle position
      //print('🎯 [LocationService] Acquisition nouvelle position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      final country = _detectCountryFromPosition(position);
      if (country != null) {
        //print('🌍 [LocationService] Pays détecté: ${country.name}');
        return LocationResult.success(
          country: country,
          position: position,
          detectionMethod: 'GPS actuel',
        );
      }

      return _getDefaultLocationResult();
    } catch (e) {
      //print('❌ [LocationService] Erreur acquisition position: $e');
      return _getDefaultLocationResult();
    }
  }

  LocationResult _getDefaultLocationResult() {
    final defaultCountry = countries.firstWhere((c) => c.code == 'CG',
        orElse: () => countries.isNotEmpty
            ? countries.first
            : const Country(
                name: 'Congo',
                code: 'CG',
                dialCode: '+242',
                flag: '🇨🇬',
                region: "Afrique centrale"));

    return LocationResult.fallback(
      country: defaultCountry,
      reason: 'Permission refusée ou erreur',
    );
  }

  Country? _detectCountryFromPosition(Position position) {
    // Utiliser la classe GlobalOfflineGeocoding existante
    try {
      final country = GlobalOfflineGeocoding.detectCountryFromCoordinates(
          position.latitude, position.longitude);

      if (country != null) {
        print(
            '✅ [LocationService] Pays détecté: ${country.name} pour ${position.latitude}, ${position.longitude}');
        return country;
      }

      print(
          '❌ [LocationService] Aucun pays détecté pour ${position.latitude}, ${position.longitude}');
      return null;
    } catch (e) {
      //print('❌ [LocationService] Erreur détection pays: $e');
      return null;
    }
  }

  // Méthode waitForInitialization existante
  Future<LocationResult> waitForInitialization() async {
    if (_currentLocation != null) {
      return _currentLocation!;
    }

    if (_isDetecting && _initializationCompleter != null) {
      return await _initializationCompleter!.future;
    }

    return await initializeLocationOptional();
  }

  // ✅ NOUVEAU: Méthode de nettoyage
  void dispose() {
    _permissionCheckTimer?.cancel();
    _locationStreamController?.close();
    _locationStreamController = null;
    _locationStream = null;
  }
}

class AuthService {
  final BuildContext context;

  AuthService(this.context);

  // ========== NOUVELLE MÉTHODE : Préchargement spécifique pour inscription Google ==========
// ========== NOUVELLE MÉTHODE : Préchargement spécifique pour inscription Google ==========

// ========== NOUVELLE MÉTHODE : Préchargement spécifique pour inscription Google ==========
  Future<void> _preloadDataForGoogleRegistration(
      String token, String countryName) async {
    try {
      print(
          '🚀 [GoogleAuth] Préchargement des données pour inscription Google...');

      final appDataProvider =
          Provider.of<AppDataProvider>(context, listen: false);

      // ========== CHARGEMENT SIMPLIFIÉ AVEC LES MÉTHODES EXISTANTES ==========

      // 1. Pays éligibles (priorité absolue pour WelcomePage)
      if (appDataProvider.eligibleCountries.isEmpty) {
        //print('📍 [GoogleAuth] Chargement des pays éligibles...');
        try {
          await appDataProvider
              .loadEligibleCountries()
              .timeout(const Duration(seconds: 8), onTimeout: () {
            //print('⚠️ [GoogleAuth] Timeout pays éligibles - continuation');
          });
          print(
              '✅ [GoogleAuth] Pays éligibles chargés: ${appDataProvider.eligibleCountries.length}');
        } catch (e) {
          //print('⚠️ [GoogleAuth] Erreur chargement pays éligibles: $e');
        }
      }

      // 2. Initialisation complète de l'app (charge tout le reste)
      //print('📦 [GoogleAuth] Initialisation complète des données...');
      try {
        await appDataProvider
            .initializeApp(context)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          print(
              '⚠️ [GoogleAuth] Timeout initialisation complète - continuation');
        });
        //print('✅ [GoogleAuth] Initialisation complète terminée');
      } catch (e) {
        //print('⚠️ [GoogleAuth] Erreur initialisation complète: $e');
      }

      // 3. Chargement des données publiques si disponible
      try {
        await appDataProvider
            .loadPublicData()
            .timeout(const Duration(seconds: 5), onTimeout: () {
          //print('⚠️ [GoogleAuth] Timeout données publiques - continuation');
        });
        //print('✅ [GoogleAuth] Données publiques chargées');
      } catch (e) {
        //print('⚠️ [GoogleAuth] Erreur données publiques: $e');
      }

      //print('✅ [GoogleAuth] Préchargement terminé');
      //print('   - Pays éligibles: ${appDataProvider.eligibleCountries.length}');
      //print('   - Services: ${appDataProvider.services.length}');
    } catch (e) {
      //print('⚠️ [GoogleAuth] Erreur préchargement (non-critique): $e');
    }
  }

// ========== NOUVELLE MÉTHODE : Vérification finale avant WelcomePage ==========
  Future<void> _ensureDataForWelcomePage() async {
    try {
      print(
          '🔍 [Register] Vérification finale des données pour WelcomePage...');

      final appDataProvider =
          Provider.of<AppDataProvider>(context, listen: false);

      // Si les pays éligibles sont toujours vides, faire une dernière tentative rapide
      if (appDataProvider.eligibleCountries.isEmpty) {
        print(
            '⚡ [Register] Dernière tentative de chargement des pays éligibles...');

        try {
          await appDataProvider
              .loadEligibleCountries()
              .timeout(const Duration(seconds: 5), onTimeout: () {
            print(
                '⚠️ [Register] Timeout dernière tentative - WelcomePage utilisera le fallback');
          });

          if (appDataProvider.eligibleCountries.isNotEmpty) {
            print(
                '✅ [Register] Pays éligibles chargés in extremis: ${appDataProvider.eligibleCountries.length}');
          }
        } catch (e) {
          //print('⚠️ [Register] Échec dernière tentative: $e');
        }
      } else {
        print(
            '✅ [Register] Données déjà disponibles: ${appDataProvider.eligibleCountries.length} pays');
      }
    } catch (e) {
      //print('⚠️ [Register] Erreur vérification finale: $e');
    }
  }

  // ========== La méthode Register ==========
  Future<void> register(String nomEtPrenom, String tel, String password,
      {String? referralCode, String? countryName, String? countryCode}) async {
    try {
      String os = Platform.isAndroid ? 'Android' : 'iOS';
      //print('📝 [Register] Inscription en cours...');
      //print('- Nom: $nomEtPrenom');
      //print('- Tel: $tel');

      // ========== DÉTERMINER LE PAYS AVANT L'INSCRIPTION ==========
      String finalCountryName = countryName ?? '';
      String finalCountryCode = countryCode ?? '';

      // Si le pays n'est pas fourni, le détecter via géolocalisation
      if (finalCountryName.isEmpty || finalCountryCode.isEmpty) {
        try {
          //print('🌍 [Register] Détection du pays en cours...');

          final locationService = LocationService();
          final locationResult =
              await locationService.initializeLocationOptional().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print(
                  '⏰ [Register] Timeout géolocalisation - utilisation Congo par défaut');
              return LocationResult.fallback(
                country: countries.firstWhere((c) => c.code == 'CG',
                    orElse: () => countries.first),
                reason: 'Timeout géolocalisation',
              );
            },
          );

          finalCountryName = locationResult.country.name;
          finalCountryCode = locationResult.country.code.toUpperCase();

          print(
              '🎯 [Register] Pays détecté: $finalCountryName (Code: $finalCountryCode)');
        } catch (e) {
          print(
              '❌ [Register] Erreur détection pays: $e - utilisation Congo par défaut');
          finalCountryName = 'Congo';
          finalCountryCode = 'CG';
        }
      }

      // S'assurer qu'on a toujours des valeurs valides
      if (finalCountryName.isEmpty) finalCountryName = 'Congo';
      if (finalCountryCode.isEmpty) finalCountryCode = 'CG';

      print(
          '✅ [Register] Pays final: $finalCountryName (Code: $finalCountryCode)');

      // ========== CRÉER LE BODY AVEC TOUS LES CHAMPS REQUIS ==========
      Map<String, dynamic> requestBody = {
        "phone_number": tel,
        "password": password,
        "nom": nomEtPrenom,
        "operating_system": os,
        "new": "ok",
        "country_name": finalCountryName,
        "country_code": finalCountryCode,
        "zone_benef": finalCountryName,
        "zone_benef_code": finalCountryCode,
      };

      // Ajouter le code de parrainage s'il existe
      if (referralCode != null && referralCode.isNotEmpty) {
        requestBody["referral_code"] = referralCode;
      }

      //print('📤 [Register] Body envoyé: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/register_apk_wpay_v2_test'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      final data = jsonDecode(response.body);
      //print('📡 [Register] Réponse serveur: ${data["Code"]}');

      if (data["Code"] == 200) {
        // Sauvegarder les informations de l'utilisateur ET le token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_infos', jsonEncode(data['user']));
        await SessionManager.saveSession(data["token"]);

        // Sauvegarder TOUTES les informations pour l'accès hors ligne
        await SessionManager.saveAllUserInfo(data['user']);

        //print('✅ [Register] Inscription réussie');

        // ========== SAUVEGARDER LE CODE PAYS LOCALEMENT ==========
        final userResponse = data['user'];
        String savedZoneBenefCode = finalCountryCode;

        //print('🎯 [Register] zone_benef_code sauvegardé: $savedZoneBenefCode');

        await ZoneBenefManager.saveZoneBenef(savedZoneBenefCode);
        await prefs.setString('country_code', finalCountryCode);
        await prefs.setString('country_name', finalCountryName);

        // Chargement des données en arrière-plan
        await _loadDataAfterRegistration(data["token"], finalCountryName);

        if (data["process_normal"] == true) {
          // Redirection vers la page de vérification
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) => VerificationScreen(
                      data: data["token"],
                      datatel: tel,
                    )),
            (route) => false,
          );
        } else {
          // Redirection basée sur le code pays
          await _handlePostRegistrationNavigationByCode(
              nomEtPrenom, data["token"], savedZoneBenefCode);
        }
      } else if (data["Code"] == 409) {
        CustomOverlay.showError(context,
            message: "Le numéro de téléphone est déjà enregistré.");
      } else {
        CustomOverlay.showError(context,
            message: data["message"] ?? "Erreur lors de l'inscription");
      }
    } catch (e) {
      //print('❌ [Register] Erreur: $e');
      CustomOverlay.showError(context,
          message: "Une erreur s'est produite lors de l'inscription");
    }
  }

// ========== NOUVELLE MÉTHODE DE REDIRECTION ==========
  // ========== AMÉLIORATION de _handlePostRegistrationNavigationByCode ==========
  Future<void> _handlePostRegistrationNavigationByCode(
      String userName, String token, String zoneBenefCode) async {
    if (!context.mounted) return;

    try {
      print(
          '🎯 [Register] Redirection basée sur zone_benef_code: $zoneBenefCode');

      // if (zoneBenefCode.toUpperCase() == 'CG') {
      //   //print('🇨🇬 [Register] Redirection vers HomePage (Congo - Code CG)');
      //   NavigationManager.setCurrentHomePage('HomePage');

      //   if (context.mounted) {
      //     Navigator.pushAndRemoveUntil(
      //       context,
      //       MaterialPageRoute(
      //           builder: (context) =>
      //               HomePage(routeObserver: RouteObserver<PageRoute>())),
      //       (route) => false,
      //     );
      //   }
      // } else {
      print(
          '🌍 [Register] Redirection vers WelcomeZoneSelectionPage (Code: $zoneBenefCode)');

      // ========== NOUVEAU : VÉRIFICATION SUPPLÉMENTAIRE DES DONNÉES ==========
      await _ensureDataForWelcomePage();

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => WelcomeZoneSelectionPage(
              userName: userName,
              onZoneSelected: (selectedZone) {
                //print('✅ Zone sélectionnée: ${selectedZone['name']}');
              },
            ),
          ),
          (route) => false,
        );
      }
      // }
    } catch (e) {
      //print('❌ [Register] Erreur redirection: $e');
      // Fallback vers Congo/HomePage
      await ZoneBenefManager.saveZoneBenef('CG');
      NavigationManager.setCurrentHomePage('HomePage');

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  HomePage(routeObserver: RouteObserver<PageRoute>())),
          (route) => false,
        );
      }
    }
  }
// ========== Redirection basée sur géolocalisation ==========

  // ========== CORRECTION MÉTHODE LOGIN ==========
  Future<void> login(String phoneNumber, String password) async {
    try {
      String os = Platform.isAndroid ? 'Android' : 'iOS';
      //print('🔐 [Login] Connexion en cours...');
      //print('- Tel: $phoneNumber');

      final response = await http.post(
        Uri.parse('$baseUrl/login_apk_wpay_v2_test'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone_number": phoneNumber,
          "password": password,
          "operating_system": os
        }),
      );

      final data = jsonDecode(response.body);
      print(data);
      //print('📡 [Login] Réponse serveur: ${data["Code"]}');

      if (data['Code'] == 200) {
        // Sauvegarder le token de session
        await SessionManager.saveSession(data['jeton']);
        //print('✅ [Login] Token de session sauvegardé');

        // Sauvegarder les informations utilisateur
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_infos', jsonEncode(data['user']));
        //print('💾 [Login] Informations utilisateur sauvegardées');

        // Sauvegarder TOUTES les informations pour l'accès hors ligne
        await SessionManager.saveAllUserInfo(data['user']);

        // ========== RÉCUPÉRER ZONE_BENEF_CODE ==========
        final zoneBenefCode =
            data["zone_benef_code"] ?? 'CG'; // Fallback vers Congo

        //print('🎯 [Login] zone_benef_code récupérée: $zoneBenefCode');

        // Sauvegarder zone_benef_code dans le localStorage
        await ZoneBenefManager.saveZoneBenef(zoneBenefCode);

        // Chargement des données en arrière-plan
        await _loadDataAfterLogin(data['jeton']);

        // Redirection basée sur zone_benef_code
        _handlePostLoginNavigationByZoneBenef(zoneBenefCode);
      } else {
        String errorMessage = data['Code'] == 401
            ? 'Numéro de téléphone ou mot de passe incorrect'
            : 'Veuillez vérifier votre connexion';

        CustomOverlay.showError(context, message: errorMessage);
      }
    } catch (e) {
      //print('❌ [Login] Erreur: $e');
      CustomOverlay.showError(context, message: "Erreur de connexion");
    }
  }

  // ========== MÉTHODE VERIFY CODE MODIFIÉE ==========
  Future<void> verifyCode({required String token, required String pin}) async {
    try {
      //print('🔄 [VerifyCode] Début vérification...');

      final response = await http.post(
        Uri.parse('$baseUrl/verify_code_apk_wpay_v2_test'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'pin': pin,
        }),
      );

      //print('📡 [VerifyCode] Status: ${response.statusCode}');
      //print('📡 [VerifyCode] Body: ${response.body}');

      final data = jsonDecode(response.body);
      //print('📊 [VerifyCode] Code reçu: ${data['Code']}');

      if (data['Code'] == 200) {
        //print('✅ [VerifyCode] Vérification réussie');

        // Sauvegarder le token
        await SessionManager.saveSession(token);

        // ========== SUCCÈS : Ne pas lever d'exception ==========
        return;
      } else {
        //print('❌ [VerifyCode] Échec - Code: ${data['Code']}');

        // ========== ÉCHEC : Lever une exception ==========
        String errorMessage = data['message'] ??
            'Le code de vérification entré n\'est pas valide';
        throw Exception(errorMessage);
      }
    } catch (e) {
      //print('❌ [VerifyCode] Exception: $e');

      // ========== RELANCER L'EXCEPTION POUR QUE confirmPin() LA CATCH ==========
      rethrow;
    }
  }

  void _handlePostLoginNavigationByZoneBenef(String? zoneBenef) {
    if (!context.mounted) return;
    //print('🎯 [Login] Redirection basée sur zone_benef: $zoneBenef');
    NavigationManager.navigateBasedOnZoneBenef(context, zoneBenef);
  }

  Future<void> _loadDataAfterRegistration(
      String token, String? countryName) async {
    try {
      //print('🔄 [Register] Chargement des données en arrière-plan...');

      // Obtenir le provider des données
      final appDataProvider =
          Provider.of<AppDataProvider>(context, listen: false);

      // NOUVEAU: Timeout de sécurité pour éviter les blocages
      Future.microtask(() async {
        try {
          //print('📦 [Register] Initialisation du DataProvider...');

          // CORRECTION: Timeout court pour ne pas bloquer l'utilisateur
          await appDataProvider.initializeApp(context).timeout(
            const Duration(seconds: 5), // Timeout réduit à 5s
            onTimeout: () {
              print(
                  '⚠️ [Register] Timeout DataProvider - continuation navigation');
              // Ne pas faire échouer, juste continuer
            },
          );

          // Charger spécifiquement les données publiques avec timeout
          await appDataProvider.loadPublicData().timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              //print('⚠️ [Register] Timeout données publiques - continuation');
            },
          );

          //print('✅ [Register] Données chargées en arrière-plan');
        } catch (e) {
          print(
              '⚠️ [Register] Erreur chargement arrière-plan (non-critique): $e');
          // Ne pas faire échouer l'inscription pour des erreurs de données
        }
      });
    } catch (e) {
      //print('❌ [Register] Erreur chargement arrière-plan: $e');
      // Ne pas faire échouer l'inscription pour cela
    }
  }

  Future<void> _loadDataAfterLogin(String token) async {
    try {
      //print('🔄 [Login] Chargement des données en arrière-plan...');

      // Obtenir le provider des données
      final appDataProvider =
          Provider.of<AppDataProvider>(context, listen: false);

      // Timeout de sécurité pour éviter les blocages
      Future.microtask(() async {
        try {
          //print('📦 [Login] Initialisation du DataProvider...');

          await appDataProvider.initializeApp(context).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print(
                  '⚠️ [Login] Timeout DataProvider - continuation navigation');
            },
          );

          //print('✅ [Login] Données chargées en arrière-plan');
        } catch (e) {
          //print('⚠️ [Login] Erreur chargement arrière-plan (non-critique): $e');
        }
      });
    } catch (e) {
      //print('❌ [Login] Erreur chargement arrière-plan: $e');
    }
  }

// ========== MÉTHODES GOOGLE AUTHENTICATION À AJOUTER DANS AuthService ==========

  // ========== GOOGLE SIGN IN ==========
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static Future<void> _initializeGoogleSignIn() async {
    await _googleSignIn.initialize(
      serverClientId: Platform.isIOS
          ? '632922069265-44s4mhv5bm87h0de8mv2tbv3kktf6vrb.apps.googleusercontent.com'
          : '632922069265-e76ug6cklkbeda91ed8ht571um2fh7jl.apps.googleusercontent.com',
    );
  }

  Null get countryName => null;

  Null get countryCode => null;

  // ========== CONNEXION AVEC GOOGLE ==========
  Future<void> loginWithGoogle() async {
    try {
      //print('🔵 [GoogleAuth] Début de la connexion Google');

      // 1. Authentification Google
      print("BBBBBBooooooooooonnnnnnnnjour ${Platform.isIOS}");

      // ÉTAPE 1 : Initialisation OBLIGATOIRE
      await _initializeGoogleSignIn();

      // ÉTAPE 2 : Authentification
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'], // ✅ Les scopes vont ici maintenant
      );
      print("BBBBBBooooooooooonnnnnnnnjour $googleUser");

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? googleToken = googleAuth.idToken;

      if (googleToken == null) {
        throw Exception('Impossible d\'obtenir le token Google');
      }

      //print('✅ [GoogleAuth] Token Google obtenu');

      // 2. Appel API backend
      final response = await http.post(
        Uri.parse('$baseUrl/google/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "google_token": googleToken,
          "google_IDtype": Platform.operatingSystem,
          "provider": 'apk'
        }),
      );

      final data = jsonDecode(response.body);
      //print('📡 [GoogleAuth] Réponse serveur: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Utilisateur existant - connexion réussie
        //print('✅ [GoogleAuth] Connexion réussie pour utilisateur existant');

        // Pas de token classique retourné, mais user_id pour identifier l'utilisateur
        final userId = data['token'];

        print(
            '**************************************************************** $data');

        // Sauvegarder les informations utilisateur
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_infos', jsonEncode(data['user']));
        await prefs.setString('auth_method', 'google');
        await prefs.setString('google_user_id', userId);

        await SessionManager.saveSession(userId);

        // Sauvegarder TOUTES les informations pour l'accès hors ligne
        await SessionManager.saveAllUserInfo(data['user']);

        //print('💾 [GoogleAuth] Informations utilisateur sauvegardées');
        final zoneBenefCode =
            data["zone_benef_code"] ?? 'CG'; // Fallback vers Congo

        // Redirection directe vers HomePage (les utilisateurs Google existants sont déjà configurés)
        // Sauvegarder zone_benef_code dans le localStorage
        await ZoneBenefManager.saveZoneBenef(zoneBenefCode);

        // Chargement des données en arrière-plan
        await _loadDataAfterLogin(userId);

        // Redirection basée sur zone_benef_code
        _handlePostLoginNavigationByZoneBenef(zoneBenefCode);

        // if (context.mounted) {
        //   Navigator.pushAndRemoveUntil(
        //     context,
        //     MaterialPageRoute(
        //       builder: (context) => HomePage(routeObserver: RouteObserver<PageRoute>())
        //     ),
        //     (route) => false,
        //   );
        // }
      } else if (response.statusCode == 201) {
        // Nouvel utilisateur - finalisation requise
        //print('🆕 [GoogleAuth] Nouvel utilisateur, finalisation requise');

        final completionToken = data['completion_token'];
        final userData = data['user'];

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GoogleProfileCompletionPage(
                completionToken: completionToken,
                userData: userData,
              ),
            ),
          );
        }
      } else {
        throw Exception(data['error'] ?? 'Erreur de connexion Google');
      }
    } catch (e) {
      //print('❌ [GoogleAuth] Erreur: $e');
      await _googleSignIn.signOut(); // Nettoyer en cas d'erreur
      rethrow;
    }
  }

  // ========== FINALISATION PROFIL GOOGLE ==========
// ========== FINALISATION PROFIL GOOGLE MODIFIÉE ==========
  Future<void> completeGoogleProfile(
      String completionToken, String phone) async {
    try {
      //print('🔵 [GoogleAuth] Finalisation du profil');

      // ========== DÉTERMINER LE PAYS AVANT L'INSCRIPTION ==========
      String finalCountryName = countryName ?? '';
      String finalCountryCode = countryCode ?? '';

      // Si le pays n'est pas fourni, le détecter via géolocalisation
      if (finalCountryName.isEmpty || finalCountryCode.isEmpty) {
        try {
          //print('🌍 [GoogleAuth] Détection du pays en cours...');

          final locationService = LocationService();
          final locationResult =
              await locationService.initializeLocationOptional().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print(
                  '⏰ [GoogleAuth] Timeout géolocalisation - utilisation Congo par défaut');
              return LocationResult.fallback(
                country: countries.firstWhere((c) => c.code == 'CG',
                    orElse: () => countries.first),
                reason: 'Timeout géolocalisation',
              );
            },
          );

          finalCountryName = locationResult.country.name;
          finalCountryCode = locationResult.country.code.toUpperCase();

          print(
              '🎯 [GoogleAuth] Pays détecté: $finalCountryName (Code: $finalCountryCode)');
        } catch (e) {
          print(
              '❌ [GoogleAuth] Erreur détection pays: $e - utilisation Congo par défaut');
          finalCountryName = 'Congo';
          finalCountryCode = 'CG';
        }
      }

      // S'assurer qu'on a toujours des valeurs valides
      if (finalCountryName.isEmpty) finalCountryName = 'Congo';
      if (finalCountryCode.isEmpty) finalCountryCode = 'CG';

      print(
          '✅ [GoogleAuth] Pays final: $finalCountryName (Code: $finalCountryCode)');

      final response = await http.post(
        Uri.parse('$baseUrl/google/complete-profile'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "completion_token": completionToken,
          "phone": phone,
          "country_name": finalCountryName,
          "country_code": finalCountryCode,
          "zone_benef": finalCountryName,
          "zone_benef_code": finalCountryCode,
          "provider": 'apk'
        }),
      );

      final data = jsonDecode(response.body);
      //print('📡 [GoogleAuth] Réponse finalisation: ${response.statusCode}');

      if (response.statusCode == 200) {
        //print('✅ [GoogleAuth] Profil complété avec succès');

        // Sauvegarder les informations utilisateur
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_infos', jsonEncode(data['user']));
        await prefs.setString('auth_method', 'google');
        await prefs.setString('google_user_id', data['token']);

        await SessionManager.saveSession(data['token']);

        // Sauvegarder TOUTES les informations pour l'accès hors ligne
        await SessionManager.saveAllUserInfo(data['user']);

        // ========== SAUVEGARDER LE CODE PAYS LOCALEMENT ==========
        String savedZoneBenefCode = finalCountryCode;

        print(
            '🎯 [GoogleAuth] zone_benef_code sauvegardé: $savedZoneBenefCode');

        await ZoneBenefManager.saveZoneBenef(savedZoneBenefCode);
        await prefs.setString('country_code', finalCountryCode);
        await prefs.setString('country_name', finalCountryName);

        // ========== NOUVEAU : PRÉCHARGEMENT DES DONNÉES AVANT NAVIGATION ==========
        await _preloadDataForGoogleRegistration(
            data["token"], finalCountryName);

        // Redirection avec données préchargées
        await _handlePostRegistrationNavigationByCode(
            data['user']['nom'], data["token"], savedZoneBenefCode);
      } else {
        throw Exception(data['error'] ?? 'Erreur lors de la finalisation');
      }
    } catch (e) {
      //print('❌ [GoogleAuth] Erreur finalisation: $e');
      rethrow;
    }
  }

  // ========== CONNEXION AVEC APPLE ==========
  Future<void> loginWithApple() async {
    try {
      print('🍎 [AppleAuth] Début de la connexion Apple');

      // 1. Vérifier la disponibilité
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        throw Exception('Sign in with Apple n\'est pas disponible sur cet appareil');
      }

      // 2. Demander l'authentification Apple
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      print('✅ [AppleAuth] Credential obtenu: ${credential.userIdentifier}');

      // 3. Appel API backend
      final response = await http.post(
        Uri.parse('$baseUrl/apple/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "apple_user_id": credential.userIdentifier,
          "identity_token": credential.identityToken,
          "authorization_code": credential.authorizationCode,
          "email": credential.email,
          "given_name": credential.givenName,
          "family_name": credential.familyName,
          "provider": 'apk'
        }),
      );

      final data = jsonDecode(response.body);
      print('📡 [AppleAuth] Réponse serveur: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Utilisateur existant - connexion réussie
        print('✅ [AppleAuth] Connexion réussie pour utilisateur existant');

        final userId = data['token'];

        // Sauvegarder les informations utilisateur
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_infos', jsonEncode(data['user']));
        await prefs.setString('auth_method', 'apple');
        await prefs.setString('apple_user_id', userId);

        await SessionManager.saveSession(userId);

        // Sauvegarder TOUTES les informations pour l'accès hors ligne
        await SessionManager.saveAllUserInfo(data['user']);

        final zoneBenefCode = data["zone_benef_code"] ?? 'CG';
        await ZoneBenefManager.saveZoneBenef(zoneBenefCode);

        // Chargement des données en arrière-plan
        await _loadDataAfterLogin(userId);

        // Redirection basée sur zone_benef_code
        _handlePostLoginNavigationByZoneBenef(zoneBenefCode);
      } else if (response.statusCode == 201) {
        // Nouvel utilisateur - finalisation requise
        print('🆕 [AppleAuth] Nouvel utilisateur, finalisation requise');

        final completionToken = data['completion_token'];
        final userData = data['user'];

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppleProfileCompletionPage(
                completionToken: completionToken,
                userData: userData,
              ),
            ),
          );
        }
      } else {
        throw Exception(data['error'] ?? 'Erreur de connexion Apple');
      }
    } catch (e) {
      print('❌ [AppleAuth] Erreur: $e');
      rethrow;
    }
  }

  // ========== FINALISATION PROFIL APPLE ==========
  Future<void> completeAppleProfile(
      String completionToken, String phone, {String nom = ''}) async {
    try {
      print('🔵 [AppleAuth] Finalisation du profil');

      // Déterminer le pays
      String finalCountryName = countryName ?? '';
      String finalCountryCode = countryCode ?? '';

      if (finalCountryName.isEmpty || finalCountryCode.isEmpty) {
        try {
          final locationService = LocationService();
          final locationResult =
              await locationService.initializeLocationOptional().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('⏰ [AppleAuth] Timeout géolocalisation - utilisation Congo par défaut');
              return LocationResult.fallback(
                country: countries.firstWhere((c) => c.code == 'CG',
                    orElse: () => countries.first),
                reason: 'Timeout géolocalisation',
              );
            },
          );

          finalCountryName = locationResult.country.name;
          finalCountryCode = locationResult.country.code.toUpperCase();
          print('🎯 [AppleAuth] Pays détecté: $finalCountryName (Code: $finalCountryCode)');
        } catch (e) {
          print('❌ [AppleAuth] Erreur détection pays: $e - utilisation Congo par défaut');
          finalCountryName = 'Congo';
          finalCountryCode = 'CG';
        }
      }

      if (finalCountryName.isEmpty) finalCountryName = 'Congo';
      if (finalCountryCode.isEmpty) finalCountryCode = 'CG';

      print('✅ [AppleAuth] Pays final: $finalCountryName (Code: $finalCountryCode)');

      final response = await http.post(
        Uri.parse('$baseUrl/apple/complete-profile'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "completion_token": completionToken,
          "phone": phone,
          "nom": nom,
          "country_name": finalCountryName,
          "country_code": finalCountryCode,
          "zone_benef": finalCountryName,
          "zone_benef_code": finalCountryCode,
          "provider": 'apk'
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('✅ [AppleAuth] Profil complété avec succès');

        // Sauvegarder les informations utilisateur
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_infos', jsonEncode(data['user']));
        await prefs.setString('auth_method', 'apple');
        await prefs.setString('apple_user_id', data['token']);

        await SessionManager.saveSession(data['token']);

        // Sauvegarder TOUTES les informations pour l'accès hors ligne
        await SessionManager.saveAllUserInfo(data['user']);

        String savedZoneBenefCode = finalCountryCode;
        await ZoneBenefManager.saveZoneBenef(savedZoneBenefCode);
        await prefs.setString('country_code', finalCountryCode);
        await prefs.setString('country_name', finalCountryName);

        // Préchargement des données
        await _preloadDataForGoogleRegistration(data["token"], finalCountryName);

        // Redirection
        await _handlePostRegistrationNavigationByCode(
            data['user']['nom'], data["token"], savedZoneBenefCode);
      } else {
        throw Exception(data['error'] ?? 'Erreur lors de la finalisation');
      }
    } catch (e) {
      print('❌ [AppleAuth] Erreur finalisation: $e');
      rethrow;
    }
  }

  // ========== DÉCONNEXION GOOGLE ==========
  static Future<void> signOutGoogle() async {
    try {
      await _initializeGoogleSignIn();
      await _googleSignIn.signOut();
      //print('🔵 [GoogleAuth] Déconnexion Google réussie');
    } catch (e) {
      //print('❌ [GoogleAuth] Erreur déconnexion Google: $e');
    }
  }
}

// ========== 2. NOUVEAU GESTIONNAIRE ZONE_BENEF ==========

class ZoneBenefManager {
  static const String _keyZoneBenef = 'zone_benef';

  // ========== SAUVEGARDE ZONE_BENEF ==========
  static Future<void> saveZoneBenef(String? zoneBenef) async {
    try {
      if (zoneBenef == null || zoneBenef.isEmpty) {
        //print('⚠️ zone_benef est null ou vide');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyZoneBenef, zoneBenef);

      //print('💾 zone_benef sauvegardée: $zoneBenef');
    } catch (e) {
      //print('❌ Erreur sauvegarde zone_benef: $e');
    }
  }

  // ========== RÉCUPÉRATION ZONE_BENEF ==========
  static Future<String?> getZoneBenef() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final zoneBenef = prefs.getString(_keyZoneBenef);

      //print('📱 zone_benef récupérée: $zoneBenef');
      return zoneBenef;
    } catch (e) {
      //print('❌ Erreur récupération zone_benef: $e');
      return null;
    }
  }

  // ========== SUPPRESSION ZONE_BENEF ==========
  static Future<void> clearZoneBenef() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyZoneBenef);
      //print('🗑️ zone_benef supprimée');
    } catch (e) {
      //print('❌ Erreur suppression zone_benef: $e');
    }
  }

  // ========== VÉRIFICATION EXISTENCE ==========
  static Future<bool> hasZoneBenef() async {
    final zoneBenef = await getZoneBenef();
    return zoneBenef != null && zoneBenef.isNotEmpty;
  }
}

// ========== 3. GESTIONNAIRE DE NAVIGATION ==========

class NavigationManager {
  static String? _currentHomePage;

  static void setCurrentHomePage(String pageType) {
    _currentHomePage = pageType;
    //print('📍 [NavigationManager] Page d\'accueil définie: $pageType');
  }

  static String getCurrentHomePage() {
    return _currentHomePage ?? 'HomePage';
  }

  static Widget getHomePageWidget(RouteObserver<PageRoute> routeObserver) {
    if (_currentHomePage == 'HomePageDias') {
      return const HomePageDias();
    } else {
      return HomePage(routeObserver: routeObserver);
    }
  }

  // ========== NAVIGATION BASÉE SUR ZONE_BENEF_CODE ==========
  static void navigateBasedOnZoneBenef(
      BuildContext context, String? zoneBenefCode,
      {RouteObserver<PageRoute>? routeObserver}) {
    try {
      if (!context.mounted) return;

      //print('🎯 Navigation basée sur zone_benef_code: $zoneBenefCode');

      String finalCode = zoneBenefCode?.toUpperCase() ?? 'CG';

      if (finalCode == 'CG') {
        // Congo (code CG) -> HomePage original
        //print('🇨🇬 Redirection vers HomePage (Congo - CG)');
        setCurrentHomePage('HomePage');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
                routeObserver: routeObserver ?? RouteObserver<PageRoute>()),
          ),
          (route) => false,
        );
      } else {
        // Autres zones -> HomePageDias
        //print('🌍 Redirection vers HomePageDias (zone_benef_code: $finalCode)');
        setCurrentHomePage('HomePageDias');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const HomePageDias(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      //print('❌ Erreur lors de la redirection: $e');
      // En cas d'erreur, rediriger vers HomePage par défaut
      if (context.mounted) {
        setCurrentHomePage('HomePage');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
                routeObserver: routeObserver ?? RouteObserver<PageRoute>()),
          ),
          (route) => false,
        );
      }
    }
  }

  static bool isCongo(String? zoneBenefCode) {
    return zoneBenefCode?.toUpperCase() == 'CG';
  }

  static Future<void> conditionalNavigate(BuildContext context,
      {RouteObserver<PageRoute>? routeObserver}) async {
    final zoneBenefCode = await ZoneBenefManager.getZoneBenef();
    navigateBasedOnZoneBenef(context, zoneBenefCode,
        routeObserver: routeObserver);
  }
}

// ========== 6. MÉTHODES UTILITAIRES SUPPLÉMENTAIRES ==========

extension ZoneBenefExtension on BuildContext {
  // Extension pour faciliter la navigation depuis n'importe quel widget
  Future<void> navigateByZoneBenef(
      {RouteObserver<PageRoute>? routeObserver}) async {
    await NavigationManager.conditionalNavigate(this,
        routeObserver: routeObserver);
  }
}

// Fonction globale pour usage facile
Future<bool> isCongoUser() async {
  final zoneBenef = await ZoneBenefManager.getZoneBenef();
  return NavigationManager.isCongo(zoneBenef);
}

class SessionManager {
  static const String _tokenKey = 'user_token';
  static String? _cachedToken;
  static bool? _cachedLoginStatus;
  static DateTime? _lastVerificationTime;

  static Future<String?> getToken() async {
    // Utiliser le cache si disponible
    if (_cachedToken != null) {
      return _cachedToken;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Vérifier d'abord la clé principale pour un accès plus rapide
      String? token = prefs.getString(_tokenKey);

      if (token != null) {
        _cachedToken = token;
        return token;
      }

      // Vérifier les clés alternatives seulement si nécessaire
      final alternativeKeys = [
        'flutter.$_tokenKey',
        'flutter.flutter.$_tokenKey'
      ];
      for (var key in alternativeKeys) {
        token = prefs.getString(key);
        if (token != null) {
          _cachedToken = token;

          // Consolider le token en arrière-plan sans bloquer
          _consolidateTokenInBackground(token, key, prefs);
          return token;
        }
      }
      return null;
    } catch (e) {
      //print('Erreur récupération token: $e');
      return null;
    }
  }

// Méthode pour consolider le token en arrière-plan
  static void _consolidateTokenInBackground(
      String token, String key, SharedPreferences prefs) {
    // Exécuter en arrière-plan après avoir retourné le token
    Future.microtask(() async {
      try {
        // Sauvegarder dans la clé principale
        await prefs.setString(_tokenKey, token);

        // Nettoyer l'ancienne clé
        if (key != _tokenKey) {
          await prefs.remove(key);
        }

        // Mise à jour de la dernière connexion et du système d'exploitation en arrière-plan
        String os = Platform.isAndroid ? 'Android' : 'iOS';
        http.get(
          Uri.parse('${baseUrl}get_user_apk_wpay_v3_test/$token'),
          headers: {
            "Content-Type": "application/json",
            "X-Operating-System": os,
            "X-Last-Connection": DateTime.now().toIso8601String()
          },
          // ignore: body_might_complete_normally_catch_error
        ).catchError((e) {
          //print('Erreur mise à jour connexion: $e');
        });

        // ✅ NOUVEAU: Envoyer le Player ID OneSignal au backend après consolidation du token
        await _sendPlayerIdAfterLogin();
      } catch (e) {
        //print('Erreur consolidation token: $e');
      }
    });
  }

  // ✅ NOUVEAU: Envoyer le Player ID OneSignal stocké localement après connexion
  static Future<void> _sendPlayerIdAfterLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playerId = prefs.getString('onesignal_player_id');

      if (playerId == null || playerId.isEmpty) {
        return;
      }

      final userId = await getToken();
      if (userId == null || userId.isEmpty) {
        return;
      }

      // Envoyer le player_id au backend
      await http.put(
        Uri.parse('https://api.live.wortis.cg/api/apk_update/player_id/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'player_id': playerId}),
      );
    } catch (e) {
      // Silently fail
    }
  }

  static Future<bool> isLoggedIn() async {
    // Utiliser le cache si disponible et récent (moins de 30 minutes)
    if (_cachedLoginStatus != null && _lastVerificationTime != null) {
      final difference = DateTime.now().difference(_lastVerificationTime!);
      if (difference.inMinutes < 30) {
        return _cachedLoginStatus!;
      }
    }

    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        _cachedLoginStatus = false;
        return false;
      }

      // Créer une réponse par défaut pour éviter les erreurs de variables non initialisées
      http.Response response;

      try {
        // Ajouter un timeout pour éviter les blocages longs
        response = await http.get(
            Uri.parse('${baseUrl}get_user_apk_wpay_v3_test_test/$token'),
            headers: {
              "Content-Type": "application/json"
            }).timeout(const Duration(seconds: 5));
      } catch (timeoutError) {
        //print('Timeout lors de la vérification de session: $timeoutError');

        // En cas de timeout, utiliser le cache si disponible,
        // sinon considérer la session comme valide et mettre à jour plus tard
        if (_cachedLoginStatus != null) {
          return _cachedLoginStatus!;
        }

        // Si pas de cache, on considère la session comme valide par défaut
        // et on mettra à jour en arrière-plan
        _cachedLoginStatus = true;
        _lastVerificationTime = DateTime.now();

        // Tenter une vérification en arrière-plan
        Future.microtask(() async {
          try {
            final bgResponse = await http.get(
                Uri.parse('${baseUrl}get_user_apk_wpay_v3_test/$token'),
                headers: {
                  "Content-Type": "application/json"
                }).timeout(const Duration(seconds: 10));

            _cachedLoginStatus = bgResponse.statusCode == 200;
            _lastVerificationTime = DateTime.now();
          } catch (e) {
            //print('Erreur vérification en arrière-plan: $e');
          }
        });

        return true;
      }

      final isValid = response.statusCode == 200;
      _cachedLoginStatus = isValid;
      _lastVerificationTime = DateTime.now();

      return isValid;
    } catch (e) {
      //print('Erreur vérification session: $e');

      // En cas d'erreur, utiliser le cache si disponible
      if (_cachedLoginStatus != null) {
        return _cachedLoginStatus!;
      }

      // Sinon, considérer la session comme invalide
      _cachedLoginStatus = false;
      return false;
    }
  }

  static Future<void> saveSession(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      _cachedToken = token;
      _cachedLoginStatus = true;
      _lastVerificationTime = DateTime.now();
    } catch (e) {
      //print('Erreur sauvegarde token: $e');
    }
  }

  /// Sauvegarde les informations utilisateur pour l'accès hors ligne (sans données sensibles)
  static Future<void> saveAllUserInfo(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Filtrer les données sensibles
      final filteredData = Map<String, dynamic>.from(userData);
      final keysToRemove = ['_id', 'check_verif', 'role', 'secure_token', 'token'];

      for (var key in keysToRemove) {
        filteredData.remove(key);
      }

      // Sauvegarder les données filtrées en JSON
      await prefs.setString('offline_user_data', jsonEncode(filteredData));
      print('✅ [SessionManager] Informations utilisateur sauvegardées pour accès hors ligne');
      print('   Données sauvegardées: ${filteredData.keys.toList()}');
      print('   Données filtrées supprimées: $keysToRemove');
    } catch (e) {
      print('❌ [SessionManager] Erreur sauvegarde infos utilisateur: $e');
    }
  }

  /// Récupère TOUTES les informations utilisateur sauvegardées
  static Future<Map<String, dynamic>> getAllUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString('offline_user_data');

      if (userDataJson != null && userDataJson.isNotEmpty) {
        return jsonDecode(userDataJson) as Map<String, dynamic>;
      }

      return {};
    } catch (e) {
      print('❌ [SessionManager] Erreur récupération infos utilisateur: $e');
      return {};
    }
  }

  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove('flutter.$_tokenKey');
      await prefs.remove('flutter.flutter.$_tokenKey');
      // Supprimer aussi les données offline
      await prefs.remove('offline_user_data');
      await prefs.remove('user_infos');
      _cachedToken = null;
      _cachedLoginStatus = null;
      _lastVerificationTime = null;
    } catch (e) {
      //print('Erreur nettoyage session: $e');
    }
  }

  static Future<void> checkSessionAndNavigate({
    required BuildContext context,
    required dynamic authenticatedRoute,
    required Widget unauthenticatedRoute,
  }) async {
    final token = await getToken();
    if (!context.mounted) return;

    if (token != null) {
      if (authenticatedRoute is Widget) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => authenticatedRoute),
        );
      } else if (authenticatedRoute is PageRouteBuilder) {
        Navigator.push(context, authenticatedRoute);
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => unauthenticatedRoute),
      );
    }
  }

  static Future<void> checkSession({
    required BuildContext context,
    Widget? unauthenticatedRoute,
  }) async {
    try {
      final isLogged = await isLoggedIn();
      if (!isLogged && context.mounted) {
        final Widget defaultRoute =
            unauthenticatedRoute ?? const AuthentificationPage();
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                defaultRoute,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeOutCubic;
              var tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                  position: animation.drive(tween), child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      //print('Erreur navigation session: $e');
      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthentificationPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
                position: animation.drive(tween), child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
        (route) => false,
      );
    }
  }
}

class DynamicFormBuilder extends StatelessWidget {
  final UserData userData;
  final bool isEditing;
  final Map<String, TextEditingController> controllers;
  final Function(String, String) onFieldChanged;

  const DynamicFormBuilder({
    super.key,
    required this.userData,
    required this.isEditing,
    required this.controllers,
    required this.onFieldChanged,
    required Map fieldIcons,
    required List fields,
    required InputDecoration Function(dynamic fieldName) fieldDecorations,
  });

  Map<String, List<FormField>> get groupedFields {
    final groups = <String, List<FormField>>{};
    for (var field in userData.fields) {
      if (!groups.containsKey(field.section)) {
        groups[field.section] = [];
      }
      groups[field.section]!.add(field);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: groupedFields.entries.map((entry) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006699),
                  ),
                ),
                const SizedBox(height: 16),
                ...entry.value.map((field) => _buildField(field)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildField(FormField field) {
    if (!controllers.containsKey(field.name)) {
      controllers[field.name] =
          TextEditingController(text: userData.getFieldValue(field.name) ?? '');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child:
          isEditing ? _buildEditableField(field) : _buildReadOnlyField(field),
    );
  }

  Widget _buildEditableField(FormField field) {
    return TextFormField(
      controller: controllers[field.name],
      decoration: InputDecoration(
        labelText: field.label,
        icon: Icon(_getIconData(field.icon)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onChanged: (value) => onFieldChanged(field.name, value),
    );
  }

  Widget _buildReadOnlyField(FormField field) {
    return ListTile(
      leading: Icon(_getIconData(field.icon)),
      title: Text(field.label),
      subtitle: Text(userData.getFieldValue(field.name) ?? ''),
    );
  }

  IconData _getIconData(String icon) {
    switch (icon) {
      case 'person':
        return Icons.person;
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      default:
        return Icons.info;
    }
  }
}

// Classe pour gérer la connexion - VERSION CORRIGÉE
class ConnectivityManager {
  final Connectivity _connectivity = Connectivity();
  bool _isDialogShowing = false;
  static bool wasDialogEverShown = false;
  BuildContext context;
  bool _isInitialized = false;
  bool _isRetrying = false; // ✅ NOUVEAU: État de retry

  ConnectivityManager(this.context) {
    if (!_isInitialized) {
      initConnectivity();
      _isInitialized = true;
    }
  }

  Future<void> initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result.contains(ConnectivityResult.none)) {
        showNoConnectionDialog();
      }

      _connectivity.onConnectivityChanged
          .listen((List<ConnectivityResult> results) async {
        // Vérifier directement les résultats
        if (results.contains(ConnectivityResult.none)) {
          if (!_isDialogShowing) {
            showNoConnectionDialog();
          }
        } else {
          // ✅ Connexion rétablie automatiquement
          if (_isDialogShowing && !_isRetrying) {
            // Vérifier une fois de plus avant de fermer
            final hasRealConnection = await checkConnectivity();
            if (hasRealConnection) {
              _closeDialogWithSuccess();
            }
          }
        }
      });
    } catch (e) {
      //print('Erreur lors de l\'initialisation de la connectivité: $e');
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }

      // Utiliser une approche plus sûre pour vérifier la connexion Internet
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 5));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (e) {
        // En cas d'échec du lookup, essayer une alternative
        try {
          final result = await InternetAddress.lookup('8.8.8.8')
              .timeout(const Duration(seconds: 3));
          return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        } catch (e2) {
          //print('Erreur lors de la vérification de la connexion: $e2');
          return false;
        }
      }
    } catch (e) {
      //print('Erreur lors de la vérification de la connectivité: $e');
      return false;
    }
  }

  // ✅ NOUVELLE MÉTHODE pour fermer le dialogue avec succès
  Future<void> _closeDialogWithSuccess() async {
    if (!_isDialogShowing || !context.mounted) return;

    try {
      await _showSuccessDialog(context);
    } catch (e) {
      //print('Erreur lors de l\'affichage du succès: $e');
      // Fermer quand même le dialogue
      if (context.mounted) {
        Navigator.of(context).pop();
        _isDialogShowing = false;
      }
    }
  }

  Future<void> _showSuccessDialog(BuildContext dialogContext) async {
    if (!dialogContext.mounted) return;

    BuildContext? successDialogContext;

    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) {
        successDialogContext = context;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_rounded,
                  size: 50,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Connexion rétablie !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          content: const Text(
            'Vous êtes à nouveau connecté à Internet. Profitez pleinement de l\'application !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(seconds: 3));

    // ✅ CORRECTION: Vérifier tous les contextes avant fermeture
    if (successDialogContext != null && successDialogContext!.mounted) {
      try {
        await Navigator.of(successDialogContext!).maybePop();
      } catch (e) {
        //print('Erreur fermeture success dialog: $e');
      }
    }

    if (dialogContext.mounted) {
      try {
        // await Navigator.of(dialogContext).maybePop();
        Navigator.of(dialogContext).popUntil((route) => route.isFirst);
      } catch (e) {
        //print('Erreur fermeture main dialog: $e');
      }
    }

    _isDialogShowing = false;
    _isRetrying = false;
  }

  // ✅ MÉTHODE RETRY CORRIGÉE avec indicateur de chargement
  Future<void> _retryConnection(
      BuildContext dialogContext, StateSetter setState) async {
    if (_isRetrying) return; // Éviter les appels multiples

    setState(() {
      _isRetrying = true;
    });

    try {
      //print('🔄 Début de la vérification de connexion...');

      bool hasConnection = false;

      try {
        // Timeout de 8 secondes pour la vérification
        hasConnection = await checkConnectivity().timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            //print('⏰ Timeout lors de la vérification de connectivité');
            return false;
          },
        );
      } catch (e) {
        //print('❌ Erreur lors de la vérification de connectivité: $e');
        hasConnection = false;
      }

      //print('📡 Résultat de la vérification: $hasConnection');

      if (hasConnection) {
        // ✅ Connexion rétablie -> succès
        //print('✅ Connexion rétablie - fermeture avec succès');
        await _showSuccessDialog(dialogContext);
      } else {
        // ❌ Pas de connexion -> garder ouvert et montrer erreur
        //print('❌ Pas de connexion - dialogue reste ouvert');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.white,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Connexion impossible. Vérifiez vos paramètres réseau.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // ✅ IMPORTANT: Réinitialiser l'état de retry SANS fermer le dialogue
        setState(() {
          _isRetrying = false;
        });
      }
    } catch (e) {
      //print('💥 Erreur générale lors de la tentative de reconnexion: $e');

      // ✅ En cas d'erreur, montrer un message mais GARDER le dialogue ouvert
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Erreur lors de la vérification. Réessayez dans un moment.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // ✅ Réinitialiser l'état SANS fermer le dialogue
      setState(() {
        _isRetrying = false;
      });
    }
  }

  void showNoConnectionDialog() {
    if (_isDialogShowing) return;

    _isDialogShowing = true;
    wasDialogEverShown = true;

    if (!context.mounted) return;

    // Naviguer vers la page de perte de connexion
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (context, _, __) => const NoConnectionPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) {
      _isDialogShowing = false;
    });
  }
}

class UserService {
  static Future<UserData> getUserInfo(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_user_apk_wpay_v3_test/$token'),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      return UserData.fromJson(jsonDecode(response.body));
    }
    throw Exception('Erreur ${response.statusCode}');
  }

  static Future<bool> deleteTransaction(
      String token, String transactionId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_tpe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'clientTransID': transactionId}),
      );

      if (response.statusCode == 200) {
        return true;
      }

      return false;
    } catch (e) {
      //print('Erreur lors de la suppression: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> updateUserInfo(
      String token, Map<String, dynamic> userData) async {
    try {
      //print('Début de la mise à jour - Données: $userData');

      // Au lieu d'encoder le token, on retire juste les espaces en début/fin
      final cleanToken = token.trim();

      final response = await http.put(
        Uri.parse('$baseUrl/update_user_apk_wpay_v2_test/$token'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(userData),
      );

      //print('Réponse du serveur: ${response.body}');
      final data = jsonDecode(response.body);

      // Nettoyer les données avant envoi
      Map<String, dynamic> cleanData = {};
      userData.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          cleanData[key] = value;
        }
      });

      switch (data['Code']) {
        case 200:
          return {
            'success': true,
            'message': data['messages'],
            'user': data['user']
          };

        case 304:
          return {
            'success': false,
            'message': 'Aucune modification n\'a été effectuée'
          };

        case 400:
          return {
            'success': false,
            'message': data['messages'] ?? 'Token invalide'
          };

        case 404:
          return {
            'success': false,
            'message': data['messages'] ?? 'Utilisateur non trouvé'
          };

        case 500:
          return {
            'success': false,
            'message': data['messages'] ?? 'Erreur serveur'
          };

        default:
          return {
            'success': false,
            'message': data['messages'] ?? 'Une erreur inattendue est survenue'
          };
      }
    } catch (e) {
      //print('Erreur lors de la mise à jour: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion, veuillez réessayer'
      };
    }
  }

  static Future<int> getbalanceMiles(String token) async {
    try {
      final response = await http.get(
          Uri.parse('$baseUrl/get_user_apk_wpay_v3_test/$token'),
          headers: {"Content-Type": "application/json"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['miles'] as int;
      }
      return 0;
    } catch (e) {
      //print('Erreur miles: $e');
      return 0;
    }
  }

  static Future<List<Transaction>> getTransactions(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_user_apk_wpay_v3_test/$token'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> transactions = data['transac'] ?? [];

        print("📊 [UserService] Transactions reçues: ${transactions.length}");

        try {
          final result =
              transactions.map((json) => Transaction.fromJson(json)).toList();
          print(
              "✅ [UserService] Conversion réussie : ${result.length} transactions");

          // Log des types de transactions
          final momoCount =
              result.where((t) => t.typeTransaction == 'momo').length;
          final cardCount =
              result.where((t) => t.typeTransaction == 'carte').length;
          print("📱 Mobile Money: $momoCount, 💳 Cartes: $cardCount");

          return result;
        } catch (e) {
          print("❌ [UserService] Erreur lors de la conversion : $e");
          rethrow;
        }
      }
      print(
          "❌ [UserService] Status code différent de 200 : ${response.statusCode}");
      return [];
    } catch (e) {
      print("❌ [UserService] Erreur dans getTransactions : $e");
      rethrow;
    }
  }

  static Future<double> refreshBalance(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/wallet/balance'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": token,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['Code'] == 200) {
        return double.parse(data['solde'].toString());
      }
      throw Exception('Erreur de mise à jour du solde: ${data['Message']}');
    }
    throw Exception('Erreur ${response.statusCode}');
  }

  static Future<bool> updateBalance(String token, double amount) async {
    final response = await http.post(
      Uri.parse('$baseUrl/update_balance_apk_wpay_v2/$token'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({'amount': amount}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['Code'] == 200;
    }
    return false;
  }

  static Future<bool> processMobileMoneyPayment(
    String token,
    double amount,
    String phoneNumber,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/process_mobile_money_payment_apk_wpay_v2/$token'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'amount': amount,
        'phone_number': phoneNumber,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['Code'] == 200;
    }
    return false;
  }

  static Future<bool> processCardPayment(
    String token,
    double amount,
    String cardHolder,
    String phoneNumber,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/process_card_payment_apk_wpay_v2/$token'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'amount': amount,
        'card_holder': cardHolder,
        'phone_number': phoneNumber,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['Code'] == 200;
    }
    return false;
  }
}

/* Le overlay */
enum MessageType { success, error, info, loading, warning }

class CustomOverlay {
  static OverlayEntry? _currentOverlay;
  static bool _isVisible = false;
  static Timer? _dismissTimer;

  static void show({
    required BuildContext context,
    required String message,
    required MessageType type,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onActionPressed,
    bool isDismissible = true,
  }) {
    // Masquer le message précédent s'il existe
    hide();

    // Créer et afficher le nouveau message
    OverlayState? overlayState = Overlay.of(context);
    _currentOverlay = OverlayEntry(
      builder: (context) => _MessageOverlay(
        message: message,
        type: type,
        onDismiss: isDismissible ? hide : null,
        actionLabel: actionLabel,
        onActionPressed: onActionPressed,
      ),
    );

    _isVisible = true;
    overlayState.insert(_currentOverlay!);

    // Configurer le timer pour masquer automatiquement le message
    if (isDismissible && type != MessageType.loading) {
      _dismissTimer?.cancel();
      _dismissTimer = Timer(duration, () {
        hide();
      });
    }
  }

  static void hide() {
    _dismissTimer?.cancel();
    if (_isVisible && _currentOverlay != null) {
      _currentOverlay!.remove();
      _currentOverlay = null;
      _isVisible = false;
    }
  }

  static void showSuccess(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    show(
      context: context,
      message: message,
      type: MessageType.success,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    show(
      context: context,
      message: message,
      type: MessageType.error,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: Duration(seconds: 60), // ou supprime la durée
    );
  }

  static void showLoading(
    BuildContext context, {
    required String message,
  }) {
    show(
      context: context,
      message: message,
      type: MessageType.loading,
      isDismissible: false,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    show(
      context: context,
      message: message,
      type: MessageType.info,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  static void showWarning(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    show(
      context: context,
      message: message,
      type: MessageType.warning,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }
}

class _MessageOverlay extends StatefulWidget {
  final String message;
  final MessageType type;
  final VoidCallback? onDismiss;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const _MessageOverlay({
    required this.message,
    required this.type,
    this.onDismiss,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  _MessageOverlayState createState() => _MessageOverlayState();
}

class _MessageOverlayState extends State<_MessageOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    ConnectivityManager(context).initConnectivity;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: -100.0, // L'animation commence en dessous de l'écran
      end: 0.0, // Et remonte vers sa position finale
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case MessageType.success:
        return Colors.green.shade600;
      case MessageType.error:
        return Colors.red.shade600;
      case MessageType.info:
        return Colors.blue.shade600;
      case MessageType.loading:
        return Colors.blue.shade600;
      case MessageType.warning:
        return Colors.orange.shade600;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case MessageType.success:
        return Icons.check_circle_outline;
      case MessageType.error:
        return Icons.error_outline;
      case MessageType.info:
        return Icons.info_outline;
      case MessageType.loading:
        return Icons.hourglass_empty;
      case MessageType.warning:
        return Icons.warning_amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            if (widget.onDismiss != null)
              GestureDetector(
                onTap: widget.onDismiss,
                child: Container(
                  color: Colors.transparent,
                  height: double.infinity,
                  width: double.infinity,
                ),
              ),
            Positioned(
              // Modifié pour positionner en bas
              bottom:
                  _animation.value + MediaQuery.of(context).padding.bottom + 10,
              left: 16,
              right: 16,
              child: SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getBackgroundColor(),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _getBackgroundColor().withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(
                                0, -4), // Modifié pour l'ombre vers le haut
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                if (widget.type == MessageType.loading)
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                else
                                  Icon(
                                    _getIcon(),
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.message,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (widget.onDismiss != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                    onPressed: widget.onDismiss,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.actionLabel != null &&
                              widget.onActionPressed != null)
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                              ),
                              child: TextButton(
                                onPressed: widget.onActionPressed,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  widget.actionLabel!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ========== CLASSES GÉOLOCALISATION ==========
class Country {
  final String name;
  final String code;
  final String dialCode;
  final String flag;
  final String region;

  const Country({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
    required this.region,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Country &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() {
    return 'Country{name: $name, code: $code, dialCode: $dialCode, region: $region}';
  }
}

enum LocationStatus {
  detected, // Pays détecté avec succès
  fallback, // Utilisation du pays par défaut
  error, // Erreur lors de la détection
}

// ========== LISTE DES PAYS ==========
const List<Country> countries = [
  // Afrique Centrale
  Country(
      name: 'Congo',
      code: 'CG',
      dialCode: '+242',
      flag: '🇨🇬',
      region: 'Afrique Centrale'),
  Country(
      name: 'Congo (RDC)',
      code: 'CD',
      dialCode: '+243',
      flag: '🇨🇩',
      region: 'Afrique Centrale'),
  Country(
      name: 'Cameroun',
      code: 'CM',
      dialCode: '+237',
      flag: '🇨🇲',
      region: 'Afrique Centrale'),
  Country(
      name: 'Gabon',
      code: 'GA',
      dialCode: '+241',
      flag: '🇬🇦',
      region: 'Afrique Centrale'),
  Country(
      name: 'Tchad',
      code: 'TD',
      dialCode: '+235',
      flag: '🇹🇩',
      region: 'Afrique Centrale'),
  Country(
      name: 'République centrafricaine',
      code: 'CF',
      dialCode: '+236',
      flag: '🇨🇫',
      region: 'Afrique Centrale'),
  Country(
      name: 'Guinée équatoriale',
      code: 'GQ',
      dialCode: '+240',
      flag: '🇬🇶',
      region: 'Afrique Centrale'),
  Country(
      name: 'São Tomé-et-Príncipe',
      code: 'ST',
      dialCode: '+239',
      flag: '🇸🇹',
      region: 'Afrique Centrale'),

  // Afrique de l'Ouest
  Country(
      name: "Côte d'Ivoire",
      code: 'CI',
      dialCode: '+225',
      flag: '🇨🇮',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Sénégal',
      code: 'SN',
      dialCode: '+221',
      flag: '🇸🇳',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Mali',
      code: 'ML',
      dialCode: '+223',
      flag: '🇲🇱',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Burkina Faso',
      code: 'BF',
      dialCode: '+226',
      flag: '🇧🇫',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Niger',
      code: 'NE',
      dialCode: '+227',
      flag: '🇳🇪',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Nigeria',
      code: 'NG',
      dialCode: '+234',
      flag: '🇳🇬',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Ghana',
      code: 'GH',
      dialCode: '+233',
      flag: '🇬🇭',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Bénin',
      code: 'BJ',
      dialCode: '+229',
      flag: '🇧🇯',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Togo',
      code: 'TG',
      dialCode: '+228',
      flag: '🇹🇬',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Guinée',
      code: 'GN',
      dialCode: '+224',
      flag: '🇬🇳',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Guinée-Bissau',
      code: 'GW',
      dialCode: '+245',
      flag: '🇬🇼',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Sierra Leone',
      code: 'SL',
      dialCode: '+232',
      flag: '🇸🇱',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Liberia',
      code: 'LR',
      dialCode: '+231',
      flag: '🇱🇷',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Mauritanie',
      code: 'MR',
      dialCode: '+222',
      flag: '🇲🇷',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Cap-Vert',
      code: 'CV',
      dialCode: '+238',
      flag: '🇨🇻',
      region: 'Afrique de l\'Ouest'),
  Country(
      name: 'Gambie',
      code: 'GM',
      dialCode: '+220',
      flag: '🇬🇲',
      region: 'Afrique de l\'Ouest'),

  // Afrique du Nord
  Country(
      name: 'Maroc',
      code: 'MA',
      dialCode: '+212',
      flag: '🇲🇦',
      region: 'Afrique du Nord'),
  Country(
      name: 'Algérie',
      code: 'DZ',
      dialCode: '+213',
      flag: '🇩🇿',
      region: 'Afrique du Nord'),
  Country(
      name: 'Tunisie',
      code: 'TN',
      dialCode: '+216',
      flag: '🇹🇳',
      region: 'Afrique du Nord'),
  Country(
      name: 'Libye',
      code: 'LY',
      dialCode: '+218',
      flag: '🇱🇾',
      region: 'Afrique du Nord'),
  Country(
      name: 'Égypte',
      code: 'EG',
      dialCode: '+20',
      flag: '🇪🇬',
      region: 'Afrique du Nord'),
  Country(
      name: 'Soudan',
      code: 'SD',
      dialCode: '+249',
      flag: '🇸🇩',
      region: 'Afrique du Nord'),

  // Afrique de l'Est
  Country(
      name: 'Éthiopie',
      code: 'ET',
      dialCode: '+251',
      flag: '🇪🇹',
      region: 'Afrique de l\'Est'),
  Country(
      name: 'Kenya',
      code: 'KE',
      dialCode: '+254',
      flag: '🇰🇪',
      region: 'Afrique de l\'Est'),
  Country(
      name: 'Tanzanie',
      code: 'TZ',
      dialCode: '+255',
      flag: '🇹🇿',
      region: 'Afrique de l\'Est'),
  Country(
      name: 'Ouganda',
      code: 'UG',
      dialCode: '+256',
      flag: '🇺🇬',
      region: 'Afrique de l\'Est'),
  Country(
      name: 'Rwanda',
      code: 'RW',
      dialCode: '+250',
      flag: '🇷🇼',
      region: 'Afrique de l\'Est'),
  Country(
      name: 'Burundi',
      code: 'BI',
      dialCode: '+257',
      flag: '🇧🇮',
      region: 'Afrique de l\'Est'),
  Country(
      name: 'Djibouti',
      code: 'DJ',
      dialCode: '+253',
      flag: '🇩🇯',
      region: 'Afrique de l\'Est'),
  Country(
      name: 'Érythrée',
      code: 'ER',
      dialCode: '+291',
      flag: '🇪🇷',
      region: 'Afrique de l\'Est'),
  Country(
      name: 'Somalie',
      code: 'SO',
      dialCode: '+252',
      flag: '🇸🇴',
      region: 'Afrique de l\'Est'),

  // Afrique Australe
  Country(
      name: 'Afrique du Sud',
      code: 'ZA',
      dialCode: '+27',
      flag: '🇿🇦',
      region: 'Afrique Australe'),
  Country(
      name: 'Zimbabwe',
      code: 'ZW',
      dialCode: '+263',
      flag: '🇿🇼',
      region: 'Afrique Australe'),
  Country(
      name: 'Botswana',
      code: 'BW',
      dialCode: '+267',
      flag: '🇧🇼',
      region: 'Afrique Australe'),
  Country(
      name: 'Namibie',
      code: 'NA',
      dialCode: '+264',
      flag: '🇳🇦',
      region: 'Afrique Australe'),
  Country(
      name: 'Zambie',
      code: 'ZM',
      dialCode: '+260',
      flag: '🇿🇲',
      region: 'Afrique Australe'),
  Country(
      name: 'Malawi',
      code: 'MW',
      dialCode: '+265',
      flag: '🇲🇼',
      region: 'Afrique Australe'),
  Country(
      name: 'Mozambique',
      code: 'MZ',
      dialCode: '+258',
      flag: '🇲🇿',
      region: 'Afrique Australe'),
  Country(
      name: 'Madagascar',
      code: 'MG',
      dialCode: '+261',
      flag: '🇲🇬',
      region: 'Afrique Australe'),
  Country(
      name: 'Maurice',
      code: 'MU',
      dialCode: '+230',
      flag: '🇲🇺',
      region: 'Afrique Australe'),
  Country(
      name: 'Seychelles',
      code: 'SC',
      dialCode: '+248',
      flag: '🇸🇨',
      region: 'Afrique Australe'),
  Country(
      name: 'Comores',
      code: 'KM',
      dialCode: '+269',
      flag: '🇰🇲',
      region: 'Afrique Australe'),
  Country(
      name: 'Lesotho',
      code: 'LS',
      dialCode: '+266',
      flag: '🇱🇸',
      region: 'Afrique Australe'),
  Country(
      name: 'Eswatini',
      code: 'SZ',
      dialCode: '+268',
      flag: '🇸🇿',
      region: 'Afrique Australe'),
  Country(
      name: 'Angola',
      code: 'AO',
      dialCode: '+244',
      flag: '🇦🇴',
      region: 'Afrique Australe'),

  // Europe Occidentale
  Country(
      name: 'France',
      code: 'FR',
      dialCode: '+33',
      flag: '🇫🇷',
      region: 'Europe Occidentale'),
  Country(
      name: 'Belgique',
      code: 'BE',
      dialCode: '+32',
      flag: '🇧🇪',
      region: 'Europe Occidentale'),
  Country(
      name: 'Allemagne',
      code: 'DE',
      dialCode: '+49',
      flag: '🇩🇪',
      region: 'Europe Occidentale'),
  Country(
      name: 'Espagne',
      code: 'ES',
      dialCode: '+34',
      flag: '🇪🇸',
      region: 'Europe Occidentale'),
  Country(
      name: 'Italie',
      code: 'IT',
      dialCode: '+39',
      flag: '🇮🇹',
      region: 'Europe Occidentale'),
  Country(
      name: 'Royaume-Uni',
      code: 'GB',
      dialCode: '+44',
      flag: '🇬🇧',
      region: 'Europe Occidentale'),
  Country(
      name: 'Suisse',
      code: 'CH',
      dialCode: '+41',
      flag: '🇨🇭',
      region: 'Europe Occidentale'),
  Country(
      name: 'Portugal',
      code: 'PT',
      dialCode: '+351',
      flag: '🇵🇹',
      region: 'Europe Occidentale'),
  Country(
      name: 'Pays-Bas',
      code: 'NL',
      dialCode: '+31',
      flag: '🇳🇱',
      region: 'Europe Occidentale'),
  Country(
      name: 'Autriche',
      code: 'AT',
      dialCode: '+43',
      flag: '🇦🇹',
      region: 'Europe Occidentale'),
  Country(
      name: 'Irlande',
      code: 'IE',
      dialCode: '+353',
      flag: '🇮🇪',
      region: 'Europe Occidentale'),
  Country(
      name: 'Luxembourg',
      code: 'LU',
      dialCode: '+352',
      flag: '🇱🇺',
      region: 'Europe Occidentale'),

  // Europe du Nord
  Country(
      name: 'Suède',
      code: 'SE',
      dialCode: '+46',
      flag: '🇸🇪',
      region: 'Europe du Nord'),
  Country(
      name: 'Norvège',
      code: 'NO',
      dialCode: '+47',
      flag: '🇳🇴',
      region: 'Europe du Nord'),
  Country(
      name: 'Danemark',
      code: 'DK',
      dialCode: '+45',
      flag: '🇩🇰',
      region: 'Europe du Nord'),
  Country(
      name: 'Finlande',
      code: 'FI',
      dialCode: '+358',
      flag: '🇫🇮',
      region: 'Europe du Nord'),
  Country(
      name: 'Islande',
      code: 'IS',
      dialCode: '+354',
      flag: '🇮🇸',
      region: 'Europe du Nord'),

  // Europe de l'Est
  Country(
      name: 'Russie',
      code: 'RU',
      dialCode: '+7',
      flag: '🇷🇺',
      region: 'Europe de l\'Est'),
  Country(
      name: 'Pologne',
      code: 'PL',
      dialCode: '+48',
      flag: '🇵🇱',
      region: 'Europe de l\'Est'),
  Country(
      name: 'République tchèque',
      code: 'CZ',
      dialCode: '+420',
      flag: '🇨🇿',
      region: 'Europe de l\'Est'),
  Country(
      name: 'Hongrie',
      code: 'HU',
      dialCode: '+36',
      flag: '🇭🇺',
      region: 'Europe de l\'Est'),
  Country(
      name: 'Slovaquie',
      code: 'SK',
      dialCode: '+421',
      flag: '🇸🇰',
      region: 'Europe de l\'Est'),
  Country(
      name: 'Roumanie',
      code: 'RO',
      dialCode: '+40',
      flag: '🇷🇴',
      region: 'Europe de l\'Est'),
  Country(
      name: 'Bulgarie',
      code: 'BG',
      dialCode: '+359',
      flag: '🇧🇬',
      region: 'Europe de l\'Est'),
  Country(
      name: 'Croatie',
      code: 'HR',
      dialCode: '+385',
      flag: '🇭🇷',
      region: 'Europe de l\'Est'),
  Country(
      name: 'Serbie',
      code: 'RS',
      dialCode: '+381',
      flag: '🇷🇸',
      region: 'Europe de l\'Est'),
  Country(
      name: 'Ukraine',
      code: 'UA',
      dialCode: '+380',
      flag: '🇺🇦',
      region: 'Europe de l\'Est'),

  // Amériques du Nord
  Country(
      name: 'États-Unis',
      code: 'US',
      dialCode: '+1',
      flag: '🇺🇸',
      region: 'Amérique du Nord'),
  Country(
      name: 'Canada',
      code: 'CA',
      dialCode: '+1',
      flag: '🇨🇦',
      region: 'Amérique du Nord'),
  Country(
      name: 'Mexique',
      code: 'MX',
      dialCode: '+52',
      flag: '🇲🇽',
      region: 'Amérique du Nord'),

  // Amérique Centrale et Caraïbes
  Country(
      name: 'Guatemala',
      code: 'GT',
      dialCode: '+502',
      flag: '🇬🇹',
      region: 'Amérique Centrale'),
  Country(
      name: 'Costa Rica',
      code: 'CR',
      dialCode: '+506',
      flag: '🇨🇷',
      region: 'Amérique Centrale'),
  Country(
      name: 'Panama',
      code: 'PA',
      dialCode: '+507',
      flag: '🇵🇦',
      region: 'Amérique Centrale'),
  Country(
      name: 'Jamaïque',
      code: 'JM',
      dialCode: '+1876',
      flag: '🇯🇲',
      region: 'Caraïbes'),
  Country(
      name: 'Haïti',
      code: 'HT',
      dialCode: '+509',
      flag: '🇭🇹',
      region: 'Caraïbes'),
  Country(
      name: 'République dominicaine',
      code: 'DO',
      dialCode: '+1809',
      flag: '🇩🇴',
      region: 'Caraïbes'),

  // Amérique du Sud
  Country(
      name: 'Brésil',
      code: 'BR',
      dialCode: '+55',
      flag: '🇧🇷',
      region: 'Amérique du Sud'),
  Country(
      name: 'Argentine',
      code: 'AR',
      dialCode: '+54',
      flag: '🇦🇷',
      region: 'Amérique du Sud'),
  Country(
      name: 'Chili',
      code: 'CL',
      dialCode: '+56',
      flag: '🇨🇱',
      region: 'Amérique du Sud'),
  Country(
      name: 'Pérou',
      code: 'PE',
      dialCode: '+51',
      flag: '🇵🇪',
      region: 'Amérique du Sud'),
  Country(
      name: 'Colombie',
      code: 'CO',
      dialCode: '+57',
      flag: '🇨🇴',
      region: 'Amérique du Sud'),
  Country(
      name: 'Venezuela',
      code: 'VE',
      dialCode: '+58',
      flag: '🇻🇪',
      region: 'Amérique du Sud'),
  Country(
      name: 'Équateur',
      code: 'EC',
      dialCode: '+593',
      flag: '🇪🇨',
      region: 'Amérique du Sud'),
  Country(
      name: 'Bolivie',
      code: 'BO',
      dialCode: '+591',
      flag: '🇧🇴',
      region: 'Amérique du Sud'),
  Country(
      name: 'Paraguay',
      code: 'PY',
      dialCode: '+595',
      flag: '🇵🇾',
      region: 'Amérique du Sud'),
  Country(
      name: 'Uruguay',
      code: 'UY',
      dialCode: '+598',
      flag: '🇺🇾',
      region: 'Amérique du Sud'),
  Country(
      name: 'Guyane',
      code: 'GY',
      dialCode: '+592',
      flag: '🇬🇾',
      region: 'Amérique du Sud'),
  Country(
      name: 'Suriname',
      code: 'SR',
      dialCode: '+597',
      flag: '🇸🇷',
      region: 'Amérique du Sud'),

  // Asie de l'Est
  Country(
      name: 'Chine',
      code: 'CN',
      dialCode: '+86',
      flag: '🇨🇳',
      region: 'Asie de l\'Est'),
  Country(
      name: 'Japon',
      code: 'JP',
      dialCode: '+81',
      flag: '🇯🇵',
      region: 'Asie de l\'Est'),
  Country(
      name: 'Corée du Sud',
      code: 'KR',
      dialCode: '+82',
      flag: '🇰🇷',
      region: 'Asie de l\'Est'),
  Country(
      name: 'Corée du Nord',
      code: 'KP',
      dialCode: '+850',
      flag: '🇰🇵',
      region: 'Asie de l\'Est'),
  Country(
      name: 'Mongolie',
      code: 'MN',
      dialCode: '+976',
      flag: '🇲🇳',
      region: 'Asie de l\'Est'),

  // Asie du Sud-Est
  Country(
      name: 'Thaïlande',
      code: 'TH',
      dialCode: '+66',
      flag: '🇹🇭',
      region: 'Asie du Sud-Est'),
  Country(
      name: 'Vietnam',
      code: 'VN',
      dialCode: '+84',
      flag: '🇻🇳',
      region: 'Asie du Sud-Est'),
  Country(
      name: 'Malaisie',
      code: 'MY',
      dialCode: '+60',
      flag: '🇲🇾',
      region: 'Asie du Sud-Est'),
  Country(
      name: 'Singapour',
      code: 'SG',
      dialCode: '+65',
      flag: '🇸🇬',
      region: 'Asie du Sud-Est'),
  Country(
      name: 'Indonésie',
      code: 'ID',
      dialCode: '+62',
      flag: '🇮🇩',
      region: 'Asie du Sud-Est'),
  Country(
      name: 'Philippines',
      code: 'PH',
      dialCode: '+63',
      flag: '🇵🇭',
      region: 'Asie du Sud-Est'),
  Country(
      name: 'Cambodge',
      code: 'KH',
      dialCode: '+855',
      flag: '🇰🇭',
      region: 'Asie du Sud-Est'),
  Country(
      name: 'Laos',
      code: 'LA',
      dialCode: '+856',
      flag: '🇱🇦',
      region: 'Asie du Sud-Est'),
  Country(
      name: 'Myanmar',
      code: 'MM',
      dialCode: '+95',
      flag: '🇲🇲',
      region: 'Asie du Sud-Est'),
  Country(
      name: 'Brunei',
      code: 'BN',
      dialCode: '+673',
      flag: '🇧🇳',
      region: 'Asie du Sud-Est'),

  // Asie du Sud
  Country(
      name: 'Inde',
      code: 'IN',
      dialCode: '+91',
      flag: '🇮🇳',
      region: 'Asie du Sud'),
  Country(
      name: 'Pakistan',
      code: 'PK',
      dialCode: '+92',
      flag: '🇵🇰',
      region: 'Asie du Sud'),
  Country(
      name: 'Bangladesh',
      code: 'BD',
      dialCode: '+880',
      flag: '🇧🇩',
      region: 'Asie du Sud'),
  Country(
      name: 'Sri Lanka',
      code: 'LK',
      dialCode: '+94',
      flag: '🇱🇰',
      region: 'Asie du Sud'),
  Country(
      name: 'Népal',
      code: 'NP',
      dialCode: '+977',
      flag: '🇳🇵',
      region: 'Asie du Sud'),
  Country(
      name: 'Bhoutan',
      code: 'BT',
      dialCode: '+975',
      flag: '🇧🇹',
      region: 'Asie du Sud'),
  Country(
      name: 'Afghanistan',
      code: 'AF',
      dialCode: '+93',
      flag: '🇦🇫',
      region: 'Asie du Sud'),

  // Moyen-Orient
  Country(
      name: 'Arabie saoudite',
      code: 'SA',
      dialCode: '+966',
      flag: '🇸🇦',
      region: 'Moyen-Orient'),
  Country(
      name: 'Émirats arabes unis',
      code: 'AE',
      dialCode: '+971',
      flag: '🇦🇪',
      region: 'Moyen-Orient'),
  Country(
      name: 'Qatar',
      code: 'QA',
      dialCode: '+974',
      flag: '🇶🇦',
      region: 'Moyen-Orient'),
  Country(
      name: 'Koweït',
      code: 'KW',
      dialCode: '+965',
      flag: '🇰🇼',
      region: 'Moyen-Orient'),
  Country(
      name: 'Bahreïn',
      code: 'BH',
      dialCode: '+973',
      flag: '🇧🇭',
      region: 'Moyen-Orient'),
  Country(
      name: 'Oman',
      code: 'OM',
      dialCode: '+968',
      flag: '🇴🇲',
      region: 'Moyen-Orient'),
  Country(
      name: 'Israël',
      code: 'IL',
      dialCode: '+972',
      flag: '🇮🇱',
      region: 'Moyen-Orient'),
  Country(
      name: 'Liban',
      code: 'LB',
      dialCode: '+961',
      flag: '🇱🇧',
      region: 'Moyen-Orient'),
  Country(
      name: 'Jordanie',
      code: 'JO',
      dialCode: '+962',
      flag: '🇯🇴',
      region: 'Moyen-Orient'),
  Country(
      name: 'Syrie',
      code: 'SY',
      dialCode: '+963',
      flag: '🇸🇾',
      region: 'Moyen-Orient'),
  Country(
      name: 'Iraq',
      code: 'IQ',
      dialCode: '+964',
      flag: '🇮🇶',
      region: 'Moyen-Orient'),
  Country(
      name: 'Iran',
      code: 'IR',
      dialCode: '+98',
      flag: '🇮🇷',
      region: 'Moyen-Orient'),
  Country(
      name: 'Turquie',
      code: 'TR',
      dialCode: '+90',
      flag: '🇹🇷',
      region: 'Moyen-Orient'),

  // Océanie
  Country(
      name: 'Australie',
      code: 'AU',
      dialCode: '+61',
      flag: '🇦🇺',
      region: 'Océanie'),
  Country(
      name: 'Nouvelle-Zélande',
      code: 'NZ',
      dialCode: '+64',
      flag: '🇳🇿',
      region: 'Océanie'),
  Country(
      name: 'Fidji',
      code: 'FJ',
      dialCode: '+679',
      flag: '🇫🇯',
      region: 'Océanie'),
  Country(
      name: 'Papouasie-Nouvelle-Guinée',
      code: 'PG',
      dialCode: '+675',
      flag: '🇵🇬',
      region: 'Océanie'),
];

class HomePageManager {
  static String _currentHomePageType = 'HomePage'; // Par défaut

  static void setCurrentHomePage(String pageType) {
    _currentHomePageType = pageType;
    //print('📍 [HomePageManager] Page d\'accueil actuelle: $pageType');
  }

  static String getCurrentHomePageType() {
    return _currentHomePageType;
  }

  static Widget getCurrentHomePageWidget(
      RouteObserver<PageRoute> routeObserver) {
    if (_currentHomePageType == 'HomePageDias') {
      return const HomePageDias();
    } else {
      return HomePage(routeObserver: routeObserver);
    }
  }
}
