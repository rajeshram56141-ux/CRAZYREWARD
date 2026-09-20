// Reward History - Frontend Client Logic

let currentPage = 1;
let currentFilters = {
    startDate: '',
    endDate: '',
    search: '',
};
let selectedRecordIds = new Set();

function escapeHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function formatCoins(value) {
    return new Intl.NumberFormat('en-IN', {
        maximumFractionDigits: 0
    }).format(Number(value) || 0);
}

function formatDate(value) {
    if (!value) return 'N/A';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return 'N/A';
    return date.toLocaleString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
    });
}

// Load stats
async function loadStats() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    try {
        const res = await fetch('/reward-history/stats', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ selectedApp }),
        });

        const json = await res.json();

        if (json.success && json.stats) {
            document.getElementById('stat-today').textContent = formatCoins(json.stats.today);
            document.getElementById('stat-month').textContent = formatCoins(json.stats.month);
            document.getElementById('stat-total').textContent = formatCoins(json.stats.total);
        }
    } catch (err) {
        console.error('Failed to load reward stats:', err);
    }
}

// Load reward list
async function loadHistory() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const tableContent = document.getElementById('tableContent');
    const paginationInfo = document.getElementById('paginationInfo');

    tableContent.innerHTML = '<div class="loading-spinner">Loading reward records...</div>';
    paginationInfo.style.display = 'none';

    // Reset row selections when reloading data
    selectedRecordIds.clear();
    updateDeleteButtonState();

    try {
        const res = await fetch('/reward-history/list', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                selectedApp,
                ...currentFilters,
                page: currentPage,
                limit: 20,
            }),
        });

        const json = await res.json();

        if (!res.ok || !json.success) {
            throw new Error(json.message || 'Failed to fetch records');
        }

        renderTable(json.records || [], json.total, json.page, json.totalPages);
        renderPagination(json.total, json.page, json.totalPages);

        paginationInfo.style.display = 'flex';
    } catch (err) {
        console.error('Failed to load reward history:', err);
        tableContent.innerHTML = `<div class="empty-state"><div class="empty-state-icon">⚠️</div><p>${escapeHtml(err.message || 'Failed to load data')}</p></div>`;
    }
}

function renderTable(records, total, page, totalPages) {
    const tableContent = document.getElementById('tableContent');

    if (!records.length) {
        tableContent.innerHTML = `
            <table class="history-table">
                <thead>
                    <tr>
                        <th class="checkbox-cell"><input type="checkbox" disabled></th>
                        <th>#</th>
                        <th>Date/Time</th>
                        <th>User ID</th>
                        <th>Provider</th>
                        <th>Coins</th>
                        <th>Gems</th>
                        <th>Reward Type</th>
                        <th>Order ID</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td colspan="9" style="text-align: center; padding: 40px; color: #64748b;">
                            No records found
                        </td>
                    </tr>
                </tbody>
            </table>
        `;
        return;
    }

    const startNum = (page - 1) * 20 + 1;

    const rows = records.map((item, index) => {
        const coinsNum = Number(item.coins) || 0;
        const gemsNum = Number(item.gems) || 0;

        const coinsHtml = coinsNum !== 0
            ? `<span style="color:${coinsNum > 0 ? '#16a34a' : '#dc2626'};font-weight:700;">${coinsNum > 0 ? '+' : ''}${formatCoins(coinsNum)}</span>`
            : '<span style="color:#94a3b8;">0</span>';

        const gemsHtml = gemsNum !== 0
            ? `<span style="color:${gemsNum > 0 ? '#2563eb' : '#dc2626'};font-weight:700;">${gemsNum > 0 ? '+' : ''}${formatCoins(gemsNum)}</span>`
            : '<span style="color:#94a3b8;">0</span>';

        return `
        <tr>
            <td class="checkbox-cell">
                <input type="checkbox" class="row-checkbox" value="${item._id}" onchange="toggleRowSelection(this)">
            </td>
            <td>${startNum + index}</td>
            <td>${escapeHtml(formatDate(item.timestamp || item.createdAt))}</td>
            <td>
                <span style="color:#2563eb;font-weight:700;cursor:pointer;" onclick="showUserLookupModal('${escapeHtml(item.userId)}')">
                    ${escapeHtml(item.userId || '')}
                </span>
            </td>
            <td><strong style="color:#0f172a;">${escapeHtml(item.provider || '')}</strong></td>
            <td>${coinsHtml}</td>
            <td>${gemsHtml}</td>
            <td><span class="status-badge status-inprogress" style="padding: 2px 10px;">${escapeHtml(item.rewardType || (gemsNum !== 0 && coinsNum === 0 ? 'gem' : 'coin'))}</span></td>
            <td style="font-family:monospace;font-size:12px;color:#475569;">${escapeHtml(item.orderId || '-')}</td>
        </tr>
    `}).join('');

    tableContent.innerHTML = `
        <table class="history-table">
            <thead>
                <tr>
                    <th class="checkbox-cell"><input type="checkbox" id="selectAllCheckbox" onchange="toggleSelectAll(this)"></th>
                    <th>#</th>
                    <th>Date/Time</th>
                    <th>User ID</th>
                    <th>Provider</th>
                    <th>Coins</th>
                    <th>Gems</th>
                    <th>Reward Type</th>
                    <th>Order ID</th>
                </tr>
            </thead>
            <tbody>
                ${rows}
            </tbody>
        </table>
    `;
}

