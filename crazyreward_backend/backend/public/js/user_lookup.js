let currentLookupContext = {
    appName: '',
    queryInput: '',
    userId: '',
    email: '',
    referralCode: '',
};

function openUserLookupModal(defaultQuery = '') {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    if (!selectedApp) {
        if (typeof showAlert === 'function') {
            showAlert('Please select an app first.');
        } else {
            alert('Please select an app first.');
        }
        return;
    }
    const query = prompt('Enter User Email, User ID, or Referral Code to search:', defaultQuery);
    if (query && query.trim()) {
        if (typeof openUserProfile === 'function') {
            openUserProfile(query.trim(), selectedApp, 'auto');
        }
    }
}

function escapeHtml(str) {
    if (str === undefined || str === null) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function showUserActionFeedback(message, type = 'info') {
    const el = document.getElementById('user-action-feedback');
    if (!el) return;
    el.className = `user-action-feedback ${type}`;
    el.textContent = String(message || '');
}

async function parseActionResponse(res) {
    const contentType = String(res.headers.get('content-type') || '').toLowerCase();

    if (contentType.includes('application/json')) {
        const json = await res.json();
        return {
            ok: res.ok && json?.success !== false,
            message: json?.message || '',
            json,
        };
    }

    const text = await res.text();
    return {
        ok: res.ok,
        message: text || '',
        json: null,
    };
}

async function postUserAction(url, payload) {
    const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload || {}),
    });

    const parsed = await parseActionResponse(res);
    if (!parsed.ok) throw new Error(parsed.message || 'Request failed');
    return parsed;
}

function getLookupIdentifierForRefresh() {
    if (currentLookupContext.userId) {
        return { value: currentLookupContext.userId, type: 'userId' };
    }
    if (currentLookupContext.email) {
        return { value: currentLookupContext.email, type: 'auto' };
    }
    return { value: currentLookupContext.queryInput, type: 'auto' };
}

async function refreshCurrentLookupModal() {
    const id = getLookupIdentifierForRefresh();
    if (!id.value || !currentLookupContext.appName) return;
    await openUserProfile(id.value, currentLookupContext.appName, id.type);
}

function resolveLookupRecipient() {
    return String(currentLookupContext.email || '').trim() || String(currentLookupContext.userId || '').trim();
}

function getLookupAttempts(input, type) {
    const trimmedInput = String(input || '').trim();
    if (!trimmedInput) return [];

    if (type === 'userId') return [{ key: 'userId', value: trimmedInput }];
    if (type === 'email') return [{ key: 'email', value: trimmedInput }];
    if (type === 'referCode') return [{ key: 'referCode', value: trimmedInput }];

    const isEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedInput);
    if (isEmail) return [{ key: 'email', value: trimmedInput }];

    // Auto mode: try userId first, then referral code.
    return [
        { key: 'userId', value: trimmedInput },
        { key: 'referCode', value: trimmedInput },
    ];
}

function shouldTryNextLookupAttempt(result, statusCode) {
    if (result?.success) return false;
    if (statusCode === 404) return true;
    const message = String(result?.message || '').toLowerCase();
    return message.includes('not found');
}

// Function to open popup from anywhere
async function openUserProfile(input, appName, type = 'auto', orderId = '') {
    const modalBody = document.getElementById('user-modal-body');
    document.getElementById('user-modal').classList.add('show');

    currentLookupContext.appName = String(appName || '').trim();
    currentLookupContext.queryInput = String(input || '').trim();

    if (type === 'userId') {
        currentLookupContext.userId = String(input || '').trim();
    }

    if (!input || !appName) {
        modalBody.innerHTML = '<div class="user-modal-message error">Invalid input or app name</div>';
        return;
    }

    modalBody.innerHTML = '<div class="user-modal-message loading">Loading user profile...</div>';

    try {
        const attempts = getLookupAttempts(input, type);
        let json = null;
        let finalErrorMessage = 'User not found';

        for (const attempt of attempts) {
            let url = `/get-user-data?app=${encodeURIComponent(appName)}&${attempt.key}=${encodeURIComponent(attempt.value)}`;
            if (orderId) {
                url += `&orderId=${encodeURIComponent(orderId)}`;
            }

            const res = await fetch(url);
            const data = await res.json();

            if (data?.success) {
                json = data;
                break;
            }

            finalErrorMessage = data?.message || finalErrorMessage;
            if (!shouldTryNextLookupAttempt(data, res.status)) {
                break;
            }
        }

        if (!json || !json.success) {
            modalBody.innerHTML = `<div class="user-modal-message error">${finalErrorMessage}</div>`;
            return;
        }

        currentLookupContext.userId = String(json?.user?.userId || currentLookupContext.userId || '');
        currentLookupContext.email = String(json?.user?.email || currentLookupContext.email || '');
        currentLookupContext.referralCode = String(json?.user?.referralCode || '');

        renderUserModalInternal(json);

    } catch (e) {
        console.error(e);
        modalBody.innerHTML = `<div class="user-modal-message error">Error: ${e.message}</div>`;
    }
}

