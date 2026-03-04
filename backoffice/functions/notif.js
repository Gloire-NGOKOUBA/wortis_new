// ======================================
// GESTION DES NOTIFICATIONS CIBLÉES
// ======================================

// Variables globales
let selectedServices = [];
let selectedCustomUsers = []; // Utilisateurs sélectionnés pour le ciblage personnalisé
let totalRecipients = 0; // Nombre total d'utilisateurs (sera mis à jour dynamiquement)
let allUsers = []; // Liste de tous les utilisateurs
let targetedUsers = []; // Utilisateurs ciblés pour la notification

// ======================================
// INITIALISATION
// ======================================
document.addEventListener('DOMContentLoaded', function() {
    initNotificationModal();
    initTargetingMode();
    initPreviewUpdates();
    initServiceSelection();
});

// ======================================
// OUVERTURE DU MODAL
// ======================================
document.getElementById('createNotificationBtn')?.addEventListener('click', function() {
    openModal('notificationModal');
    resetNotificationForm();
});

// ======================================
// RESET DU FORMULAIRE
// ======================================
function resetNotificationForm() {
    document.getElementById('notificationForm').reset();
    selectedServices = [];
    selectedCustomUsers = [];

    // Reset des checkboxes
    document.querySelectorAll('input[name="service"]').forEach(cb => cb.checked = false);

    // Reset du mode de ciblage
    document.querySelector('input[name="targetingMode"][value="all"]').checked = true;
    hideAllTargetingSections();

    // Reset de la liste des utilisateurs personnalisés
    updateSelectedUsersDisplay();

    // Update counters
    updateRecipientsCounter();
    updatePreview();
}

// ======================================
// MODE DE CIBLAGE
// ======================================
function initTargetingMode() {
    const targetingModeInputs = document.querySelectorAll('input[name="targetingMode"]');

    targetingModeInputs.forEach(input => {
        input.addEventListener('change', function() {
            handleTargetingModeChange(this.value);
        });
    });
}

function handleTargetingModeChange(mode) {
    hideAllTargetingSections();

    switch(mode) {
        case 'all':
            updateRecipientsCounter(allUsers.length);
            break;
        case 'services':
            document.getElementById('servicesTargeting').style.display = 'block';
            updateRecipientsCounter(calculateServiceRecipients());
            break;
        case 'custom':
            document.getElementById('customTargeting').style.display = 'block';
            renderCustomUsersList();
            updateRecipientsCounter(selectedCustomUsers.length);
            break;
    }
}

function hideAllTargetingSections() {
    document.getElementById('servicesTargeting').style.display = 'none';
    document.getElementById('customTargeting').style.display = 'none';
}

// ======================================
// SÉLECTION DES SERVICES
// ======================================
function initServiceSelection() {
    // Gestion de la sélection des services
    const serviceCheckboxes = document.querySelectorAll('input[name="service"]');
    serviceCheckboxes.forEach(checkbox => {
        checkbox.addEventListener('change', async function() {
            const serviceCard = this.closest('.service-card');
            const numc = this.value;

            if (this.checked) {
                selectedServices.push(numc);
                // Ajouter une classe pour marquer le service comme sélectionné
                if (serviceCard) {
                    serviceCard.classList.add('selected');
                }
            } else {
                selectedServices = selectedServices.filter(id => id !== numc);
                // Retirer la classe de sélection
                if (serviceCard) {
                    serviceCard.classList.remove('selected');
                }
            }

            const count = await calculateServiceRecipients();
            updateRecipientsCounter(count);
        });
    });

    // Recherche de services
    const searchInput = document.getElementById('searchServices');
    if (searchInput) {
        searchInput.addEventListener('input', function(e) {
            filterServices(e.target.value);
        });
    }

    // Gestion de la recherche d'utilisateurs personnalisés
    const searchUsersInput = document.getElementById('searchSpecificUsers');
    if (searchUsersInput) {
        searchUsersInput.addEventListener('input', function(e) {
            filterCustomUsers(e.target.value);
        });
    }
}

