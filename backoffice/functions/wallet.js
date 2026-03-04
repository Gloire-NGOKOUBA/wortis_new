// wallet.js - Gestion des portefeuilles utilisateurs

// Variables pour la gestion des portefeuilles
let wallets = [];
let filteredWallets = [];
let currentPageWallet = 1;
let itemsPerPageWallet = 10;

// Fonction pour récupérer les portefeuilles (utilisateurs avec leurs miles)
async function fetchWallets() {
    try {
        console.log("Début de fetchWallets");
        
        const response = await fetch('https://api.live.wortis.cg/dash_user_apk');
        const data = await response.json();
        
        console.log("Wallets data:", data);
        
        // Stocker tous les utilisateurs (avec leurs miles)
        wallets = data.enregistrements || [];
        
        // Trier les utilisateurs par nom
        wallets.sort((a, b) => {
            return (a.nom || '').localeCompare(b.nom || '');
        });
        
        filteredWallets = [...wallets];
        displayWalletsPaginated(currentPageWallet);
        setupPaginationWallet();
    } catch (error) {
        console.error('Erreur détaillée:', error);
        showToast('Erreur lors du chargement des portefeuilles', 'error');
    }
}

// Fonction pour afficher les portefeuilles avec pagination
function displayWalletsPaginated(page) {
    const tableBody = document.getElementById('walletsTableBody');
    tableBody.innerHTML = '';

    // Calculer les indices
    const startIndex = (page - 1) * itemsPerPageWallet;
    const endIndex = Math.min(startIndex + itemsPerPageWallet, filteredWallets.length);
    
    // Mettre à jour les infos de pagination
    document.getElementById('startItemWallet').textContent = filteredWallets.length > 0 ? startIndex + 1 : 0;
    document.getElementById('endItemWallet').textContent = endIndex;
    document.getElementById('totalItemsWallet').textContent = filteredWallets.length;

    // Afficher les portefeuilles
    for (let i = startIndex; i < endIndex; i++) {
        const wallet = filteredWallets[i];
        const row = document.createElement('tr');
        
        row.innerHTML = `
            <td>${wallet.nom || 'Pas de Nom'}</td>
            <td>${wallet.phone_number || 'N/A'}</td>
            <td>${wallet.miles || 0}</td>
            <td>
                <button class="btn btn-primary" onclick="updateMiles('${wallet._id}')">
                    <i class="fas fa-coins"></i> Mettre à jour les Miles
                </button>
            </td>
        `;
        
        tableBody.appendChild(row);
    }
}

// Configuration de la pagination pour les portefeuilles
function setupPaginationWallet() {
    const totalPages = Math.ceil(filteredWallets.length / itemsPerPageWallet);
    const paginationElement = document.getElementById('paginationWallet');
    paginationElement.innerHTML = '';

    // Bouton précédent
    const prevLi = document.createElement('li');
    prevLi.className = `pagination-item ${currentPageWallet === 1 ? 'disabled' : ''}`;
    prevLi.innerHTML = '<i class="fas fa-chevron-left"></i>';
    prevLi.addEventListener('click', () => {
        if (currentPageWallet > 1) goToPageWallet(currentPageWallet - 1);
    });
    paginationElement.appendChild(prevLi);

    // Numéros de page
    for (let i = Math.max(1, currentPageWallet - 2); i <= Math.min(totalPages, currentPageWallet + 2); i++) {
        const pageLi = document.createElement('li');
        pageLi.className = `pagination-item ${currentPageWallet === i ? 'active' : ''}`;
        pageLi.textContent = i;
        pageLi.addEventListener('click', () => goToPageWallet(i));
        paginationElement.appendChild(pageLi);
    }

    // Bouton suivant
    const nextLi = document.createElement('li');
    nextLi.className = `pagination-item ${currentPageWallet === totalPages ? 'disabled' : ''}`;
    nextLi.innerHTML = '<i class="fas fa-chevron-right"></i>';
    nextLi.addEventListener('click', () => {
        if (currentPageWallet < totalPages) goToPageWallet(currentPageWallet + 1);
    });
    paginationElement.appendChild(nextLi);
}

