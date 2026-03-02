from flask import Flask, request, jsonify
import requests
from bson import ObjectId
from datetime import datetime


def apk_calculate_order_total(commandes):
    """
    Calcule le montant total de la commande en se basant sur les prix dans cat_vival
    """
    total = 0
    for product_id, valeur in commandes.items():
        try:
            id_commande = product_id.split("_")[0] if "_" in product_id else product_id
            object_id = ObjectId(id_commande)

            # Récupérer le prix depuis la base de données
            product_in_db = euroshop_db.cat_vival.find_one({"_id": object_id})

            if product_in_db:
                quantite = valeur.get('quantite', 0)
                prix_unitaire = product_in_db['prix']
                total += prix_unitaire * quantite

        except Exception as e:
            print(f"[VIVAL] Erreur calcul total pour {product_id}: {str(e)}")
            continue

    return total


def apk_enrich_order_with_catalog_data(commandes):
    """
    Enrichit les données de commande avec les informations complètes du catalogue cat_vival
    """
    enriched_commandes = {}

    for product_id, valeur in commandes.items():
        try:
            id_commande = product_id.split("_")[0] if "_" in product_id else product_id
            object_id = ObjectId(id_commande)

            # Récupérer toutes les infos du produit depuis cat_vival
            product_in_db = euroshop_db.cat_vival.find_one({"_id": object_id})

            if product_in_db:
                enriched_commandes[str(object_id)] = {
                    'product_id': str(object_id),
                    'nom': product_in_db['nom'],
                    'prix_unitaire': product_in_db['prix'],
                    'quantite': valeur.get('quantite', 1),
                    'total': product_in_db['prix'] * valeur.get('quantite', 1),
                    'description': product_in_db.get('description', ''),
                    'fileLink': product_in_db.get('fileLink', ''),
                    'l': product_in_db.get('l', ''),
                    'vendu': product_in_db.get('vendu', 0)
                }

        except Exception as e:
            print(f"[VIVAL] Erreur enrichissement pour {product_id}: {str(e)}")
            continue

    return enriched_commandes

