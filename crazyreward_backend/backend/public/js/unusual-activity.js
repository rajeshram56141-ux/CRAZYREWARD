let currentPage = 1;
let currentDateRange = 'all';
let currentType = '';
let selectedUser = null;

function getSelectedApp() {
    return document.getElementById('appSelect')?.value || '';
}

function showLoading() {
    document.getElementById('loadingOverlay').style.display = 'flex';
}

function hideLoading() {
    document.getElementById('loadingOverlay').style.display = 'none';
}

async function loadUsers() {
    const app = getSelectedApp();
    if (!app) {
        document.getElementById('users-tbody').innerHTML = '<tr><td colspan="6" style="text-align: center; padding: 40px;">Select an app first</td></tr>';
        return;
    }

    showLoading();

    try {
        const params = new URLSearchParams({
            app,
            page: currentPage,
            limit: 20,
            dateRange: currentDateRange,
        });

        if (currentType) {
            params.append('type', currentType);
        }

        const res = await fetch(`/api/unusual-activity-users?${params}`);
        const data = await res.json();

        if (data.success) {
            renderUsers(data.users);
            renderStats(data.stats);
            renderPagination(data.total);
        } else {
            document.getElementById('users-tbody').innerHTML = `<tr><td colspan="6" style="text-align: center; padding: 40px; color: red;">${data.message}</td></tr>`;
        }
    } catch (err) {
        console.error('Error loading users:', err);
        document.getElementById('users-tbody').innerHTML = '<tr><td colspan="6" style="text-align: center; padding: 40px; color: red;">Error loading data</td></tr>';
    } finally {
        hideLoading();
    }
}

function renderUsers(users) {
    const tbody = document.getElementById('users-tbody');

    if (!users || users.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; padding: 40px;">No suspicious activity found</td></tr>';
        return;
    }

    tbody.innerHTML = users.map(user => {
        const activitiesCount = user.activities?.length || 0;
        const lastUpdated = user.lastUpdated ? formatDate(user.lastUpdated) : 'N/A';
        const statusClass = user.isBlocked ? 'status-blocked' : 'status-active';
        const statusText = user.isBlocked ? 'Blocked' : 'Active';

        return `
            <tr>
                <td><code>${escapeHtml(user.userId.substring(0, 12))}...</code></td>
                <td>${escapeHtml(user.email || 'N/A')}</td>
                <td><span class="ua-badge">${activitiesCount}</span></td>
                <td>${lastUpdated}</td>
                <td><span class="ua-status ${statusClass}">${statusText}</span></td>
                <td style="text-align: right;">
                    <button class="btn-action-view" onclick="viewDetails('${user.userId}')">View</button>
                    <button class="btn-action-delete" onclick="deleteFromList('${user.userId}')">Delete</button>
                </td>
            </tr>
        `;
    }).join('');
}

function renderStats(stats) {
    document.getElementById('stat-total').textContent = stats.total || 0;
    document.getElementById('stat-blocked').textContent = stats.blocked || 0;
    document.getElementById('stat-active').textContent = stats.active || 0;
}

function renderPagination(total) {
    const totalPages = Math.ceil(total / 20);
    const pagination = document.getElementById('pagination');

    if (totalPages <= 1) {
        pagination.innerHTML = '';
        return;
    }

    let html = '';

    if (currentPage > 1) {
        html += `<button onclick="goToPage(${currentPage - 1})">Previous</button>`;
    }

    html += `<span>Page ${currentPage} of ${totalPages}</span>`;

    if (currentPage < totalPages) {
        html += `<button onclick="goToPage(${currentPage + 1})">Next</button>`;
    }

    pagination.innerHTML = html;
}

function goToPage(page) {
    currentPage = page;
    loadUsers();
}

function switchDateRange(range) {
    currentDateRange = range;
    currentPage = 1;

    document.querySelectorAll('.ua-tab').forEach(tab => {
        tab.classList.remove('active');
    });
    event.target.classList.add('active');

    loadUsers();
}

async function viewDetails(userId) {
    const app = getSelectedApp();
    if (!app) return;

    showLoading();

    try {
        const res = await fetch(`/api/unusual-activity-details?app=${encodeURIComponent(app)}&userId=${encodeURIComponent(userId)}`);
        const data = await res.json();

        if (data.success) {
            selectedUser = {
                userId,
                app,
                email: data.email,
                isBlocked: data.isBlocked,
                payoutBlocked: data.payoutBlocked,
                payoutBlockReason: data.payoutBlockReason,
                suspiciousData: data.suspiciousData,
                blockHistory: data.blockHistory,
            };
            openDetailsModal(data);
        } else {
            showAlert('Error loading details: ' + data.message);
        }
    } catch (err) {
        console.error('Error viewing details:', err);
        showAlert('Error loading details');
    } finally {
        hideLoading();
    }
}