function closeUserModal() {
    document.getElementById('user-modal').classList.remove('show');
}

async function addAppBonusFromPopup() {
    try {
        const payoutInput = document.getElementById('app-bonus-payout');
        const payout = Number(payoutInput?.value);
        const recipient = resolveLookupRecipient();

        if (!currentLookupContext.appName) throw new Error('App not selected');
        if (!recipient) throw new Error('User email/userId missing');
        if (!Number.isFinite(payout) || payout <= 0) throw new Error('Enter valid payout (> 0)');

        showUserActionFeedback('Adding app bonus...', 'loading');
        const result = await postUserAction('/add-app-bonus', {
            email: recipient,
            userId: currentLookupContext.userId,
            payout,
            selectedApp: currentLookupContext.appName,
        });

        showUserActionFeedback(result.message || 'App bonus added successfully', 'success');
        if (payoutInput) payoutInput.value = '';
        await refreshCurrentLookupModal();
    } catch (error) {
        console.error(error);
        showUserActionFeedback(error.message || 'Failed to add app bonus', 'error');
    }
}

async function deductCoinsFromPopup() {
    try {
        const payoutInput = document.getElementById('coins-deduct-payout');
        const payout = Number(payoutInput?.value);
        const recipient = resolveLookupRecipient();

        if (!currentLookupContext.appName) throw new Error('App not selected');
        if (!recipient) throw new Error('User email/userId missing');
        if (!Number.isFinite(payout) || payout <= 0) throw new Error('Enter valid payout (> 0)');

        showUserActionFeedback('Deducting coins...', 'loading');
        const result = await postUserAction('/deduct-user-coins', {
            email: recipient,
            userId: currentLookupContext.userId,
            payout,
            selectedApp: currentLookupContext.appName,
        });

        showUserActionFeedback(result.message || 'Coins deducted successfully', 'success');
        if (payoutInput) payoutInput.value = '';
        await refreshCurrentLookupModal();
    } catch (error) {
        console.error(error);
        showUserActionFeedback(error.message || 'Failed to deduct coins', 'error');
    }
}

async function updateBlockFromPopup(block) {
    try {
        const reasonInput = document.getElementById('block-reason');
        const reason = String(reasonInput?.value || '').trim();
        const recipient = resolveLookupRecipient();

        if (!currentLookupContext.appName) throw new Error('App not selected');
        if (!recipient) throw new Error('User email/userId missing');
        if (block && !reason) throw new Error('Reason is required for blocking account');

        showUserActionFeedback(block ? 'Blocking account...' : 'Unblocking account...', 'loading');
        const result = await postUserAction('/block-user', {
            email: recipient,
            userId: currentLookupContext.userId,
            selectedApp: currentLookupContext.appName,
            reason,
            block: !!block,
        });

        showUserActionFeedback(result.message || 'Account state updated', 'success');
        if (reasonInput && !block) reasonInput.value = '';
        await refreshCurrentLookupModal();
    } catch (error) {
        console.error(error);
        showUserActionFeedback(error.message || 'Failed to update account state', 'error');
    }
}

async function updatePayoutBlockFromPopup(block) {
    try {
        const reasonInput = document.getElementById('payout-block-reason');
        const reason = String(reasonInput?.value || '').trim();
        const recipient = resolveLookupRecipient();

        if (!currentLookupContext.appName) throw new Error('App not selected');
        if (!recipient) throw new Error('User email/userId missing');
        if (block && !reason) throw new Error('Reason is required for blocking payouts');

        showUserActionFeedback(block ? 'Blocking payouts...' : 'Unblocking payouts...', 'loading');
        const result = await postUserAction('/block-payout', {
            email: recipient,
            userId: currentLookupContext.userId,
            selectedApp: currentLookupContext.appName,
            reason,
            block: !!block,
        });

        showUserActionFeedback(result.message || 'Payout block state updated', 'success');
        if (reasonInput && !block) reasonInput.value = '';
        await refreshCurrentLookupModal();
    } catch (error) {
        console.error(error);
        showUserActionFeedback(error.message || 'Failed to update payout block state', 'error');
    }
}

