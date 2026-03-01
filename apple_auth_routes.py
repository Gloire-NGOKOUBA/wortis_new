# ============================================================
#  ROUTES APPLE + GOOGLE SIGN-IN  –  Wortis APK
#  À coller dans votre fichier Flask principal (app.py)
#
#  Dépendances déjà présentes dans votre projet :
#    - flask, pymongo (client), bcrypt, requests
#    - generate_secure_token_apk() (votre fonction existante)
#
#  Avant de déployer, créer les index TTL MongoDB (une seule fois) :
#    db.ApplePendingUsers.createIndex({ "created_at": 1 }, { expireAfterSeconds: 1800 })
#    db.GooglePendingUsers.createIndex({ "created_at": 1 }, { expireAfterSeconds: 1800 })
# ============================================================

import json
import secrets
import urllib.parse
from datetime import datetime

import requests
from flask import request, jsonify


# ─────────────────────────────────────────────────────────────
#  ROUTE 1  –  /apple/login
#  Appelée au tap sur "Se connecter avec Apple"
#
#  Body JSON attendu :
#    apple_user_id      (str)  obligatoire
#    identity_token     (str)  optionnel – pour vérification côté serveur
#    authorization_code (str)  optionnel
#    email              (str)  fourni uniquement à la 1re connexion Apple
#    given_name         (str)  idem
#    family_name        (str)  idem
#    provider           (str)  "apk"
#
#  Réponses :
#    200  →  utilisateur existant  →  connexion directe
#    201  →  nouvel utilisateur    →  renvoie completion_token
#    400  →  paramètre manquant
# ─────────────────────────────────────────────────────────────
@app.route('/apple/login', methods=['POST'])
def apple_login():
    data = request.get_json()

    apple_user_id = data.get('apple_user_id')
    email         = data.get('email')    or ''
    given_name    = data.get('given_name')  or ''
    family_name   = data.get('family_name') or ''

    if not apple_user_id:
        return jsonify({"error": "apple_user_id requis"}), 400

    # ── Utilisateur existant ──────────────────────────────────
    user = client.APK_ARCHIVE.Users.find_one({
        "apple_user_id": apple_user_id,
        "check_verif":   True
    })

    if user:
        client.APK_ARCHIVE.Users.update_one(
            {"apple_user_id": apple_user_id},
            {"$set": {"derniere_connexion": datetime.utcnow()}}
        )

        serializable_user = {
            "_id":          str(user["_id"]),
            "phone_number": user.get("phone_number", ""),
            "nom":          user["nom"],
            "role":         user["role"],
            "secure_token": user.get("secure_token", ""),
            "token":        user["token"],
            "check_verif":  user["check_verif"],
        }

        return jsonify({
            "Code":            200,
            "messages":        "Connexion réussie",
            "token":           user["token"],
            "user":            serializable_user,
            "zone_benef":      user.get("zone_benef", ""),
            "zone_benef_code": user.get("zone_benef_code", "CG")
        }), 200

    # ── Nouvel utilisateur → générer un completion_token ─────
    nom = f"{given_name} {family_name}".strip() or ""

    completion_token = secrets.token_urlsafe(32)

    # Stocker temporairement en attendant le complément de profil
    client.APK_ARCHIVE.ApplePendingUsers.replace_one(
        {"apple_user_id": apple_user_id},
        {
            "apple_user_id":    apple_user_id,
            "completion_token": completion_token,
            "email":            email,
            "nom":              nom,
            "created_at":       datetime.utcnow()
        },
        upsert=True
    )

    return jsonify({
        "completion_token": completion_token,
        "user": {
            "apple_user_id": apple_user_id,
            "email":         email,
            "nom":           nom,
            "given_name":    given_name,
            "family_name":   family_name,
        }
    }), 201


