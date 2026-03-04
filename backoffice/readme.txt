# WortisAPK Admin - Structure des fichiers JavaScript

Ce document explique la structure des fichiers JavaScript qui ont été réorganisés pour améliorer la maintenance et la lisibilité du code.

## Fichiers principaux

### gas.js
- Gestion de la navigation entre les pages
- Fonctions générales utilisées par toute l'application (modals, toasts, formatage de dates)
- Point central qui coordonne les changements de page et appelle les fonctions appropriées

### main.js
- Point d'entrée de l'application
- Initialisation globale
- Gestion du mode sombre

## Fichiers par fonctionnalité

### dashboard.js
- Gestion du tableau de bord principal
- Chargement et affichage des statistiques
- Gestion des activités récentes et derniers utilisateurs

### user.js
- Gestion complète des utilisateurs (CRUD)
- Fonctions d'affichage, pagination, recherche et filtrage
- Fonctions de validation de formulaire

### wallet.js
- Gestion des portefeuilles des utilisateurs
- Mise à jour des miles
- Pagination et recherche de portefeuilles

### secteur.js
- Gestion des secteurs d'activité
- CRUD complet pour les secteurs
- Pagination et recherche

### service.js
- Gestion des services
- CRUD complet pour les services
- Filtrage par secteur d'activité
- Pagination et recherche

### banners.js
- Gestion des bannières promotionnelles
- Ajout, édition et suppression de bannières
- Prévisualisation des images
- Pagination et recherche

### notif.js
- Gestion des notifications
- Création et envoi de notifications
- Prévisualisation des notifications
- Filtrage et recherche

## Comment intégrer ces fichiers

Dans le fichier HTML principal, incluez ces scripts dans l'ordre suivant:

```html
<script src="gas.js"></script>
<script src="main.js"></script>
<script src="dashboard.js"></script>
<script src="user.js"></script>
<script src="wallet.js"></script>
<script src="secteur.js"></script>
<script src="service.js"></script>
<script src="banners.js"></script>
<script src="notif.js"></script>
```

Cette organisation permet de:
1. Séparer clairement les responsabilités
2. Faciliter la maintenance de chaque module
3. Améliorer la lisibilité du code
4. Permettre à plusieurs développeurs de travailler en parallèle sur différentes fonctionnalités
5. Faciliter les tests unitaires pour chaque composant
6. Réduire les conflits lors des fusions de code (merge conflicts)
7. Permettre le chargement conditionnel des scripts si nécessaire