async function calculateServiceRecipients() {
    if (selectedServices.length === 0) return 0;

    try {
        // Appel API pour récupérer le nombre réel d'utilisateurs par numc
        console.log(`📊 Calcul pour ${selectedServices.length} service(s):`, selectedServices);

        const response = await fetch('https://api.live.wortis.cg/notifications/api/users/by-numc', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                numc_list: selectedServices,  // Les numc des services sélectionnés
                min_transactions: 1
            })
        });

        if (response.ok) {
            const data = await response.json();
            console.log(`✅ ${data.total_users} utilisateurs trouvés pour ces services`);
            return data.total_users || 0;
        } else {
            const errorText = await response.text();
            console.error('Erreur lors du calcul des destinataires par service:', errorText);
            return 0;
        }
    } catch (error) {
        console.error('Erreur API:', error);
        return 0;
    }
}

// ======================================
// CIBLAGE PERSONNALISÉ - GESTION DES UTILISATEURS
// ======================================
function renderCustomUsersList() {
    const container = document.getElementById('customUsersListContainer');
    if (!container) return;

    container.innerHTML = '';

    if (allUsers.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-user-slash"></i>
                <p>Aucun utilisateur disponible</p>
            </div>
        `;
        return;
    }

    // Créer une liste d'utilisateurs
    allUsers.forEach(user => {
        const isSelected = selectedCustomUsers.some(u => u.user_id === user.user_id);

        const userCard = document.createElement('div');
        userCard.className = `user-card ${isSelected ? 'selected' : ''}`;
        userCard.innerHTML = `
            <div class="user-card-info">
                <div class="user-card-avatar">
                    <i class="fas fa-user"></i>
                </div>
                <div class="user-card-details">
                    <div class="user-card-name">${user.nom || 'Utilisateur'}</div>
                    <div class="user-card-meta">${user.phone_number || user.user_id}</div>
                </div>
            </div>
            <button type="button" class="btn-select-user" data-user-id="${user.user_id}">
                <i class="fas ${isSelected ? 'fa-check' : 'fa-plus'}"></i>
            </button>
        `;

        // Event listener pour sélectionner/désélectionner
        const selectBtn = userCard.querySelector('.btn-select-user');
        selectBtn.addEventListener('click', function() {
            toggleUserSelection(user);
        });

        container.appendChild(userCard);
    });
}

function toggleUserSelection(user) {
    const index = selectedCustomUsers.findIndex(u => u.user_id === user.user_id);

    if (index > -1) {
        // Retirer l'utilisateur
        selectedCustomUsers.splice(index, 1);
    } else {
        // Ajouter l'utilisateur
        selectedCustomUsers.push(user);
    }

    // Mettre à jour l'affichage
    updateSelectedUsersDisplay();
    renderCustomUsersList();
    updateRecipientsCounter(selectedCustomUsers.length);
}

function updateSelectedUsersDisplay() {
    const container = document.getElementById('selectedUsersContainer');
    const countElement = document.getElementById('selectedUsersCount');

    if (!container) return;

    countElement.textContent = selectedCustomUsers.length;

    if (selectedCustomUsers.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-users"></i>
                <p>Aucun utilisateur sélectionné</p>
                <small>Utilisez la recherche ci-dessus pour trouver et sélectionner des utilisateurs</small>
            </div>
        `;
        return;
    }

    container.innerHTML = '';
    selectedCustomUsers.forEach(user => {
        const userTag = document.createElement('div');
        userTag.className = 'user-tag';
        userTag.innerHTML = `
            <span class="user-tag-name">${user.nom || 'Utilisateur'}</span>
            <span class="user-tag-phone">${user.phone_number || user.user_id}</span>
            <button type="button" class="user-tag-remove" data-user-id="${user.user_id}">
                <i class="fas fa-times"></i>
            </button>
        `;

        const removeBtn = userTag.querySelector('.user-tag-remove');
        removeBtn.addEventListener('click', function() {
            toggleUserSelection(user);
        });

        container.appendChild(userTag);
    });
}

