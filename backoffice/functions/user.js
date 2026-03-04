// user.js - Gestion des utilisateurs

// Variable globale pour stocker les utilisateurs
let users = [];

// Variables de pagination
let currentPage = 1;
let itemsPerPage = 10;
let filteredUsers = [];

// Fetch and Display Users
async function fetchUsers() {
    try {
        console.log("Début de fetchUsers");
        
        // Afficher un indicateur de chargement dans le tableau
        const tableBody = document.getElementById('usersTableBody');
        if (tableBody) {
            tableBody.innerHTML = '<tr><td colspan="4" class="text-center">Chargement des utilisateurs...</td></tr>';
        }
        
        // Faire la requête API
        const response = await fetch('https://api.live.wortis.cg/dash_user_apk');
        
        if (!response.ok) {
            throw new Error(`Erreur HTTP: ${response.status}`);
        }
        
        const data = await response.json();
        console.log("Données utilisateurs récupérées:", data);
        
        if (data && data.enregistrements) {
            users = data.enregistrements;
            filteredUsers = [...users];
            displayUsersPaginated(currentPage);
            setupPagination();
        } else {
            console.error("Format de données inattendu:", data);
            showToast('Format de données utilisateurs incorrect', 'error');
            
            // Afficher un message d'erreur dans le tableau
            if (tableBody) {
                tableBody.innerHTML = '<tr><td colspan="4" class="text-center text-danger">Impossible de charger les utilisateurs</td></tr>';
            }
        }
    } catch (error) {
        console.error('Erreur lors de la récupération des utilisateurs:', error);
        showToast('Erreur lors du chargement des utilisateurs', 'error');
        
        // Afficher un message d'erreur dans le tableau
        const tableBody = document.getElementById('usersTableBody');
        if (tableBody) {
            tableBody.innerHTML = '<tr><td colspan="4" class="text-center text-danger">Erreur lors du chargement des utilisateurs</td></tr>';
        }
    }
}

// Fonction pour afficher les utilisateurs avec pagination
function displayUsersPaginated(page) {
    const tableBody = document.getElementById('usersTableBody');
    if (!tableBody) return;
    
    tableBody.innerHTML = '';

    // Si aucun utilisateur n'est trouvé
    if (filteredUsers.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="4" class="text-center">Aucun utilisateur trouvé</td></tr>';
        
        // Mettre à jour les infos de pagination
        document.getElementById('startItem').textContent = '0';
        document.getElementById('endItem').textContent = '0';
        document.getElementById('totalItems').textContent = '0';
        return;
    }

    // Calculer les indices
    const startIndex = (page - 1) * itemsPerPage;
    const endIndex = Math.min(startIndex + itemsPerPage, filteredUsers.length);
    
    // Mettre à jour les infos de pagination
    document.getElementById('startItem').textContent = filteredUsers.length > 0 ? startIndex + 1 : 0;
    document.getElementById('endItem').textContent = endIndex;
    document.getElementById('totalItems').textContent = filteredUsers.length;

    // Afficher uniquement les utilisateurs de la page courante
    for (let i = startIndex; i < endIndex; i++) {
        const user = filteredUsers[i];
        const row = document.createElement('tr');
        
        // Formatage de la date
        let dateFormatted = 'N/A';
        if (user.date_creation) {
            try {
                dateFormatted = new Date(user.date_creation).toLocaleDateString();
            } catch (error) {
                console.error('Erreur lors du formatage de la date:', error);
            }
        }
        
        row.innerHTML = `
            <td>${user.nom || 'N/A'}</td>
            <td>${user.phone_number || 'N/A'}</td>
            <td>${dateFormatted}</td>
            <td>
                <button class="btn btn-outline" onclick="editUser('${user._id}')">
                    <i class="fas fa-edit"></i> Éditer
                </button>
                <button class="btn btn-danger" onclick="deleteUser('${user._id}')">
                    <i class="fas fa-trash"></i> Supprimer
                </button>
            </td>
        `;
        tableBody.appendChild(row);
    }
}

// Configuration de la pagination
function setupPagination() {
    const paginationElement = document.getElementById('pagination');
    if (!paginationElement) return;
    
    const totalPages = Math.ceil(filteredUsers.length / itemsPerPage);
    paginationElement.innerHTML = '';

    if (totalPages === 0) {
        return; // Ne pas afficher la pagination s'il n'y a pas de pages
    }

    // Bouton précédent
    const prevLi = document.createElement('li');
    prevLi.className = `pagination-item ${currentPage === 1 ? 'disabled' : ''}`;
    prevLi.innerHTML = '<i class="fas fa-chevron-left"></i>';
    prevLi.addEventListener('click', () => {
        if (currentPage > 1) goToPage(currentPage - 1);
    });
    paginationElement.appendChild(prevLi);

    // Numéros de page
    for (let i = Math.max(1, currentPage - 2); i <= Math.min(totalPages, currentPage + 2); i++) {
        const pageLi = document.createElement('li');
        pageLi.className = `pagination-item ${currentPage === i ? 'active' : ''}`;
        pageLi.textContent = i;
        pageLi.addEventListener('click', () => goToPage(i));
        paginationElement.appendChild(pageLi);
    }

    // Bouton suivant
    const nextLi = document.createElement('li');
    nextLi.className = `pagination-item ${currentPage === totalPages ? 'disabled' : ''}`;
    nextLi.innerHTML = '<i class="fas fa-chevron-right"></i>';
    nextLi.addEventListener('click', () => {
        if (currentPage < totalPages) goToPage(currentPage + 1);
    });
    paginationElement.appendChild(nextLi);
}

