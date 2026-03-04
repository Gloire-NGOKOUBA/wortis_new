// banners.js - Gestion des bannières

// Variables pour la gestion des bannières
let banners = [];
let filteredBanners = [];
let currentPageBanner = 1;
let itemsPerPageBanner = 9; // 9 bannières par page pour une grille 3x3

// Fonction pour récupérer les bannières
async function fetchBanners() {
    try {
        console.log("Début de fetchBanners");
        
        const response = await fetch('https://api.live.wortis.cg/acceuil_apk_wpay_v2');
        const data = await response.json();
        
        console.log("Banners data:", data);
        
        // Stocker toutes les bannières
        banners = data.banner || [];
        
        // Trier les bannières par ID
        banners.sort((a, b) => {
            return a._id.localeCompare(b._id);
        });
        
        filteredBanners = [...banners];
        displayBannersPaginated(currentPageBanner);
        setupPaginationBanner();
    } catch (error) {
        console.error('Erreur détaillée:', error);
        showToast('Erreur lors du chargement des bannières', 'error');
    }
}

// Fonction pour afficher les bannières avec pagination
function displayBannersPaginated(page) {
    const bannersContainer = document.getElementById('bannersContainer');
    if (!bannersContainer) return;
    
    bannersContainer.innerHTML = '';

    // Calculer les indices
    const startIndex = (page - 1) * itemsPerPageBanner;
    const endIndex = Math.min(startIndex + itemsPerPageBanner, filteredBanners.length);
    
    // Mettre à jour les infos de pagination
    document.getElementById('startItemBanner').textContent = filteredBanners.length > 0 ? startIndex + 1 : 0;
    document.getElementById('endItemBanner').textContent = endIndex;
    document.getElementById('totalItemsBanner').textContent = filteredBanners.length;

    // Afficher les bannières
    for (let i = startIndex; i < endIndex; i++) {
        const banner = filteredBanners[i];
        
        // Extraire le nom de l'image à partir de l'URL complète
        const imageUrl = banner.image;
        const imageName = imageUrl.substring(imageUrl.lastIndexOf('/') + 1);
        
        // Créer la carte pour la bannière
        const bannerCard = document.createElement('div');
        bannerCard.className = 'banner-card';
        bannerCard.innerHTML = `
            <img src="${imageUrl}" alt="Bannière" class="banner-image" onerror="this.src='https://via.placeholder.com/250x150?text=Image+non+disponible'">
            <div class="banner-info">
                <h3 class="banner-title">${imageName}</h3>
                <div class="banner-actions">
                    <button class="btn btn-outline btn-sm" onclick="editBanner('${banner._id}')">
                        <i class="fas fa-edit"></i> Éditer
                    </button>
                    <button class="btn btn-danger btn-sm" onclick="deleteBanner('${banner._id}')">
                        <i class="fas fa-trash"></i> Supprimer
                    </button>
                </div>
            </div>
        `;
        
        bannersContainer.appendChild(bannerCard);
    }
}

// Configuration de la pagination pour les bannières
function setupPaginationBanner() {
    const paginationElement = document.getElementById('paginationBanner');
    if (!paginationElement) return;
    
    const totalPages = Math.ceil(filteredBanners.length / itemsPerPageBanner);
    paginationElement.innerHTML = '';

    // Bouton précédent
    const prevLi = document.createElement('li');
    prevLi.className = `pagination-item ${currentPageBanner === 1 ? 'disabled' : ''}`;
    prevLi.innerHTML = '<i class="fas fa-chevron-left"></i>';
    prevLi.addEventListener('click', () => {
        if (currentPageBanner > 1) goToPageBanner(currentPageBanner - 1);
    });
    paginationElement.appendChild(prevLi);

    // Numéros de page
    for (let i = Math.max(1, currentPageBanner - 2); i <= Math.min(totalPages, currentPageBanner + 2); i++) {
        const pageLi = document.createElement('li');
        pageLi.className = `pagination-item ${currentPageBanner === i ? 'active' : ''}`;
        pageLi.textContent = i;
        pageLi.addEventListener('click', () => goToPageBanner(i));
        paginationElement.appendChild(pageLi);
    }

    // Bouton suivant
    const nextLi = document.createElement('li');
    nextLi.className = `pagination-item ${currentPageBanner === totalPages ? 'disabled' : ''}`;
    nextLi.innerHTML = '<i class="fas fa-chevron-right"></i>';
    nextLi.addEventListener('click', () => {
        if (currentPageBanner < totalPages) goToPageBanner(currentPageBanner + 1);
    });
    paginationElement.appendChild(nextLi);
}

