// secteur.js - Gestion des secteurs d'activité

// Variables pour la gestion des secteurs
let secteurs = [];
let filteredSecteurs = [];
let currentPageSecteur = 1;
let itemsPerPageSecteur = 10;
let allServices = []; // Pour stocker tous les services

// Fonction pour récupérer les secteurs d'activité en combinant deux APIs
async function fetchSecteurs() {
    try {
        // Faire deux requêtes en parallèle
        const [servicesResponse, secteursResponse] = await Promise.all([
            fetch('https://api.live.wortis.cg/get_services_back'),
            fetch('https://api.live.wortis.cg/acceuil_apk_wpay_v2_back')
        ]);
        
        console.log("Réponses APIs reçues");
        
        const servicesData = await servicesResponse.json();
        const secteursData = await secteursResponse.json();
        
        console.log("Services data:", servicesData);
        console.log("Secteurs data:", secteursData);
        
        // Stocker tous les services
        allServices = servicesData.all_services || [];
        
        // Créer un mapping pour compter les services par secteur
        const servicesParSecteur = {};
        allServices.forEach(service => {
            const secteurName = service.SecteurActivite;
            if (secteurName) {
                servicesParSecteur[secteurName] = (servicesParSecteur[secteurName] || 0) + 1;
            }
        });
        
        // Utiliser directement les secteurs de la collection SecteurActivite_test
        secteurs = [];
        if (secteursData && secteursData.SecteurActivite) {
            secteurs = secteursData.SecteurActivite.map(secteur => {
                return {
                    name: secteur.name,
                    icon: secteur.icon || 'question-circle',
                    rang: parseInt(secteur.rang) || 999,
                    // Compter combien de services utilisent ce secteur
                    count: servicesParSecteur[secteur.name] || 0
                };
            });
        }
        
        // Trier les secteurs par rang ou par nom
        secteurs.sort((a, b) => {
            if (a.rang !== b.rang) {
                return a.rang - b.rang;
            }
            return a.name.localeCompare(b.name);
        });
        
        console.log("Secteurs après traitement:", secteurs);
        
        filteredSecteurs = [...secteurs];
        displaySecteursPaginated(currentPageSecteur);
        setupPaginationSecteur();
    } catch (error) {
        console.error('Erreur lors de la récupération des secteurs:', error);
        showToast('Erreur lors du chargement des secteurs', 'error');
    }
}

// Fonction pour afficher les secteurs avec pagination
function displaySecteursPaginated(page) {
    const tableBody = document.getElementById('secteursTableBody');
    tableBody.innerHTML = '';

    // Calculer les indices
    const startIndex = (page - 1) * itemsPerPageSecteur;
    const endIndex = Math.min(startIndex + itemsPerPageSecteur, filteredSecteurs.length);
    
    // Mettre à jour les infos de pagination
    document.getElementById('startItemSecteur').textContent = filteredSecteurs.length > 0 ? startIndex + 1 : 0;
    document.getElementById('endItemSecteur').textContent = endIndex;
    document.getElementById('totalItemsSecteur').textContent = filteredSecteurs.length;

    // Afficher les secteurs
    for (let i = startIndex; i < endIndex; i++) {
        const secteur = filteredSecteurs[i];
        const row = document.createElement('tr');
        
        row.innerHTML = `
            <td>${secteur.name || 'N/A'}</td>
            <td><i class="fas fa-${secteur.icon || 'question-circle'}"></i> ${secteur.icon || 'N/A'}</td>
            <td>${secteur.rang !== 999 ? secteur.rang : 'Non défini'}</td>
            <td>${secteur.count || 0}</td>
            <td>
                <button class="btn btn-outline" onclick="editSecteur('${secteur.name}')">
                    <i class="fas fa-edit"></i> Éditer
                </button>
                <button class="btn btn-danger" onclick="deleteSecteur('${secteur.name}')">
                    <i class="fas fa-trash"></i> Supprimer
                </button>
            </td>
        `;
        tableBody.appendChild(row);
    }
}

// Configuration de la pagination pour les secteurs
function setupPaginationSecteur() {
    const totalPages = Math.ceil(filteredSecteurs.length / itemsPerPageSecteur);
    const paginationElement = document.getElementById('paginationSecteur');
    paginationElement.innerHTML = '';

    // Bouton précédent
    const prevLi = document.createElement('li');
    prevLi.className = `pagination-item ${currentPageSecteur === 1 ? 'disabled' : ''}`;
    prevLi.innerHTML = '<i class="fas fa-chevron-left"></i>';
    prevLi.addEventListener('click', () => {
        if (currentPageSecteur > 1) goToPageSecteur(currentPageSecteur - 1);
    });
    paginationElement.appendChild(prevLi);

    // Numéros de page
    for (let i = Math.max(1, currentPageSecteur - 2); i <= Math.min(totalPages, currentPageSecteur + 2); i++) {
        const pageLi = document.createElement('li');
        pageLi.className = `pagination-item ${currentPageSecteur === i ? 'active' : ''}`;
        pageLi.textContent = i;
        pageLi.addEventListener('click', () => goToPageSecteur(i));
        paginationElement.appendChild(pageLi);
    }

    // Bouton suivant
    const nextLi = document.createElement('li');
    nextLi.className = `pagination-item ${currentPageSecteur === totalPages ? 'disabled' : ''}`;
    nextLi.innerHTML = '<i class="fas fa-chevron-right"></i>';
    nextLi.addEventListener('click', () => {
        if (currentPageSecteur < totalPages) goToPageSecteur(currentPageSecteur + 1);
    });
    paginationElement.appendChild(nextLi);
}