# ─────────────────────────────────────────────────────────────
#  ROUTE 2  –  /apple/complete-profile
#  Appelée après que l'utilisateur a saisi son numéro de tél.
#
#  Body JSON attendu :
#    completion_token  (str)  obligatoire – reçu depuis /apple/login
#    phone             (str)  obligatoire
#    country_name      (str)  ex: "Congo"
#    country_code      (str)  ex: "CG"
#    zone_benef        (str)  ex: "Congo"
#    zone_benef_code   (str)  ex: "CG"
#    provider          (str)  "apk"
#
#  Réponses :
#    200  →  compte créé (ou déjà existant)
#    400  →  paramètre manquant ou token invalide/expiré
# ─────────────────────────────────────────────────────────────
@app.route('/apple/complete-profile', methods=['POST'])
def apple_complete_profile():
    data = request.get_json()

    completion_token = data.get('completion_token')
    phone            = data.get('phone')
    country_name     = data.get('country_name',     'Congo')
    country_code     = data.get('country_code',     'CG')
    zone_benef       = data.get('zone_benef',       country_name)
    zone_benef_code  = data.get('zone_benef_code',  country_code)

    if not completion_token or not phone:
        return jsonify({"error": "completion_token et phone sont requis"}), 400

    # ── Récupérer les données Apple en attente ────────────────
    pending = client.APK_ARCHIVE.ApplePendingUsers.find_one({
        "completion_token": completion_token
    })

    if not pending:
        return jsonify({"error": "Token invalide ou expiré"}), 400

    apple_user_id    = pending["apple_user_id"]
    nom_from_request = (data.get('nom') or '').strip()
    nom              = nom_from_request or pending.get("nom") or phone
    email            = pending.get("email", "")

    # ── Protection contre le double appel ────────────────────
    existing = client.APK_ARCHIVE.Users.find_one({"apple_user_id": apple_user_id})
    if existing:
        client.APK_ARCHIVE.ApplePendingUsers.delete_one({
            "completion_token": completion_token
        })
        return jsonify({
            "Code":     200,
            "messages": "Compte déjà créé",
            "token":    existing["token"],
            "user": {
                "_id":          str(existing["_id"]),
                "phone_number": existing.get("phone_number", ""),
                "nom":          existing["nom"],
                "role":         existing["role"],
                "secure_token": existing.get("secure_token", ""),
                "token":        existing["token"],
                "check_verif":  existing["check_verif"],
            }
        }), 200

    # ── Créer le compte utilisateur ───────────────────────────
    secure_token = generate_secure_token_apk()
    token        = urllib.parse.quote(f"{secure_token}_-_{phone}_-_{nom}")

    user_document = {
        "apple_user_id":      apple_user_id,
        "phone_number":       phone,
        "email":              email,
        "nom":                nom,
        "miles":              10,
        "date_creation":      datetime.utcnow(),
        "derniere_connexion": None,
        "role":               "utilisateur",
        "secure_token":       secure_token,
        "token":              token,
        "check_verif":        True,
        "country_name":       country_name,
        "country_code":       country_code,
        "zone_benef":         zone_benef,
        "zone_benef_code":    zone_benef_code,
        "operating_system":   "iOS",
        "auth_method":        "apple"
    }

    result = client.APK_ARCHIVE.Users.insert_one(user_document)

    # ── Nettoyer la collection temporaire ─────────────────────
    client.APK_ARCHIVE.ApplePendingUsers.delete_one({
        "completion_token": completion_token
    })

    # ── Créer le wallet Miles (identique au register normal) ──
    client.APK_ARCHIVE.Miles.insert_one({
        "user_id":    token,
        "balance":    10,
        "currency":   "Miles",
        "pin":        secure_token,
        "is_active":  True,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    })

    # ── Notifications de bienvenue (non-bloquantes) ───────────
    try:
        notif_url = "https://api.live.wortis.cg/create_notifications"
        headers   = {"Content-Type": "application/json"}

        requests.post(notif_url, headers=headers, data=json.dumps({
            "type":    "info",
            "contenu": "Votre compte a été créé avec succès ! ☺️.",
            "user_id": token,
            "icone":   "info",
            "title":   "Bienvenue sur Wortis",
            "firebase": False
        }))

        requests.post(notif_url, headers=headers, data=json.dumps({
            "type":    "kdo",
            "contenu": "Vous venez de recevoir 10 Miles dans votre compte WortisPay",
            "user_id": token,
            "icone":   "kdo",
            "title":   "WortisPay Kdo"
        }))
    except Exception:
        pass  # non-bloquant, ne pas faire échouer l'inscription

    # ── Réponse finale ────────────────────────────────────────
    created = client.APK_ARCHIVE.Users.find_one({"_id": result.inserted_id})

    return jsonify({
        "Code":     200,
        "messages": "Profil complété avec succès",
        "token":    token,
        "user": {
            "_id":               str(created["_id"]),
            "phone_number":      created["phone_number"],
            "nom":               created["nom"],
            "date_creation":     created["date_creation"].isoformat(),
            "derniere_connexion": None,
            "role":              created["role"],
            "secure_token":      created["secure_token"],
            "token":             created["token"],
            "check_verif":       created["check_verif"],
            "operating_system":  created["operating_system"],
            "country_code":      created["country_code"],
            "zone_benef":        created["zone_benef"],
            "zone_benef_code":   created["zone_benef_code"],
        }
    }), 200