// Fonction pour aller à une page spécifique (portefeuilles)
function goToPageWallet(page) {
    currentPageWallet = page;
    displayWalletsPaginated(currentPageWallet);
    setupPaginationWallet();
}

// Fonction pour mettre à jour les miles d'un utilisateur
function updateMiles(userId) {
    const user = wallets.find(w => w._id === userId);
    if (user) {
        document.getElementById('updateMilesUserId').value = userId;
        document.getElementById('updateMilesUserName').value = user.nom || '';
        document.getElementById('updateMilesCurrentMiles').value = user.miles || 0;
        document.getElementById('updateMilesNewMiles').value = user.miles || 0;
        
        openModal('updateMilesModal');
    } else {
        showToast('Utilisateur non trouvé', 'error');
    }
}

// Fonction pour rechercher des portefeuilles
function searchWallets(searchTerm) {
    if (searchTerm.trim() === '') {
        filteredWallets = [...wallets];
    } else {
        searchTerm = searchTerm.toLowerCase();
        filteredWallets = wallets.filter(wallet => {
            return (wallet.nom && wallet.nom.toLowerCase().includes(searchTerm)) ||
                (wallet.phone_number && wallet.phone_number.toLowerCase().includes(searchTerm));
        });
    }
    
    currentPageWallet = 1;
    displayWalletsPaginated(currentPageWallet);
    setupPaginationWallet();
}

// Initialisation des événements
document.addEventListener('DOMContentLoaded', function() {
    // Écouteur pour la recherche de portefeuilles
    const searchWalletInput = document.getElementById('searchWallet');
    if (searchWalletInput) {
        searchWalletInput.addEventListener('input', (e) => {
            searchWallets(e.target.value);
        });
    }
    
   // Bouton de sauvegarde des miles
const saveMilesBtn = document.getElementById('saveMilesBtn');
if (saveMilesBtn) {
    saveMilesBtn.addEventListener('click', async () => {
        const userId = document.getElementById('updateMilesUserId').value;
        const newMiles = document.getElementById('updateMilesNewMiles').value;
        
        if (!newMiles || isNaN(parseInt(newMiles))) {
            showToast('Veuillez entrer un nombre de miles valide', 'error');
            return;
        }
        
        try {
            // Trouver l'utilisateur pour obtenir son token
            const user = wallets.find(w => w._id === userId);
            if (!user || !user.token) {
                showToast('Information utilisateur incomplète', 'error');
                return;
            }
            
            // Appel à l'API pour mettre à jour les miles
            const response = await fetch(`https://api.live.wortis.cg/update_user_apk_wpay_v2_back/${user.token}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    miles: parseInt(newMiles)
                })
            });
            
            const result = await response.json();
            
            if (result.Code === 200) {
                showToast('Miles mis à jour avec succès', 'success');
                closeModal('updateMilesModal');
                
                // Mettre à jour localement pour voir le changement immédiatement
                const userIndex = wallets.findIndex(w => w._id === userId);
                if (userIndex !== -1) {
                    wallets[userIndex].miles = parseInt(newMiles);
                    const filteredIndex = filteredWallets.findIndex(w => w._id === userId);
                    if (filteredIndex !== -1) {
                        filteredWallets[filteredIndex].miles = parseInt(newMiles);
                    }
                    displayWalletsPaginated(currentPageWallet);
                }
                
                // Optionnel : rafraîchir la liste complète
                // fetchWallets();
            } else {
                showToast(`Erreur: ${result.messages}`, 'error');
            }
        } catch (error) {
            console.error('Erreur lors de la mise à jour des miles:', error);
            showToast('Erreur lors de la mise à jour des miles', 'error');
        }
    });
}
});