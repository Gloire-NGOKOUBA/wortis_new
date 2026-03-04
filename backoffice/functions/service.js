// service.js - Gestion des services

// Variables pour la gestion des services
let services = [];
let filteredServices = [];
let currentPageService = 1;
let itemsPerPageService = 10;

// Fonction pour récupérer les services
async function fetchServices() {
    try {
        console.log("Début de fetchServices");
        
        const response = await fetch('https://api.live.wortis.cg/get_services_back');
        
        if (!response.ok) {
            throw new Error(`Erreur HTTP: ${response.status}`);
        }
        
        const data = await response.json();
        console.log("Services data:", data);
        
        // Stocker tous les services
        services = data.all_services || [];
        
        // Trier les services par rang ou par nom
        services.sort((a, b) => {
            if (a.rang !== b.rang) {
                return parseInt(a.rang || 999) - parseInt(b.rang || 999);
            }
            return (a.name || '').localeCompare(b.name || '');
        });
        
        filteredServices = [...services];
        displayServicesPaginated(currentPageService);
        setupPaginationService();
        
        // Remplir le dropdown des secteurs dans le modal des services
        populateSectorsDropdown();
    } catch (error) {
        console.error('Erreur détaillée services:', error);
        showToast('Erreur lors du chargement des services', 'error');
    }
}

// Fonction pour remplir le dropdown des secteurs
function populateSectorsDropdown() {
    const secteurSelect = document.getElementById('serviceSecteur');
    if (!secteurSelect) return;
    
    secteurSelect.innerHTML = '<option value="">Sélectionnez un secteur</option>';

    // Obtenir les secteurs uniques à partir des services
    const uniqueSectors = [...new Set(services.map(service => service.SecteurActivite))].filter(Boolean);

    uniqueSectors.sort().forEach(sector => {
        const option = document.createElement('option');
        option.value = sector;
        option.textContent = sector;
        secteurSelect.appendChild(option);
    });
}

// Fonction pour afficher les services avec pagination
function displayServicesPaginated(page) {
    const tableBody = document.getElementById('servicesTableBody');
    if (!tableBody) return;
    
    tableBody.innerHTML = '';

    // Calculer les indices
    const startIndex = (page - 1) * itemsPerPageService;
    const endIndex = Math.min(startIndex + itemsPerPageService, filteredServices.length);
    
    // Mettre à jour les infos de pagination
    document.getElementById('startItemService').textContent = filteredServices.length > 0 ? startIndex + 1 : 0;
    document.getElementById('endItemService').textContent = endIndex;
    document.getElementById('totalItemsService').textContent = filteredServices.length;

    // Afficher les services
    for (let i = startIndex; i < endIndex; i++) {
        const service = filteredServices[i];
        const row = document.createElement('tr');
        
        row.innerHTML = `
            <td>${service.name || 'N/A'}</td>
            <td>${service.Type_Service || 'N/A'}</td>
            <td>${service.SecteurActivite || 'N/A'}</td>
            <td>${service.rang || 'Non défini'}</td>
            <td>
                <span class="badge ${service.status ? 'badge-success' : 'badge-danger'}">
                    ${service.status ? 'Actif' : 'Inactif'}
                </span>
            </td>
            <td>
                <button class="btn btn-outline" onclick="editService('${service._id}')">
                    <i class="fas fa-edit"></i> Éditer
                </button>
                <button class="btn btn-danger" onclick="deleteService('${service._id}')">
                    <i class="fas fa-trash"></i> Supprimer
                </button>
            </td>
        `;
        tableBody.appendChild(row);
    }
}