async function toggleAccountDeletedFromPopup(accountDeleted) {
    try {
        const reasonInput = document.getElementById('account-deleted-reason');
        const reason = String(reasonInput?.value || '').trim();
        const recipient = resolveLookupRecipient();

        if (!currentLookupContext.appName) throw new Error('App not selected');
        if (!recipient) throw new Error('User email/userId missing');
        if (accountDeleted && !reason) throw new Error('Reason is required to set account_deleted true');

        showUserActionFeedback('Updating account_deleted...', 'loading');
        const result = await postUserAction('/toggle-account-deleted', {
            email: recipient,
            userId: currentLookupContext.userId,
            selectedApp: currentLookupContext.appName,
            reason,
            account_deleted: !!accountDeleted,
        });

        showUserActionFeedback(result.message || 'account_deleted updated', 'success');
        if (reasonInput && !accountDeleted) reasonInput.value = '';
        await refreshCurrentLookupModal();
    } catch (error) {
        console.error(error);
        showUserActionFeedback(error.message || 'Failed to update account_deleted', 'error');
    }
}

async function deleteAccountDocFromPopup() {
    try {
        const recipient = resolveLookupRecipient();
        if (!currentLookupContext.appName) throw new Error('App not selected');
        if (!recipient) throw new Error('User email/userId missing');

        const ok = window.confirm('Delete full user account document? This cannot be undone.');
        if (!ok) return;

        showUserActionFeedback('Deleting user account document...', 'loading');
        const result = await postUserAction('/delete-user-account', {
            email: recipient,
            userId: currentLookupContext.userId,
            selectedApp: currentLookupContext.appName,
        });

        showUserActionFeedback(result.message || 'Account document deleted', 'success');
        setTimeout(() => {
            closeUserModal();
        }, 600);
    } catch (error) {
        console.error(error);
        showUserActionFeedback(error.message || 'Failed to delete account document', 'error');
    }
}

async function wipeAllUserDataFromPopup() {
    try {
        const recipient = resolveLookupRecipient();
        if (!currentLookupContext.appName) throw new Error('App not selected');
        if (!recipient) throw new Error('User email/userId missing');

        const ok1 = window.confirm('WARNING: Are you absolutely sure you want to WIPE all data for this user? This will delete the user document, all coins history, all payouts, all game logs, and their Firebase Auth login. THIS ACTION CANNOT BE UNDONE.');
        if (!ok1) return;

        const ok2 = window.confirm('FINAL CONFIRMATION: Double check if you really want to destroy this user account completely. Click OK to execute wipe.');
        if (!ok2) return;

        showUserActionFeedback('Wiping all user data completely...', 'loading');
        const result = await postUserAction('/wipe-user-data', {
            email: recipient,
            userId: currentLookupContext.userId,
            selectedApp: currentLookupContext.appName,
        });

        showUserActionFeedback(result.message || 'All user data wiped completely', 'success');
        setTimeout(() => {
            closeUserModal();
        }, 1500);
    } catch (error) {
        console.error(error);
        showUserActionFeedback(error.message || 'Failed to wipe user data', 'error');
    }
}