function renderPagination(total, page, totalPages) {
    const paginationText = document.getElementById('paginationText');
    const prevBtn = document.getElementById('prevBtn');
    const nextBtn = document.getElementById('nextBtn');

    const start = Math.min((page - 1) * 20 + 1, total);
    const end = Math.min(page * 20, total);

    paginationText.textContent = `Showing ${total ? start : 0}-${end} of ${total.toLocaleString('en-IN')} records (Page ${page} of ${totalPages || 1})`;

    prevBtn.disabled = page <= 1;
    nextBtn.disabled = page >= totalPages;
}

// Checkbox selection management
function toggleRowSelection(checkbox) {
    const id = checkbox.value;
    if (checkbox.checked) {
        selectedRecordIds.add(id);
    } else {
        selectedRecordIds.delete(id);
        const selectAll = document.getElementById('selectAllCheckbox');
        if (selectAll) selectAll.checked = false;
    }
    updateDeleteButtonState();
}

function toggleSelectAll(selectAllCheckbox) {
    const checkboxes = document.querySelectorAll('.row-checkbox');
    checkboxes.forEach(cb => {
        cb.checked = selectAllCheckbox.checked;
        if (selectAllCheckbox.checked) {
            selectedRecordIds.add(cb.value);
        } else {
            selectedRecordIds.delete(cb.value);
        }
    });
    updateDeleteButtonState();
}

function updateDeleteButtonState() {
    const btn = document.getElementById('btnDeleteSelected');
    const countSpan = document.getElementById('deleteCount');
    const count = selectedRecordIds.size;

    if (countSpan) countSpan.textContent = count;
    if (btn) {
        btn.disabled = count === 0;
    }
}

// Delete Selected records
async function deleteSelectedRecords() {
    const count = selectedRecordIds.size;
    if (count === 0) return;

    const ok = window.confirm(`Are you sure you want to delete these ${count} reward history records? This cannot be undone.`);
    if (!ok) return;

    const ids = Array.from(selectedRecordIds);

    try {
        const res = await fetch('/reward-history/delete', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ids }),
        });

        const json = await res.json();
        if (json.success) {
            showAlert(json.message || `Successfully deleted ${count} records`, () => {
                loadStats();
                loadHistory();
            });
        } else {
            showAlert(json.message || 'Failed to delete records');
        }
    } catch (err) {
        console.error('Error deleting records:', err);
        showAlert('Error occurred during deletion request');
    }
}

function applyFilters() {
    currentFilters = {
        startDate: document.getElementById('startDate')?.value || '',
        endDate: document.getElementById('endDate')?.value || '',
        search: document.getElementById('searchInput')?.value || '',
    };
    currentPage = 1;
    loadHistory();
}

function resetFilters() {
    document.getElementById('startDate').value = '';
    document.getElementById('endDate').value = '';
    document.getElementById('searchInput').value = '';

    currentFilters = {
        startDate: '',
        endDate: '',
        search: '',
    };
    currentPage = 1;
    loadHistory();
}

function changePage(delta) {
    currentPage += delta;
    if (currentPage < 1) currentPage = 1;
    loadHistory();
}

// Show alert modal helper
function showAlert(message, callback) {
    const modal = document.getElementById('alert-modal');
    const messageEl = modal?.querySelector('.alert-message');
    const okBtn = document.getElementById('alert-ok');

    if (messageEl) messageEl.textContent = message;
    if (modal) modal.style.display = 'flex';

    const closeModal = () => {
        if (modal) modal.style.display = 'none';
        okBtn?.removeEventListener('click', closeModal);
        if (callback) callback();
    };

    okBtn?.addEventListener('click', closeModal);
}

// App selector change
document.getElementById('appSelect')?.addEventListener('change', () => {
    currentPage = 1;
    loadStats();
    loadHistory();
});

// Initial load
document.addEventListener('DOMContentLoaded', () => {
    loadStats();
    loadHistory();
});

// Enter key for search
document.getElementById('searchInput')?.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        applyFilters();
    }
});