// Fonction pour aller à une page spécifique
function goToPage(page) {
    currentPage = page;
    displayUsersPaginated(currentPage);
    setupPagination();
}

// Validation du formulaire
function validateUserForm(formData) {
    const errors = [];
    
    if (!formData.nom || formData.nom.trim() === '') {
        errors.push('Le nom est requis');
    }
    
    if (!formData.phone_number || formData.phone_number.trim() === '') {
        errors.push('Le numéro de téléphone est requis');
    } else if (!/^[0-9+\s()-]{8,15}$/.test(formData.phone_number)) {
        errors.push('Le format du numéro de téléphone est invalide');
    }
    
    // Pour la création d'utilisateur, le mot de passe est requis
    if (!formData.password) {
        errors.push('Le mot de passe est requis');
    } else if (formData.password.length < 6) {
        errors.push('Le mot de passe doit contenir au moins 6 caractères');
    }
    
    return errors;
}

// Fonction pour la création d'utilisateur
async function submitAddUser() {
    const form = document.getElementById('addUserForm');
    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());
    
    // Validation des données
    const validationErrors = validateUserForm(data);
    if (validationErrors.length > 0) {
        showToast(validationErrors[0], 'error');
        return;
    }
    
    // Récupérer le bouton d'ajout pour afficher l'état de chargement
    const addButton = document.querySelector('#addUserModal .btn-primary');
    const originalText = addButton.innerHTML;
    addButton.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Ajout en cours...';
    addButton.disabled = true;
    
    try {
        // Préparer les données pour l'API
        const apiData = {
            nom: data.nom,
            phone_number: data.phone_number,
            password: data.password,
            status: data.status === 'on'
        };
        
        console.log('Données à envoyer:', apiData);
        
        const response = await fetch('https://api.live.wortis.cg/register_apk_wpay_v2_back', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(apiData)
        });

        const result = await response.json();
        console.log('Réponse création:', result);

        if (response.ok || result.Code === 200) {
            closeModal('addUserModal');
            showToast('Utilisateur ajouté avec succès', 'success');
            form.reset();
            fetchUsers(); // Rafraîchir la liste
        } else {
            // Afficher le message d'erreur spécifique s'il existe
            showToast(result.messages || 'Erreur lors de l\'ajout de l\'utilisateur', 'error');
        }
    } catch (error) {
        console.error('Erreur complète:', error);
        showToast('Erreur de connexion au serveur', 'error');
    } finally {
        // Restaurer l'état du bouton
        addButton.innerHTML = originalText;
        addButton.disabled = false;
    }
}

// Fonction pour éditer un utilisateur
function editUser(userId) {
    const user = users.find(u => u._id === userId);
    if (user) {
        const form = document.getElementById('editUserForm');
        form.querySelector('[name="userId"]').value = userId;
        form.querySelector('[name="userToken"]').value = user.token || ''; // Stocker le token
        form.querySelector('[name="nom"]').value = user.nom || '';
        form.querySelector('[name="phone_number"]').value = user.phone_number || '';
        
        // Si vous avez un switch pour le statut
        const statusSwitch = form.querySelector('[name="status"]');
        if (statusSwitch) {
            statusSwitch.checked = user.status !== false;
        }
        
        openModal('editUserModal');
    } else {
        showToast('Utilisateur non trouvé', 'error');
    }
}