function filterCustomUsers(searchTerm) {
    const term = searchTerm.toLowerCase().trim();
    const userCards = document.querySelectorAll('.user-card');

    userCards.forEach(card => {
        const name = card.querySelector('.user-card-name')?.textContent.toLowerCase() || '';
        const meta = card.querySelector('.user-card-meta')?.textContent.toLowerCase() || '';

        if (name.includes(term) || meta.includes(term)) {
            card.style.display = 'flex';
        } else {
            card.style.display = 'none';
        }
    });
}

function filterServices(searchTerm) {
    const serviceCards = document.querySelectorAll('.service-card');
    const term = searchTerm.toLowerCase();

    serviceCards.forEach(card => {
        const serviceName = card.querySelector('.service-name').textContent.toLowerCase();
        if (serviceName.includes(term)) {
            card.style.display = 'block';
        } else {
            card.style.display = 'none';
        }
    });
}

// ======================================
// COMPTEUR DE DESTINATAIRES
// ======================================
function updateRecipientsCounter(count = 0) {
    const counterElement = document.getElementById('recipientsCount');
    const summaryElement = document.getElementById('summaryRecipients');

    // Animation du compteur
    animateCounter(counterElement, parseInt(counterElement.textContent), count);

    if (summaryElement) {
        summaryElement.textContent = count;
    }
}

function animateCounter(element, start, end) {
    const duration = 500;
    const startTime = performance.now();

    function update(currentTime) {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);

        const currentValue = Math.floor(start + (end - start) * progress);
        element.textContent = currentValue;

        if (progress < 1) {
            requestAnimationFrame(update);
        }
    }

    requestAnimationFrame(update);
}

// ======================================
// PRÉVISUALISATION EN TEMPS RÉEL
// ======================================
function initPreviewUpdates() {
    // Mise à jour du titre
    const titleInput = document.getElementById('notificationTitle');
    if (titleInput) {
        titleInput.addEventListener('input', function(e) {
            updatePreviewTitle(e.target.value);
        });
    }

    // Mise à jour du contenu
    const contentInput = document.getElementById('notificationContent');
    if (contentInput) {
        contentInput.addEventListener('input', function(e) {
            updatePreviewContent(e.target.value);
            updateCharCounter(e.target.value.length);
        });
    }

    // Mise à jour du type
    const typeSelect = document.getElementById('notificationType');
    if (typeSelect) {
        typeSelect.addEventListener('change', function(e) {
            updateSummaryType(e.target.value);
        });
    }

    // Mise à jour de la programmation
    const scheduleInputs = document.querySelectorAll('input[name="schedule"]');
    scheduleInputs.forEach(input => {
        input.addEventListener('change', function() {
            handleScheduleChange(this.value);
        });
    });
}

function updatePreviewTitle(title) {
    const previewTitle = document.getElementById('previewTitle');
    previewTitle.textContent = title || 'Titre de la notification';
}

function updatePreviewContent(content) {
    const previewContent = document.getElementById('previewContent');
    previewContent.textContent = content || 'Contenu de la notification...';
}

function updateCharCounter(count) {
    const charCountElement = document.getElementById('charCount');
    charCountElement.textContent = count;

    // Change la couleur si on dépasse 200 caractères
    const counter = charCountElement.parentElement;
    if (count > 200) {
        counter.style.color = 'var(--danger-color)';
    } else {
        counter.style.color = 'var(--text-light)';
    }
}

function updateSummaryType(type) {
    const typeMap = {
        'info': '📋 Information',
        'promo': '🎁 Promotion',
        'alert': '⚠️ Alerte',
        'system': '⚙️ Système'
    };

    const summaryType = document.getElementById('summaryType');
    summaryType.textContent = typeMap[type] || 'Information';
}