@app.route('/apk/vival/checkout', methods=['POST'])
def apk_vival_checkout():
    """
    Route pour gérer le paiement et l'enregistrement de commande Vival

    Payload attendu:
    {
        "montant": 4200,
        "momo": "242066985554",
        "name": "John Doe",
        "mobile": "242066985554",
        "adresse": "Brazzaville, Congo",
        "nom": "John Doe",
        "commande": {
            "65cf5106abf1d162d35664ae": {
                "nom": "Pack de 8 x 1.5",
                "prix": 2100,
                "quantite": 2,
                "description": "Le grand classique...",
                "fileLink": "1_5l.png"
            }
        }
    }
    """
    print("\n" + "="*80)
    print("🚀 [VIVAL CHECKOUT] Nouvelle demande de commande")
    print("="*80)

    data = request.json

    print(f"📦 [VIVAL] Données reçues:")
    print(f"   - Montant: {data.get('montant')} FCFA")
    print(f"   - Client: {data.get('nom')}")
    print(f"   - Mobile: {data.get('mobile')}")
    print(f"   - Adresse: {data.get('adresse')}")
    print(f"   - Nombre de produits: {len(data.get('commande', {}))}")

    # Validation des champs obligatoires
    required_fields = ['montant', 'momo', 'name', 'mobile', 'adresse', 'nom', 'commande']
    missing_fields = [field for field in required_fields if field not in data]

    if missing_fields:
        print(f"❌ [VIVAL] Validation échouée - Champs manquants: {', '.join(missing_fields)}")
        return jsonify({
            'error': f'Champs manquants: {", ".join(missing_fields)}'
        }), 400

    print("✅ [VIVAL] Validation des champs obligatoires: OK")

    # Validation de la commande
    print(f"🔍 [VIVAL] Validation de la commande...")
    if not apk_validate_commandes_vival(data.get('commande', {})):
        print("❌ [VIVAL] Validation de la commande échouée")
        return jsonify({'msg': 'Données de commande invalides'}), 400

    print("✅ [VIVAL] Validation de la commande: OK")

    # Calculer et vérifier le montant total
    print(f"💰 [VIVAL] Calcul du montant total...")
    calculated_total = apk_calculate_order_total(data['commande'])
    print(f"   - Montant envoyé: {data['montant']} FCFA")
    print(f"   - Montant calculé: {calculated_total} FCFA")
    print(f"   - Différence: {abs(calculated_total - data['montant'])} FCFA")

    if abs(calculated_total - data['montant']) > 1:  # Tolérance de 1 FCFA pour les arrondis
        print(f"❌ [VIVAL] Montant invalide - Différence trop grande")
        return jsonify({
            'error': 'Le montant ne correspond pas au total de la commande',
            'montant_envoye': data['montant'],
            'montant_calcule': calculated_total
        }), 400

    print("✅ [VIVAL] Validation du montant: OK")

    # Étape 1: Déclencher le paiement via WortisPay
    try:
        payment_data = {
            "numc": "4b851209-4de0-4581-9eb5-2225f9925d12",
            "montant": data['montant'],
            "numPaid": data['momo'],
            "typeVersement": "Commande Vival",
            "name": data['name']
        }

        print(f"[VIVAL] Déclenchement du paiement pour {data['name']} - Montant: {data['montant']}")

        payment_response = requests.post(
            'https://wortispay.com/api/paiement/json',
            json=payment_data,
            headers={'Content-Type': 'application/json'},
            timeout=30
        )

        payment_result = payment_response.json()

        print(f"[VIVAL] Réponse paiement: {payment_result}")

        # Vérifier si le paiement a été initié avec succès
        if payment_response.status_code != 200:
            return jsonify({
                'error': 'Échec du déclenchement du paiement',
                'details': payment_result
            }), 400

        # Extraire le transID du paiement
        trans_id = payment_result.get('transID') or payment_result.get('transaction_id') or payment_result.get('id')

        if not trans_id:
            # Si l'API ne retourne pas de transID, en générer un
            trans_id = f"VIVAL_{datetime.now().strftime('%Y%m%d%H%M%S')}_{data['momo'][-4:]}"
            print(f"⚠️  [VIVAL] Aucun transID retourné par WortisPay")
            print(f"🔄 [VIVAL] TransID généré: {trans_id}")
        else:
            print(f"🆔 [VIVAL] TransID reçu: {trans_id}")

    except requests.exceptions.Timeout:
        print(f"⏱️  [VIVAL] Timeout lors de l'appel à WortisPay (>30s)")
        return jsonify({
            'error': 'Délai d\'attente dépassé lors du paiement'
        }), 504
    except requests.exceptions.RequestException as e:
        print(f"❌ [VIVAL] Erreur réseau lors du paiement: {str(e)}")
        print(f"   - Type: {type(e).__name__}")
        return jsonify({
            'error': 'Erreur lors de la communication avec le service de paiement',
            'details': str(e)
        }), 500
    except Exception as e:
        print(f"❌ [VIVAL] Erreur inattendue lors du paiement: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return jsonify({
            'error': 'Erreur inattendue lors du paiement',
            'details': str(e)
        }), 500

    # Étape 2: Enregistrer la commande dans MongoDB
    print("\n" + "-"*80)
    print("💾 [VIVAL] ÉTAPE 2: Enregistrement de la commande dans MongoDB")
    print("-"*80)

    try:
        # Enrichir la commande avec les données complètes du catalogue
        print(f"🔄 [VIVAL] Enrichissement de la commande avec cat_vival...")
        enriched_commande = apk_enrich_order_with_catalog_data(data['commande'])
        print(f"   - Produits enrichis: {len(enriched_commande)}")

        order_data = {
            'transID': trans_id,
            'mobile': data['mobile'],
            'adresse': data['adresse'],
            'nom': data['nom'],
            'commande': enriched_commande,
            'commande_originale': data['commande'],
            'montant': data['montant'],
            'payment_status': payment_result.get('status', 'pending'),
            'payment_response': payment_result,
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }

        print(f"💾 [VIVAL] Insertion dans MongoDB...")
        result = euroshop_db.vival.insert_one(order_data)
        print(f"✅ [VIVAL] Commande enregistrée avec ID: {result.inserted_id}")

        # Mettre à jour le nombre de ventes pour chaque produit
        print(f"📊 [VIVAL] Mise à jour des compteurs de vente...")
        apk_update_product_sales(enriched_commande)

        nombre_articles = sum(item['quantite'] for item in enriched_commande.values())

        print("\n" + "="*80)
        print("🎉 [VIVAL] COMMANDE RÉUSSIE")
        print("="*80)
        print(f"   - TransID: {trans_id}")
        print(f"   - Order ID: {result.inserted_id}")
        print(f"   - Montant: {data['montant']} FCFA")
        print(f"   - Articles: {nombre_articles}")
        print(f"   - Client: {data['nom']}")
        print("="*80 + "\n")

        return jsonify({
            'code': 200,
            'message': 'Paiement initié et commande enregistrée avec succès',
            'transID': trans_id,
            'order_id': str(result.inserted_id),
            'montant_total': data['montant'],
            'nombre_articles': nombre_articles,
            'payment_details': payment_result
        }), 201

    except Exception as e:
        print(f"❌ [VIVAL] Erreur lors de l'enregistrement: {str(e)}")
        import traceback
        print(f"📋 [VIVAL] Traceback complet:")
        print(traceback.format_exc())
        return jsonify({
            'error': 'Paiement initié mais erreur lors de l\'enregistrement de la commande',
            'transID': trans_id,
            'details': str(e)
        }), 500


