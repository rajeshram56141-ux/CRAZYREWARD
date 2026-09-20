// Payment History - Frontend Logic

let currentPage = 1;
let currentFilters = {
    startDate: '',
    endDate: '',
    status: 'all',
    method: 'all',
    search: '',
};

let selectedOrderIds = new Set();
let pendingDeleteOrderId = null;
let isBulkDelete = false;
let currentRecordsList = [];

function escapeHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function formatCurrency(value) {
    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        minimumFractionDigits: 0,
        maximumFractionDigits: 2,
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

function getStatusClass(status) {
    const statusMap = {
        success: 'status-success',
        pending: 'status-pending',
        failed: 'status-failed',
        inprogress: 'status-inprogress',
    };
    return statusMap[status?.toLowerCase()] || 'status-pending';
}

function getStatusLabel(status) {
    const labelMap = {
        success: 'Success',
        pending: 'Pending',
        failed: 'Failed',
        inprogress: 'In Progress',
    };
    return labelMap[status?.toLowerCase()] || status || 'Unknown';
}

function updateMethodFilterDropdown(methods) {
    const selectEl = document.getElementById('methodFilter');
    if (!selectEl) return;
    const currentVal = (selectEl.value || 'all').toLowerCase();

    let html = '<option value="all">All Methods</option>';
    methods.forEach(m => {
        const val = escapeHtml(m);
        html += `<option value="${val}" ${currentVal === val.toLowerCase() ? 'selected' : ''}>${val}</option>`;
    });

    selectEl.innerHTML = html;
}

// Load stats
async function loadStats() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    try {
        const res = await fetch('/payment-history/stats', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ selectedApp }),
        });

        const json = await res.json();

        if (json.success) {
            if (json.stats) {
                document.getElementById('stat-today').textContent = formatCurrency(json.stats.today);
                document.getElementById('stat-yesterday').textContent = formatCurrency(json.stats.yesterday);
                document.getElementById('stat-month').textContent = formatCurrency(json.stats.month);
            }
            if (Array.isArray(json.methods)) {
                updateMethodFilterDropdown(json.methods);
            }
        }
    } catch (err) {
        console.error('Failed to load stats:', err);
    }
}