function handleScheduleChange(scheduleType) {
    const dateContainer = document.getElementById('scheduleDateContainer');
    const summarySchedule = document.getElementById('summarySchedule');

    if (scheduleType === 'scheduled') {
        dateContainer.style.display = 'block';
        summarySchedule.textContent = 'Programmé';
    } else {
        dateContainer.style.display = 'none';
        summarySchedule.textContent = 'Envoi immédiat';
    }
}

function updatePreview() {
    updatePreviewTitle('');
    updatePreviewContent('');
    updateSummaryType('info');
}

// ======================================
// ENVOI DE LA NOTIFICATION
// ======================================
document.getElementById('saveNotificationBtn')?.addEventListener('click', function() {
    sendNotification();
});

async function sendNotification() {
    const form = document.getElementById('notificationForm');

    // Validation du formulaire
    if (!form.checkValidity()) {
        form.reportValidity();
        return;
    }

    // Récupération des données
    const title = document.getElementById('notificationTitle').value;
    const content = document.getElementById('notificationContent').value;
    const type = document.getElementById('notificationType').value;
    const priority = document.getElementById('notificationPriority').value;
    const targetingMode = document.querySelector('input[name="targetingMode"]:checked').value;
    const schedule = document.querySelector('input[name="schedule"]:checked').value;
    const scheduleDate = document.getElementById('scheduleDate')?.value || null;

    // Déterminer les utilisateurs ciblés
    targetedUsers = await getTargetedUsers(targetingMode);

    // Validation des destinataires
    if (targetedUsers.length === 0) {
        showToast('Veuillez sélectionner au moins un destinataire', 'error');
        return;
    }

    // Désactiver le bouton d'envoi pour éviter les doubles clics
    const sendButton = document.getElementById('saveNotificationBtn');
    sendButton.disabled = true;
    sendButton.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Envoi en cours...';

    console.log(`🚀 Envoi de la notification à ${targetedUsers.length} utilisateurs...`);

    try {
        let successCount = 0;
        let failCount = 0;

        // Envoyer la notification à chaque utilisateur ciblé
        for (const user of targetedUsers) {
            try {
                const notificationPayload = {
                    user_id: user.user_id,  // user_id = token (ex: "4328_-_+242068196183_-_GAS-EBEBA")
                    type: type,
                    contenu: content,
                    icone: type,
                    title: title
                };

                console.log(`📤 Envoi notification à: ${user.nom} (${user.user_id})`);

                const response = await fetch('https://api.live.wortis.cg/create_notifications', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(notificationPayload)
                });

                if (response.ok) {
                    const result = await response.json();
                    console.log(`✅ Notification envoyée à ${user.nom}:`, result);
                    successCount++;
                } else {
                    const errorText = await response.text();
                    console.error(`❌ Erreur pour ${user.nom} (${response.status}):`, errorText);
                    failCount++;
                }

                // Petit délai pour éviter de surcharger l'API
                await new Promise(resolve => setTimeout(resolve, 100));

            } catch (error) {
                console.error(`❌ Erreur d'envoi pour ${user.nom || user.user_id}:`, error);
                failCount++;
            }
        }

        // Afficher le résultat final
        if (successCount > 0) {
            showToast(`✅ Notification envoyée à ${successCount} utilisateur(s) avec succès!`, 'success');

            if (failCount > 0) {
                setTimeout(() => {
                    showToast(`⚠️ ${failCount} erreur(s) d'envoi`, 'error');
                }, 2000);
            }

            // Fermer le modal après succès
            setTimeout(() => {
                closeModal('notificationModal');
                resetNotificationForm();
            }, 2000);
        } else {
            showToast('❌ Échec de l\'envoi de toutes les notifications', 'error');
        }

    } catch (error) {
        console.error('Erreur globale lors de l\'envoi:', error);
        showToast('❌ Erreur lors de l\'envoi des notifications', 'error');
    } finally {
        // Réactiver le bouton
        sendButton.disabled = false;
        sendButton.innerHTML = '<i class="fas fa-paper-plane"></i> Envoyer la notification';
    }
}

