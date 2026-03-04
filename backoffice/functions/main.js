// main.js - Point d'entrée principal de l'application

// Initialisation de l'application
document.addEventListener('DOMContentLoaded', function() {
    console.log('Initialisation de l\'application WortisAPK Admin');
    
    // Activer le dark mode si préféré par l'utilisateur ou sauvegardé localement
    initDarkMode();
    
    // Charger le tableau de bord initial
    if (document.querySelector('.main-content').style.display !== 'none') {
        if (typeof refreshDashboard === 'function') {
            refreshDashboard();
        }
    }
});

// Gestion du mode sombre
function initDarkMode() {
    const darkModeToggle = document.querySelector('.dark-mode-toggle');
    const body = document.body;
    
    // Vérifier si le dark mode est enregistré dans localStorage
    const isDarkMode = localStorage.getItem('darkMode') === 'true';
    
    if (isDarkMode) {
        body.classList.add('dark-mode');
        updateDarkModeIcon(true);
    }
    
    // Écouteur pour le bouton de basculement du mode sombre
    if (darkModeToggle) {
        darkModeToggle.addEventListener('click', () => {
            body.classList.toggle('dark-mode');
            const isCurrentlyDark = body.classList.contains('dark-mode');
            localStorage.setItem('darkMode', isCurrentlyDark);
            updateDarkModeIcon(isCurrentlyDark);
        });
    }
}

// Mettre à jour l'icône du mode sombre
function updateDarkModeIcon(isDark) {
    const darkModeIcon = document.querySelector('.dark-mode-toggle i');
    if (darkModeIcon) {
        darkModeIcon.className = isDark ? 'fas fa-sun' : 'fas fa-moon';
    }
}