// Fonction pour aller à une page spécifique (secteurs)
function goToPageSecteur(page) {
    currentPageSecteur = page;
    displaySecteursPaginated(currentPageSecteur);
    setupPaginationSecteur();
}

// Fonction pour éditer un secteur
function editSecteur(sectorName) {
    const secteur = secteurs.find(s => s.name === sectorName);
    if (secteur) {
        document.getElementById('secteurModalTitle').textContent = 'Modifier le secteur d\'activité';
        document.getElementById('secteurId').value = secteur.name;
        document.getElementById('secteurName').value = secteur.name || '';
        document.getElementById('secteurIcon').value = secteur.icon || '';
        document.getElementById('secteurRang').value = secteur.rang || 1;
        openModal('secteurModal');
    } else {
        showToast('Secteur non trouvé', 'error');
    }
}

// Fonction pour supprimer un secteur
async function deleteSecteur(sectorName) {
    if (confirm(`Êtes-vous sûr de vouloir supprimer le secteur "${sectorName}" ?`)) {
        // Vérifiez si des services sont associés à ce secteur
        const servicesAssocies = allServices.filter(service => service.SecteurActivite === sectorName);
        
        if (servicesAssocies.length > 0) {
            showToast(`Impossible de supprimer ce secteur, il contient ${servicesAssocies.length} service(s)`, 'error');
        } else {
            try {
                // Appel à l'API pour supprimer le secteur
                const response = await fetch('https://api.live.wortis.cg/update_secteur_activite', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        action: 'delete',
                        oldName: sectorName
                    })
                });
                
                const result = await response.json();
                
                if (result.Code === 200) {
                    showToast('Secteur supprimé avec succès', 'success');
                    
                    // Rafraîchir la liste après suppression
                    fetchSecteurs();
                } else {
                    showToast(`Erreur: ${result.messages || 'Suppression échouée'}`, 'error');
                }
            } catch (error) {
                console.error('Erreur lors de la suppression du secteur:', error);
                showToast('Erreur lors de la suppression du secteur', 'error');
            }
        }
    }
}

// Fonction pour rechercher des secteurs
function searchSecteurs(searchTerm) {
    if (searchTerm.trim() === '') {
        filteredSecteurs = [...secteurs];
    } else {
        searchTerm = searchTerm.toLowerCase();
        filteredSecteurs = secteurs.filter(secteur => {
            return (secteur.name && secteur.name.toLowerCase().includes(searchTerm)) ||
                (secteur.icon && secteur.icon.toLowerCase().includes(searchTerm));
        });
    }
    
    currentPageSecteur = 1;
    displaySecteursPaginated(currentPageSecteur);
    setupPaginationSecteur();
}

// Initialisation des événements
document.addEventListener('DOMContentLoaded', function() {
    // Écouteur pour la recherche de secteurs
    const searchSecteurInput = document.getElementById('searchSecteur');
    if (searchSecteurInput) {
        searchSecteurInput.addEventListener('input', (e) => {
            searchSecteurs(e.target.value);
        });
    }

    // Bouton d'ajout de secteur
    const addSecteurBtn = document.getElementById('addSecteurBtn');
    if (addSecteurBtn) {
        addSecteurBtn.addEventListener('click', () => {
            document.getElementById('secteurModalTitle').textContent = 'Ajouter un secteur d\'activité';
            document.getElementById('secteurForm').reset();
            document.getElementById('secteurId').value = '';
            openModal('secteurModal');
        });
    }

    // Bouton de sauvegarde du secteur
const saveSecteurBtn = document.getElementById('saveSecteurBtn');
if (saveSecteurBtn) {
    saveSecteurBtn.addEventListener('click', async () => {
        const secteurId = document.getElementById('secteurId').value;
        const secteurName = document.getElementById('secteurName').value;
        const secteurIcon = document.getElementById('secteurIcon').value;
        const secteurRang = parseInt(document.getElementById('secteurRang').value) || 1;
        
        if (!secteurName) {
            showToast('Veuillez entrer un nom de secteur', 'error');
            return;
        }
        
        try {
            // Préparer les données à envoyer
            const secteurData = {
                name: secteurName,
                icon: secteurIcon,
                rang: secteurRang
            };
            
            // Déterminer si c'est un ajout ou une modification
            const isEdit = !!secteurId;
            
            // URL de l'API pour les secteurs d'activité
            const apiUrl = 'https://api.live.wortis.cg/update_secteur_activite';
            
            // Appel à l'API
            const response = await fetch(apiUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    action: isEdit ? 'update' : 'add',
                    oldName: isEdit ? secteurId : null,
                    secteur: secteurData
                })
            });
            
            const result = await response.json();
            
            if (result.Code === 200) {
                showToast(isEdit ? 'Secteur modifié avec succès' : 'Secteur ajouté avec succès', 'success');
                closeModal('secteurModal');
                
                // Rafraîchir la liste après modification
                fetchSecteurs();
            } else {
                showToast(`Erreur: ${result.messages || 'Opération échouée'}`, 'error');
            }
        } catch (error) {
            console.error('Erreur lors de la sauvegarde du secteur:', error);
            showToast('Erreur lors de la sauvegarde du secteur', 'error');
        }
    });
}
});