function openDetailsModal(data) {
    const userInfoEl = document.getElementById('details-user-info');
    const activitiesEl = document.getElementById('details-activities');
    const historyEl = document.getElementById('details-block-history');
    const actionsEl = document.getElementById('details-actions');

    // User Info
    userInfoEl.innerHTML = `
        <div style="background: #f3f4f6; padding: 15px; border-radius: 8px; font-size: 14px; line-height: 1.6;">
            <p style="margin: 4px 0;"><strong>User ID:</strong> <code>${escapeHtml(data.suspiciousData?.userId || '')}</code></p>
            <p style="margin: 4px 0;"><strong>Email:</strong> ${escapeHtml(data.email || 'N/A')}</p>
            <div style="display: flex; gap: 15px; margin-top: 10px;">
                <p style="margin: 0;"><strong>Account Status:</strong> <span class="ua-status ${data.isBlocked ? 'status-blocked' : 'status-active'}">${data.isBlocked ? 'Blocked' : 'Active'}</span></p>
                <p style="margin: 0;"><strong>Payout Status:</strong> <span class="ua-status ${data.payoutBlocked ? 'status-blocked' : 'status-active'}">${data.payoutBlocked ? 'Blocked' : 'Active'}</span></p>
            </div>
            ${data.payoutBlocked && data.payoutBlockReason ? `<p style="margin: 8px 0 0 0; color: #ef4444;"><strong>Payout Block Reason:</strong> ${escapeHtml(data.payoutBlockReason)}</p>` : ''}
        </div>
    `;

    // Activities
    const activities = data.suspiciousData?.activities || [];
    if (activities.length > 0) {
        activitiesEl.innerHTML = `
            <h4 style="margin-bottom: 10px;">Suspicious Activities (${activities.length}) <span style="font-size: 11px; color: #6b7280; font-weight: normal;">(Click any activity to view logs & timestamps)</span></h4>
            <div style="max-height: 350px; overflow-y: auto; display: flex; flex-direction: column; gap: 8px;">
                ${activities.map(act => `
                    <div class="ua-activity-item" style="cursor: pointer; border: 1px solid #e5e7eb; padding: 12px; border-radius: 8px;" onclick="toggleActivityLogs('${act.type}', this)">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <div style="display: flex; align-items: center; gap: 10px;">
                                <span class="ua-activity-icon" style="font-size: 20px;">${getActivityIcon(act.type)}</span>
                                <div>
                                    <div class="ua-activity-type" style="font-weight: 600; color: #111827;">${getActivityLabel(act.type)}</div>
                                    <div class="ua-activity-details" style="font-size: 13px; color: #4b5563; margin-top: 2px;">${escapeHtml(act.details)}</div>
                                </div>
                            </div>
                            <div style="text-align: right;">
                                <div class="ua-activity-date" style="font-size: 11px; color: #9ca3af; margin-bottom: 2px;">${formatDate(act.detectedAt)}</div>
                                ${act.coinValue ? `<div class="ua-activity-coins" style="color: #10b981; font-weight: 600; font-size: 13px;">${act.coinValue} coins</div>` : ''}
                            </div>
                        </div>
                        
                        <!-- Collapsible raw logs list -->
                        <div class="ua-activity-logs-container" style="display: none; margin-top: 10px; padding-top: 10px; border-top: 1px dashed #e5e7eb; font-size: 12px;">
                            <div class="ua-logs-loading" style="color: #6b7280; font-style: italic; padding: 4px 0;">Loading detailed logs...</div>
                            <ul class="ua-logs-list" style="list-style: none; padding-left: 0; margin: 0; max-height: 180px; overflow-y: auto; display: flex; flex-direction: column; gap: 4px;"></ul>
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
    } else {
        activitiesEl.innerHTML = '<p>No suspicious activities recorded</p>';
    }

    // Block History
    const history = data.blockHistory || [];
    if (history.length > 0) {
        historyEl.innerHTML = `
            <h4 style="margin-bottom: 10px;">Block History (${history.length})</h4>
            <div style="max-height: 200px; overflow-y: auto;">
                ${history.map(h => `
                    <div class="ua-history-item">
                        <span class="ua-status ${h.isActive ? 'status-blocked' : 'status-active'}">
                            ${h.isActive ? 'Blocked' : 'Active'}
                        </span>
                        <span>${escapeHtml(h.reason || 'No reason')}</span>
                        <span style="color: #666;">${formatDate(h.blockedAt)}</span>
                        <span style="color: #666;">by ${escapeHtml(h.blockedBy || 'system')}</span>
                    </div>
                `).join('')}
            </div>
        `;
    } else {
        historyEl.innerHTML = '<h4 style="margin-bottom: 10px;">Block History</h4><p>No block history</p>';
    }

    // Actions
    let blockUserBtn = data.isBlocked ? 
        `<button class="btn-primary" onclick="unblockUser()">Unlock User</button>` : 
        `<button class="btn-danger" onclick="blockUser()">Block User</button>`;

    let blockPayoutBtn = data.payoutBlocked ? 
        `<button class="btn-primary" onclick="unblockPayout()">Unlock Payout</button>` : 
        `<button class="btn-danger" onclick="blockPayout()">Block Payout</button>`;

    actionsEl.innerHTML = `
        ${blockUserBtn}
        ${blockPayoutBtn}
        <button class="btn-secondary" onclick="closeDetailsModal()">Close</button>
    `;

    document.getElementById('details-modal').classList.add('is-open');
}