# ═════════════════════════════════════════════════════════════
#  ROUTES GOOGLE SIGN-IN
# ═════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────
#  ROUTE 3  –  /google/login
#
#  Body JSON attendu :
#    google_token   (str)  obligatoire – ID token Google
#    google_IDtype  (str)  "ios" | "android"
#    provider       (str)  "apk"
#
#  Réponses :
#    200  →  utilisateur existant  →  connexion directe
#    201  →  nouvel utilisateur    →  renvoie completion_token
#    400  →  token manquant
#    401  →  token Google invalide
# ─────────────────────────────────────────────────────────────
@app.route('/google/login', methods=['POST'])
def google_login():
    data = request.get_json()

    google_token  = data.get('google_token')
    google_IDtype = data.get('google_IDtype', 'unknown')

    if not google_token:
        return jsonify({"error": "google_token requis"}), 400

    # ── Vérifier le token via Google tokeninfo ────────────────
    try:
        verify_resp = requests.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": google_token},
            timeout=10
        )
        if verify_resp.status_code != 200:
            return jsonify({"error": "Token Google invalide"}), 401

        google_info = verify_resp.json()
    except Exception:
        return jsonify({"error": "Impossible de vérifier le token Google"}), 401

    google_user_id = google_info.get("sub")
    email          = google_info.get("email", "")
    given_name     = google_info.get("given_name", "") or ""
    family_name    = google_info.get("family_name", "") or ""
    nom            = f"{given_name} {family_name}".strip() or email

    if not google_user_id:
        return jsonify({"error": "Identifiant Google introuvable"}), 401

    # ── Utilisateur existant ──────────────────────────────────
    user = client.APK_ARCHIVE.Users.find_one({
        "google_user_id": google_user_id,
        "check_verif":    True
    })

    if user:
        client.APK_ARCHIVE.Users.update_one(
            {"google_user_id": google_user_id},
            {"$set": {"derniere_connexion": datetime.utcnow()}}
        )

        serializable_user = {
            "_id":          str(user["_id"]),
            "phone_number": user.get("phone_number", ""),
            "nom":          user["nom"],
            "role":         user["role"],
            "secure_token": user.get("secure_token", ""),
            "token":        user["token"],
            "check_verif":  user["check_verif"],
        }

        return jsonify({
            "Code":            200,
            "messages":        "Connexion réussie",
            "token":           user["token"],
            "user":            serializable_user,
            "zone_benef":      user.get("zone_benef", ""),
            "zone_benef_code": user.get("zone_benef_code", "CG")
        }), 200

    # ── Nouvel utilisateur → générer un completion_token ─────
    completion_token = secrets.token_urlsafe(32)

    client.APK_ARCHIVE.GooglePendingUsers.replace_one(
        {"google_user_id": google_user_id},
        {
            "google_user_id":   google_user_id,
            "completion_token": completion_token,
            "email":            email,
            "nom":              nom,
            "google_IDtype":    google_IDtype,
            "created_at":       datetime.utcnow()
        },
        upsert=True
    )

    return jsonify({
        "completion_token": completion_token,
        "user": {
            "google_user_id": google_user_id,
            "email":          email,
            "nom":            nom,
            "given_name":     given_name,
            "family_name":    family_name,
        }
    }), 201


