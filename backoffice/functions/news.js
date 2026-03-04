// news.js - Gestion des Actualités (CRUD)

const NEWS_API        = 'https://api.live.wortis.cg/wortis_app_bp/news';
const NEWS_UPLOAD_API = 'https://api.live.wortis.cg/wortis_app_bp/news/upload-image';

let newsList     = [];
let filteredNews = [];
let currentPageNews    = 1;
const itemsPerPageNews = 10;

// URL de l'image déjà uploadée (avant enregistrement du formulaire)
let uploadedImageUrl = '';

const CATEGORIES = {
    general:     { label: 'Général',      icon: 'fas fa-info-circle',          color: 'badge-primary' },
    promo:       { label: 'Promotion',    icon: 'fas fa-tag',                  color: 'badge-success' },
    maintenance: { label: 'Maintenance',  icon: 'fas fa-tools',                color: 'badge-warning' },
    alerte:      { label: 'Alerte',       icon: 'fas fa-exclamation-triangle', color: 'badge-danger'  },
    nouveaute:   { label: 'Nouveauté',    icon: 'fas fa-star',                 color: 'badge-info'    },
};

// ─────────────────────────────────────────────
// FETCH
// ─────────────────────────────────────────────
async function fetchNews() {
    const tableBody = document.getElementById('newsTableBody');
    if (tableBody) {
        tableBody.innerHTML = '<tr><td colspan="6" class="text-center">Chargement des actualités...</td></tr>';
    }

    try {
        const response = await fetch(NEWS_API);
        if (!response.ok) throw new Error(`Erreur HTTP: ${response.status}`);

        const data = await response.json();
        if (!data.success) throw new Error(data.message || 'Erreur inconnue');

        newsList     = data.news || [];
        filteredNews = [...newsList];
        displayNewsPaginated(currentPageNews);
        setupPaginationNews();

    } catch (error) {
        console.error('[fetchNews]', error);
        showToast('Erreur lors du chargement des actualités', 'error');
        if (tableBody) {
            tableBody.innerHTML = '<tr><td colspan="6" class="text-center text-danger">Impossible de charger les actualités</td></tr>';
        }
    }
}