function renderUserModalInternal(data) {
    const {
        user = {},
        payoutHistory = [],
        rewardHistory = [],
        referralStats = {},
        conversionRate = 100,
        todayEarnings = { totalCoins: 0, items: [] },
        allEarnings = [],
    } = data || {};

    const fmt = (coins) => `₹${((Number(coins) || 0) / (conversionRate || 1)).toFixed(2)}`;
    const safePhoto = String(user.photoUrl || '').trim() || 'https://via.placeholder.com/120?text=User';
    const blocked = !!user.blocked;
    const payoutBlocked = !!user.payoutBlocked;
    const payoutBlockReason = user.payoutBlockReason || '';
    const accountDeleted = !!user.accountDeleted;

    // Today's Earnings breakdown
    const todayItems = Array.isArray(todayEarnings.items) ? todayEarnings.items : [];
    const todayTotal = Number(todayEarnings.totalCoins) || 0;

    const formatSignedEarn = (coins, gems, isGem) => {
        if (isGem) {
            const num = Number(gems) || Number(coins) || 0;
            const sign = num > 0 ? '+' : num < 0 ? '-' : '';
            return {
                text: `${sign}${Math.abs(num)} Gems 💎`,
                color: num < 0 ? '#dc2626' : '#8b5cf6',
                isNegative: num < 0
            };
        }
        const num = Number(coins) || 0;
        const sign = num > 0 ? '+' : num < 0 ? '-' : '';
        const rsVal = (Math.abs(num) / (conversionRate || 1)).toFixed(2);
        return {
            text: `${sign}₹${rsVal}`,
            color: num < 0 ? '#dc2626' : '#16a34a',
            isNegative: num < 0
        };
    };

    const todayEarningsList = todayItems.length > 0 ? todayItems.map((item) => {
        const label = item.provider || item.taskId || item.gameId || item.type || 'Unknown';
        const isGem = item.rewardType === 'gem' || (Number(item.gems) !== 0 && Number(item.coins) === 0) || (label && label.toLowerCase().includes('gem'));
        const typeIcon = isGem 
            ? '<i class="fa-solid fa-gem" style="color: #8b5cf6;"></i>' 
            : item.type === 'reward' ? '<i class="fa-solid fa-bullseye" style="color: #6366f1;"></i>' 
            : item.type === 'daily_task' ? '<i class="fa-solid fa-calendar-check" style="color: #06b6d4;"></i>' 
            : item.type === 'task' ? '<i class="fa-solid fa-circle-check" style="color: #10b981;"></i>' 
            : item.type === 'game' ? '<i class="fa-solid fa-gamepad" style="color: #8b5cf6;"></i>' 
            : '<i class="fa-solid fa-coins" style="color: #d97706;"></i>';
        const formatted = formatSignedEarn(item.coins, item.gems, isGem);
        return `
            <li class="breakdown-item">
                <span class="provider-name">${typeIcon} ${escapeHtml(label)}</span>
                <span class="coin-val" style="color: ${formatted.color}; font-weight: 700;">${formatted.text}</span>
            </li>`;
    }).join('') : '<li class="breakdown-item empty-row">No earnings today</li>';

    // All-time Earnings (from all collections)
    const allEarnList = allEarnings.length > 0 ? allEarnings.map((item) => {
        const isGem = item.rewardType === 'gem' || (Number(item.gems) !== 0 && Number(item.coins) === 0) || (item.name && item.name.toLowerCase().includes('gem'));
        const formatted = formatSignedEarn(item.coins, item.gems, isGem);
        return `
            <li class="breakdown-item">
                <span class="provider-name">${isGem ? '💎 ' : ''}${escapeHtml(item.name)}</span>
                <span class="coin-val" style="color: ${formatted.color}; font-weight: 700;">${formatted.text}</span>
            </li>`;
    }).join('') : '<li class="breakdown-item empty-row">No earnings found</li>';

    // Payouts
    const payBreakdown = {};
    (Array.isArray(payoutHistory) ? payoutHistory : []).forEach((payout) => {
        const method = payout.methodName || 'Unknown';
        const status = (payout.status || 'UNKNOWN').toUpperCase();
        const key = `${method}|${status}`;
        if (!payBreakdown[key]) {
            payBreakdown[key] = {
                method,
                status,
                amount: 0,
                symbol: String(payout.symbol || '₹'),
            };
        }
        payBreakdown[key].amount += (Number(payout.amount) || 0);
    });

    const getStatusColor = (status) => {
        if (['SUCCESS', 'PAID', 'COMPLETED'].includes(status)) return '#16a34a';
        if (['PENDING', 'PROCESSING', 'IN_PROGRESS'].includes(status)) return '#d97706';
        if (['FAILED', 'REJECTED', 'CANCELLED'].includes(status)) return '#dc2626';
        return '#4b5563';
    };

    const payList = Object.values(payBreakdown).sort((a, b) => a.method.localeCompare(b.method)).map((item) => {
        const color = getStatusColor(item.status);
        return `
        <li class="breakdown-item">
            <div class="payout-left">
                <span class="provider-name">${escapeHtml(item.method)}</span>
                <span class="payout-status" style="--status-color:${color};--status-bg:${color}1f;--status-border:${color}66;">${item.status}</span>
            </div>
            <span class="coin-val coin-spend" style="color:${color}">-₹${(Number(item.amount) || 0).toFixed(2)}</span>
        </li>`;
    }).join('') || '<li class="breakdown-item empty-row">No payouts found</li>';

    const html = `
        <div class="user-profile-shell">
            <div class="user-profile-header">
                <img src="${escapeHtml(safePhoto)}" class="user-avatar-placeholder" alt="Profile">
                <div class="user-identity">
                    <div class="user-name">${escapeHtml(user.userName || 'Unknown User')}</div>
                    <div class="user-email">${escapeHtml(user.email || 'No email')}</div>
                    <div class="user-meta">ID: ${escapeHtml(user.userId || 'N/A')} | Referral Code: ${escapeHtml(user.referralCode || 'N/A')}</div>
                    <div class="user-state-row">
                        <span class="user-state-chip ${blocked ? 'warn' : 'ok'}">Account: ${blocked ? 'Blocked' : 'Active'}</span>
                        <span class="user-state-chip ${payoutBlocked ? 'danger' : 'ok'}">Payout: ${payoutBlocked ? 'Blocked' : 'Active'}</span>
                        <span class="user-state-chip ${accountDeleted ? 'danger' : 'ok'}">Account Deleted: ${accountDeleted ? 'True' : 'False'}</span>
                    </div>
                    ${user.adminReason ? `<div class="user-admin-reason">Reason: ${escapeHtml(user.adminReason)}</div>` : ''}
                    ${payoutBlocked && payoutBlockReason ? `<div class="user-admin-reason" style="color:#ef4444; border-left-color:#ef4444;">Payout Block Reason: ${escapeHtml(payoutBlockReason)}</div>` : ''}
                </div>
            </div>


        <div class="stats-grid">

    <!-- 💼 Wallet -->
    <div class="stat-card">
        <div class="stat-label">Wallet Balance</div>
        <div class="stat-value stat-blue">${fmt(user.coins)}</div>
    </div>

    <!-- 💰 Total Earned -->
    <div class="stat-card">
        <div class="stat-label">Total Earned</div>
        <div class="stat-value stat-green">${fmt(user.totalCoins)}</div>
    </div>

</div>


<!-- ⭐ REFERRAL ANALYTICS -->
<div class="referral-analytics-card">

    <div class="ref-header">
        👥 Referral Analytics
    </div>

    <!-- 🔹 OVERVIEW -->
    <div class="ref-overview">

        <div class="ref-overview-item">
            <div class="ref-number">${referralStats.totalCount || 0}</div>
            <div class="ref-text">Total Referrals</div>
        </div>

        <div class="ref-overview-item">
            <div class="ref-number ref-green">
                ${fmt(referralStats.totalCoins || 0)}
            </div>
            <div class="ref-text">Total Earnings</div>
        </div>

    </div>

    <!-- 🔹 LEVEL BREAKDOWN -->
    <div class="ref-level-grid">

        <div class="ref-level">
            <div class="ref-level-title">L1</div>
            <div class="ref-level-users">${referralStats.level1Count || 0} users</div>
            <div class="ref-level-coins">${fmt(referralStats.level1Coins || 0)}</div>
        </div>

        <div class="ref-level">
            <div class="ref-level-title">L2</div>
            <div class="ref-level-users">${referralStats.level2Count || 0} users</div>
            <div class="ref-level-coins">${fmt(referralStats.level2Coins || 0)}</div>
        </div>

        <div class="ref-level">
            <div class="ref-level-title">L3</div>
            <div class="ref-level-users">${referralStats.level3Count || 0} users</div>
            <div class="ref-level-coins">${fmt(referralStats.level3Coins || 0)}</div>
        </div>

    </div>

</div>

            <div class="admin-tools-card">
                <div class="tools-hero">
                    <div>
                        <div class="tools-kicker">Admin Controls</div>
                        <div class="tools-title">User Actions</div>
                        <div class="tools-description">Manage bonus, deduction, block state, and account deletion controls.</div>
                    </div>
                    <div class="tools-indicator">Live</div>
                </div>

                <div class="tools-grid">
                    <div class="tool-panel panel-bonus">
                        <div class="tool-panel-head">
                            <h4>App Bonus</h4>
                            <span class="tool-tag">Coins Credit</span>
                        </div>
                        <p class="tool-note">Enter payout amount to credit bonus instantly.</p>
                        <div class="tool-inline">
                            <input id="app-bonus-payout" type="number" step="0.01" min="0" placeholder="e.g. ₹10" />
                            <button class="tool-btn" onclick="addAppBonusFromPopup()">Add Bonus</button>
                        </div>
                    </div>

                    <div class="tool-panel panel-deduct">
                        <div class="tool-panel-head">
                            <h4>Coins Deduct</h4>
                            <span class="tool-tag warn">Direct Deduct</span>
                        </div>
                       <p class="tool-note">Direct deduct (payout x 100)</p>
                        <div class="tool-inline">
                            <input id="coins-deduct-payout" type="number" step="0.01" min="0" placeholder="e.g. ₹10" />
                            <button class="tool-btn warn" onclick="deductCoinsFromPopup()">Deduct Coins</button>
                        </div>
                    </div>

                    <div class="tool-panel panel-block">
                        <div class="tool-panel-head">
                            <h4>Block Control</h4>
                            <span class="tool-tag danger">Security</span>
                        </div>
                        <p class="tool-note">Reason required when blocking an account.</p>
                        <input id="block-reason" type="text" placeholder="Reason for block (required for block)" />
                        <div class="tool-actions">
                            <button class="tool-btn danger" onclick="updateBlockFromPopup(true)">Block Account</button>
                            <button class="tool-btn success" onclick="updateBlockFromPopup(false)">Unblock Account</button>
                        </div>
                    </div>

                    <div class="tool-panel panel-payout-block">
                        <div class="tool-panel-head">
                            <h4>Withdraw Control</h4>
                            <span class="tool-tag danger">Payout Block</span>
                        </div>
                        <p class="tool-note">Reason required when blocking payouts.</p>
                        <input id="payout-block-reason" type="text" placeholder="Reason for payout block (required)" />
                        <div class="tool-actions">
                            <button class="tool-btn danger" onclick="updatePayoutBlockFromPopup(true)">Block Payout</button>
                            <button class="tool-btn success" onclick="updatePayoutBlockFromPopup(false)">Unblock Payout</button>
                        </div>
                    </div>

                    <div class="tool-panel panel-delete">
                        <div class="tool-panel-head">
                            <h4>Account Deleted</h4>
                            <span class="tool-tag warn">Flag Toggle</span>
                        </div>
                        <p class="tool-note">Reason required when setting account_deleted to true.</p>
                        <input id="account-deleted-reason" type="text" placeholder="Reason (required for true)" />
                        <div class="tool-actions">
                            <button class="tool-btn danger" onclick="toggleAccountDeletedFromPopup(true)">Set True</button>
                            <button class="tool-btn success" onclick="toggleAccountDeletedFromPopup(false)">Set False</button>
                        </div>
                        <div class="tool-actions single" style="display: flex; flex-direction: column; gap: 8px;">
                            <button class="tool-btn danger" onclick="deleteAccountDocFromPopup()">Delete Full Account Doc</button>
                            <button class="tool-btn danger" style="background-color: #991b1b; color: #fff;" onclick="wipeAllUserDataFromPopup()">💥 Wipe All User Data</button>
                        </div>
                    </div>
                </div>

                <div id="user-action-feedback" class="user-action-feedback"></div>
            </div>

            <div class="breakdown-section">
                <div class="breakdown-card">
                    <div class="breakdown-header earn-header">📅 Today's Earnings <span style="color:#16a34a;font-weight:600;">${fmt(todayTotal)}</span></div>
                    <ul class="breakdown-list">${todayEarningsList}</ul>
                </div>
                <div class="breakdown-card">
                    <div class="breakdown-header earn-header">🎁 All-Time Earnings</div>
                    <ul class="breakdown-list">${allEarnList}</ul>
                </div>
                <div class="breakdown-card">
                    <div class="breakdown-header payout-header">💸 Payout History</div>
                    <ul class="breakdown-list">${payList}</ul>
                </div>
            </div>
        </div>
    `;

    const modalBody = document.getElementById('user-modal-body');
    modalBody.innerHTML = html;
}
