from flask import Flask, request, jsonify, Blueprint
from flask_cors import CORS
from pymongo import MongoClient
from datetime import datetime, timedelta
from typing import List, Dict
import requests
import os

# ===== CRÉATION DE L'APPLICATION FLASK =====
app = Flask(__name__)

# Configuration CORS pour toute l'application
CORS(app, resources={
    r"/*": {
        "origins": "*",
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"]
    }
})

# Création du Blueprint pour les notifications
notif_back_bp = Blueprint('notifications', __name__, url_prefix='/notifications')

# ===== CONFIGURATION MONGODB =====

client = MongoClient(
    "mongodb://dipadmin:Cgt*2020#@31.207.36.187,62.210.100.14,62.210.101.31/admin?replicaSet=rs0&readPreference=secondaryPreferred&authSource=admin&connectTimeoutMS=30000",
    connect=False
)

# Base de données
db_app = client.APK_ARCHIVE  # Base des utilisateurs
db_central = client.wortispay  # Base centrale des transactions

# API de notification existante
NOTIFICATION_API_URL = 'https://api.live.wortis.cg/create_notifications'


# ===== SERVICE DE GESTION DES NOTIFICATIONS =====
class NotificationService:
    """Service de gestion des notifications ciblées"""

    @staticmethod
    def get_users_by_numc(numc_list: List[str], min_transactions: int = 1,
                          date_debut: str = None, date_fin: str = None) -> List[Dict]:
        """
        Récupère les utilisateurs ayant payé des services identifiés par leur numc

        Args:
            numc_list: Liste des numc (identifiants uniques des services)
            min_transactions: Nombre minimum de transactions
            date_debut: Date de début (optionnel)
            date_fin: Date de fin (optionnel)

        Returns:
            Liste des utilisateurs avec leurs statistiques
        """
        # Construction du filtre de recherche basé sur numc
        match_filter = {
            'numc': {'$in': numc_list},
            'user_id': {'$exists': True},  # Uniquement les transactions avec user_id
            'status': {
                '$gte': '200',
                '$lte': 'SUCCESSFUL'
            }
        }

        if date_debut or date_fin:
            match_filter['createdAt'] = {}
            if date_debut:
                match_filter['createdAt']['$gte'] = date_debut
            if date_fin:
                match_filter['createdAt']['$lte'] = date_fin

        # Agrégation pour compter les transactions par utilisateur
        pipeline = [
            {'$match': match_filter},
            {'$group': {
                '_id': '$user_id',  # Grouper par user_id unique
                'nombre_transactions': {'$sum': 1},
                'montant_total': {'$sum': {'$toDouble': '$montant_reel'}},
                'services_payes': {'$addToSet': '$numc'},
                'derniere_transaction': {'$max': '$createdAt'}
            }},
            {'$match': {'nombre_transactions': {'$gte': min_transactions}}},
            {'$project': {
                'user_id': '$_id',
                'nombre_transactions': 1,
                'montant_total': 1,
                'services_payes': 1,
                'derniere_transaction': 1,
                '_id': 0
            }}
        ]

        print(f"🔍 Recherche dans db_central.transac avec numc: {numc_list}")
        users_transactions = list(db_central.transac.aggregate(pipeline))
        print(f"📊 Trouvé {len(users_transactions)} utilisateurs uniques")

        # Récupérer les user_id
        user_ids = [ut['user_id'] for ut in users_transactions]

        # Récupérer les infos complètes des users depuis la base app (via token)
        users_info = list(db_app.Users.find(
            {'token': {'$in': user_ids}, 'check_verif': True, 'player_id': {'$exists': True}},
            {'token': 1, 'nom': 1, 'phone_number': 1, 'active': 1, 'player_id': 1, '_id': 0}
        ))

        users_map = {u['token']: u for u in users_info}
        result = []

        for ut in users_transactions:
            user_id = ut['user_id']
            if user_id in users_map:
                user_data = users_map[user_id].copy()
                user_data['user_id'] = user_id  # token
                user_data['stats'] = {
                    'nombre_transactions': ut['nombre_transactions'],
                    'montant_total': round(ut['montant_total'], 2),
                    'services_payes': ut['services_payes'],
                    'derniere_transaction': ut['derniere_transaction']
                }
                result.append(user_data)

        print(f"✅ Retour de {len(result)} utilisateurs vérifiés avec player_id")
        return result

    @staticmethod
    def get_users_by_service_types(service_types: List[str], min_transactions: int = 1,
                                    date_debut: str = None, date_fin: str = None) -> List[Dict]:
        # Construction du filtre de recherche
        match_filter = {
            'inite': {'$in': service_types},
            'status': {
                '$gte': '200',
                '$lte': 'SUCCESSFUL'
            }
        }

        if date_debut or date_fin:
            match_filter['createdAt'] = {}
            if date_debut:
                match_filter['createdAt']['$gte'] = date_debut
            if date_fin:
                match_filter['createdAt']['$lte'] = date_fin

        # Agrégation pour compter les transactions par utilisateur
        pipeline = [
            {'$match': match_filter},
            {'$group': {
                '_id': '$token',
                'nombre_transactions': {'$sum': 1},
                'montant_total': {'$sum': {'$toDouble': '$montant_reel'}},
                'services_payes': {'$addToSet': '$inite'},
                'derniere_transaction': {'$max': '$createdAt'}
            }},
            {'$match': {'nombre_transactions': {'$gte': min_transactions}}},
            {'$project': {
                'user_token': '$_id',
                'nombre_transactions': 1,
                'montant_total': 1,
                'services_payes': 1,
                'derniere_transaction': 1,
                '_id': 0
            }}
        ]

        users_transactions = list(db_central.transac.aggregate(pipeline))
        user_tokens = [ut['user_token'] for ut in users_transactions]

        users_info = list(db_app.Users.find(
            {'token': {'$in': user_tokens}, 'player_id': {'$exists': True}},
            {'token': 1, 'nom': 1, 'phone_number': 1, 'active': 1, 'player_id': 1, '_id': 0}
        ))

        users_map = {u['token']: u for u in users_info}
        result = []

        for ut in users_transactions:
            user_token = ut['user_token']
            if user_token in users_map:
                user_data = users_map[user_token].copy()
                user_data['user_id'] = user_token
                user_data['stats'] = {
                    'nombre_transactions': ut['nombre_transactions'],
                    'montant_total': round(ut['montant_total'], 2),
                    'services_payes': ut['services_payes'],
                    'derniere_transaction': ut['derniere_transaction']
                }
                result.append(user_data)

        return result

    @staticmethod
    def send_bulk_notifications(users: List[Dict], title: str, message: str,
                                      notification_type: str = "info") -> Dict:
        
        results = {
            'total_users': len(users),
            'success': 0,
            'failed': 0,
            'details': []
        }

        for user in users:
            try:
                user_id = user.get('user_id')
                if not user_id:
                    results['failed'] += 1
                    continue

                notification_payload = {
                    'user_id': user_id,
                    'type': notification_type,
                    'contenu': message,
                    'title': title,
                    'icone': notification_type
                }

                response = requests.post(
                    NOTIFICATION_API_URL,
                    json=notification_payload,
                    timeout=10
                )

                if response.status_code == 200:
                    results['success'] += 1
                    results['details'].append({
                        'user_id': user_id,
                        'user_name': user.get('nom', 'N/A'),
                        'status': 'success'
                    })
                else:
                    results['failed'] += 1
                    results['details'].append({
                        'user_id': user_id,
                        'status': 'failed',
                        'error': response.text
                    })

            except Exception as e:
                results['failed'] += 1
                results['details'].append({
                    'user_id': user.get('user_id', 'unknown'),
                    'status': 'error',
                    'error': str(e)
                })

        return results


