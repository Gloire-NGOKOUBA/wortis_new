// gas.js - Gestion de la navigation entre les pages

// Toggle Sidebar
document.addEventListener('DOMContentLoaded', function() {
    const menuToggle = document.getElementById('menuToggle');
    const sidebar = document.getElementById('sidebar');
    
    if (menuToggle) {
        menuToggle.addEventListener('click', () => {
            sidebar.classList.toggle('active');
        });
    }
    
    // Gestion de la navigation entre les pages
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', function(e) {
            e.preventDefault();
            
            // Retirer la classe active de tous les éléments de navigation
            document.querySelectorAll('.nav-item').forEach(navItem => {
                navItem.classList.remove('active');
            });
            
            // Ajouter la classe active à l'élément cliqué
            this.classList.add('active');
            
            // Identifier la page à afficher
            const pageType = this.getAttribute('data-page');
            const pageId = pageType + '-page';
            
            // Masquer toutes les pages
            document.querySelectorAll('.page').forEach(page => {
                page.style.display = 'none';
            });
            
            // Traitement spécial pour le tableau de bord (page principale)
            if (pageType === 'dashboard') {
                // Afficher le tableau de bord (main content)
                document.querySelector('.main-content').style.display = 'block';
                
                // Rafraîchir les données du tableau de bord si nécessaire
                if (typeof refreshDashboard === 'function') {
                    refreshDashboard();
                }
            } else {
                // Pour toutes les pages secondaires
                // Masquer la page principale (tableau de bord)
                document.querySelector('.main-content').style.display = 'none';
                
                // Afficher la page correspondante
                const pageElement = document.getElementById(pageId);
                if (pageElement) {
                    pageElement.style.display = 'block';
                    
                    // Charger les données selon la page
                    if (pageType === 'users' && typeof fetchUsers === 'function') {
                        fetchUsers();
                    } else if (pageType === 'secteurs' && typeof fetchSecteurs === 'function') {
                        fetchSecteurs();
                    } else if (pageType === 'services' && typeof fetchServices === 'function') {
                        fetchServices();
                    } else if (pageType === 'banners' && typeof fetchBanners === 'function') {
                        fetchBanners();
                    } else if (pageType === 'wallets' && typeof fetchWallets === 'function') {
                        fetchWallets();
                    } else if (pageType === 'notifications' && typeof fetchNotifications === 'function') {
                        fetchNotifications();
                    } else if (pageType === 'news' && typeof fetchNews === 'function') {
                        fetchNews();
                    }
                }
            }
        });
    });
});

// Modal Functions
function openModal(modalId) {
    document.getElementById(modalId).classList.add('active');
}

function closeModal(modalId) {
    document.getElementById(modalId).classList.remove('active');
}

// Toast Functions
function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    const icon = toast.querySelector('.toast-icon');
    const messageEl = toast.querySelector('.toast-message');

    toast.className = `toast ${type}`;
    icon.className = `toast-icon fas ${type === 'success' ? 'fa-check-circle' : 'fa-exclamation-circle'}`;
    messageEl.textContent = message;

    toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), 3000);
}

// Formatter la date pour l'affichage
function formatDate(dateString) {
    if (!dateString) return 'N/A';
    
    try {
        // Essayer différents formats de date
        let date;
        if (dateString.includes('GMT')) {
            // Format: "Mon, 24 Feb 2025 09:57:33 GMT"
            date = new Date(dateString);
        } else {
            // Format ISO ou autres
            date = new Date(dateString);
        }
        
        if (isNaN(date.getTime())) {
            return dateString; // Retourner la chaîne originale si la conversion échoue
        }
        
        return date.toLocaleDateString();
    } catch (e) {
        console.error('Erreur de formatage de date:', e);
        return dateString;
    }
}