// Load history list
async function loadHistory() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const tableContent = document.getElementById('tableContent');
    const paginationInfo = document.getElementById('paginationInfo');

    tableContent.innerHTML = '<div class="loading-spinner">Loading payment history...</div>';
    paginationInfo.style.display = 'none';

    try {
        const res = await fetch('/payment-history/list', {
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

        currentRecordsList = json.records || [];
        renderTable(currentRecordsList, json.total, json.page, json.totalPages);
        renderPagination(json.total, json.page, json.totalPages);
        updateBulkUI();

        // Update the filtered total range card values
        const successVal = json.filteredSuccessTotal || 0;
        const failedVal = json.filteredFailedTotal || 0;
        const successCountVal = json.filteredSuccessCount || 0;

        const successEl = document.getElementById('stat-filtered-success');
        if (successEl) {
            successEl.textContent = formatCurrency(successVal);
        }

        const failedEl = document.getElementById('stat-filtered-failed');
        if (failedEl) {
            failedEl.textContent = formatCurrency(failedVal);
        }

        const successCountEl = document.getElementById('stat-filtered-success-count');
        if (successCountEl) {
            successCountEl.textContent = Number(successCountVal).toLocaleString('en-IN');
        }

        paginationInfo.style.display = 'flex';
    } catch (err) {
        console.error('Failed to load history:', err);
        tableContent.innerHTML = `<div class="empty-state"><div class="empty-state-icon">⚠️</div><p>${escapeHtml(err.message || 'Failed to load data')}</p></div>`;
    }
}

function renderTable(records, total, page, totalPages) {
    const tableContent = document.getElementById('tableContent');

    if (!records.length) {
        tableContent.innerHTML = `
            <div class="table-responsive">
                <table class="history-table">
                    <thead>
                        <tr>
                            <th class="col-checkbox">
                                <input type="checkbox" disabled class="select-all-checkbox">
                            </th>
                            <th>#</th>
                            <th>Date/Time</th>
                            <th>Order ID</th>
                            <th>User ID</th>
                            <th>Email</th>
                            <th>Method</th>
                            <th>Amount</th>
                            <th>Coins</th>
                            <th>Status</th>
                            <th>Code / UTR</th>
                            <th class="col-action">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td colspan="12" style="text-align: center; padding: 40px; color: #64748b;">
                                No records found
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
        `;
        return;
    }

    const startNum = (page - 1) * 20 + 1;

    const rows = records.map((item, index) => {
        const orderId = item.orderId || item.id || '';
        const isChecked = orderId && selectedOrderIds.has(orderId);
        const hasRedeemCode = item.redeemCode && String(item.redeemCode).trim() !== '' && String(item.redeemCode).toLowerCase() !== 'n/a';
        let codeHtml = '<span style="color: #94a3b8;">-</span>';

        if (hasRedeemCode) {
            const rawCode = String(item.redeemCode).trim();
            codeHtml = `<span class="code-chip" title="Click to copy: ${escapeHtml(rawCode)}" onclick="copyText('${escapeHtml(rawCode)}')">📋 ${escapeHtml(rawCode)}</span>`;
        } else if (item.utr || item.refId || item.txnId) {
            const utrVal = String(item.utr || item.refId || item.txnId).trim();
            codeHtml = `<span style="color: #475569; font-weight: 600; font-family: ui-monospace, monospace; font-size: 12px;" title="${escapeHtml(utrVal)}">${escapeHtml(utrVal)}</span>`;
        }

        const safeOrderId = escapeHtml(orderId);
        const safeUserId = escapeHtml(item.userId || '');
        const safeEmail = escapeHtml(item.email || '');

        return `
        <tr id="row-${safeOrderId}" class="${isChecked ? 'row-selected' : ''}">
            <td class="col-checkbox">
                <input type="checkbox" class="row-checkbox" value="${safeOrderId}" ${isChecked ? 'checked' : ''} onchange="toggleRowSelection('${safeOrderId}', this.checked)">
            </td>
            <td style="color: #94a3b8; font-weight: 700; font-size: 12px;">${startNum + index}</td>
            <td style="white-space: nowrap; font-size: 12.5px; color: #475569;">${escapeHtml(formatDate(item.timestamp))}</td>
            <td style="white-space: nowrap;"><strong style="color: #0f172a; font-family: ui-monospace, monospace; font-size: 12.5px;">${safeOrderId}</strong></td>
            <td style="max-width: 140px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="${safeUserId}">${safeUserId || '-'}</td>
            <td style="max-width: 160px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="${safeEmail}">${safeEmail || '-'}</td>
            <td style="white-space: nowrap;"><span style="font-weight: 600; color: #334155;">${escapeHtml(item.methodName || '-')}</span></td>
            <td style="white-space: nowrap;"><strong style="color: #047857; font-size: 14px;">${formatCurrency(item.amount)}</strong></td>
            <td style="white-space: nowrap; font-weight: 600; color: #6d28d9;">${Number(item.coins || 0).toLocaleString('en-IN')}</td>
            <td><span class="status-badge ${getStatusClass(item.status)}">${getStatusLabel(item.status)}</span></td>
            <td style="max-width: 200px;">${codeHtml}</td>
            <td class="col-action">
                <button type="button" class="btn-delete-row" title="Delete payment record" onclick="confirmDeletePayment('${safeOrderId}')">
                    🗑️ Delete
                </button>
            </td>
        </tr>
        `;
    }).join('');

    tableContent.innerHTML = `
        <div class="table-responsive">
            <table class="history-table">
                <thead>
                    <tr>
                        <th class="col-checkbox">
                            <input type="checkbox" id="selectAllCheckbox" class="select-all-checkbox" onchange="toggleSelectAll(this.checked)" title="Select All on this page">
                        </th>
                        <th>#</th>
                        <th>Date/Time</th>
                        <th>Order ID</th>
                        <th>User ID</th>
                        <th>Email</th>
                        <th>Method</th>
                        <th>Amount</th>
                        <th>Coins</th>
                        <th>Status</th>
                        <th>Code / UTR</th>
                        <th class="col-action">Action</th>
                    </tr>
                </thead>
                <tbody>
                    ${rows}
                </tbody>
            </table>
        </div>
    `;
}

function renderPagination(total, page, totalPages) {
    const paginationText = document.getElementById('paginationText');
    const prevBtn = document.getElementById('prevBtn');
    const nextBtn = document.getElementById('nextBtn');

    const start = Math.min((page - 1) * 20 + 1, total);
    const end = Math.min(page * 20, total);

    paginationText.textContent = `Showing ${total ? start : 0}-${end} of ${total.toLocaleString('en-IN')} records`;

    prevBtn.disabled = page <= 1;
    nextBtn.disabled = page >= totalPages;
}

// Selection & Bulk Logic
function toggleRowSelection(orderId, isChecked) {
    if (!orderId) return;
    if (isChecked) {
        selectedOrderIds.add(orderId);
    } else {
        selectedOrderIds.delete(orderId);
    }

    const rowEl = document.getElementById(`row-${orderId}`);
    if (rowEl) {
        if (isChecked) {
            rowEl.classList.add('row-selected');
        } else {
            rowEl.classList.remove('row-selected');
        }
    }

    updateBulkUI();
}

function toggleSelectAll(isChecked) {
    const pageOrderIds = currentRecordsList.map(r => r.orderId || r.id).filter(Boolean);

    pageOrderIds.forEach(id => {
        if (isChecked) {
            selectedOrderIds.add(id);
        } else {
            selectedOrderIds.delete(id);
        }

        const rowEl = document.getElementById(`row-${id}`);
        if (rowEl) {
            if (isChecked) {
                rowEl.classList.add('row-selected');
            } else {
                rowEl.classList.remove('row-selected');
            }
        }
    });

    const checkboxes = document.querySelectorAll('.row-checkbox');
    checkboxes.forEach(cb => {
        cb.checked = isChecked;
    });

    updateBulkUI();
}

function updateBulkUI() {
    const bulkHeader = document.getElementById('bulkActionsHeader');
    const bulkCountSpan = document.getElementById('bulkSelectedCount');
    const selectAllCb = document.getElementById('selectAllCheckbox');

    const count = selectedOrderIds.size;

    if (bulkHeader && bulkCountSpan) {
        if (count > 0) {
            bulkHeader.style.display = 'block';
            bulkCountSpan.textContent = count;
        } else {
            bulkHeader.style.display = 'none';
            bulkCountSpan.textContent = '0';
        }
    }

    if (selectAllCb && currentRecordsList.length > 0) {
        const pageOrderIds = currentRecordsList.map(r => r.orderId || r.id).filter(Boolean);
        const selectedOnPage = pageOrderIds.filter(id => selectedOrderIds.has(id)).length;

        if (selectedOnPage === pageOrderIds.length && pageOrderIds.length > 0) {
            selectAllCb.checked = true;
            selectAllCb.indeterminate = false;
        } else if (selectedOnPage > 0) {
            selectAllCb.checked = false;
            selectAllCb.indeterminate = true;
        } else {
            selectAllCb.checked = false;
            selectAllCb.indeterminate = false;
        }
    }
}

function clearSelection() {
    selectedOrderIds.clear();
    updateBulkUI();
}

function copyText(text) {
    if (!text) return;
    navigator.clipboard.writeText(text).then(() => {
        showAlert(`Copied Code: ${text}`);
    }).catch(() => {
        showAlert(`Code: ${text}`);
    });
}

function applyFilters() {
    currentFilters = {
        startDate: document.getElementById('startDate')?.value || '',
        endDate: document.getElementById('endDate')?.value || '',
        status: document.getElementById('statusFilter')?.value || 'all',
        method: document.getElementById('methodFilter')?.value || 'all',
        search: document.getElementById('searchInput')?.value || '',
    };
    currentPage = 1;
    clearSelection();
    loadHistory();
}

function resetFilters() {
    document.getElementById('startDate').value = '';
    document.getElementById('endDate').value = '';
    document.getElementById('statusFilter').value = 'all';
    document.getElementById('methodFilter').value = 'all';
    document.getElementById('searchInput').value = '';

    currentFilters = {
        startDate: '',
        endDate: '',
        status: 'all',
        method: 'all',
        search: '',
    };
    currentPage = 1;
    clearSelection();
    loadHistory();
}

function changePage(delta) {
    currentPage += delta;
    if (currentPage < 1) currentPage = 1;
    loadHistory();
}

function exportCSV() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const params = new URLSearchParams({
        selectedApp,
        ...currentFilters,
    });

    window.location.href = `/payment-history/export?${params.toString()}`;
}

