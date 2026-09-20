// Super Offer History - Frontend Client Logic

let currentPage = 1;
let currentFilters = {
    search: '',
    status: '',
    stepType: '',
    startDate: '',
    endDate: '',
};
let selectedRecordIds = new Set();
let cachedRecordsMap = new Map();

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

function onAppChanged() {
    currentPage = 1;
    loadStats();
    loadHistory();
}

// Load stats
async function loadStats() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    try {
        const res = await fetch('/super-offer-history/stats', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ selectedApp }),
        });

        const json = await res.json();

        if (json.success && json.stats) {
            document.getElementById('stat-today').textContent = formatCoins(json.stats.todayCoins);
            document.getElementById('stat-month').textContent = formatCoins(json.stats.monthCoins);
            document.getElementById('stat-inprogress').textContent = formatCoins(json.stats.inProgressCount);
            document.getElementById('stat-completed').textContent = formatCoins(json.stats.completedCount);
        }
    } catch (err) {
        console.error('Failed to load super offer stats:', err);
    }
}

// Load history records
async function loadHistory() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const tableContent = document.getElementById('tableContent');
    const paginationInfo = document.getElementById('paginationInfo');

    tableContent.innerHTML = '<div class="loading-spinner">Loading super offer records...</div>';
    paginationInfo.style.display = 'none';

    selectedRecordIds.clear();
    updateDeleteButtonState();

    try {
        const res = await fetch('/super-offer-history/list', {
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

        cachedRecordsMap.clear();
        (json.records || []).forEach(r => cachedRecordsMap.set(String(r._id), r));

        renderTable(json.records || [], json.total, json.page, json.totalPages);
        renderPagination(json.total, json.page, json.totalPages);

        paginationInfo.style.display = 'flex';
    } catch (err) {
        console.error('Failed to load super offer history:', err);
        tableContent.innerHTML = `<div class="empty-state"><div class="empty-state-icon">⚠️</div><p>${escapeHtml(err.message || 'Failed to load data')}</p></div>`;
    }
}

function renderTable(records, total, page, totalPages) {
    const tableContent = document.getElementById('tableContent');

    if (!records || records.length === 0) {
        tableContent.innerHTML = '<div class="empty-state"><div class="empty-state-icon">🔍</div><p>No Super Offer records found.</p></div>';
        return;
    }

    let rowsHtml = '';
    records.forEach(r => {
        const id = String(r._id);
        const isChecked = selectedRecordIds.has(id);
        const status = (r.status || 'in_progress').toLowerCase();
        
        let proofHtml = '<span style="color: #94a3b8; font-size: 11.5px;">-</span>';
        if (r.proofImageUrl) {
            proofHtml = `<img src="${escapeHtml(r.proofImageUrl)}" class="proof-thumb" onclick="window.open('${escapeHtml(r.proofImageUrl)}', '_blank')" title="Click to view full screenshot">`;
        }

        const dateStr = formatDate(r.completedAt || r.installedAt || r.createdAt);
        const stepDisplay = `Step ${r.stepNumber || 1}: ${escapeHtml(r.stepName || 'Install & Launch')}`;
        const typeBadge = `<span style="font-size: 10px; color: #64748b; background: #f1f5f9; padding: 2px 6px; border-radius: 4px; font-weight: 700; text-transform: uppercase; margin-left: 4px;">${escapeHtml(r.stepType || 'install')}</span>`;

        rowsHtml += `
            <tr id="row-${id}">
                <td class="checkbox-cell">
                    <input type="checkbox" class="row-checkbox" value="${id}" ${isChecked ? 'checked' : ''} onchange="toggleRowSelect('${id}', this.checked)">
                </td>
                <td>
                    <div style="font-weight: 700; color: #0f172a; font-size: 13.5px;">${escapeHtml(r.userId || 'Unknown')}</div>
                    ${r.userEmail ? `<div style="font-size: 11.5px; color: #64748b; margin-top: 2px;">${escapeHtml(r.userEmail)}</div>` : ''}
                </td>
                <td>
                    <div style="font-weight: 700; color: #1e293b;">${escapeHtml(r.appName || 'Super Offer App')}</div>
                    <div style="font-size: 11.5px; color: #64748b; margin-top: 2px; font-family: monospace;">${escapeHtml(r.packageName || '-')}</div>
                </td>
                <td>
                    <div style="font-weight: 700; color: #334155;">${stepDisplay} ${typeBadge}</div>
                </td>
                <td>
                    <span style="font-weight: 800; color: #b45309; font-size: 14px;">
                        🪙 ${formatCoins(r.coins || 0)}
                    </span>
                </td>
                <td>${proofHtml}</td>
                <td>
                    <span class="status-pill ${status}">
                        ${escapeHtml(status.replace('_', ' '))}
                    </span>
                    ${r.rejectionReason ? `<div style="font-size: 11px; color: #dc2626; margin-top: 4px; max-width: 140px;">${escapeHtml(r.rejectionReason)}</div>` : ''}
                </td>
                <td>
                    <div style="font-size: 12.5px; color: #334155; font-weight: 600;">${dateStr}</div>
                </td>
                <td style="text-align: right; white-space: nowrap;">
                    <button class="btn-row-action edit" onclick="openEditModal('${id}')">
                        ✏️ Edit
                    </button>
                    <button class="btn-row-action delete" onclick="deleteSingleRecord('${id}')" style="margin-left: 6px;">
                        🗑️
                    </button>
                </td>
            </tr>
        `;
    });

    tableContent.innerHTML = `
        <div style="overflow-x: auto;">
            <table class="history-table">
                <thead>
                    <tr>
                        <th class="checkbox-cell">
                            <input type="checkbox" id="selectAllCheckbox" onchange="toggleSelectAll(this)">
                        </th>
                        <th>User</th>
                        <th>App & Package</th>
                        <th>Step Details</th>
                        <th>Coins</th>
                        <th>Proof</th>
                        <th>Status</th>
                        <th>Completed / Created</th>
                        <th style="text-align: right;">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${rowsHtml}
                </tbody>
            </table>
        </div>
    `;
}

function renderPagination(total, page, totalPages) {
    const text = document.getElementById('paginationText');
    const prevBtn = document.getElementById('prevBtn');
    const nextBtn = document.getElementById('nextBtn');

    const start = total === 0 ? 0 : (page - 1) * 20 + 1;
    const end = Math.min(page * 20, total);
    text.textContent = `Showing ${start}-${end} of ${total} records`;

    prevBtn.disabled = page <= 1;
    nextBtn.disabled = page >= totalPages;
}

function changePage(delta) {
    currentPage += delta;
    loadHistory();
}

function applyFilters() {
    currentPage = 1;
    currentFilters.search = document.getElementById('searchInput')?.value.trim() || '';
    currentFilters.status = document.getElementById('statusFilter')?.value.trim() || '';
    currentFilters.stepType = document.getElementById('stepTypeFilter')?.value.trim() || '';
    currentFilters.startDate = document.getElementById('startDateInput')?.value || '';
    currentFilters.endDate = document.getElementById('endDateInput')?.value || '';
    loadHistory();
}

function resetFilters() {
    document.getElementById('searchInput').value = '';
    document.getElementById('statusFilter').value = '';
    document.getElementById('stepTypeFilter').value = '';
    document.getElementById('startDateInput').value = '';
    document.getElementById('endDateInput').value = '';
    applyFilters();
}

// Row Selection
function toggleRowSelect(id, checked) {
    if (checked) selectedRecordIds.add(id);
    else selectedRecordIds.delete(id);
    updateDeleteButtonState();
}

function toggleSelectAll(masterCheckbox) {
    const checkboxes = document.querySelectorAll('.row-checkbox');
    checkboxes.forEach(cb => {
        cb.checked = masterCheckbox.checked;
        if (masterCheckbox.checked) selectedRecordIds.add(cb.value);
        else selectedRecordIds.delete(cb.value);
    });
    updateDeleteButtonState();
}

function updateDeleteButtonState() {
    const btn = document.getElementById('btnDeleteSelected');
    const countSpan = document.getElementById('deleteCount');
    const count = selectedRecordIds.size;
    countSpan.textContent = count;
    btn.disabled = count === 0;
}

// Delete single record
async function deleteSingleRecord(id) {
    if (!confirm('Are you sure you want to delete this Super Offer record? This action cannot be undone.')) return;

    try {
        const res = await fetch('/super-offer-history/delete', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ids: [id] }),
        });
        const json = await res.json();
        if (json.success) {
            loadHistory();
            loadStats();
        } else {
            alert(json.message || 'Failed to delete record');
        }
    } catch (err) {
        alert('Error: ' + err.message);
    }
}