// ======================================
// RÉCUPÉRATION DES UTILISATEURS CIBLÉS
// ======================================
async function getTargetedUsers(targetingMode) {
    switch(targetingMode) {
        case 'all':
            return allUsers;

        case 'services':
            if (selectedServices.length === 0) return [];

            try {
                // Appel API pour récupérer les utilisateurs ayant payé ces services (via numc)
                console.log('📤 Récupération des utilisateurs pour les services:', selectedServices);

                const response = await fetch('https://api.live.wortis.cg/notifications/api/users/by-numc', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        numc_list: selectedServices,  // numc des services sélectionnés
                        min_transactions: 1
                    })
                });

                if (response.ok) {
                    const data = await response.json();
                    console.log(`✅ ${data.total_users} utilisateurs ciblés par services (numc)`);
                    console.log('Détails:', data.debug);
                    return data.users || [];
                } else {
                    const errorText = await response.text();
                    console.error('Erreur lors de la récupération des utilisateurs par services:', errorText);
                    return [];
                }
            } catch (error) {
                console.error('Erreur API:', error);
                return [];
            }

        case 'custom':
            return selectedCustomUsers;

        default:
            return [];
    }
}

// ======================================
// CIBLAGE PERSONNALISÉ (fonction supprimée - utilise selectedCustomUsers directement)
// ======================================

// ======================================
// MODAL MANAGEMENT
// ======================================
async function initNotificationModal() {
    // Charger les utilisateurs au démarrage
    await loadUsersFromAPI();
}

async function loadUsersFromAPI() {
    try {
        console.log('Chargement des utilisateurs...');

        const response = await fetch('https://api.live.wortis.cg/dash_user_apk');

        if (!response.ok) {
            throw new Error(`Erreur HTTP: ${response.status}`);
        }

        const data = await response.json();

        if (data && data.enregistrements) {
            // Filtrer uniquement les utilisateurs vérifiés (check_verif: true)
            const usersVerified = data.enregistrements.filter(user => user.check_verif === true);

            // Adapter la structure des données pour notre utilisation
            allUsers = usersVerified.map(user => ({
                user_id: user.token,  // user_id = token pour l'API de notifications
                token: user.token,
                nom: user.nom || 'Utilisateur',
                phone_number: user.phone_number || '',
                active: user.active || false,
                player_id: user.player_id || null,
                fcm_token: user.fcm_token || null,
                miles: user.miles || 0,
                date_creation: user.date_creation,
                country_code: user.country_code || 'CG',
                country_name: user.country_name || 'Congo'
            }));

            totalRecipients = allUsers.length;

            console.log(`✅ ${totalRecipients} utilisateurs vérifiés chargés (sur ${data.enregistrements.length} total)`);
            console.log(`📊 Filtrage: check_verif === true uniquement`);

            // Mettre à jour le compteur initial
            updateRecipientsCounter(totalRecipients);

            // Charger les services
            loadServicesFromAPI();
        } else {
            console.error('Format de données inattendu:', data);
            showToast('Erreur lors du chargement des utilisateurs', 'error');
        }
    } catch (error) {
        console.error('Erreur lors de la récupération des utilisateurs:', error);
        showToast('Erreur de connexion avec l\'API', 'error');
    }
}

async function loadServicesFromAPI() {
    try {
        console.log('Chargement des services depuis l\'API...');

        // Nouvelle route pour récupérer les services depuis MongoDB
        const response = await fetch('https://api.live.wortis.cg/notifications/api/services');

        if (!response.ok) {
            throw new Error(`Erreur HTTP: ${response.status}`);
        }

        const data = await response.json();

        if (data && data.services && Array.isArray(data.services)) {
            const services = data.services;

            console.log(`✅ ${services.length} services chargés depuis MongoDB`);
            console.log('Services avec numc:', services.map(s => ({ name: s.name, numc: s.numc })));

            // Rendre les services dans la grille
            if (services.length > 0) {
                renderServices(services);
            } else {
                console.log('⚠️ Aucun service disponible');
            }
        } else {
            console.warn('Format de données inattendu:', data);
            console.log('⚠️ Aucun service trouvé dans la réponse API');
        }

    } catch (error) {
        console.error('Erreur lors du chargement des services:', error);
        console.log('⚠️ Impossible de charger les services depuis l\'API');
    }
}

