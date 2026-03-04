import random
import uuid
import logging
from flask import Flask, request, jsonify, Blueprint
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timezone
import requests
from flask_cors import CORS
import os
from bson import ObjectId
from pymongo import MongoClient, DESCENDING
import json
from datetime import timedelta
import string
import ftplib
import base64
from io import BytesIO
from ..functions import ultraChatBot
from ressources.functions import send_msg
from ressources.databases import marchandbd
from ressources.databases import client


# ── Config FTP ──
FTP_HOST = "apigede.wortispay.cg"
FTP_USER = "ftp_apigede_wortispay_cg"
FTP_PASS = "X8FNf8hEk6s5pNHZ"
FTP_DIR  = "/apk-mobile/news"
BASE_IMAGE_URL = "https://apigede.wortispay.cg/apk-mobile/news"

# Configuration Blueprint
wortis_app_bp = Blueprint('wortis_app', __name__, url_prefix='/wortis_app_bp')

# Référence à la collection news
def news_collection():
    return client['wortispay']['news']


# ─────────────────────────────────────────────
# Utilitaire : sérialiser un document MongoDB
# ─────────────────────────────────────────────
def serialize_news(doc):
    doc['_id'] = str(doc['_id'])
    return doc


# ─────────────────────────────────────────────
# Health check
# ─────────────────────────────────────────────
@wortis_app_bp.route('/')
def hello():
    return jsonify({"message": "Hello from Back office App Wortis"})


# ─────────────────────────────────────────────
# GET  /wortis_app_bp/news
# Liste toutes les news
# Query params: statut, categorie
# ─────────────────────────────────────────────
@wortis_app_bp.route('/news', methods=['GET'])
def get_news():
    try:
        statut    = request.args.get('statut', None)
        categorie = request.args.get('categorie', None)

        query = {}
        if statut:
            query['statut'] = statut
        if categorie:
            query['categorie'] = categorie

        col    = news_collection()
        cursor = col.find(query).sort('date_creation', DESCENDING)
        news   = [serialize_news(doc) for doc in cursor]

        return jsonify({"success": True, "total": len(news), "news": news}), 200

    except Exception as e:
        logging.error(f"[GET /news] {e}")
        return jsonify({"success": False, "message": str(e)}), 500


# ─────────────────────────────────────────────
# POST /wortis_app_bp/news/upload-image
# Upload d'une image via FTP → retourne l'URL publique
# Body: multipart/form-data, champ "image"
# ─────────────────────────────────────────────
@wortis_app_bp.route('/news/upload-image', methods=['POST'])
def upload_news_image():
    try:
        if 'image' not in request.files:
            return jsonify({"success": False, "message": "Aucun fichier fourni"}), 400

        file = request.files['image']
        if not file.filename:
            return jsonify({"success": False, "message": "Nom de fichier vide"}), 400

        # Générer un nom de fichier unique
        ext      = os.path.splitext(file.filename)[1].lower() or '.jpg'
        filename = f"news_{uuid.uuid4().hex}{ext}"

        file_bytes = file.read()

        # Upload FTP
        ftp = ftplib.FTP(FTP_HOST)
        ftp.login(FTP_USER, FTP_PASS)
        ftp.cwd(FTP_DIR)
        ftp.storbinary(f"STOR {filename}", BytesIO(file_bytes))
        ftp.quit()

        image_url = f"{BASE_IMAGE_URL}/{filename}"
        return jsonify({"success": True, "url": image_url, "filename": filename}), 200

    except ftplib.all_errors as e:
        logging.error(f"[FTP upload] {e}")
        return jsonify({"success": False, "message": f"Erreur FTP : {str(e)}"}), 500
    except Exception as e:
        logging.error(f"[POST /news/upload-image] {e}")
        return jsonify({"success": False, "message": str(e)}), 500


# ─────────────────────────────────────────────
# GET  /wortis_app_bp/news/<id>
# Détail d'une news
# ─────────────────────────────────────────────
@wortis_app_bp.route('/news/<string:news_id>', methods=['GET'])
def get_news_by_id(news_id):
    try:
        col = news_collection()
        doc = col.find_one({"_id": ObjectId(news_id)})
        if not doc:
            return jsonify({"success": False, "message": "News introuvable"}), 404
        return jsonify({"success": True, "news": serialize_news(doc)}), 200
    except Exception as e:
        logging.error(f"[GET /news/{news_id}] {e}")
        return jsonify({"success": False, "message": str(e)}), 500