// Show alert modal
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

// Confirm delete modal logic (Single Delete)
function confirmDeletePayment(orderId) {
    if (!orderId) return;
    isBulkDelete = false;
    pendingDeleteOrderId = orderId;

    const modal = document.getElementById('confirm-delete-modal');
    const title = document.getElementById('confirm-delete-title');
    const msg = document.getElementById('confirm-delete-msg');

    if (title) title.textContent = 'Delete Payment Record';
    if (msg) {
        msg.textContent = `Are you sure you want to permanently delete payment record "${orderId}"?`;
    }
    if (modal) modal.style.display = 'flex';
}

// Confirm bulk delete modal logic
function confirmBulkDeletePayment() {
    const count = selectedOrderIds.size;
    if (count === 0) {
        showAlert('Please select at least one record to delete.');
        return;
    }

    isBulkDelete = true;
    pendingDeleteOrderId = null;

    const modal = document.getElementById('confirm-delete-modal');
    const title = document.getElementById('confirm-delete-title');
    const msg = document.getElementById('confirm-delete-msg');

    if (title) title.textContent = 'Bulk Delete Payment Records';
    if (msg) {
        msg.textContent = `Are you sure you want to permanently delete ${count} selected payment record(s)? This action cannot be undone.`;
    }
    if (modal) modal.style.display = 'flex';
}