# ===== MAPPING SERVICE_ID → TYPE_VERSEMENT =====
def get_service_type_mapping():
    try:
        response = requests.get('https://api.live.wortis.cg/get_services_back', timeout=10)
        if response.ok:
            services = response.json()
            mapping = {}

            for service in services:
                service_id = service.get('_id')
                service_name = service.get('name', '').lower()

                if 'Facture Internet' in service_name:
                    mapping[service_id] = 'SPEEDPAY'
                elif 'Facture électricité' in service_name :
                    mapping[service_id] = 'E2C'
                elif 'Frais Scolaire' in service_name or 'eau' in service_name:
                    mapping[service_id] = 'ECOL'
                elif 'Recharge Pelissa' in service_name:
                    mapping[service_id] = 'PELISSA'
                elif 'Facture Eau' in service_name :
                    mapping[service_id] = 'LCDE'
                elif 'Mobile Money' in service_name :
                    mapping[service_id] = 'EDEPOT'

            return mapping
        else:
            print(f"Erreur lors de la récupération des services: {response.status_code}")
            return {}
    except Exception as e:
        print(f"Erreur lors du mapping des services: {str(e)}")
        return {}


# ===== ROUTES API =====

@notif_back_bp.route('/')
def hello():
    return jsonify({"message": "Hello from Notifications API"})