// Fonction pour soumettre les modifications d'un utilisateur
async function submitEditUser() {
    const form = document.getElementById('editUserForm');
    const userId = form.querySelector('[name="userId"]').value;
    const userToken = form.querySelector('[name="userToken"]').value;
    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());
    
    // Validation
    if (!data.nom || !data.phone_number) {
        showToast('Veuillez remplir tous les champs', 'error');
        return;
    }
    
    // Afficher l'indicateur de chargement
    const editButton = document.querySelector('#editUserModal .btn-primary');
    const originalText = editButton.innerHTML;
    editButton.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Modification en cours...';
    editButton.disabled = true;

    try {
        // Préparer les données pour l'API
        const apiData = {
            nom: data.nom,
            phone_number: data.phone_number,
            status: data.status === 'on' // Convertir la valeur du switch en booléen
        };
        
        console.log('Données à envoyer pour modification:', apiData);
        
        // Utiliser le token au lieu de l'ID pour l'URL
        const response = await fetch(`https://api.live.wortis.cg/update_user_apk_wpay_v2_back/${userToken}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(apiData)
        });

        const result = await response.json();
        console.log('Réponse modification:', result);

        if (result.Code === 200) {
            closeModal('editUserModal');
            showToast('Utilisateur modifié avec succès', 'success');
            fetchUsers(); // Rafraîchir la liste
        } else {
            showToast(result.messages || 'Erreur lors de la modification', 'error');
        }
    } catch (error) {
        console.error('Erreur:', error);
        showToast('Erreur lors de la modification de l\'utilisateur', 'error');
    } finally {
        // Restaurer l'état du bouton
        editButton.innerHTML = originalText;
        editButton.disabled = false;
    }
}

// Fonction pour préparer la suppression d'un utilisateur
function deleteUser(userId) {
    const user = users.find(u => u._id === userId);
    if (user && user.token) {
        document.getElementById('deleteUserId').value = user.token; // Stocker le token au lieu de l'ID
        // Afficher le nom de l'utilisateur dans la confirmation
        const userName = user.nom || 'Cet utilisateur';
        document.querySelector('#deleteUserModal .modal-body p').textContent = 
            `Êtes-vous sûr de vouloir supprimer l'utilisateur "${userName}" ? Cette action est irréversible.`;
        openModal('deleteUserModal');
    } else {
        showToast('Utilisateur non trouvé', 'error');
    }
}

// Fonction pour confirmer la suppression d'un utilisateur
async function confirmDeleteUser() {
    const userToken = document.getElementById('deleteUserId').value;
    if (!userToken) {
        showToast('Token utilisateur non trouvé', 'error');
        return;
    }

    // Récupérer le bouton de suppression pour afficher l'état de chargement
    const deleteButton = document.querySelector('#deleteUserModal .btn-danger');
    const originalText = deleteButton.innerHTML;
    deleteButton.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Suppression...';
    deleteButton.disabled = true;

    try {
        console.log('Token pour suppression:', userToken);
        
        const response = await fetch('https://api.live.wortis.cg/clear_users_apk_wpay_v2', {
            method: 'DELETE',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ token: userToken }) // Envoyer le token dans le body
        });

        const result = await response.json();
        console.log('Réponse suppression:', result);

        if (result.Code === 200) {
            closeModal('deleteUserModal');
            showToast('Utilisateur supprimé avec succès', 'success');
            fetchUsers(); // Rafraîchir la liste
        } else {
            showToast(result.messages || 'Erreur lors de la suppression', 'error');
        }
    } catch (error) {
        console.error('Erreur complète:', error);
        showToast('Erreur lors de la suppression de l\'utilisateur', 'error');
    } finally {
        // Restaurer l'état du bouton
        deleteButton.innerHTML = originalText;
        deleteButton.disabled = false;
    }
}

// Initialisation des événements
document.addEventListener('DOMContentLoaded', function() {
    // Écouteur pour la recherche d'utilisateurs
    const searchInput = document.querySelector('#users-page .search-input');
    if (searchInput) {
        searchInput.addEventListener('input', (e) => {
            const searchTerm = e.target.value.toLowerCase();
            
            if (searchTerm.trim() === '') {
                filteredUsers = [...users];
            } else {
                filteredUsers = users.filter(user => {
                    return (user.nom && user.nom.toLowerCase().includes(searchTerm)) ||
                        (user.phone_number && user.phone_number.toLowerCase().includes(searchTerm));
                });
            }
            
            currentPage = 1; // Retour à la première page
            displayUsersPaginated(currentPage);
            setupPagination();
        });
    }

    // Bouton pour ajouter un utilisateur
    const addUserButton = document.getElementById('addUserBtn');
    if (addUserButton) {
        addUserButton.addEventListener('click', function() {
            document.getElementById('addUserForm').reset();
            // S'assurer que le switch de statut est actif par défaut
            const statusSwitch = document.querySelector('#addUserForm [name="status"]');
            if (statusSwitch) {
                statusSwitch.checked = true;
            }
            openModal('addUserModal');
        });
    }
    
    // Écouteurs pour les boutons de soumission des formulaires
    const submitAddUserBtn = document.querySelector('#addUserModal .btn-primary');
    if (submitAddUserBtn) {
        submitAddUserBtn.addEventListener('click', submitAddUser);
    }
    
    const submitEditUserBtn = document.querySelector('#editUserModal .btn-primary');
    if (submitEditUserBtn) {
        submitEditUserBtn.addEventListener('click', submitEditUser);
    }
    
    const confirmDeleteUserBtn = document.querySelector('#deleteUserModal .btn-danger');
    if (confirmDeleteUserBtn) {
        confirmDeleteUserBtn.addEventListener('click', confirmDeleteUser);
    }
    
    // Charger les utilisateurs au démarrage si on est sur la page utilisateurs
    if (document.getElementById('users-page') && 
        document.getElementById('users-page').style.display !== 'none') {
        fetchUsers();
    }
});