// Fonction pour aller à une page spécifique (bannières)
function goToPageBanner(page) {
    currentPageBanner = page;
    displayBannersPaginated(currentPageBanner);
    setupPaginationBanner();
}

// Fonction pour éditer une bannière
function editBanner(bannerId) {
    const banner = banners.find(b => b._id === bannerId);
    if (banner) {
        // Extraire le nom de l'image à partir de l'URL complète
        const imageUrl = banner.image;
        const imageName = imageUrl.substring(imageUrl.lastIndexOf('/') + 1);
        
        document.getElementById('bannerModalTitle').textContent = 'Modifier la bannière';
        document.getElementById('bannerId').value = banner._id;
        document.getElementById('bannerImageName').value = imageName;
        
        // Afficher l'aperçu de l'image
        const previewImg = document.getElementById('bannerPreview');
        previewImg.src = imageUrl;
        previewImg.style.display = 'block';
        document.getElementById('bannerPreviewPlaceholder').style.display = 'none';
        
        openModal('bannerModal');
    } else {
        showToast('Bannière non trouvée', 'error');
    }
}

// Fonction pour supprimer une bannière
function deleteBanner(bannerId) {
    if (confirm(`Êtes-vous sûr de vouloir supprimer cette bannière ?`)) {
        showToast('Cette fonctionnalité n\'est pas encore implémentée', 'error');
        // Ici, ajoutez le code pour supprimer la bannière via une API si elle existe
    }
}

// Fonction pour rechercher des bannières
function searchBanners(searchTerm) {
    if (searchTerm.trim() === '') {
        filteredBanners = [...banners];
    } else {
        searchTerm = searchTerm.toLowerCase();
        filteredBanners = banners.filter(banner => {
            const imageName = banner.image.substring(banner.image.lastIndexOf('/') + 1).toLowerCase();
            return imageName.includes(searchTerm);
        });
    }
    
    currentPageBanner = 1;
    displayBannersPaginated(currentPageBanner);
    setupPaginationBanner();
}

// Aperçu en direct de la bannière lors de la saisie du nom
function updateBannerPreview() {
    const imageName = document.getElementById('bannerImageName').value.trim();
    const previewImg = document.getElementById('bannerPreview');
    const placeholder = document.getElementById('bannerPreviewPlaceholder');
    
    if (imageName) {
        const imageUrl = `https://apigede.wortispay.cg/apk-mobile/banner_service/${imageName}`;
        previewImg.src = imageUrl;
        previewImg.style.display = 'block';
        placeholder.style.display = 'none';
        
        // Gérer les erreurs de chargement d'image
        previewImg.onerror = function() {
            previewImg.src = 'https://via.placeholder.com/250x150?text=Image+non+disponible';
        };
    } else {
        previewImg.style.display = 'none';
        placeholder.style.display = 'block';
    }
}

// Initialisation des événements
document.addEventListener('DOMContentLoaded', function() {
    // Écouteur pour la recherche de bannières
    const searchBannerInput = document.getElementById('searchBanner');
    if (searchBannerInput) {
        searchBannerInput.addEventListener('input', (e) => {
            searchBanners(e.target.value);
        });
    }
    
    // Bouton d'ajout de bannière
    const addBannerBtn = document.getElementById('addBannerBtn');
    if (addBannerBtn) {
        addBannerBtn.addEventListener('click', () => {
            document.getElementById('bannerModalTitle').textContent = 'Ajouter une bannière';
            document.getElementById('bannerForm').reset();
            document.getElementById('bannerId').value = '';
            document.getElementById('bannerPreview').style.display = 'none';
            document.getElementById('bannerPreviewPlaceholder').style.display = 'block';
            openModal('bannerModal');
        });
    }
    
    // Aperçu en direct de la bannière
    const bannerImageName = document.getElementById('bannerImageName');
    if (bannerImageName) {
        bannerImageName.addEventListener('input', updateBannerPreview);
    }
    
    // Bouton de sauvegarde de bannière
    const saveBannerBtn = document.getElementById('saveBannerBtn');
    if (saveBannerBtn) {
        saveBannerBtn.addEventListener('click', () => {
            const bannerId = document.getElementById('bannerId').value;
            const imageName = document.getElementById('bannerImageName').value.trim();
            
            if (!imageName) {
                showToast('Veuillez entrer un nom d\'image', 'error');
                return;
            }
            
            // Ici, vous ajouteriez l'appel à l'API pour ajouter/modifier la bannière
            showToast(bannerId ? 'Bannière modifiée avec succès' : 'Bannière ajoutée avec succès', 'success');
            closeModal('bannerModal');
            
            // Rafraîchir la liste après modification
            fetchBanners();
        });
    }
});