@notif_back_bp.route('/api/services', methods=['GET', 'OPTIONS'])
def get_services():
    """
    Récupère tous les services disponibles depuis l'API get_services_back
    Filtre les services ayant un numc et eligible_countries contenant "CG"

    Response:
    {
        "total_services": 10,
        "services": [
            {
                "_id": "68b030f70e4a78da29ba92fc",
                "name": "Packs Eau",
                "numc": "4b851209-4de0-4581-9eb5-2225f9925d12",
                "icon": "eau",
                "logo": "https://...",
                "description": "...",
                "status": true,
                "eligible_countries": "CG"
            }
        ]
    }
    """
    # Gestion CORS
    if request.method == 'OPTIONS':
        response = jsonify({'status': 'ok'})
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
        return response, 200

    try:
        # Récupérer tous les services depuis l'API existante
        print("📡 Appel à https://api.live.wortis.cg/get_services_back")
        api_response = requests.get('https://api.live.wortis.cg/get_services_back', timeout=10)

        if not api_response.ok:
            raise Exception(f"Erreur API get_services_back: {api_response.status_code}")

        response_data = api_response.json()

        # L'API retourne { "all_services": [...], "random_services": [...] }
        if isinstance(response_data, dict) and 'all_services' in response_data:
            all_services = response_data['all_services']
            print(f"📥 {len(all_services)} services récupérés depuis l'API")
        elif isinstance(response_data, list):
            all_services = response_data
            print(f"📥 {len(all_services)} services récupérés depuis l'API")
        else:
            print(f"⚠️ Format inattendu: {type(response_data)}")
            if isinstance(response_data, dict):
                print(f"Clés disponibles: {list(response_data.keys())}")
            raise Exception(f"Format de réponse inattendu de get_services_back")

        # Filtrer les services avec numc ET eligible_countries contenant "CG"
        filtered_services = []
        for service in all_services:
            # Vérifier que service est bien un dict et pas une string
            if not isinstance(service, dict):
                continue

            # Vérifier que le service a un numc
            numc = service.get('numc')
            if not numc:
                continue

            # Vérifier que eligible_countries contient "CG"
            eligible_countries = service.get('eligible_countries', '')
            # eligible_countries peut être une string ou None
            if not eligible_countries:
                continue

            # Convertir en string si nécessaire
            if not isinstance(eligible_countries, str):
                eligible_countries = str(eligible_countries)

            if 'CG' not in eligible_countries:
                continue

            filtered_services.append(service)

        print(f"✅ {len(filtered_services)} services filtrés (avec numc + CG)")

        response = jsonify({
            'total_services': len(filtered_services),
            'services': filtered_services
        })
        response.headers['Access-Control-Allow-Origin'] = '*'
        return response, 200

    except Exception as e:
        print(f"❌ Erreur lors de la récupération des services: {str(e)}")
        import traceback
        traceback.print_exc()
        response = jsonify({'error': str(e)})
        response.headers['Access-Control-Allow-Origin'] = '*'
        return response, 500


@notif_back_bp.route('/api/users/by-numc', methods=['POST', 'OPTIONS'])
def get_users_by_numc():
    data = request.get_json()
    min_transactions = data.get("min_transactions")
    numc_list = data.get("numc_list")
    date_debut = data.get("date_debut")
    date_fin = data.get("date_fin")
    
    match_filter = {
        "numc": { "$in": numc_list }
    }

    # Gestion filtre de dates si fourni
    if date_debut and date_fin:
        match_filter["transaction_date"] = {
            "$gte": {"$date": date_debut},
            "$lte": {"$date": date_fin}
        }

    pipeline = [
        { "$match": match_filter },

        {
            "$group": {
                "_id": "$user_id",
                "transactions": { "$sum": 1 },
                "doc": { "$first": "$$ROOT" }
            }
        },

        { "$match": { "transactions": { "$gte": min_transactions } } },

        { "$replaceRoot": { "newRoot": "$doc" } }
    ]

    results = list(db_central.transac.aggregate(pipeline))

    return results

@notif_back_bp.route('/api/users/by-services', methods=['POST'])
def get_users_by_services():
    try:
        data = request.get_json()

        if 'service_ids' not in data or not data['service_ids']:
            return jsonify({'error': 'service_ids est requis et ne peut pas être vide'}), 400

        service_ids = data['service_ids']
        min_transactions = data.get('min_transactions', 1)
        date_debut = data.get('date_debut')
        date_fin = data.get('date_fin')

        service_mapping = get_service_type_mapping()

        service_types = []
        for service_id in service_ids:
            if service_id in service_mapping:
                service_types.append(service_mapping[service_id])
            else:
                print(f"⚠️ Service {service_id} non mappé")

        if not service_types:
            return jsonify({
                'error': 'Aucun type de service correspondant trouvé',
                'total_users': 0,
                'users': []
            }), 200

        print(f"📋 Service IDs: {service_ids}")
        print(f"📋 Types de versement: {service_types}")

        users = NotificationService.get_users_by_service_types(
            service_types=service_types,
            min_transactions=min_transactions,
            date_debut=date_debut,
            date_fin=date_fin
        )

        return jsonify({
            'total_users': len(users),
            'users': users,
            'debug': {
                'service_ids_requested': service_ids,
                'service_types_matched': service_types
            }
        }), 200

    except Exception as e:
        print(f"❌ Erreur: {str(e)}")
        return jsonify({'error': str(e)}), 500