// Configuration de la pagination pour les services
function setupPaginationService() {
    const paginationElement = document.getElementById('paginationService');
    if (!paginationElement) return;
    
    const totalPages = Math.ceil(filteredServices.length / itemsPerPageService);
    paginationElement.innerHTML = '';

    // Bouton précédent
    const prevLi = document.createElement('li');
    prevLi.className = `pagination-item ${currentPageService === 1 ? 'disabled' : ''}`;
    prevLi.innerHTML = '<i class="fas fa-chevron-left"></i>';
    prevLi.addEventListener('click', () => {
        if (currentPageService > 1) goToPageService(currentPageService - 1);
    });
    paginationElement.appendChild(prevLi);

    // Numéros de page
    for (let i = Math.max(1, currentPageService - 2); i <= Math.min(totalPages, currentPageService + 2); i++) {
        const pageLi = document.createElement('li');
        pageLi.className = `pagination-item ${currentPageService === i ? 'active' : ''}`;
        pageLi.textContent = i;
        pageLi.addEventListener('click', () => goToPageService(i));
        paginationElement.appendChild(pageLi);
    }

    // Bouton suivant
    const nextLi = document.createElement('li');
    nextLi.className = `pagination-item ${currentPageService === totalPages ? 'disabled' : ''}`;
    nextLi.innerHTML = '<i class="fas fa-chevron-right"></i>';
    nextLi.addEventListener('click', () => {
        if (currentPageService < totalPages) goToPageService(currentPageService + 1);
    });
    paginationElement.appendChild(nextLi);
}

// Fonction pour aller à une page spécifique (services)
function goToPageService(page) {
    currentPageService = page;
    displayServicesPaginated(currentPageService);
    setupPaginationService();
}

// Fonction pour éditer un service
function editService(serviceId) {
    const service = services.find(s => s._id === serviceId);
    if (service) {
        document.getElementById('serviceModalTitle').textContent = 'Modifier le service';
        document.getElementById('serviceId').value = service._id;
        document.getElementById('serviceName').value = service.name || '';
        document.getElementById('serviceType').value = service.Type_Service || '';
        document.getElementById('serviceSecteur').value = service.SecteurActivite || '';
        document.getElementById('serviceRang').value = service.rang || '';
        document.getElementById('serviceStatus').value = service.status.toString();
        document.getElementById('serviceIcon').value = service.icon || '';
        openModal('serviceModal');
    } else {
        showToast('Service non trouvé', 'error');
    }
}

// Fonction pour supprimer un service
function deleteService(serviceId) {
    if (confirm(`Êtes-vous sûr de vouloir supprimer ce service ?`)) {
        showToast('Cette fonctionnalité n\'est pas encore implémentée', 'error');
        // Ici, ajoutez le code pour supprimer le service via une API si elle existe
    }
}

// Fonction pour rechercher des services
function searchServices(searchTerm) {
    if (searchTerm.trim() === '') {
        filteredServices = [...services];
    } else {
        searchTerm = searchTerm.toLowerCase();
        filteredServices = services.filter(service => {
            return (service.name && service.name.toLowerCase().includes(searchTerm)) ||
                   (service.Type_Service && service.Type_Service.toLowerCase().includes(searchTerm)) ||
                   (service.SecteurActivite && service.SecteurActivite.toLowerCase().includes(searchTerm));
        });
    }

    currentPageService = 1;
    displayServicesPaginated(currentPageService);
    setupPaginationService();
}

// Initialisation des événements
document.addEventListener('DOMContentLoaded', function() {
    // Écouteur pour la recherche de services
    const searchServiceInput = document.getElementById('searchService');
    if (searchServiceInput) {
        searchServiceInput.addEventListener('input', (e) => {
            searchServices(e.target.value);
        });
    }

    // Bouton d'ajout de service
    const addServiceBtn = document.getElementById('addServiceBtn');
    if (addServiceBtn) {
        addServiceBtn.addEventListener('click', () => {
            document.getElementById('serviceModalTitle').textContent = 'Ajouter un service';
            document.getElementById('serviceForm').reset();
            document.getElementById('serviceId').value = '';
            openModal('serviceModal');
        });
    }

    // Bouton de sauvegarde de service
    const saveServiceBtn = document.getElementById('saveServiceBtn');
    if (saveServiceBtn) {
        saveServiceBtn.addEventListener('click', () => {
            const serviceId = document.getElementById('serviceId').value;
            const serviceName = document.getElementById('serviceName').value;
            
            if (!serviceName) {
                showToast('Veuillez entrer un nom de service', 'error');
                return;
            }
            
            // Simuler une mise à jour pour l'instant
            // Dans un environnement réel, vous feriez un appel API ici
            showToast(serviceId ? 'Service modifié avec succès' : 'Service ajouté avec succès', 'success');
            closeModal('serviceModal');
            
            // Rafraîchir la liste après modification
            fetchServices();
        });
    }
});