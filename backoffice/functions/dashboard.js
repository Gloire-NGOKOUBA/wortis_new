// dashboard.js - Gestion du tableau de bord

// Fonction pour rafraîchir les données du tableau de bord
function refreshDashboard() {
    console.log('Rafraîchissement du tableau de bord...');
    
    // Ici vous pourriez appeler diverses fonctions pour mettre à jour
    // les statistiques et les données affichées sur le tableau de bord
    fetchDashboardStats();
    fetchRecentActivity();
    fetchLatestUsers();
}

// Fonction pour récupérer les statistiques
async function fetchDashboardStats() {
    try {
        // Dans un environnement réel, vous feriez des appels API ici
        console.log('Chargement des statistiques du tableau de bord...');
        
        // Exemple de mise à jour des statistiques
        // Ici, nous simulons des données, mais vous récupéreriez ces données depuis votre API
        // const response = await fetch('https://api.live.wortis.cg/dashboard_stats');
        // const data = await response.json();
        
        // Pour l'exemple, on utilise des valeurs statiques
        updateDashboardStats({
            users: 608,
            transactions: 240,
            activeServices: 27,
            notifications: 1524
        });
        
    } catch (error) {
        console.error('Erreur lors du chargement des statistiques:', error);
        showToast('Erreur lors du chargement des statistiques', 'error');
    }
}

// Fonction pour mettre à jour l'affichage des statistiques
function updateDashboardStats(stats) {
    // Mettre à jour les valeurs des cartes de statistiques
    if (stats.users) {
        const userStats = document.querySelector('.stats-card-primary .stats-value');
        if (userStats) userStats.textContent = stats.users;
    }
    
    if (stats.transactions) {
        const transactionStats = document.querySelector('.stats-card-success .stats-value');
        if (transactionStats) transactionStats.textContent = stats.transactions;
    }
    
    if (stats.activeServices) {
        const serviceStats = document.querySelector('.stats-card-warning .stats-value');
        if (serviceStats) serviceStats.textContent = stats.activeServices;
    }
    
    if (stats.notifications) {
        const notifStats = document.querySelector('.stats-card-danger .stats-value');
        if (notifStats) notifStats.textContent = stats.notifications;
    }
}

// Fonction pour récupérer les activités récentes
async function fetchRecentActivity() {
    try {
        console.log('Chargement des activités récentes...');
        
        // Exemple : Récupération des activités récentes depuis l'API
        // const response = await fetch('https://api.live.wortis.cg/recent_activity');
        // const data = await response.json();
        
        // Pour l'exemple, nous gardons les données statiques
        // Si vous aviez des données réelles, vous afficheriez celles-ci ici
        
    } catch (error) {
        console.error('Erreur lors du chargement des activités récentes:', error);
    }
}

// Fonction pour récupérer les derniers utilisateurs
async function fetchLatestUsers() {
    try {
        console.log('Chargement des derniers utilisateurs...');
        
        // Exemple : Récupération des derniers utilisateurs depuis l'API
        // const response = await fetch('https://api.live.wortis.cg/latest_users');
        // const data = await response.json();
        
        // Pour l'exemple, nous gardons les données statiques
        // Si vous aviez des données réelles, vous afficheriez celles-ci ici
        
    } catch (error) {
        console.error('Erreur lors du chargement des derniers utilisateurs:', error);
    }
}

// Initialisation
document.addEventListener('DOMContentLoaded', function() {
    // Si on est sur la page du tableau de bord au chargement initial, on rafraîchit les données
    if (document.querySelector('.main-content').style.display !== 'none') {
        refreshDashboard();
    }
    
    // Bouton de rafraîchissement du tableau de bord (si présent)
    const refreshButton = document.querySelector('.content-header .btn-primary');
    if (refreshButton) {
        refreshButton.addEventListener('click', refreshDashboard);
    }
});