@app.route('/apk/vival', methods=['POST'])
def apk_vival():
    """
    Route existante pour enregistrer directement une commande Vival
    (sans passer par le paiement)
    """
    data = request.json
    if 'transID' not in data or 'mobile' not in data or 'adresse' not in data or 'nom' not in data or 'commande' not in data:
        return jsonify({'error': 'Certains champs sont manquants'}), 400

    if not apk_validate_commandes_vival(data.get('commande', {})):
        return jsonify({'msg': 'Données de commande invalides'}), 400

    try:
        data['created_at'] = datetime.utcnow()
        data['updated_at'] = datetime.utcnow()
        euroshop_db.vival.insert_one(data)
        return jsonify({'code': 200, 'message': 'Données insérées avec succès'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500


def apk_validate_commandes_vival(commandes):
    """
    Valide que tous les produits de la commande existent dans la base de données cat_vival

    Structure attendue de commandes:
    {
        "65cf5106abf1d162d35664ae": {
            "nom": "Pack de 8 x 1.5",
            "prix": 2100,
            "quantite": 2,
            "description": "...",
            "fileLink": "1_5l.png"
        }
    }
    """
    if not isinstance(commandes, dict) or len(commandes) == 0:
        print("[VIVAL] Commande vide ou format invalide")
        return False

    for product_id, valeur in commandes.items():
        try:
            # Extraire l'ID du produit (supporte "id_qty" ou juste "id")
            id_commande = product_id.split("_")[0] if "_" in product_id else product_id

            # Valider que c'est un ObjectId valide
            if not ObjectId.is_valid(id_commande):
                print(f"[VIVAL] ObjectId invalide: {id_commande}")
                return False

            object_id = ObjectId(id_commande)

            # Vérifier que le produit existe dans le catalogue
            product_in_db = euroshop_db.cat_vival.find_one({"_id": object_id})

            if not product_in_db:
                print(f"[VIVAL] Produit non trouvé dans cat_vival: {id_commande}")
                return False

            # Valider les données du produit dans la commande
            if not isinstance(valeur, dict):
                print(f"[VIVAL] Format de produit invalide pour: {product_id}")
                return False

            # Vérifier les champs requis
            if 'quantite' not in valeur or not isinstance(valeur['quantite'], (int, float)):
                print(f"[VIVAL] Quantité manquante ou invalide pour: {product_id}")
                return False

            if valeur['quantite'] <= 0:
                print(f"[VIVAL] Quantité doit être supérieure à 0 pour: {product_id}")
                return False

            # Valider que le prix correspond (optionnel mais recommandé)
            if 'prix' in valeur and valeur['prix'] != product_in_db['prix']:
                print(f"[VIVAL] ATTENTION: Prix différent pour {product_in_db['nom']}: "
                      f"commande={valeur['prix']}, DB={product_in_db['prix']}")

            print(f"[VIVAL] ✓ Produit validé: {product_in_db['nom']} (ID: {id_commande}) x{valeur['quantite']} "
                  f"= {product_in_db['prix'] * valeur['quantite']} FCFA")

        except Exception as e:
            print(f"[VIVAL] Erreur validation produit {product_id}: {str(e)}")
            return False

    return True


def apk_update_product_sales(enriched_commande):
    """
    Met à jour le compteur 'vendu' dans cat_vival pour chaque produit commandé
    """
    try:
        for product_id, item in enriched_commande.items():
            euroshop_db.cat_vival.update_one(
                {'_id': ObjectId(product_id)},
                {'$inc': {'vendu': item['quantite']}}
            )
            print(f"[VIVAL] ✓ Compteur vendu mis à jour pour {item['nom']}: +{item['quantite']}")

    except Exception as e:
        print(f"[VIVAL] Erreur mise à jour compteur vendu: {str(e)}")


@app.route('/apk/vival/payment/callback', methods=['POST'])
def apk_vival_payment_callback():
    """
    Route de callback pour recevoir les mises à jour de statut de paiement
    """
    data = request.json

    if 'transID' not in data:
        return jsonify({'error': 'transID manquant'}), 400

    try:
        # Mettre à jour le statut du paiement dans la commande
        update_result = euroshop_db.vival.update_one(
            {'transID': data['transID']},
            {
                '$set': {
                    'payment_status': data.get('status', 'unknown'),
                    'payment_callback': data,
                    'updated_at': datetime.utcnow()
                }
            }
        )

        if update_result.matched_count == 0:
            return jsonify({
                'error': 'Commande non trouvée',
                'transID': data['transID']
            }), 404

        print(f"[VIVAL] Callback reçu pour {data['transID']}: {data.get('status')}")

        return jsonify({
            'code': 200,
            'message': 'Statut de paiement mis à jour'
        }), 200

    except Exception as e:
        print(f"[VIVAL] Erreur callback: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/apk/vival/orders/<order_id>', methods=['GET'])
def apk_get_vival_order(order_id):
    """
    Récupérer les détails d'une commande Vival
    """
    try:
        if not ObjectId.is_valid(order_id):
            return jsonify({'error': 'ID de commande invalide'}), 400

        order = euroshop_db.vival.find_one({'_id': ObjectId(order_id)})

        if not order:
            return jsonify({'error': 'Commande non trouvée'}), 404

        # Convertir ObjectId en string pour la sérialisation JSON
        order['_id'] = str(order['_id'])
        if 'created_at' in order:
            order['created_at'] = order['created_at'].isoformat()
        if 'updated_at' in order:
            order['updated_at'] = order['updated_at'].isoformat()

        return jsonify(order), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/acceuil_apk_wpay_v2_test/<user_id>', methods=['GET'])
def acceuil_apk_wpay_v2_test(user_id):
    # Préparer les versions du token pour gérer l'encodage
    token_decoded = urllib.parse.unquote(user_id)
    token_encoded = urllib.parse.quote(user_id)
    
    # Vérifier d'abord si l'utilisateur existe avec l'une des variantes du token
    user = client.APK_ARCHIVE.Users.find_one({
        'token': {'$in': [user_id, token_decoded, token_encoded]}
    })
    
    if not user:
        return jsonify({'error': 'Utilisateur non trouvé.'}), 404
    
    # Utiliser le token réel trouvé dans la base de données
    actual_token = user.get('token')
    
    print("Zone bénéficiaire de l'utilisateur dans accueil")
    zone = get_zone_benef(actual_token)  # Utiliser le token réel
    
    # Récupération des bannières
    response = list(client.APK_ARCHIVE.Banner.find({
        "$or": [
            {"international": True},
            {"eligible_countrie": zone}
        ]
    }))
    # if not response:
    #     response = list(client.APK_ARCHIVE.Banner.find({"eligible_countrie": 'CG'}))
    #     if not response:
    #         return jsonify({'error': 'Bannières non trouvées.'}), 404
    
    response = [
        {
            'image': banniere.get('image', ''),
            'serviceName': banniere.get('serviceName'),
        }
        for banniere in response
    ]
    
    # Récupération des secteurs d'activité
    response_1 = list(client.APK_ARCHIVE.SecteurActivite.find({"eligible_countrie": zone}))
    
    if len(response_1) == 0:
        sectordias = list(client.APK_ARCHIVE.SecteurActivite.find({"eligible_countrie": "diaspora"}))
        response_1.extend(sectordias)  # ✅ Fix ici
    
    for secteur in response_1:
        secteur['_id'] = str(secteur['_id'])
    
    # Tri par ordre de rang
    response_1.sort(key=lambda x: int(x['rang']))
    
    return jsonify({
        'banner': response,
        'SecteurActivite': response_1
    }), 200