function closeDetailsModal() {
    document.getElementById('details-modal').classList.remove('is-open');
    selectedUser = null;
}

async function blockUser() {
    if (!selectedUser) return;

    const reason = prompt('Enter reason for blocking:');
    if (reason === null) return;

    showLoading();

    try {
        const res = await fetch('/api/block-user', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                app: selectedUser.app,
                userId: selectedUser.userId,
                reason,
                activities: selectedUser.suspiciousData?.activities || [],
            }),
        });

        const data = await res.json();

        if (data.success) {
            showAlert('User blocked successfully');
            closeDetailsModal();
            loadUsers();
        } else {
            showAlert('Error: ' + data.message);
        }
    } catch (err) {
        console.error('Error blocking user:', err);
        showAlert('Error blocking user');
    } finally {
        hideLoading();
    }
}

async function unblockUser() {
    if (!selectedUser) return;

    showConfirm('Are you sure you want to unblock this user?', async (confirmed) => {
        if (!confirmed) return;

        showLoading();

        try {
            const res = await fetch('/api/unblock-user', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    app: selectedUser.app,
                    userId: selectedUser.userId,
                }),
            });

            const data = await res.json();

            if (data.success) {
                showAlert('User unblocked successfully');
                closeDetailsModal();
                loadUsers();
            } else {
                showAlert('Error: ' + data.message);
            }
        } catch (err) {
            console.error('Error unblocking user:', err);
            showAlert('Error unblocking user');
        } finally {
            hideLoading();
        }
    });
}

async function deleteFromList(userId) {
    const app = getSelectedApp();
    if (!app) return;

    showConfirm('Remove this user from unusual activity list?', async (confirmed) => {
        if (!confirmed) return;

        showLoading();

        try {
            const res = await fetch('/api/delete-unusual-activity', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ app, userId }),
            });

            const data = await res.json();

            if (data.success) {
                showAlert('User removed from list');
                loadUsers();
            } else {
                showAlert('Error: ' + data.message);
            }
        } catch (err) {
            console.error('Error deleting user:', err);
            showAlert('Error removing user');
        } finally {
            hideLoading();
        }
    });
}

async function triggerScan() {
    const btn = document.getElementById('stat-trigger-scan');
    btn.textContent = 'Scanning...';
    btn.disabled = true;

    try {
        const res = await fetch('/api/trigger-scan', { method: 'POST' });
        const data = await res.json();

        if (data.success) {
            showAlert('Scan completed successfully! Refreshing list...');
            setTimeout(() => loadUsers(), 1000);
        } else {
            showAlert('Error: ' + data.message);
        }
    } catch (err) {
        console.error('Error triggering scan:', err);
        showAlert('Error triggering scan');
    } finally {
        btn.textContent = 'Run Scan';
        btn.disabled = false;
    }
}

function getActivityIcon(type) {
    const icons = {
        watch_earn: '<i class="fa-solid fa-play" style="color: #ef4444;"></i>',
        daily_task: '<i class="fa-solid fa-list-check" style="color: #3b82f6;"></i>',
        read_earn: '<i class="fa-solid fa-book-open" style="color: #10b981;"></i>',
        play_games: '<i class="fa-solid fa-gamepad" style="color: #8b5cf6;"></i>',
        withdrawal: '<i class="fa-solid fa-wallet" style="color: #16a34a;"></i>',
        daily_checkin: '<i class="fa-solid fa-calendar-check" style="color: #06b6d4;"></i>',
        payout_abuse: '<i class="fa-solid fa-money-bill-transfer" style="color: #dc2626;"></i>',
    };
    return icons[type] || '<i class="fa-solid fa-triangle-exclamation" style="color: #f59e0b;"></i>';
}