# ─────────────────────────────────────────────
# POST /wortis_app_bp/news
# Créer une nouvelle news
# Body JSON: { titre, contenu, image?, categorie, statut }
# ─────────────────────────────────────────────
@wortis_app_bp.route('/news', methods=['POST'])
def create_news():
    try:
        body = request.get_json(force=True)

        titre     = body.get('titre', '').strip()
        contenu   = body.get('contenu', '').strip()
        image     = body.get('image', '').strip()
        categorie = body.get('categorie', 'general').strip()
        statut    = body.get('statut', 'active').strip()

        if not titre or not contenu:
            return jsonify({"success": False, "message": "Les champs titre et contenu sont obligatoires"}), 400

        if categorie not in ['general', 'promo', 'maintenance', 'alerte', 'nouveaute']:
            categorie = 'general'

        if statut not in ['active', 'inactive']:
            statut = 'active'

        now = datetime.now(timezone.utc)
        doc = {
            "titre":           titre,
            "contenu":         contenu,
            "image":           image,
            "categorie":       categorie,
            "statut":          statut,
            "date_creation":   now,
            "date_modification": now
        }

        result = news_collection().insert_one(doc)
        doc['_id'] = str(result.inserted_id)

        return jsonify({"success": True, "message": "News créée avec succès", "news": doc}), 201

    except Exception as e:
        logging.error(f"[POST /news] {e}")
        return jsonify({"success": False, "message": str(e)}), 500


# ─────────────────────────────────────────────
# PUT  /wortis_app_bp/news/<id>
# Modifier une news existante
# ─────────────────────────────────────────────
@wortis_app_bp.route('/news/<string:news_id>', methods=['PUT'])
def update_news(news_id):
    try:
        body = request.get_json(force=True)
        col  = news_collection()

        existing = col.find_one({"_id": ObjectId(news_id)})
        if not existing:
            return jsonify({"success": False, "message": "News introuvable"}), 404

        updates = {}
        if 'titre' in body:
            titre = body['titre'].strip()
            if not titre:
                return jsonify({"success": False, "message": "Le titre ne peut pas être vide"}), 400
            updates['titre'] = titre

        if 'contenu' in body:
            contenu = body['contenu'].strip()
            if not contenu:
                return jsonify({"success": False, "message": "Le contenu ne peut pas être vide"}), 400
            updates['contenu'] = contenu

        if 'image' in body:
            updates['image'] = body['image'].strip()

        if 'categorie' in body:
            cat = body['categorie'].strip()
            updates['categorie'] = cat if cat in ['general', 'promo', 'maintenance', 'alerte', 'nouveaute'] else 'general'

        if 'statut' in body:
            st = body['statut'].strip()
            updates['statut'] = st if st in ['active', 'inactive'] else 'active'

        if not updates:
            return jsonify({"success": False, "message": "Aucune modification fournie"}), 400

        updates['date_modification'] = datetime.now(timezone.utc)

        col.update_one({"_id": ObjectId(news_id)}, {"$set": updates})

        updated = col.find_one({"_id": ObjectId(news_id)})
        return jsonify({"success": True, "message": "News modifiée avec succès", "news": serialize_news(updated)}), 200

    except Exception as e:
        logging.error(f"[PUT /news/{news_id}] {e}")
        return jsonify({"success": False, "message": str(e)}), 500


# ─────────────────────────────────────────────
# DELETE /wortis_app_bp/news/<id>
# Supprimer une news
# ─────────────────────────────────────────────
@wortis_app_bp.route('/news/<string:news_id>', methods=['DELETE'])
def delete_news(news_id):
    try:
        col    = news_collection()
        result = col.delete_one({"_id": ObjectId(news_id)})

        if result.deleted_count == 0:
            return jsonify({"success": False, "message": "News introuvable"}), 404

        return jsonify({"success": True, "message": "News supprimée avec succès"}), 200

    except Exception as e:
        logging.error(f"[DELETE /news/{news_id}] {e}")
        return jsonify({"success": False, "message": str(e)}), 500