@notif_back_bp.route('/api/notifications/send-to-service-users', methods=['POST'])
def send_notifications_to_service_users():
    try:
        data = request.get_json()

        if 'service_ids' not in data or 'notification' not in data:
            return jsonify({'error': 'service_ids et notification sont requis'}), 400

        service_ids = data['service_ids']
        min_transactions = data.get('min_transactions', 1)
        date_debut = data.get('date_debut')
        date_fin = data.get('date_fin')

        service_mapping = get_service_type_mapping()

        service_types = []
        for service_id in service_ids:
            if service_id in service_mapping:
                service_types.append(service_mapping[service_id])

        if not service_types:
            return jsonify({
                'error': 'Aucun type de service correspondant trouvé',
                'total_targeted': 0
            }), 200

        users = NotificationService.get_users_by_service_types(
            service_types=service_types,
            min_transactions=min_transactions,
            date_debut=date_debut,
            date_fin=date_fin
        )

        if not users:
            return jsonify({
                'message': 'Aucun utilisateur trouvé avec ces critères',
                'total_targeted': 0
            }), 200

        notif_data = data['notification']
        results = NotificationService.send_bulk_notifications(
            users=users,
            title=notif_data['title'],
            message=notif_data['message'],
            notification_type=notif_data.get('type', 'info')
        )

        return jsonify({
            'message': 'Notifications envoyées',
            'total_targeted': len(users),
            'results': results
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@notif_back_bp.route('/api/services/stats', methods=['GET'])
def get_services_usage_stats():
    """
    Retourne les statistiques d'utilisation par service (numc)
    avec le nombre d'utilisateurs uniques pour chaque service
    """
    try:
        pipeline = [
            {
                "$match": {
                    "status": { "$in": ["200", "SUCCESSFUL"] },
                    "numc": { "$exists": True, "$ne": None }  # Filtrer les transactions avec numc
                }
            },
            {
                "$group": {
                    "_id": "$numc",  # Grouper par numc (service)
                    "users_uniques": { "$addToSet": "$user_id" }  # Liste unique des user_id
                }
            },
            {
                "$project": {
                    "_id": 0,
                    "numc": "$_id",
                    "nombre_utilisateurs": { "$size": "$users_uniques" }  # Compter les users uniques
                }
            },
            {
                "$sort": { "nombre_utilisateurs": -1 }  # Trier par nombre d'utilisateurs décroissant
            }
        ]

        stats = list(db_central.transac.aggregate(pipeline))

        # Calculer le total
        total_services = len(stats)

        return jsonify({
            'services': stats,
            'total_services': total_services
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@notif_back_bp.route('/api/services/<numc>/users/count', methods=['GET', 'OPTIONS'])
def get_service_users_count(numc):
    """
    Retourne le nombre d'utilisateurs uniques pour un service spécifique (par numc)

    Response:
    {
        "numc": "4b851209-4de0-4581-9eb5-2225f9925d12",
        "nombre_utilisateurs": 543
    }
    """
    # Gestion CORS
    if request.method == 'OPTIONS':
        response = jsonify({'status': 'ok'})
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
        return response, 200

    try:
        pipeline = [
            {
                "$match": {
                    "numc": numc,
                    "status": { "$in": ["200", "SUCCESSFUL"] },
                    "user_id": { "$exists": True, "$ne": None }
                }
            },
            {
                "$group": {
                    "_id": "$user_id"
                }
            },
            {
                "$count": "nombre_utilisateurs"
            }
        ]

        result = list(db_central.transac.aggregate(pipeline))

        nombre_utilisateurs = result[0]['nombre_utilisateurs'] if result else 0

        response = jsonify({
            'numc': numc,
            'nombre_utilisateurs': nombre_utilisateurs
        })
        response.headers['Access-Control-Allow-Origin'] = '*'
        return response, 200

    except Exception as e:
        print(f"❌ Erreur lors du comptage des utilisateurs pour {numc}: {str(e)}")
        response = jsonify({'error': str(e)})
        response.headers['Access-Control-Allow-Origin'] = '*'
        return response, 500


@notif_back_bp.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'message': 'Notifications API is running'
    }), 200


# ===== ENREGISTREMENT DU BLUEPRINT ET LANCEMENT =====
app.register_blueprint(notif_back_bp)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)