function getActivityLabel(type) {
    const labels = {
        watch_earn: 'Watch & Earn',
        daily_task: 'Daily Task',
        read_earn: 'Read & Earn',
        play_games: 'Play Games',
        withdrawal: 'Withdrawal',
        daily_checkin: 'Daily Check-in',
        payout_abuse: 'Payout Abuse',
    };
    return labels[type] || type;
}

function formatDate(dateStr) {
    if (!dateStr) return 'N/A';
    const date = new Date(dateStr);
    return date.toLocaleString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
    });
}

function escapeHtml(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

// Event Listeners
document.addEventListener('DOMContentLoaded', () => {
    const appSelect = document.getElementById('appSelect');
    const typeFilter = document.getElementById('typeFilter');

    if (appSelect) {
        appSelect.addEventListener('change', () => {
            currentPage = 1;
            loadUsers();
        });
    }

    if (typeFilter) {
        currentType = typeFilter.value;
    }

    // Initial load
    loadUsers();
});

async function toggleActivityLogs(type, element) {
    const container = element.querySelector('.ua-activity-logs-container');
    if (!container) return;

    if (container.style.display === 'block') {
        container.style.display = 'none';
        return;
    }

    container.style.display = 'block';

    if (container.getAttribute('data-loaded') === 'true') {
        return;
    }

    const loadingEl = container.querySelector('.ua-logs-loading');
    const listEl = container.querySelector('.ua-logs-list');

    try {
        const app = selectedUser.app;
        const userId = selectedUser.userId;
        const res = await fetch(`/api/unusual-activity-logs?app=${encodeURIComponent(app)}&userId=${encodeURIComponent(userId)}&type=${encodeURIComponent(type)}`);
        const data = await res.json();

        if (data.success && data.logs && data.logs.length > 0) {
            listEl.innerHTML = data.logs.map(log => `
                <li style="display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid #f3f4f6; color: #374151;">
                    <span style="font-weight: 500;">${escapeHtml(log.title)}</span>
                    <span style="color: #6b7280; font-family: monospace;">
                        ${formatDate(log.timestamp)} 
                        <strong style="color: #059669; margin-left: 10px;">+${log.coins} coins</strong>
                    </span>
                </li>
            `).join('');
            container.setAttribute('data-loaded', 'true');
        } else {
            listEl.innerHTML = `<li style="color: #9ca3af; font-style: italic; padding: 6px 0;">No raw logs found for this type.</li>`;
        }
    } catch (err) {
        console.error('Error fetching activity logs:', err);
        listEl.innerHTML = `<li style="color: red; font-style: italic; padding: 6px 0;">Failed to load logs.</li>`;
    } finally {
        if (loadingEl) loadingEl.style.display = 'none';
    }
}

async function blockPayout() {
    if (!selectedUser) return;

    const reason = prompt('Enter reason for blocking payout:');
    if (reason === null) return;

    showLoading();

    try {
        const res = await fetch('/api/unusual-activity/block-payout', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                app: selectedUser.app,
                userId: selectedUser.userId,
                block: true,
                reason,
            }),
        });

        const data = await res.json();

        if (data.success) {
            showAlert('Payout blocked successfully');
            closeDetailsModal();
            loadUsers();
        } else {
            showAlert('Error: ' + data.message);
        }
    } catch (err) {
        console.error('Error blocking payout:', err);
        showAlert('Error blocking payout');
    } finally {
        hideLoading();
    }
}

async function unblockPayout() {
    if (!selectedUser) return;

    showConfirm('Are you sure you want to unblock payouts for this user?', async (confirmed) => {
        if (!confirmed) return;

        showLoading();

        try {
            const res = await fetch('/api/unusual-activity/block-payout', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    app: selectedUser.app,
                    userId: selectedUser.userId,
                    block: false,
                }),
            });

            const data = await res.json();

            if (data.success) {
                showAlert('Payout unblocked successfully');
                closeDetailsModal();
                loadUsers();
            } else {
                showAlert('Error: ' + data.message);
            }
        } catch (err) {
            console.error('Error unblocking payout:', err);
            showAlert('Error unblocking payout');
        } finally {
            hideLoading();
        }
    });
}