# ─────────────────────────────────────────────────────────────
#  ROUTE 4  –  /google/complete-profile
#
#  Body JSON attendu :
#    completion_token  (str)  obligatoire
#    phone             (str)  obligatoire
#    country_name      (str)  ex: "Congo"
#    country_code      (str)  ex: "CG"
#    zone_benef        (str)
#    zone_benef_code   (str)
#    provider          (str)  "apk"
#
#  Réponses :
#    200  →  compte créé (ou déjà existant)
#    400  →  paramètre manquant ou token invalide/expiré
# ─────────────────────────────────────────────────────────────
@app.route('/google/complete-profile', methods=['POST'])
def google_complete_profile():
    data = request.get_json()

    completion_token = data.get('completion_token')
    phone            = data.get('phone')
    country_name     = data.get('country_name',    'Congo')
    country_code     = data.get('country_code',    'CG')
    zone_benef       = data.get('zone_benef',      country_name)
    zone_benef_code  = data.get('zone_benef_code', country_code)

    if not completion_token or not phone:
        return jsonify({"error": "completion_token et phone sont requis"}), 400

    # ── Récupérer les données Google en attente ───────────────
    pending = client.APK_ARCHIVE.GooglePendingUsers.find_one({
        "completion_token": completion_token
    })

    if not pending:
        return jsonify({"error": "Token invalide ou expiré"}), 400

    google_user_id = pending["google_user_id"]
    nom            = (data.get('nom') or '').strip() or pending.get("nom") or phone
    email          = pending.get("email", "")

    # ── Protection contre le double appel ────────────────────
    existing = client.APK_ARCHIVE.Users.find_one({"google_user_id": google_user_id})
    if existing:
        client.APK_ARCHIVE.GooglePendingUsers.delete_one({
            "completion_token": completion_token
        })
        return jsonify({
            "Code":     200,
            "messages": "Compte déjà créé",
            "token":    existing["token"],
            "user": {
                "_id":          str(existing["_id"]),
                "phone_number": existing.get("phone_number", ""),
                "nom":          existing["nom"],
                "role":         existing["role"],
                "secure_token": existing.get("secure_token", ""),
                "token":        existing["token"],
                "check_verif":  existing["check_verif"],
            }
        }), 200

    # ── Créer le compte utilisateur ───────────────────────────
    secure_token = generate_secure_token_apk()
    token        = urllib.parse.quote(f"{secure_token}_-_{phone}_-_{nom}")

    user_document = {
        "google_user_id":     google_user_id,
        "phone_number":       phone,
        "email":              email,
        "nom":                nom,
        "miles":              10,
        "date_creation":      datetime.utcnow(),
        "derniere_connexion": None,
        "role":               "utilisateur",
        "secure_token":       secure_token,
        "token":              token,
        "check_verif":        True,
        "country_name":       country_name,
        "country_code":       country_code,
        "zone_benef":         zone_benef,
        "zone_benef_code":    zone_benef_code,
        "operating_system":   pending.get("google_IDtype", "unknown"),
        "auth_method":        "google"
    }

    result = client.APK_ARCHIVE.Users.insert_one(user_document)

    # ── Nettoyer la collection temporaire ─────────────────────
    client.APK_ARCHIVE.GooglePendingUsers.delete_one({
        "completion_token": completion_token
    })

    # ── Créer le wallet Miles ─────────────────────────────────
    client.APK_ARCHIVE.Miles.insert_one({
        "user_id":    token,
        "balance":    10,
        "currency":   "Miles",
        "pin":        secure_token,
        "is_active":  True,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    })

    # ── Notifications de bienvenue (non-bloquantes) ───────────
    try:
        notif_url = "https://api.live.wortis.cg/create_notifications"
        headers   = {"Content-Type": "application/json"}

        requests.post(notif_url, headers=headers, data=json.dumps({
            "type":    "info",
            "contenu": "Votre compte a été créé avec succès ! ☺️.",
            "user_id": token,
            "icone":   "info",
            "title":   "Bienvenue sur Wortis",
            "firebase": False
        }))
        requests.post(notif_url, headers=headers, data=json.dumps({
            "type":    "kdo",
            "contenu": "Vous venez de recevoir 10 Miles dans votre compte WortisPay",
            "user_id": token,
            "icone":   "kdo",
            "title":   "WortisPay Kdo"
        }))
    except Exception:
        pass

    # ── Réponse finale ────────────────────────────────────────
    created = client.APK_ARCHIVE.Users.find_one({"_id": result.inserted_id})

    return jsonify({
        "Code":     200,
        "messages": "Profil Google complété avec succès",
        "token":    token,
        "user": {
            "_id":               str(created["_id"]),
            "phone_number":      created["phone_number"],
            "nom":               created["nom"],
            "date_creation":     created["date_creation"].isoformat(),
            "derniere_connexion": None,
            "role":              created["role"],
            "secure_token":      created["secure_token"],
            "token":             created["token"],
            "check_verif":       created["check_verif"],
            "operating_system":  created["operating_system"],
            "country_code":      created["country_code"],
            "zone_benef":        created["zone_benef"],
            "zone_benef_code":   created["zone_benef_code"],
        }
    }), 200