// Bulk delete
async function executeBulkDelete() {
    const count = selectedRecordIds.size;
    if (count === 0) return;
    if (!confirm(`Are you sure you want to delete ${count} selected Super Offer records?`)) return;

    try {
        const res = await fetch('/super-offer-history/delete', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ids: Array.from(selectedRecordIds) }),
        });
        const json = await res.json();
        if (json.success) {
            loadHistory();
            loadStats();
        } else {
            alert(json.message || 'Failed to delete records');
        }
    } catch (err) {
        alert('Error: ' + err.message);
    }
}

// Edit Record Modal
function openEditModal(id) {
    const record = cachedRecordsMap.get(id);
    if (!record) return;

    document.getElementById('editRecordId').value = id;
    document.getElementById('editUserId').value = record.userId || '';
    document.getElementById('editAppName').value = record.appName || '';
    document.getElementById('editPackageName').value = record.packageName || '';
    document.getElementById('editStepNumber').value = record.stepNumber || 1;
    document.getElementById('editStepName').value = record.stepName || '';
    document.getElementById('editCoins').value = record.coins || 0;
    document.getElementById('editUsageMinutes').value = record.usageMinutes || 0;
    document.getElementById('editStatus').value = (record.status || 'in_progress').toLowerCase();
    document.getElementById('editRejectionReason').value = record.rejectionReason || '';

    document.getElementById('editRecordModal').style.display = 'flex';
}

function closeEditModal() {
    document.getElementById('editRecordModal').style.display = 'none';
}

async function saveRecordChanges() {
    const id = document.getElementById('editRecordId').value;
    const btn = document.getElementById('btnSaveRecord');

    const payload = {
        id,
        appName: document.getElementById('editAppName').value.trim(),
        packageName: document.getElementById('editPackageName').value.trim(),
        stepNumber: Number(document.getElementById('editStepNumber').value) || 1,
        stepName: document.getElementById('editStepName').value.trim(),
        coins: Number(document.getElementById('editCoins').value) || 0,
        usageMinutes: Number(document.getElementById('editUsageMinutes').value) || 0,
        status: document.getElementById('editStatus').value.trim(),
        rejectionReason: document.getElementById('editRejectionReason').value.trim(),
    };

    btn.disabled = true;
    btn.textContent = 'Saving...';

    try {
        const res = await fetch('/super-offer-history/update', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        const json = await res.json();

        if (json.success) {
            closeEditModal();
            loadHistory();
            loadStats();
        } else {
            alert(json.message || 'Failed to update record');
        }
    } catch (err) {
        alert('Error: ' + err.message);
    } finally {
        btn.disabled = false;
        btn.textContent = '💾 Save Changes';
    }
}

// Initial load
document.addEventListener('DOMContentLoaded', () => {
    loadStats();
    loadHistory();
});