// ─────────────────────────────────────────────
// DISPLAY
// ─────────────────────────────────────────────
function displayNewsPaginated(page) {
    const tableBody = document.getElementById('newsTableBody');
    if (!tableBody) return;

    tableBody.innerHTML = '';

    if (filteredNews.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="6" class="text-center">Aucune actualité trouvée</td></tr>';
        document.getElementById('startItemNews').textContent  = '0';
        document.getElementById('endItemNews').textContent    = '0';
        document.getElementById('totalItemsNews').textContent = '0';
        return;
    }

    const startIndex = (page - 1) * itemsPerPageNews;
    const endIndex   = Math.min(startIndex + itemsPerPageNews, filteredNews.length);

    document.getElementById('startItemNews').textContent  = startIndex + 1;
    document.getElementById('endItemNews').textContent    = endIndex;
    document.getElementById('totalItemsNews').textContent = filteredNews.length;

    for (let i = startIndex; i < endIndex; i++) {
        const news = filteredNews[i];
        const cat  = CATEGORIES[news.categorie] || CATEGORIES.general;
        const date = news.date_creation
            ? new Date(news.date_creation).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' })
            : '—';
        const statutBadge = news.statut === 'active'
            ? '<span class="badge badge-success"><i class="fas fa-check"></i> Active</span>'
            : '<span class="badge badge-danger"><i class="fas fa-ban"></i> Inactive</span>';
        const imagePreview = news.image
            ? `<img src="${escapeHtml(news.image)}" alt="img" style="width:48px;height:32px;object-fit:cover;border-radius:4px;" onerror="this.style.display='none'">`
            : '<span style="color:var(--text-muted);font-size:12px;">—</span>';

        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${imagePreview}</td>
            <td>
                <div class="cell-main">${escapeHtml(news.titre)}</div>
                <div class="cell-sub">${escapeHtml(news.contenu.substring(0, 60))}${news.contenu.length > 60 ? '…' : ''}</div>
            </td>
            <td><span class="badge ${cat.color}"><i class="${cat.icon}"></i> ${cat.label}</span></td>
            <td>${statutBadge}</td>
            <td>${date}</td>
            <td>
                <button class="btn btn-outline btn-sm" onclick="openEditNews('${news._id}')">
                    <i class="fas fa-edit"></i> Éditer
                </button>
                <button class="btn btn-danger btn-sm" onclick="openDeleteNews('${news._id}', '${escapeHtml(news.titre)}')">
                    <i class="fas fa-trash"></i>
                </button>
            </td>
        `;
        tableBody.appendChild(row);
    }
}

// ─────────────────────────────────────────────
// PAGINATION
// ─────────────────────────────────────────────
function setupPaginationNews() {
    const paginationEl = document.getElementById('paginationNews');
    if (!paginationEl) return;

    const totalPages = Math.ceil(filteredNews.length / itemsPerPageNews);
    paginationEl.innerHTML = '';

    const prevLi = document.createElement('li');
    prevLi.className = `pagination-item ${currentPageNews === 1 ? 'disabled' : ''}`;
    prevLi.innerHTML = '<i class="fas fa-chevron-left"></i>';
    prevLi.addEventListener('click', () => { if (currentPageNews > 1) goToPageNews(currentPageNews - 1); });
    paginationEl.appendChild(prevLi);

    for (let i = Math.max(1, currentPageNews - 2); i <= Math.min(totalPages, currentPageNews + 2); i++) {
        const li = document.createElement('li');
        li.className = `pagination-item ${currentPageNews === i ? 'active' : ''}`;
        li.textContent = i;
        li.addEventListener('click', () => goToPageNews(i));
        paginationEl.appendChild(li);
    }

    const nextLi = document.createElement('li');
    nextLi.className = `pagination-item ${currentPageNews === totalPages ? 'disabled' : ''}`;
    nextLi.innerHTML = '<i class="fas fa-chevron-right"></i>';
    nextLi.addEventListener('click', () => { if (currentPageNews < totalPages) goToPageNews(currentPageNews + 1); });
    paginationEl.appendChild(nextLi);
}

function goToPageNews(page) {
    currentPageNews = page;
    displayNewsPaginated(currentPageNews);
    setupPaginationNews();
}

// ─────────────────────────────────────────────
// SEARCH / FILTER
// ─────────────────────────────────────────────
function filterNews() {
    const searchTerm = (document.getElementById('searchNews')?.value || '').toLowerCase().trim();
    const filterCat  = document.getElementById('filterNewsCategorie')?.value || '';
    const filterStat = document.getElementById('filterNewsStatut')?.value || '';

    filteredNews = newsList.filter(news => {
        const matchSearch = !searchTerm
            || news.titre.toLowerCase().includes(searchTerm)
            || news.contenu.toLowerCase().includes(searchTerm);
        const matchCat  = !filterCat  || news.categorie === filterCat;
        const matchStat = !filterStat || news.statut    === filterStat;
        return matchSearch && matchCat && matchStat;
    });

    currentPageNews = 1;
    displayNewsPaginated(currentPageNews);
    setupPaginationNews();
}

// ─────────────────────────────────────────────
// UPLOAD IMAGE via FTP (avant enregistrement)
// ─────────────────────────────────────────────
async function uploadNewsImage(file) {
    const uploadZone   = document.getElementById('newsUploadZone');
    const uploadStatus = document.getElementById('newsUploadStatus');

    uploadStatus.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Upload en cours...';
    uploadStatus.style.color = 'var(--primary-color)';

    const formData = new FormData();
    formData.append('image', file);

    try {
        const response = await fetch(NEWS_UPLOAD_API, { method: 'POST', body: formData });
        const data     = await response.json();

        if (!data.success) throw new Error(data.message || 'Erreur upload');

        uploadedImageUrl = data.url;

        // Afficher l'aperçu
        const preview = document.getElementById('newsImagePreview');
        preview.src   = uploadedImageUrl;
        preview.style.display = 'block';

        uploadStatus.innerHTML = `<i class="fas fa-check-circle"></i> Image uploadée : <strong>${data.filename}</strong>`;
        uploadStatus.style.color = 'var(--success-color)';

    } catch (error) {
        console.error('[uploadNewsImage]', error);
        uploadStatus.innerHTML = `<i class="fas fa-times-circle"></i> Échec : ${error.message}`;
        uploadStatus.style.color = 'var(--danger-color)';
        uploadedImageUrl = '';
    }
}

// ─────────────────────────────────────────────
// OPEN CREATE MODAL
// ─────────────────────────────────────────────
function openCreateNews() {
    document.getElementById('newsModalTitle').textContent = 'Ajouter une actualité';
    document.getElementById('newsForm').reset();
    document.getElementById('newsId').value = '';
    document.getElementById('newsImagePreview').style.display = 'none';
    document.getElementById('newsUploadStatus').innerHTML = '';
    uploadedImageUrl = '';
    openModal('newsModal');
}

// ─────────────────────────────────────────────
// OPEN EDIT MODAL
// ─────────────────────────────────────────────
function openEditNews(newsId) {
    const news = newsList.find(n => n._id === newsId);
    if (!news) { showToast('Actualité introuvable', 'error'); return; }

    document.getElementById('newsModalTitle').textContent = 'Modifier une actualité';
    document.getElementById('newsId').value        = news._id;
    document.getElementById('newsTitre').value     = news.titre;
    document.getElementById('newsContenu').value   = news.contenu;
    document.getElementById('newsCategorie').value = news.categorie;
    document.getElementById('newsStatut').value    = news.statut;

    // Pré-charger l'image existante
    uploadedImageUrl = news.image || '';
    const preview    = document.getElementById('newsImagePreview');
    if (uploadedImageUrl) {
        preview.src = uploadedImageUrl;
        preview.style.display = 'block';
        document.getElementById('newsUploadStatus').innerHTML =
            `<i class="fas fa-check-circle"></i> Image actuelle chargée`;
        document.getElementById('newsUploadStatus').style.color = 'var(--success-color)';
    } else {
        preview.style.display = 'none';
        document.getElementById('newsUploadStatus').innerHTML = '';
    }

    // Reset input file
    document.getElementById('newsImageFile').value = '';
    openModal('newsModal');
}

// ─────────────────────────────────────────────
// SAVE (CREATE ou UPDATE)
// ─────────────────────────────────────────────
async function saveNews() {
    const newsId    = document.getElementById('newsId').value;
    const titre     = document.getElementById('newsTitre').value.trim();
    const contenu   = document.getElementById('newsContenu').value.trim();
    const categorie = document.getElementById('newsCategorie').value;
    const statut    = document.getElementById('newsStatut').value;

    if (!titre || !contenu) {
        showToast('Les champs titre et contenu sont obligatoires', 'error');
        return;
    }

    const btn = document.getElementById('saveNewsBtn');
    btn.disabled = true;
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Enregistrement...';

    try {
        const url    = newsId ? `${NEWS_API}/${newsId}` : NEWS_API;
        const method = newsId ? 'PUT' : 'POST';

        const response = await fetch(url, {
            method,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ titre, contenu, image: uploadedImageUrl, categorie, statut })
        });

        const data = await response.json();
        if (!data.success) throw new Error(data.message || 'Erreur serveur');

        showToast(newsId ? 'Actualité modifiée avec succès' : 'Actualité créée avec succès', 'success');
        closeModal('newsModal');
        fetchNews();

    } catch (error) {
        console.error('[saveNews]', error);
        showToast(error.message || 'Erreur lors de l\'enregistrement', 'error');
    } finally {
        btn.disabled = false;
        btn.innerHTML = '<i class="fas fa-save"></i> Enregistrer';
    }
}

// ─────────────────────────────────────────────
// DELETE
// ─────────────────────────────────────────────
function openDeleteNews(newsId, titre) {
    document.getElementById('deleteNewsId').value       = newsId;
    document.getElementById('deleteNewsTitle').textContent = titre;
    openModal('deleteNewsModal');
}

async function confirmDeleteNews() {
    const newsId = document.getElementById('deleteNewsId').value;
    const btn    = document.getElementById('confirmDeleteNewsBtn');
    btn.disabled = true;
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Suppression...';

    try {
        const response = await fetch(`${NEWS_API}/${newsId}`, { method: 'DELETE' });
        const data     = await response.json();
        if (!data.success) throw new Error(data.message || 'Erreur serveur');

        showToast('Actualité supprimée avec succès', 'success');
        closeModal('deleteNewsModal');
        fetchNews();

    } catch (error) {
        console.error('[confirmDeleteNews]', error);
        showToast(error.message || 'Erreur lors de la suppression', 'error');
    } finally {
        btn.disabled = false;
        btn.innerHTML = '<i class="fas fa-trash-alt"></i> Supprimer';
    }
}

// ─────────────────────────────────────────────
// UTILITAIRE
// ─────────────────────────────────────────────
function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// ─────────────────────────────────────────────
// INIT
// ─────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', function () {

    document.getElementById('addNewsBtn')?.addEventListener('click', openCreateNews);
    document.getElementById('searchNews')?.addEventListener('input', filterNews);
    document.getElementById('filterNewsCategorie')?.addEventListener('change', filterNews);
    document.getElementById('filterNewsStatut')?.addEventListener('change', filterNews);
    document.getElementById('saveNewsBtn')?.addEventListener('click', saveNews);
    document.getElementById('confirmDeleteNewsBtn')?.addEventListener('click', confirmDeleteNews);

    // File picker — upload immédiat à la sélection
    const fileInput = document.getElementById('newsImageFile');
    if (fileInput) {
        fileInput.addEventListener('change', function () {
            if (this.files && this.files[0]) {
                uploadNewsImage(this.files[0]);
            }
        });
    }

    // Drag & drop sur la zone d'upload
    const uploadZone = document.getElementById('newsUploadZone');
    if (uploadZone) {
        uploadZone.addEventListener('click', () => document.getElementById('newsImageFile').click());
        uploadZone.addEventListener('dragover', e => { e.preventDefault(); uploadZone.classList.add('dragover'); });
        uploadZone.addEventListener('dragleave', () => uploadZone.classList.remove('dragover'));
        uploadZone.addEventListener('drop', e => {
            e.preventDefault();
            uploadZone.classList.remove('dragover');
            const file = e.dataTransfer.files[0];
            if (file && file.type.startsWith('image/')) uploadNewsImage(file);
        });
    }
});