// Fonction loadSecteursFromAPI supprimée - plus besoin de secteurs

function renderServices(services) {
    const servicesGrid = document.getElementById('servicesGrid');
    if (!servicesGrid) return;

    servicesGrid.innerHTML = '';

    services.forEach(service => {
        // Extraire l'icône ou utiliser une icône par défaut
        const iconName = service.icon || 'settings';

        // Mapper les icônes vers Font Awesome
        const iconMap = {
            'credit_card': 'credit-card',
            'water_drop': 'water',
            'eau': 'water',
            'bolt': 'bolt',
            'wifi': 'wifi',
            'school': 'graduation-cap',
            'phone': 'mobile-alt',
            'smartphone': 'mobile-alt',
            'receipt_long': 'receipt',
            'local_shipping': 'truck',
            'shopping_cart': 'shopping-cart',
            'shield': 'shield-alt',
            'settings': 'cog',
            'money': 'money-bill',
            'electricity': 'bolt',
            'internet': 'wifi'
        };

        const faIcon = iconMap[iconName] || 'cog';

        const serviceCard = `
            <label class="service-card" data-service-numc="${service.numc}">
                <input type="checkbox" name="service" value="${service.numc}" data-service-name="${service.name}">
                <div class="service-card-content">
                    <i class="fas fa-${faIcon}"></i>
                    <span class="service-name">${service.name}</span>
                    <span class="service-users" data-numc="${service.numc}">
                        <i class="fas fa-spinner fa-spin"></i> Chargement...
                    </span>
                </div>
            </label>
        `;
        servicesGrid.innerHTML += serviceCard;
    });

    // Charger le nombre d'utilisateurs pour chaque service
    services.forEach(service => {
        loadServiceUsersCount(service.numc);
    });

    // Réinitialiser les event listeners après le rendu
    initServiceSelection();

    console.log(`✅ ${services.length} services rendus dans l'interface`);
}

// Fonction pour charger le nombre d'utilisateurs d'un service
async function loadServiceUsersCount(numc) {
    try {
        const response = await fetch(`https://api.live.wortis.cg/notifications/api/services/${numc}/users/count`);

        if (!response.ok) {
            throw new Error(`Erreur HTTP: ${response.status}`);
        }

        const data = await response.json();
        const count = data.nombre_utilisateurs || 0;

        // Mettre à jour l'affichage
        const userCountSpan = document.querySelector(`.service-users[data-numc="${numc}"]`);
        if (userCountSpan) {
            userCountSpan.innerHTML = `<i class="fas fa-users"></i> ${count} utilisateur${count > 1 ? 's' : ''}`;
        }

    } catch (error) {
        console.error(`Erreur lors du chargement du nombre d'utilisateurs pour ${numc}:`, error);
        const userCountSpan = document.querySelector(`.service-users[data-numc="${numc}"]`);
        if (userCountSpan) {
            userCountSpan.innerHTML = `<i class="fas fa-exclamation-triangle"></i> Erreur`;
        }
    }
}

// Fonction renderSecteurs supprimée - plus besoin de secteurs

// ======================================
// TOAST NOTIFICATIONS
// ======================================
function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    const toastMessage = toast.querySelector('.toast-message');
    const toastIcon = toast.querySelector('.toast-icon');

    // Mise à jour du contenu
    toastMessage.textContent = message;

    // Mise à jour de l'icône et du style
    toast.className = 'toast show ' + type;

    if (type === 'success') {
        toastIcon.className = 'toast-icon fas fa-check-circle';
    } else if (type === 'error') {
        toastIcon.className = 'toast-icon fas fa-exclamation-circle';
    }

    // Masquer après 3 secondes
    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

console.log('✅ Module de notifications ciblées chargé avec succès');