function closeConfirmDeleteModal() {
    pendingDeleteOrderId = null;
    isBulkDelete = false;
    const modal = document.getElementById('confirm-delete-modal');
    if (modal) modal.style.display = 'none';
}

async function executeDeletePayment() {
    const deleteBtn = document.getElementById('confirm-delete-btn');

    try {
        if (deleteBtn) {
            deleteBtn.disabled = true;
            deleteBtn.textContent = 'Deleting...';
        }

        if (isBulkDelete) {
            const orderIds = Array.from(selectedOrderIds);
            if (!orderIds.length) {
                closeConfirmDeleteModal();
                return;
            }

            const res = await fetch('/payment-history/delete-bulk', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ orderIds }),
            });
            const json = await res.json();

            closeConfirmDeleteModal();

            if (json.success) {
                clearSelection();
                showAlert(json.message || `Successfully deleted ${orderIds.length} payment records.`);
                loadStats();
                loadHistory();
            } else {
                showAlert(json.message || 'Failed to delete payment records in bulk.');
            }
        } else {
            if (!pendingDeleteOrderId) {
                closeConfirmDeleteModal();
                return;
            }
            const orderId = pendingDeleteOrderId;

            const res = await fetch('/payment-history/delete', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ orderId }),
            });
            const json = await res.json();

            closeConfirmDeleteModal();

            if (json.success) {
                selectedOrderIds.delete(orderId);
                updateBulkUI();
                showAlert(json.message || 'Payment record deleted successfully.');
                loadStats();
                loadHistory();
            } else {
                showAlert(json.message || 'Failed to delete payment record.');
            }
        }
    } catch (err) {
        console.error('Delete error:', err);
        closeConfirmDeleteModal();
        showAlert(err.message || 'Error deleting payment record(s).');
    } finally {
        if (deleteBtn) {
            deleteBtn.disabled = false;
            deleteBtn.textContent = 'Yes, Delete';
        }
    }
}

// App selector change
document.getElementById('appSelect')?.addEventListener('change', () => {
    currentPage = 1;
    clearSelection();
    loadStats();
    loadHistory();
});

// Initial load
document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('confirm-delete-cancel')?.addEventListener('click', closeConfirmDeleteModal);
    document.getElementById('confirm-delete-btn')?.addEventListener('click', executeDeletePayment);
    loadStats();
    loadHistory();
});

// Enter key for search
document.getElementById('searchInput')?.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        applyFilters();
    }
});