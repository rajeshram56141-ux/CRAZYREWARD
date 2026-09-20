// User Activity - Frontend Logic

let currentUserId = null;
let currentLookupType = 'userId';
let currentApp = '';
let currentUserData = null;
let referralLevelData = []; // Store referral data for level filtering

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

function formatCoins(value) {
    return new Intl.NumberFormat('en-IN', {
        minimumFractionDigits: 0,
        maximumFractionDigits: 0,
    }).format(Number(value) || 0);
}

function formatDate(value) {
    if (!value) return 'N/A';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return 'N/A';
    return date.toLocaleString('en-IN', {
        timeZone: 'Asia/Kolkata',
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
    });
}

function formatShortDate(value) {
    if (!value) return 'N/A';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return 'N/A';
    return date.toLocaleDateString('en-IN', {
        timeZone: 'Asia/Kolkata',
        day: '2-digit',
        month: 'short',
        year: 'numeric',
    });
}

function formatIstForInput(rawDate) {
    if (!rawDate) return '';
    const date = new Date(rawDate);
    if (Number.isNaN(date.getTime())) return '';
    const istMs = date.getTime() + (5.5 * 60 * 60 * 1000);
    return new Date(istMs).toISOString().slice(0, 16);
}

function isToday(value) {
    if (!value) return false;
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return false;
    const now = new Date();
    return date.getDate() === now.getDate() &&
        date.getMonth() === now.getMonth() &&
        date.getFullYear() === now.getFullYear();
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

// User Details fields configuration
const USER_DETAILS_FIELDS = [
    { key: 'accountDeleted', label: 'Account Deleted', editable: true, type: 'boolean' },
    { key: 'blocked', label: 'Blocked', editable: true, type: 'boolean' },
    { key: 'coins', label: 'Coins', editable: true, type: 'number' },
    { key: 'gems', label: 'Gems', editable: true, type: 'number' },
    { key: 'country', label: 'Country', editable: true, type: 'text' },
    { key: 'deviceId', label: 'Device ID', editable: false, type: 'text' },
    { key: 'physicalDeviceId', label: 'Physical Device ID', editable: false, type: 'text' },
    { key: 'isRooted', label: 'Is Rooted', editable: false, type: 'boolean' },
    { key: 'isEmulator', label: 'Is Emulator', editable: false, type: 'boolean' },
    { key: 'isVpnActive', label: 'VPN Active', editable: false, type: 'boolean' },
    { key: 'isDeveloperOptions', label: 'Dev Options', editable: false, type: 'boolean' },
    { key: 'isMockLocation', label: 'Mock Location', editable: false, type: 'boolean' },
    { key: 'email', label: 'Email', editable: true, type: 'text' },
    { key: 'firstLogin', label: 'First Login', editable: false, type: 'datetime' },
    { key: 'gaid', label: 'GAID', editable: false, type: 'text' },
    { key: 'ipAddress', label: 'IP Address', editable: false, type: 'text' },
    { key: 'isGuest', label: 'Is Guest', editable: true, type: 'boolean' },
    { key: 'lastLogin', label: 'Last Login', editable: false, type: 'datetime' },
    { key: 'mobileNo', label: 'Mobile No', editable: true, type: 'text' },
    { key: 'name', label: 'Name', editable: true, type: 'text' },
    { key: 'photoUrl', label: 'Photo URL', editable: true, type: 'text' },
    { key: 'referralCode', label: 'Referral Code', editable: false, type: 'text' },
    { key: 'socialFollowed', label: 'Social Followed', editable: false, type: 'number' },
    { key: 'source', label: 'Source', editable: true, type: 'text' },
    { key: 'streak', label: 'Streak', editable: true, type: 'number' },
    { key: 'streakClaimed', label: 'Streak Claimed', editable: true, type: 'boolean' },
    { key: 'isSuperOfferUnlocked', label: 'Super Offer Unlocked (isOfferUnlocked)', editable: true, type: 'boolean' },
    { key: 'superOfferAssignType', label: 'Super Offer Assigned Mode', editable: true, type: 'text' },
    { key: 'gameDailyLimit', label: 'Game Daily Limit', editable: true, type: 'number' },
    { key: 'gameClaimsToday', label: 'Game Claims Today', editable: true, type: 'number' },
    { key: 'superOfferLimit', label: 'Super Offer Unlock Limit', editable: true, type: 'number' },
    { key: 'superOfferGameInstallTriggerAt', label: 'Game Install Task Claim #', editable: true, type: 'number' },
    { key: 'superOfferClaimsToday', label: 'Super Offer Claims Today', editable: true, type: 'number' },
    { key: 'superOfferAssignedAt', label: 'Super Offer Assigned Date', editable: true, type: 'datetime' },
    { key: 'battleInstallTaskNumber', label: 'Battle Install Task Target Count', editable: true, type: 'number' },
    { key: 'battleInstallTaskCompletedToday', label: 'Battle Install Task Completed Today', editable: true, type: 'boolean' },
    { key: 'battleInstallTaskAssignedDate', label: 'Battle Install Task Assigned Date', editable: true, type: 'datetime' },
    { key: 'freeBattlesJoinedToday', label: 'Free Battles Joined Today', editable: true, type: 'number' },
    { key: 'battleDailyLimit', label: 'Battle Daily Limit', editable: true, type: 'number' },
    { key: 'totalCoins', label: 'Total Coins', editable: true, type: 'number' },
    { key: 'userId', label: 'User ID', editable: false, type: 'text' },
];

// Render user details table
function renderUserDetailsTable(userData) {
    const tbody = document.getElementById('ua-user-details-tbody');
    if (!tbody || !userData) return;

    tbody.innerHTML = USER_DETAILS_FIELDS.map(field => {
        let value = userData[field.key];
        if ((value === undefined || value === null || value === '') && field.key === 'name') {
            value = userData.displayName || userData.userName || '';
        }
        if ((value === undefined || value === null || value === '') && field.key === 'blocked') {
            value = userData.isBlocked ?? false;
        }
        const displayValue = formatFieldValue(value, field.type, field.key);

        if (field.editable) {
            return `
                <tr>
                    <td class="ua-detail-label">${field.label}</td>
                    <td class="ua-detail-value">
                        ${getEditInput(field, value)}
                    </td>
                </tr>`;
        } else {
            return `
                <tr>
                    <td class="ua-detail-label">${field.label}</td>
                    <td class="ua-detail-value">${displayValue}</td>
                </tr>`;
        }
    }).join('');
}

// Get edit input based on field type
function getEditInput(field, value) {
    switch (field.type) {
        case 'boolean':
            const boolStr = (value === true || value === 'true') ? 'true' : 'false';
            return `
                <select class="ua-edit-input" data-field="${field.key}" data-original="${boolStr}">
                    <option value="true" ${boolStr === 'true' ? 'selected' : ''}>True</option>
                    <option value="false" ${boolStr === 'false' ? 'selected' : ''}>False</option>
                </select>`;
        case 'number':
            const numVal = value ?? 0;
            return `<input type="number" class="ua-edit-input" data-field="${field.key}" data-original="${numVal}" value="${numVal}">`;
        case 'datetime':
            const dateVal = value ? new Date(value).toISOString().slice(0, 16) : '';
            return `<input type="datetime-local" class="ua-edit-input" data-field="${field.key}" data-original="${dateVal}" value="${dateVal}">`;
        default:
            const textVal = value ?? '';
            return `<input type="text" class="ua-edit-input" data-field="${field.key}" data-original="${textVal}" value="${textVal}">`;
    }
}

// Format field value for display
function formatFieldValue(value, type, key = '') {
    if (value === undefined || value === null || value === '') return '-';

    if (key === 'isRooted') {
        return value ? '<span style="color:#ef4444; font-weight:bold;">⚠️ Rooted</span>' : '<span style="color:#16a34a; font-weight:bold;">✅ Clean (Not Rooted)</span>';
    }
    if (key === 'isEmulator') {
        return value ? '<span style="color:#ea580c; font-weight:bold;">⚠️ Emulator</span>' : '<span style="color:#16a34a; font-weight:bold;">📱 Real Device</span>';
    }
    if (key === 'isVpnActive') {
        return value ? '<span style="color:#ef4444; font-weight:bold;">⚠️ VPN Active</span>' : '<span style="color:#16a34a; font-weight:bold;">✅ Direct IP</span>';
    }
    if (key === 'isDeveloperOptions') {
        return value ? '<span style="color:#ea580c; font-weight:bold;">⚠️ Enabled</span>' : '<span style="color:#16a34a; font-weight:bold;">✅ Disabled</span>';
    }
    if (key === 'isMockLocation') {
        return value ? '<span style="color:#ef4444; font-weight:bold;">⚠️ Mocked</span>' : '<span style="color:#16a34a; font-weight:bold;">✅ Real GPS</span>';
    }

    switch (type) {
        case 'boolean':
            return value ? 'True' : 'False';
        case 'number':
            return Number(value).toLocaleString('en-IN');
        case 'datetime':
            return formatDate(value);
        default:
            return escapeHtml(String(value));
    }
}

// Save user details
async function saveUserDetails() {
    currentApp = String(document.getElementById('appSelect')?.value || currentApp || '').trim();
    const effectiveUserId = currentUserData?.user?.userId || currentUserId;
    if (!currentApp || !effectiveUserId) {
        showAlert('No user selected');
        return;
    }

    const updates = {};
    const inputs = document.querySelectorAll('.ua-edit-input');

    inputs.forEach(input => {
        const field = input.dataset.field;
        if (!field) return;

        let value = input.value;
        const orig = input.dataset.original;

        // Skip fields that haven't been modified by admin (prevents stale balance overwrite)
        if (orig !== undefined && String(value).trim() === String(orig).trim()) {
            return;
        }

        const fieldConfig = USER_DETAILS_FIELDS.find(f => f.key === field);
        const type = fieldConfig ? fieldConfig.type : (input.type === 'number' ? 'number' : input.type === 'datetime-local' ? 'datetime' : 'text');

        if (fieldConfig && !fieldConfig.editable) return;

        if (type === 'boolean') {
            value = (value === 'true' || value === true);
        } else if (type === 'number') {
            value = value !== '' ? Number(value) : 0;
            if (isNaN(value)) value = 0;
        } else if (type === 'datetime') {
            if (value) {
                try {
                    const dateObj = new Date(value.includes('+') || value.includes('Z') ? value : value + ':00+05:30');
                    if (!isNaN(dateObj.getTime())) {
                        value = dateObj.toISOString();
                    } else {
                        value = null;
                    }
                } catch (e) {
                    value = null;
                }
            } else {
                value = null;
            }
        }

        updates[field] = value;
    });

    showLoading(true);

    try {
        const res = await fetch('/api/update-user-data', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                app: currentApp,
                userId: effectiveUserId,
                updates
            })
        });

        const data = await res.json();

        if (data.success) {
            showAlert('User details saved successfully');
            if (currentUserData?.user?.userId) {
                openUserDetail(currentUserData.user.userId, 'userId');
            } else {
                openUserDetail(effectiveUserId, currentLookupType);
            }
        } else {
            showAlert('Error: ' + (data.message || 'Failed to save'));
        }
    } catch (err) {
        console.error('Error saving user details:', err);
        showAlert('Error saving user details: ' + (err.message || 'Server error'));
    } finally {
        showLoading(false);
    }
}

// Initialize page
async function initUserActivity() {
    currentApp = String(document.getElementById('appSelect')?.value || '').trim();
    if (!currentApp) return;

    if (typeof fetchUserDirectory === 'function') {
        fetchUserDirectory(true);
    }

    document.getElementById('appSelect')?.addEventListener('change', async () => {
        currentApp = String(document.getElementById('appSelect')?.value || '').trim();
        showListView();
        if (typeof fetchUserDirectory === 'function') {
            fetchUserDirectory(true);
        }
    });
}

function showListView() {
    document.getElementById('user-list-view').style.display = 'block';
    document.getElementById('user-detail-view').style.display = 'none';
    currentUserId = null;
    currentUserData = null;
}

function showDetailView() {
    document.getElementById('user-list-view').style.display = 'none';
    document.getElementById('user-detail-view').style.display = 'block';
}

function goBackToList() {
    showListView();
    if (typeof fetchUserDirectory === 'function') {
        fetchUserDirectory(false);
    }
}

function refreshUserDetail() {
    if (!currentUserId) {
        showAlert('No user selected');
        return;
    }
    openUserDetail(currentUserId, currentLookupType);
}

async function searchUserDirectly() {
    const searchInput = document.getElementById('ua-header-search-input');
    const input = String(searchInput?.value || '').trim();
    if (!input) {
        showAlert('Please enter a User ID, Email, or Referral Code');
        return;
    }

    const lookupType = input.includes('@') ? 'email' : 'userId';
    await openUserDetail(input, lookupType);
}

async function openUserDetail(input, lookupType) {
    currentUserId = input;
    currentLookupType = lookupType || (input.includes('@') ? 'email' : 'userId');
    currentApp = String(document.getElementById('appSelect')?.value || '').trim();

    if (!input) {
        showAlert('Invalid user');
        return;
    }

    showLoading(true);
    showDetailView();

    try {
        const url = `/get-user-data?app=${encodeURIComponent(currentApp)}&${currentLookupType === 'email' ? 'email' : 'userId'}=${encodeURIComponent(input)}`;
        const res = await fetch(url);
        const json = await res.json();

        if (!res.ok || !json.success) {
            throw new Error(json.message || 'Failed to load user data');
        }

        currentUserData = json;
        currentUserId = json.user?.userId || input;

        // Sync header search box
        const searchInput = document.getElementById('ua-header-search-input');
        if (searchInput) {
            searchInput.value = json.user?.userId || input;
        }

        renderUserDetail(json);
    } catch (err) {
        console.error('Failed to load user data:', err);
        showAlert(err.message || 'Failed to load user data');
        if (!currentUserData) {
            showListView();
        }
    } finally {
        showLoading(false);
    }
}

function renderUserDetail(data) {
    const {
        user = {},
        referralStats = {},
        payoutHistory = [],
        todayEarnings = {},
        allEarnings = [],
        dailyTaskHistory = [],
        taskHistory = [],
        gameHistory = [],
        rewardHistory = []
    } = data || {};
    const conversionRate = data.conversionRate || 100;
    const fmt = (coins) => formatCurrency((Number(coins) || 0) / conversionRate);

    // Profile header
    document.getElementById('ua-user-avatar').src = user.photoUrl || 'https://via.placeholder.com/80?text=User';
    document.getElementById('ua-user-name').textContent = user.name || user.displayName || user.userName || 'User';
    document.getElementById('ua-user-email').textContent = user.email || 'No email';
    document.getElementById('ua-user-id').textContent = user.userId || '-';
    document.getElementById('ua-referral-code').textContent = user.referralCode || '-';

    // Status chips
    const statusChip = document.getElementById('ua-status-chip');
    if (user.blocked || user.isBlocked) {
        statusChip.textContent = 'Blocked';
        statusChip.className = 'ua-status-chip danger';
    } else {
        statusChip.textContent = 'Active';
        statusChip.className = 'ua-status-chip ok';
    }

    const deletedChip = document.getElementById('ua-deleted-chip');
    if (user.accountDeleted) {
        deletedChip.textContent = 'Account Deleted: True';
        deletedChip.className = 'ua-status-chip danger';
    } else {
        deletedChip.textContent = 'Account Deleted: False';
        deletedChip.className = 'ua-status-chip ok';
    }



    // Overview tab stats
    document.getElementById('ua-wallet-balance').textContent = formatCoins(user.coins);
    document.getElementById('ua-total-earned').textContent = formatCoins(user.totalCoins);
    document.getElementById('ua-total-referrals').textContent = referralStats.totalCount || 0;

    // Profile info
    document.getElementById('ua-profile-name').textContent = user.name || user.displayName || user.userName || '-';
    document.getElementById('ua-profile-email').textContent = user.email || '-';
    document.getElementById('ua-profile-userid').textContent = user.userId || '-';
    document.getElementById('ua-profile-referral').textContent = user.referralCode || '-';

    // Render user details table
    renderUserDetailsTable(user);

    // ========== TASKS TAB ==========
    const assignTypeEl = document.getElementById('ua-task-assign-type');
    if (assignTypeEl) {
        assignTypeEl.value = user.superOfferAssignType === 'daily' ? 'daily' : 'hours';
    }
    // Game Play Limit & Progress
    const gameLimitEl = document.getElementById('ua-task-game-limit');
    if (gameLimitEl) {
        gameLimitEl.value = Number(user.gameDailyLimit) || 10;
    }
    const gameClaimsInputEl = document.getElementById('ua-game-claims-today-input');
    const gameTotalLimitSpan = document.getElementById('ua-game-total-limit');
    const gameClaimsTodayCalculated = Array.isArray(rewardHistory)
        ? rewardHistory.filter(r => {
            const p = String(r.provider || '').toLowerCase();
            return (p.includes('game gems') || p.includes('app install gems')) && isToday(r.timestamp);
        }).length
        : 0;
    const finalGameClaimsToday = user.gameClaimsToday !== undefined && user.gameClaimsToday !== null ? Number(user.gameClaimsToday) : gameClaimsTodayCalculated;

    if (gameClaimsInputEl) {
        gameClaimsInputEl.value = finalGameClaimsToday;
    }
    if (gameTotalLimitSpan) {
        gameTotalLimitSpan.textContent = Number(user.gameDailyLimit) || 10;
    }

    const gameTriggerEl = document.getElementById('ua-task-game-trigger');
    if (gameTriggerEl) {
        gameTriggerEl.value = user.superOfferGameInstallTriggerAt !== undefined && user.superOfferGameInstallTriggerAt !== null
            ? Number(user.superOfferGameInstallTriggerAt)
            : 2;
    }

    // Super Offer Unlock Limit & Progress
    const limitLabelEl = document.getElementById('ua-task-limit-label');
    const limitHelpEl = document.getElementById('ua-task-limit-help');
    const limitEl = document.getElementById('ua-task-limit');
    const totalLimitSpan = document.getElementById('ua-task-total-limit');
    const isHoursAssignType = (user.superOfferAssignType || 'hours') !== 'daily';

    function updateSuperOfferLimitDisplay(isHours) {
        const gapVal = user.superOfferGapMinutes !== undefined && user.superOfferGapMinutes !== null ? Number(user.superOfferGapMinutes) : 60;
        if (limitLabelEl) {
            limitLabelEl.textContent = isHours ? 'Super Offer Cooldown Gap (Minutes)' : 'Super Offer Unlock Limit (Daily Limit)';
        }
        if (limitHelpEl) {
            limitHelpEl.textContent = isHours
                ? 'Cooldown time in minutes required between Super Offer unlocks (e.g. 10 = 10 mins, 60 = 1 hr)'
                : 'Max times user can spend gems to unlock Super Offer per day';
        }
        if (limitEl) {
            limitEl.disabled = false;
            if (isHours) {
                limitEl.dataset.field = 'superOfferGapMinutes';
                limitEl.value = gapVal;
                limitEl.placeholder = 'e.g. 60';
            } else {
                limitEl.dataset.field = 'superOfferLimit';
                limitEl.value = Number(user.superOfferLimit) || 1;
                limitEl.placeholder = 'e.g. 10';
            }
        }
        if (totalLimitSpan) {
            if (isHours) {
                const hrs = Math.floor(gapVal / 60);
                const mins = gapVal % 60;
                const hrsText = hrs > 0 ? `${hrs}h${mins > 0 ? ` ${mins}m` : ''}` : `${mins}m`;
                totalLimitSpan.textContent = `${gapVal} Mins (${hrsText} Gap)`;
            } else {
                totalLimitSpan.textContent = Number(user.superOfferLimit) || 1;
            }
        }
    }

    updateSuperOfferLimitDisplay(isHoursAssignType);

    if (assignTypeEl) {
        assignTypeEl.onchange = function () {
            updateSuperOfferLimitDisplay(this.value !== 'daily');
        };
    }

    const claimsInputEl = document.getElementById('ua-task-claims-today-input');
    const superOfferClaimsTodayCalculated = Array.isArray(rewardHistory)
        ? rewardHistory.filter(r => String(r.provider || '').toLowerCase().includes('super offer') && isToday(r.timestamp)).length
        : 0;
    const finalSuperOfferClaimsToday = user.superOfferClaimsToday !== undefined && user.superOfferClaimsToday !== null ? Number(user.superOfferClaimsToday) : superOfferClaimsTodayCalculated;

    if (claimsInputEl) {
        claimsInputEl.value = finalSuperOfferClaimsToday;
    }

    const assignedAtInputEl = document.getElementById('ua-task-assigned-at-input');
    if (assignedAtInputEl) {
        const rawDate = user.superOfferAssignedAt || user.updatedAt || user.lastActiveAt || user.createdAt;
        assignedAtInputEl.value = formatIstForInput(rawDate);
    }

    const isUnlockedEl = document.getElementById('ua-task-is-unlocked');
    if (isUnlockedEl) {
        isUnlockedEl.value = user.isSuperOfferUnlocked === true ? 'true' : 'false';
    }

    const gameAssignedAtInputEl = document.getElementById('ua-task-game-assigned-at-input');
    if (gameAssignedAtInputEl) {
        const rawDate = user.gameAssignedAt || user.createdAt;
        gameAssignedAtInputEl.value = formatIstForInput(rawDate);
    }

    // Populate Battle Install Task inputs
    const battleLimitEl = document.getElementById('ua-task-battle-limit');
    if (battleLimitEl) {
        battleLimitEl.value = Number(user.battleInstallTaskNumber) || 0;
    }
    const battleCompletedTodayEl = document.getElementById('ua-task-battle-completed-today');
    if (battleCompletedTodayEl) {
        battleCompletedTodayEl.value = user.battleInstallTaskCompletedToday ? 'true' : 'false';
    }
    const battleTotalLimitEl = document.getElementById('ua-task-battle-total-limit');
    if (battleTotalLimitEl) {
        battleTotalLimitEl.textContent = Number(user.battleInstallTaskNumber) || 0;
    }
    const battleAssignedAtEl = document.getElementById('ua-task-battle-assigned-at-input');
    if (battleAssignedAtEl) {
        const rawDate = user.battleInstallTaskAssignedDate || user.createdAt;
        battleAssignedAtEl.value = formatIstForInput(rawDate);
    }
    const freeJoinedCountEl = document.getElementById('ua-task-free-joined-count');
    if (freeJoinedCountEl) {
        freeJoinedCountEl.value = Number(user.freeBattlesJoinedToday) || 0;
    }
    const battleDailyLimitEl = document.getElementById('ua-task-battle-daily-limit');
    if (battleDailyLimitEl) {
        battleDailyLimitEl.value = Number(user.battleDailyLimit) || 0;
    }

    const superOfferAssignedTodayEl = document.getElementById('ua-task-super-offer-assigned-today');
    if (superOfferAssignedTodayEl) {
        const todayStr = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
        const isAssigned = (user.superOfferAssignedDateStr === todayStr);
        superOfferAssignedTodayEl.value = isAssigned ? 'true' : 'false';
    }

    const gameAssignedTodayEl = document.getElementById('ua-task-game-assigned-today');
    if (gameAssignedTodayEl) {
        const todayStr = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
        const isAssigned = (user.gameAssignedDateStr === todayStr);
        gameAssignedTodayEl.value = isAssigned ? 'true' : 'false';
    }

    // Render Daily Challenge Progress
    renderDailyChallengeTasks(data.dailyChallenge);

    // ========== EARNINGS TAB ==========
    // 1. Redeem & Pending Coins Summary Cards
    const successfulPayouts = (payoutHistory || []).filter(p => ['success', 'successful', 'paid', 'completed'].includes(String(p.status || '').toLowerCase()));
    const pendingPayouts = (payoutHistory || []).filter(p => ['pending', 'processing', 'in_progress'].includes(String(p.status || '').toLowerCase()));

    const totalRedeemCoins = successfulPayouts.reduce((sum, p) => sum + (Number(p.coins) || ((Number(p.amount) || 0) * conversionRate)), 0);
    const totalRedeemAmount = successfulPayouts.reduce((sum, p) => sum + (Number(p.amount) || 0), 0);

    const pendingRedeemCoins = pendingPayouts.reduce((sum, p) => sum + (Number(p.coins) || ((Number(p.amount) || 0) * conversionRate)), 0);
    const pendingRedeemAmount = pendingPayouts.reduce((sum, p) => sum + (Number(p.amount) || 0), 0);

    const userCurrentCoins = Number(user.coins) || 0;
    const userCurrentInRs = (userCurrentCoins / conversionRate);

    const elTotalRedeemCoins = document.getElementById('ua-earnings-total-redeem-coins');
    if (elTotalRedeemCoins) elTotalRedeemCoins.textContent = `${totalRedeemCoins.toLocaleString('en-IN')} Coins`;

    const elTotalRedeemAmount = document.getElementById('ua-earnings-total-redeem-amount');
    if (elTotalRedeemAmount) elTotalRedeemAmount.textContent = `≈ ${formatCurrency(totalRedeemAmount)} (Completed)`;

    const elPendingRedeemCoins = document.getElementById('ua-earnings-pending-redeem-coins');
    if (elPendingRedeemCoins) elPendingRedeemCoins.textContent = `${pendingRedeemCoins.toLocaleString('en-IN')} Coins`;

    const elPendingRedeemAmount = document.getElementById('ua-earnings-pending-redeem-amount');
    if (elPendingRedeemAmount) elPendingRedeemAmount.textContent = `In Process: ${formatCurrency(pendingRedeemAmount)}`;

    const elRemainingCoins = document.getElementById('ua-earnings-remaining-wallet-coins');
    if (elRemainingCoins) elRemainingCoins.textContent = `Available Balance: ${userCurrentCoins.toLocaleString('en-IN')} Coins (${formatCurrency(userCurrentInRs)})`;

    // 2. Today's Earnings
    const todayTotal = todayEarnings.totalCoins || 0;
    document.getElementById('ua-today-total').textContent = formatCoins(todayTotal);

    const todayItems = todayEarnings.items || [];
    const todayEarningsList = document.getElementById('ua-today-earnings-list');
    if (todayItems.length > 0) {
        todayEarningsList.innerHTML = todayItems.map(item => {
            const label = item.provider || item.taskId || item.gameId || item.type || 'Unknown';
            const gemVal = Number(item.gems) || 0;
            const coinVal = Number(item.coins) || 0;
            const isGem = item.rewardType === 'gem' || (gemVal !== 0 && coinVal === 0) || (label && label.toLowerCase().includes('gem'));
            const num = isGem ? (gemVal || coinVal) : coinVal;
            const sign = num > 0 ? '+' : num < 0 ? '-' : '';
            const isNegative = num < 0;
            const displayVal = isGem
                ? `${sign}${Math.abs(num)} Gems 💎`
                : `${sign}${formatCoins(Math.abs(num))}`;
            const valColor = isNegative 
                ? '#dc2626' 
                : isGem 
                    ? '#8b5cf6' 
                    : '#16a34a';

            const icon = isGem
                ? '<i class="fa-solid fa-gem" style="color: #8b5cf6;"></i>'
                : item.type === 'reward' ? '<i class="fa-solid fa-bullseye" style="color: #6366f1;"></i>'
                : item.type === 'daily_task' ? '<i class="fa-solid fa-calendar-check" style="color: #06b6d4;"></i>'
                : item.type === 'task' ? '<i class="fa-solid fa-circle-check" style="color: #10b981;"></i>'
                : item.type === 'game' ? '<i class="fa-solid fa-gamepad" style="color: #8b5cf6;"></i>'
                : '<i class="fa-solid fa-coins" style="color: #d97706;"></i>';

            return `
                <div class="ua-breakdown-item">
                    <div>
                        <span class="ua-breakdown-label">${icon} ${escapeHtml(label)}</span>
                        <span class="ua-breakdown-time">${formatDate(item.timestamp)}</span>
                    </div>
                    <span class="ua-breakdown-value" style="color: ${valColor}; font-weight: 700;">${displayVal}</span>
                </div>`;
        }).join('');
    } else {
        todayEarningsList.innerHTML = '<div class="ua-empty-state">No earnings today</div>';
    }

    // All-time earnings - EXPANDABLE with date-wise breakdown
    const allTimeTotal = allEarnings
        .filter(e => e.rewardType !== 'gem' && (!e.name || !e.name.toLowerCase().includes('gem')))
        .reduce((sum, e) => sum + (Number(e.coins) || 0), 0);
    document.getElementById('ua-alltime-total').textContent = formatCoins(allTimeTotal);

    // Build date-wise data for each earnings source
    const allEarningsList = document.getElementById('ua-alltime-earnings-list');
    if (allEarnings.length > 0) {
        // Get all history data grouped by source
        const sourceHistory = {};

        rewardHistory.forEach(r => {
            const key = r.provider || 'Reward';
            const gemVal = Number(r.gems) || 0;
            const coinVal = Number(r.coins) || 0;
            const isGem = r.rewardType === 'gem' || (gemVal !== 0 && coinVal === 0) || key.toLowerCase().includes('gem');
            if (!sourceHistory[key]) sourceHistory[key] = { items: [], total: 0, isGem: isGem };
            const amount = isGem ? (gemVal || coinVal) : coinVal;
            sourceHistory[key].items.push({ coins: amount, isGem: isGem, timestamp: r.timestamp });
            sourceHistory[key].total += amount;
        });

        dailyTaskHistory.forEach(t => {
            const key = t.taskId || 'Daily Task';
            if (!sourceHistory[key]) sourceHistory[key] = { items: [], total: 0, isGem: false };
            sourceHistory[key].items.push({ coins: t.coins, isGem: false, timestamp: t.timestamp });
            sourceHistory[key].total += Number(t.coins) || 0;
        });

        taskHistory.forEach(t => {
            const key = t.taskId || 'Task';
            if (!sourceHistory[key]) sourceHistory[key] = { items: [], total: 0, isGem: false };
            sourceHistory[key].items.push({ coins: t.coins, isGem: false, timestamp: t.timestamp });
            sourceHistory[key].total += Number(t.coins) || 0;
        });

        gameHistory.forEach(g => {
            const key = g.gameId || 'Game';
            if (!sourceHistory[key]) sourceHistory[key] = { items: [], total: 0, isGem: false };
            sourceHistory[key].items.push({ coins: g.coins, isGem: false, timestamp: g.timestamp });
            sourceHistory[key].total += Number(g.coins) || 0;
        });

        allEarningsList.innerHTML = Object.entries(sourceHistory).map(([source, data]) => {
            const isGem = data.isGem || source.toLowerCase().includes('gem');
            const formatSignedNumber = (val) => {
                const num = Number(val) || 0;
                const sign = num > 0 ? '+' : num < 0 ? '-' : '';
                return {
                    text: isGem ? `${sign}${Math.abs(num)} Gems 💎` : `${sign}${formatCoins(Math.abs(num))}`,
                    color: num < 0 ? '#dc2626' : isGem ? '#8b5cf6' : '#16a34a'
                };
            };

            const itemsHtml = data.items.map(item => {
                const formatted = formatSignedNumber(item.coins);
                return `
                    <div class="ua-expand-item">
                        <span class="ua-expand-date">${formatDate(item.timestamp)}</span>
                        <span class="ua-expand-coins" style="color: ${formatted.color}; font-weight: 700;">${formatted.text}</span>
                    </div>
                `;
            }).join('');

            const totalFormatted = formatSignedNumber(data.total);

            return `
                <div class="ua-expandable-item">
                    <div class="ua-expandable-header" onclick="toggleEarningsExpand(this)">
                        <span class="ua-breakdown-label">${isGem ? '💎 ' : ''}${escapeHtml(source)}</span>
                        <div>
                            <span class="ua-breakdown-value" style="color: ${totalFormatted.color}; font-weight: 700;">${totalFormatted.text}</span>
                            <span class="ua-expand-arrow">▼</span>
                        </div>
                    </div>
                    <div class="ua-expandable-content" style="display: none;">
                        ${itemsHtml}
                    </div>
                </div>`;
        }).join('');
    } else {
        allEarningsList.innerHTML = '<div class="ua-empty-state">No earnings found</div>';
    }

    // ========== REFERRALS TAB ==========
    document.getElementById('ua-ref-total').textContent = referralStats.totalCount || 0;
    document.getElementById('ua-ref-earnings').textContent = formatCoins(referralStats.totalCoins || 0);

    // Make level cards clickable
    const l1Card = document.getElementById('ua-ref-l1-users').parentElement;
    const l2Card = document.getElementById('ua-ref-l2-users').parentElement;
    const l3Card = document.getElementById('ua-ref-l3-users').parentElement;

    l1Card.style.cursor = 'pointer';
    l1Card.onclick = () => showReferralLevel(1);
    l2Card.style.cursor = 'pointer';
    l2Card.onclick = () => showReferralLevel(2);
    l3Card.style.cursor = 'pointer';
    l3Card.onclick = () => showReferralLevel(3);

    document.getElementById('ua-ref-l1-users').textContent = `${referralStats.level1Count || 0} users`;
    document.getElementById('ua-ref-l1-coins').textContent = formatCoins(referralStats.level1Coins || 0);
    document.getElementById('ua-ref-l2-users').textContent = `${referralStats.level2Count || 0} users`;
    document.getElementById('ua-ref-l2-coins').textContent = formatCoins(referralStats.level2Coins || 0);
    document.getElementById('ua-ref-l3-users').textContent = `${referralStats.level3Count || 0} users`;
    document.getElementById('ua-ref-l3-coins').textContent = formatCoins(referralStats.level3Coins || 0);

    // ========== PAYOUTS TAB ==========
    // Calculate success stats
    const successPayouts = payoutHistory.filter(p => p.status?.toLowerCase() === 'success');
    const totalSuccessAmount = successPayouts.reduce((sum, p) => sum + (Number(p.amount) || 0), 0);

    // Add payout stats
    const payoutStatsHtml = `
        <div class="ua-payout-stats">
            <div class="ua-payout-stat">
                <span class="ua-payout-stat-label">Total Payouts</span>
                <span class="ua-payout-stat-value">${payoutHistory.length}</span>
            </div>
            <div class="ua-payout-stat">
                <span class="ua-payout-stat-label">Successful</span>
                <span class="ua-payout-stat-value stat-green">${successPayouts.length}</span>
            </div>
            <div class="ua-payout-stat">
                <span class="ua-payout-stat-label">Total Withdrawn</span>
                <span class="ua-payout-stat-value stat-green">${formatCurrency(totalSuccessAmount)}</span>
            </div>
            <div class="ua-payout-stat">
                <span class="ua-payout-stat-label">Pending/Failed</span>
                <span class="ua-payout-stat-value">${payoutHistory.length - successPayouts.length}</span>
            </div>
        </div>
    `;

    const payoutsList = document.getElementById('ua-payouts-list');
    if (payoutHistory.length > 0) {
        payoutsList.innerHTML = payoutStatsHtml + `
            <table class="ua-table">
                <thead>
                    <tr>
                        <th>Date & Time</th>
                        <th>Method</th>
                        <th>Amount</th>
                        <th>Coins</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    ${payoutHistory.map(p => `
                        <tr>
                            <td>${formatDate(p.timestamp)}</td>
                            <td>${escapeHtml(p.methodName)}</td>
                            <td>${formatCurrency(p.amount)}</td>
                            <td>${(Number(p.coins) || 0).toLocaleString('en-IN')}</td>
                            <td><span class="status-badge ${getStatusClass(p.status)}">${getStatusLabel(p.status)}</span></td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>`;
    } else {
        payoutsList.innerHTML = payoutStatsHtml + '<div class="ua-empty-state">No payout records</div>';
    }

    // ========== ACTIVITY LOG TAB ==========
    const activityItems = [];

    (rewardHistory || []).forEach(r => {
        const coins = Number(r.coins) || 0;
        const gems = Number(r.gems) || 0;

        // Skip generic Super Offer coin entry if superOfferHistory already has detailed entries
        if (r.provider === 'Super Offer' && (data.superOfferHistory || []).length > 0) {
            return;
        }

        activityItems.push({
            type: gems !== 0 && coins === 0 ? 'gem' : 'reward',
            label: r.provider || 'Reward',
            coins: coins,
            gems: gems,
            rewardType: r.rewardType,
            timestamp: r.timestamp || r.createdAt,
        });
    });

    (dailyTaskHistory || []).forEach(t => {
        activityItems.push({
            type: 'daily_task',
            label: t.taskId || 'Daily Task',
            coins: Number(t.coins) || 0,
            timestamp: t.timestamp || t.createdAt,
        });
    });

    (taskHistory || []).forEach(t => {
        activityItems.push({
            type: 'task',
            label: t.taskId || 'Task',
            coins: Number(t.coins) || 0,
            timestamp: t.timestamp || t.createdAt,
        });
    });

    (gameHistory || []).forEach(g => {
        activityItems.push({
            type: 'game',
            label: g.gameId || 'Game',
            coins: Number(g.coins) || 0,
            timestamp: g.timestamp || g.createdAt,
        });
    });

    (payoutHistory || []).forEach(p => {
        const payoutAmt = Number(p.amount) || Number(p.coins) || 0;
        activityItems.push({
            type: 'payout',
            label: `${p.methodName || 'Withdrawal'} Withdrawal`,
            coins: -payoutAmt,
            coinsUsed: p.coins,
            timestamp: p.timestamp || p.createdAt,
            status: p.status,
        });
    });

    (data.superOfferHistory || []).forEach(so => {
        activityItems.push({
            type: 'super_offer',
            label: `Super Offer: ${so.appName || so.packageName || 'App'} (${so.stepName || 'Step ' + (so.stepNumber || 1)})`,
            coins: Number(so.coins) || 0,
            timestamp: so.createdAt || so.installedAt || so.timestamp,
            status: so.status,
        });
    });

    // Sort by timestamp descending
    activityItems.sort((a, b) => {
        const timeA = a.timestamp ? new Date(a.timestamp).getTime() : 0;
        const timeB = b.timestamp ? new Date(b.timestamp).getTime() : 0;
        return timeB - timeA;
    });

    const activityList = document.getElementById('ua-activity-list');
    if (activityItems.length > 0) {
        activityList.innerHTML = activityItems.map(item => {
            const isGem = item.type === 'gem' || (item.gems && item.gems !== 0 && (!item.coins || item.coins === 0));
            const icon = isGem
                ? '<i class="fa-solid fa-gem" style="color: #a855f7;"></i>'
                : item.type === 'reward' ? '<i class="fa-solid fa-bullseye" style="color: #6366f1;"></i>'
                : item.type === 'super_offer' ? '<i class="fa-solid fa-bolt" style="color: #f59e0b;"></i>'
                : item.type === 'daily_task' ? '<i class="fa-solid fa-calendar-check" style="color: #06b6d4;"></i>'
                : item.type === 'task' ? '<i class="fa-solid fa-circle-check" style="color: #10b981;"></i>'
                : item.type === 'game' ? '<i class="fa-solid fa-gamepad" style="color: #8b5cf6;"></i>'
                : item.type === 'payout' ? '<i class="fa-solid fa-money-bill-transfer" style="color: #dc2626;"></i>'
                : '<i class="fa-solid fa-coins" style="color: #d97706;"></i>';

            let valueHtml = '';
            if (isGem) {
                const gemVal = item.gems || 0;
                const valueClass = gemVal >= 0 ? 'coin-earn' : 'coin-spend';
                valueHtml = `<div class="ua-activity-coins ${valueClass}" style="color: ${gemVal >= 0 ? '#9333ea' : '#dc2626'} !important;">${gemVal >= 0 ? '+' : ''}${gemVal} Gems</div>`;
            } else {
                const valueClass = item.coins >= 0 ? 'coin-earn' : 'coin-spend';
                const coinsText = item.coins >= 0 ? `+${formatCoins(item.coins)}` : formatCoins(item.coins);
                valueHtml = `<div class="ua-activity-coins ${valueClass}">${coinsText}</div>`;
            }

            const statusHtml = item.status ? `<span class="ua-activity-status ${getStatusClass(item.status)}">${getStatusLabel(item.status)}</span>` : '';
            const coinsUsedText = item.coinsUsed ? ` (${(Number(item.coinsUsed) || 0).toLocaleString('en-IN')} coins)` : '';

            return `
                <div class="ua-activity-item">
                    <div class="ua-activity-icon ${item.type}">${icon}</div>
                    <div class="ua-activity-details">
                        <div class="ua-activity-label">${escapeHtml(item.label)}${coinsUsedText}</div>
                        <div class="ua-activity-time">${formatDate(item.timestamp)}</div>
                        ${statusHtml}
                    </div>
                    ${valueHtml}
                </div>`;
        }).join('');
    } else {
        activityList.innerHTML = '<div class="ua-empty-state">No activity records</div>';
    }
}

// Toggle earnings expandable
function toggleEarningsExpand(header) {
    const content = header.nextElementSibling;
    const arrow = header.querySelector('.ua-expand-arrow');
    if (content.style.display === 'none') {
        content.style.display = 'block';
        arrow.textContent = '▲';
    } else {
        content.style.display = 'none';
        arrow.textContent = '▼';
    }
}

// Show referral level users
async function showReferralLevel(level) {
    if (!currentApp || !currentUserId) return;

    const lookupParam = currentLookupType === 'email' ? 'email' : 'userId';
    const url = `/get-user-data?app=${encodeURIComponent(currentApp)}&${lookupParam}=${encodeURIComponent(currentUserId)}`;

    showLoading(true);

    try {
        const res = await fetch(url);
        const json = await res.json();

        if (!res.ok || !json.success) {
            throw new Error(json.message || 'Failed to load referral data');
        }

        // Show modal with level users
        showReferralLevelModal(json.referralStats?.inviteHistory || [], level);
    } catch (err) {
        showAlert(err.message || 'Failed to load referral data');
    } finally {
        showLoading(false);
    }
}

function showReferralLevelModal(inviteHistory, level) {
    const levelUsers = inviteHistory.filter(inv => Number(inv.level) === level);

    const modal = document.getElementById('alert-modal');
    const messageEl = modal?.querySelector('.alert-message');
    const okBtn = document.getElementById('alert-ok');

    if (levelUsers.length > 0) {
        messageEl.innerHTML = `
            <div style="max-height: 400px; overflow-y: auto;">
                <h4 style="margin-bottom: 12px;">L${level} Users (${levelUsers.length})</h4>
                <table style="width: 100%; border-collapse: collapse; font-size: 13px;">
                    <thead>
                        <tr style="background: #f3f4f6;">
                            <th style="padding: 8px; text-align: left;">Email</th>
                            <th style="padding: 8px; text-align: left;">Coins</th>
                            <th style="padding: 8px; text-align: left;">Date</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${levelUsers.map((inv) => `
                            <tr style="border-bottom: 1px solid #e5e7eb;">
                                <td style="padding: 8px;">${escapeHtml(inv.email || inv.referredEmail || inv.docId || inv.userId || 'N/A')}</td>
                                <td style="padding: 8px; color: #16a34a;">+${formatCoins(inv.coins || 0)}</td>
                                <td style="padding: 8px;">${formatDate(inv.firstLogin || inv.timestamp)}</td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            </div>
        `;
    } else {
        messageEl.innerHTML = `<div class="ua-empty-state">No L${level} referral users found</div>`;
    }

    if (modal) modal.style.display = 'flex';

    const closeModal = () => {
        if (modal) modal.style.display = 'none';
        okBtn?.removeEventListener('click', closeModal);
    };

    okBtn?.addEventListener('click', closeModal);
}

function switchTab(tabName) {
    document.querySelectorAll('.ua-tab').forEach(tab => {
        tab.classList.remove('active');
    });
    document.querySelector(`.ua-tab[onclick="switchTab('${tabName}')"]`)?.classList.add('active');

    document.querySelectorAll('.ua-tab-panel').forEach(panel => {
        panel.classList.remove('active');
    });
    document.getElementById(`ua-tab-${tabName}`)?.classList.add('active');

    if (tabName === 'super-offer') {
        loadUserSuperOfferData();
    }
}

let currentSuperOfferData = null;

function switchSoSubtab(tabName) {
    const tabs = ['pending', 'completed', 'timeline'];
    tabs.forEach(t => {
        const btn = document.getElementById(`so-subtab-${t}`);
        const panel = document.getElementById(`so-panel-${t}`);
        if (btn) {
            if (t === tabName) {
                btn.style.background = '#3b82f6';
                btn.style.color = '#ffffff';
            } else {
                btn.style.background = '#e2e8f0';
                btn.style.color = '#475569';
            }
        }
        if (panel) {
            panel.style.display = t === tabName ? 'block' : 'none';
        }
    });
}

function openSoStatsModal(pkgName) {
    if (!currentSuperOfferData || (!currentSuperOfferData.apps && !currentSuperOfferData.pendingApps && !currentSuperOfferData.completedApps)) return;
    const allAppsList = [
        ...(currentSuperOfferData.pendingApps || []),
        ...(currentSuperOfferData.completedApps || []),
        ...(currentSuperOfferData.apps || [])
    ];
    const app = allAppsList.find(a => a.packageName === pkgName || a.appName === pkgName);
    if (!app) return;

    const soConfig = (app.configSnapshot && Object.keys(app.configSnapshot).length > 0)
        ? app.configSnapshot
        : (currentSuperOfferData.superOfferConfig || {});
    const isVerificationOn = app.isVerificationEnabled === true || (app.configSnapshot && app.configSnapshot.verificationEnabled === true);
    const activeMethod = Number(soConfig.activeMethod || (soConfig.screenshotVerificationEnabled === false ? 3 : 4));
    const isScreenshotOn = isVerificationOn && (activeMethod === 4) && (soConfig.screenshotVerificationEnabled !== false);

    const configuredUsageSteps = Array.isArray(soConfig.usageSteps) ? soConfig.usageSteps : [];

    const installCoins = (app.steps && app.steps.install && Number(app.steps.install.coins) > 0)
        ? Number(app.steps.install.coins)
        : (Number(soConfig.reward) || 0);

    const screenshotCoins = isScreenshotOn
        ? (Number(app.steps?.screenshot?.coins) || Number(soConfig.screenshotCoins) || 0)
        : 0;

    const usageCoins = isVerificationOn
        ? configuredUsageSteps.reduce((sum, st) => sum + (Number(st.coins) || 0), 0)
        : 0;

    const totalOfferCoins = app.totalOfferCoins || (installCoins + screenshotCoins + usageCoins);

    document.getElementById('soModalAppName').innerText = app.appName || app.packageName;
    document.getElementById('soModalPkgName').innerText = app.packageName || '';

    const statusBg = app.status === 'completed' ? '#dcfce7' :
                     (app.status === 'rejected' ? '#fee2e2' :
                     (app.status === 'removed' ? '#fee2e2' :
                     (app.status === 'uninstalled' ? '#f1f5f9' : '#fef3c7')));

    const statusColor = app.status === 'completed' ? '#15803d' :
                       (app.status === 'rejected' ? '#dc2626' :
                       (app.status === 'removed' ? '#dc2626' :
                       (app.status === 'uninstalled' ? '#64748b' : '#d97706')));

    document.getElementById('soModalOverallStatus').innerHTML = `
        <div>
            <span style="font-size: 12px; color: #64748b; font-weight: 600;">Overall Status:</span>
            <span style="background: ${statusBg}; color: ${statusColor}; padding: 3px 10px; border-radius: 6px; font-size: 11px; font-weight: 800; text-transform: uppercase; margin-left: 6px;">
                ${(app.status || 'in_progress').replace('_', ' ')}
            </span>
        </div>
        <div style="text-align: right;">
            <div style="font-size: 11.5px; color: #64748b; font-weight: 700; text-transform: uppercase;">
                Total Reward: <span style="color: #0f172a; font-weight: 800; font-size: 13.5px;">🪙 ${totalOfferCoins} Coins</span>
            </div>
            <div style="font-weight: 800; color: #b45309; font-size: 14px; margin-top: 2px;">
                🪙 ${app.totalCoinsEarned || 0} Coins Earned
            </div>
        </div>
    `;

    // Render Steps
    const stepsListEl = document.getElementById('soModalStepsList');
    let stepsHtml = '';

    // Step 1: Install & Claim
    const installDone = (app.steps && app.steps.install && app.steps.install.status === 'completed') || app.status === 'completed';
    const installDate = (app.steps && app.steps.install && app.steps.install.completedAt)
        ? new Date(app.steps.install.completedAt).toLocaleString('en-IN')
        : (app.lastActivityAt ? new Date(app.lastActivityAt).toLocaleString('en-IN') : '-');
    stepsHtml += `
        <div style="padding: 12px; border-radius: 10px; border: 1.5px solid ${installDone ? '#bbf7d0' : '#e2e8f0'}; background: ${installDone ? '#f0fdf4' : '#ffffff'};">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <strong style="color: #0f172a; font-size: 13.5px;">Step 1: Install App & Initial Launch</strong>
                    <div style="font-size: 11.5px; color: #64748b; margin-top: 2px;">Reward: 🪙 ${installCoins} Coins | Completed: ${installDate}</div>
                </div>
                <span style="background: ${installDone ? '#dcfce7' : '#f1f5f9'}; color: ${installDone ? '#15803d' : '#64748b'}; padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 800;">
                    ${installDone ? '✓ COMPLETED' : 'IN PROGRESS'}
                </span>
            </div>
        </div>
    `;

    // IF Super Offer Verification is ON: Show Step 2 (Proof) & Multi-Step Usage Pipeline!
    if (isVerificationOn) {
        // Step 2: Screenshot Proof Verification (ONLY IF ENABLED IN CONFIG/SNAPSHOT)
        if (isScreenshotOn) {
            const sc = app.steps ? app.steps.screenshot : null;
            let scStatus = (sc && sc.status && sc.status !== 'not_submitted' && sc.status !== 'not_done') ? sc.status : (installDone ? 'pending_upload' : 'locked');
            if (scStatus === 'completed' && (!sc || !sc.imageUrl)) {
                scStatus = installDone ? 'pending_upload' : 'locked';
            }
            const scColor = scStatus === 'approved' || scStatus === 'completed' ? '#15803d' : (scStatus === 'rejected' ? '#dc2626' : (scStatus === 'locked' ? '#64748b' : '#d97706'));
            const scBg = scStatus === 'approved' || scStatus === 'completed' ? '#dcfce7' : (scStatus === 'rejected' ? '#fee2e2' : (scStatus === 'locked' ? '#f1f5f9' : '#fef3c7'));
            const scLabel = scStatus === 'approved' || scStatus === 'completed' ? '✓ APPROVED' : (scStatus === 'rejected' ? 'REJECTED' : (scStatus === 'pending_upload' ? 'WAITING PROOF' : (scStatus === 'locked' ? 'LOCKED' : 'UNDER REVIEW')));

            let scImgHtml = '';
            if (sc && sc.imageUrl) {
                scImgHtml = `
                    <div style="margin-top: 10px;">
                        <span style="font-size: 11.5px; color: #64748b; font-weight: 600;">Uploaded Proof Screenshot:</span><br>
                        <img src="${sc.imageUrl}" style="width: 80px; height: 80px; object-fit: cover; border-radius: 8px; border: 1.5px solid #cbd5e1; margin-top: 4px; cursor: pointer;" onclick="window.open('${sc.imageUrl}', '_blank')">
                    </div>
                `;
            }

            stepsHtml += `
                <div style="padding: 12px; border-radius: 10px; border: 1.5px solid ${scStatus === 'approved' || scStatus === 'completed' ? '#bbf7d0' : (scStatus === 'rejected' ? '#fca5a5' : '#e2e8f0')}; background: ${scStatus === 'approved' || scStatus === 'completed' ? '#f0fdf4' : (scStatus === 'rejected' ? '#fef2f2' : '#ffffff')}; margin-top: 10px;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <div>
                            <strong style="color: #0f172a; font-size: 13.5px;">Step 2: Screenshot Proof Verification</strong>
                            <div style="font-size: 11.5px; color: #64748b; margin-top: 2px;">Reward: 🪙 ${screenshotCoins} Coins</div>
                            ${sc && sc.rejectionReason ? `<div style="font-size: 11.5px; color: #dc2626; margin-top: 2px;">Rejection Reason: ${sc.rejectionReason}</div>` : ''}
                        </div>
                        <span style="background: ${scBg}; color: ${scColor}; padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 800; text-transform: uppercase;">
                            ${scLabel}
                        </span>
                    </div>
                    ${scImgHtml}
                </div>
            `;
        }

        let previousUsageDone = installDone;
        configuredUsageSteps.forEach((st, idx) => {
            const stepNum = isScreenshotOn ? (idx + 3) : (idx + 2);
            const userHistoryStep = (currentSuperOfferData.history || []).find(h => {
                const isSameApp = (h.packageName === app.packageName || h.appName === app.appName);
                if (!isSameApp) return false;

                // Match by exact stepName first if both present
                if (h.stepName && st.name) {
                    return h.stepName.trim().toLowerCase() === st.name.trim().toLowerCase();
                }
                // Fallback to stepNumber
                return h.stepNumber === stepNum;
            });

            const isStepDone = userHistoryStep && (userHistoryStep.status === 'completed' || userHistoryStep.status === 'approved');
            const isStepSkipped = userHistoryStep && userHistoryStep.status === 'skipped';
            const isStepInProgress = userHistoryStep && userHistoryStep.status === 'in_progress';
            const isStepPending = !isStepDone && !isStepSkipped && !isStepInProgress && previousUsageDone;
            const isStepLocked = !isStepDone && !isStepSkipped && !isStepInProgress && !previousUsageDone;

            const stColor = isStepDone ? '#15803d' : (isStepSkipped ? '#b91c1c' : (isStepInProgress ? '#d97706' : (isStepPending ? '#d97706' : '#64748b')));
            const stBg = isStepDone ? '#dcfce7' : (isStepSkipped ? '#fee2e2' : (isStepInProgress ? '#fef3c7' : (isStepPending ? '#fef3c7' : '#f1f5f9')));
            const stLabel = isStepDone ? '✓ COMPLETED' : (isStepSkipped ? 'SKIPPED (0 🪙)' : (isStepInProgress ? 'IN PROGRESS' : (isStepPending ? 'PENDING' : 'LOCKED')));
            const stBorder = isStepDone ? '#bbf7d0' : (isStepSkipped ? '#fca5a5' : (isStepPending ? '#fde68a' : '#e2e8f0'));
            const stCardBg = isStepDone ? '#f0fdf4' : (isStepSkipped ? '#fef2f2' : (isStepPending ? '#fffbeb' : '#ffffff'));

            previousUsageDone = isStepDone || isStepSkipped;

            const cooldownGapSec = st.cooldownSeconds !== undefined ? st.cooldownSeconds : (st.hoursGap || 0);
            let cooldownText = '';
            if (cooldownGapSec > 0) {
                if (cooldownGapSec < 60) cooldownText = ` | Cooldown: ${cooldownGapSec}s`;
                else if (cooldownGapSec < 3600) cooldownText = ` | Cooldown: ${Math.round(cooldownGapSec / 60)} mins`;
                else cooldownText = ` | Cooldown: ${Math.round(cooldownGapSec / 3600)} hrs`;
            }

            const usageSec = st.usageSeconds !== undefined ? st.usageSeconds : ((st.minutes || 5) * 60);
            const usageText = usageSec < 60 ? `${usageSec}s` : `${Math.round(usageSec / 60)} Mins`;

            stepsHtml += `
                <div style="padding: 12px; border-radius: 10px; border: 1.5px solid ${stBorder}; background: ${stCardBg}; margin-top: 10px;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <div>
                            <strong style="color: #0f172a; font-size: 13.5px;">Step ${stepNum}: ${st.name || `Usage Step ${idx + 1}`}</strong>
                            <div style="font-size: 11.5px; color: #64748b; margin-top: 2px;">Target: ${usageText} Active Usage | Reward: 🪙 ${st.coins || 0} Coins${cooldownText}</div>
                        </div>
                        <span style="background: ${stBg}; color: ${stColor}; padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 800;">
                            ${stLabel}
                        </span>
                    </div>
                </div>
            `;
        });
    }

    stepsListEl.innerHTML = stepsHtml;

    const modal = document.getElementById('soStatsModal');
    if (modal) modal.style.display = 'flex';
}

function closeSoStatsModal() {
    const modal = document.getElementById('soStatsModal');
    if (modal) modal.style.display = 'none';
}

async function deleteSoApp(packageName) {
    if (!currentUserId || !packageName) return;
    if (!confirm(`Are you sure you want to delete all Super Offer history for "${packageName}"?`)) return;

    try {
        const res = await fetch('/admin/user-super-offer-history/delete-app', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ userId: currentUserId, packageName })
        });
        const json = await res.json();
        if (json.success) {
            alert(json.message || 'Deleted successfully');
            loadUserSuperOfferData();
        } else {
            alert(json.message || 'Failed to delete offer history');
        }
    } catch (err) {
        alert('Server error deleting offer history');
    }
}

async function deleteSoHistoryItem(id) {
    if (!id) return;
    if (!confirm('Are you sure you want to delete this specific activity history record?')) return;

    try {
        const res = await fetch(`/admin/user-super-offer-history/delete/${id}`, {
            method: 'POST'
        });
        const json = await res.json();
        if (json.success) {
            loadUserSuperOfferData();
        } else {
            alert(json.message || 'Failed to delete record');
        }
    } catch (err) {
        alert('Server error deleting record');
    }
}

async function loadUserSuperOfferData() {
    if (!currentUserId) return;
    const startDate = document.getElementById('ua-start-date')?.value || '';
    const endDate = document.getElementById('ua-end-date')?.value || '';
    const status = document.getElementById('ua-so-status-filter')?.value || 'all';

    let url = `/admin/user-super-offer-history/${encodeURIComponent(currentUserId)}?status=${encodeURIComponent(status)}`;
    if (startDate) url += `&start=${encodeURIComponent(startDate)}`;
    if (endDate) url += `&end=${encodeURIComponent(endDate)}`;

    const tbodyPending = document.getElementById('ua-so-pending-tbody');
    const tbodyCompleted = document.getElementById('ua-so-completed-tbody');
    const tbodyTimeline = document.getElementById('ua-so-history-tbody');

    if (tbodyPending) tbodyPending.innerHTML = '<tr><td colspan="6" style="text-align: center; color: var(--muted); padding: 24px;">Loading pending offers...</td></tr>';
    if (tbodyCompleted) tbodyCompleted.innerHTML = '<tr><td colspan="6" style="text-align: center; color: var(--muted); padding: 24px;">Loading completed offers...</td></tr>';
    if (tbodyTimeline) tbodyTimeline.innerHTML = '<tr><td colspan="9" style="text-align: center; color: var(--muted); padding: 24px;">Loading activity log...</td></tr>';

    try {
        const res = await fetch(url);
        const json = await res.json();
        if (json.success) {
            currentSuperOfferData = json;
            const s = json.summary || {};
            if (document.getElementById('ua-so-total-started')) document.getElementById('ua-so-total-started').innerText = s.totalStarted || 0;
            if (document.getElementById('ua-so-total-completed')) document.getElementById('ua-so-total-completed').innerText = s.totalCompleted || 0;
            if (document.getElementById('ua-so-total-pending')) document.getElementById('ua-so-total-pending').innerText = s.totalPending || 0;
            if (document.getElementById('ua-so-total-removed')) document.getElementById('ua-so-total-removed').innerText = s.totalRemoved || 0;
            if (document.getElementById('ua-so-total-coins')) document.getElementById('ua-so-total-coins').innerText = `🪙 ${s.totalCoinsEarned || 0} Coins`;

            const pendingApps = json.pendingApps || [];
            const completedApps = json.completedApps || [];
            const history = json.history || [];

            if (document.getElementById('so-count-pending')) document.getElementById('so-count-pending').innerText = pendingApps.length;
            if (document.getElementById('so-count-completed')) document.getElementById('so-count-completed').innerText = completedApps.length;

            // 1. Render Pending Offers Table
            if (tbodyPending) {
                if (pendingApps.length === 0) {
                    tbodyPending.innerHTML = '<tr><td colspan="6" style="text-align: center; color: var(--muted); padding: 36px;">No pending offers for this user.</td></tr>';
                } else {
                    tbodyPending.innerHTML = pendingApps.map(a => {
                        const dateStr = a.lastActivityAt ? new Date(a.lastActivityAt).toLocaleString('en-IN') : '-';
                        const statusColor = a.status === 'rejected' ? '#dc2626' : '#d97706';
                        const statusBg = a.status === 'rejected' ? '#fee2e2' : '#fef3c7';

                        return `
                            <tr style="border-bottom: 1px solid var(--border); font-size: 12.5px;">
                                <td style="padding: 10px; font-weight: 700; color: #0f172a;">${a.appName || '-'}</td>
                                <td style="padding: 10px; font-family: monospace; font-size: 11.5px; color: var(--muted);">${a.packageName || '-'}</td>
                                <td style="padding: 10px;">
                                    <span style="background: ${statusBg}; color: ${statusColor}; padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 800; text-transform: uppercase;">
                                        ${(a.status || 'pending').replace('_', ' ')}
                                    </span>
                                </td>
                                <td style="padding: 10px; font-weight: 800; color: #b45309;">
                                    🪙 ${a.totalCoinsEarned || 0}
                                    <span style="font-size: 11.5px; font-weight: 600; color: #64748b;">/ ${a.totalOfferCoins || a.totalCoinsEarned || 0}</span>
                                </td>
                                <td style="padding: 10px; color: var(--muted); font-size: 11.5px;">${dateStr}</td>
                                <td style="padding: 10px; text-align: right;">
                                    <div style="display: inline-flex; gap: 6px;">
                                        <button type="button" class="btn-primary-sm" onclick="openSoStatsModal('${a.packageName}')" style="padding: 5px 10px; font-size: 11.5px; font-weight: 700; border-radius: 6px; background: #2563eb; color: #ffffff; border: none; cursor: pointer;">
                                            🔍 View Stats
                                        </button>
                                        <button type="button" class="btn-danger-sm" onclick="deleteSoApp('${a.packageName}')" style="padding: 5px 10px; font-size: 11.5px; font-weight: 700; border-radius: 6px; background: #ef4444; color: #ffffff; border: none; cursor: pointer;">
                                            🗑️ Delete
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        `;
                    }).join('');
                }
            }

            // 2. Render Completed Offers Table
            if (tbodyCompleted) {
                if (completedApps.length === 0) {
                    tbodyCompleted.innerHTML = '<tr><td colspan="6" style="text-align: center; color: var(--muted); padding: 36px;">No completed offers for this user.</td></tr>';
                } else {
                    tbodyCompleted.innerHTML = completedApps.map(a => {
                        const dateStr = a.lastActivityAt ? new Date(a.lastActivityAt).toLocaleString('en-IN') : '-';

                        const isRemoved = a.status === 'removed';
                        const isUninstalled = a.status === 'uninstalled';
                        const statusBg = isRemoved ? '#fee2e2' : (isUninstalled ? '#f1f5f9' : '#dcfce7');
                        const statusColor = isRemoved ? '#dc2626' : (isUninstalled ? '#64748b' : '#15803d');
                        const statusText = isRemoved ? 'REMOVED' : (isUninstalled ? 'UNINSTALLED' : 'COMPLETED');

                        return `
                            <tr style="border-bottom: 1px solid var(--border); font-size: 12.5px;">
                                <td style="padding: 10px; font-weight: 700; color: #0f172a;">${a.appName || '-'}</td>
                                <td style="padding: 10px; font-family: monospace; font-size: 11.5px; color: var(--muted);">${a.packageName || '-'}</td>
                                <td style="padding: 10px;">
                                    <span style="background: ${statusBg}; color: ${statusColor}; padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 800; text-transform: uppercase;">
                                        ${statusText}
                                    </span>
                                </td>
                                <td style="padding: 10px; font-weight: 800; color: #15803d;">
                                    🪙 ${a.totalCoinsEarned || a.totalOfferCoins || 0}
                                    <span style="font-size: 11px; font-weight: 600; color: #64748b;">/ ${a.totalOfferCoins || a.totalCoinsEarned || 0}</span>
                                </td>
                                <td style="padding: 10px; color: var(--muted); font-size: 11.5px;">${dateStr}</td>
                                <td style="padding: 10px; text-align: right;">
                                    <div style="display: inline-flex; gap: 6px;">
                                        <button type="button" class="btn-primary-sm" onclick="openSoStatsModal('${a.packageName}')" style="padding: 5px 10px; font-size: 11.5px; font-weight: 700; border-radius: 6px; background: #2563eb; color: #ffffff; border: none; cursor: pointer;">
                                            🔍 View Stats
                                        </button>
                                        <button type="button" class="btn-danger-sm" onclick="deleteSoApp('${a.packageName}')" style="padding: 5px 10px; font-size: 11.5px; font-weight: 700; border-radius: 6px; background: #ef4444; color: #ffffff; border: none; cursor: pointer;">
                                            🗑️ Delete
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        `;
                    }).join('');
                }
            }

            // 3. Render Timeline Table
            if (tbodyTimeline) {
                if (history.length === 0) {
                    tbodyTimeline.innerHTML = '<tr><td colspan="9" style="text-align: center; color: var(--muted); padding: 36px;">No super offer records match this filter.</td></tr>';
                    return;
                }

                tbodyTimeline.innerHTML = history.map(h => {
                    const statusColor = (h.status === 'completed' || h.status === 'approved') ? '#15803d' :
                                        (h.status === 'rejected' || h.status === 'removed') ? '#dc2626' :
                                        (h.status === 'uninstalled') ? '#64748b' : '#d97706';

                    const statusBg = (h.status === 'completed' || h.status === 'approved') ? '#dcfce7' :
                                     (h.status === 'rejected' || h.status === 'removed') ? '#fee2e2' :
                                     (h.status === 'uninstalled') ? '#f1f5f9' : '#fef3c7';
                    const dateStr = h.createdAt ? new Date(h.createdAt).toLocaleString('en-IN') : '-';

                    return `
                        <tr style="border-bottom: 1px solid var(--border); font-size: 12.5px;">
                            <td style="padding: 10px; font-weight: 700;">${h.appName || '-'}</td>
                            <td style="padding: 10px; font-family: monospace; font-size: 11.5px; color: var(--muted);">${h.packageName || '-'}</td>
                            <td style="padding: 10px;">
                                <strong>${h.stepName || 'Step ' + (h.stepNumber || 1)}</strong>
                                <span style="font-size: 11px; color: var(--muted); display: block;">Type: ${h.stepType || 'install'}</span>
                            </td>
                            <td style="padding: 10px;">
                                <span style="background: ${statusBg}; color: ${statusColor}; padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: 800; text-transform: uppercase;">
                                    ${h.status}
                                </span>
                                ${h.rejectionReason ? `<span style="display: block; font-size: 10.5px; color: #dc2626; margin-top: 2px;">${h.rejectionReason}</span>` : ''}
                            </td>
                            <td style="padding: 10px; font-weight: 800; color: #b45309;">${h.coins ? `🪙 ${h.coins}` : '-'}</td>
                            <td style="padding: 10px; color: var(--muted);">${h.usageMinutes ? `${h.usageMinutes} mins` : '-'}</td>
                            <td style="padding: 10px;">
                                ${h.proofImageUrl ? `<a href="${h.proofImageUrl}" target="_blank" style="color: #2563eb; font-weight: 700; text-decoration: underline;">View Proof</a>` : '-'}
                            </td>
                            <td style="padding: 10px; color: var(--muted); font-size: 11.5px;">${dateStr}</td>
                            <td style="padding: 10px; text-align: right;">
                                <button type="button" onclick="deleteSoHistoryItem('${h._id}')" style="padding: 4px 8px; font-size: 11px; font-weight: 700; border-radius: 6px; background: #fee2e2; color: #dc2626; border: 1px solid #fca5a5; cursor: pointer;">
                                    🗑️ Delete
                                </button>
                            </td>
                        </tr>
                    `;
                }).join('');
            }
        }
    } catch (err) {
        if (tbodyPending) tbodyPending.innerHTML = '<tr><td colspan="6" style="text-align: center; color: #dc2626; padding: 24px;">Failed to load Super Offer data</td></tr>';
    }
}

async function applyDateFilter() {
    if (!currentUserId) return;
    loadUserSuperOfferData();

    const startDate = document.getElementById('ua-start-date')?.value || '';
    const endDate = document.getElementById('ua-end-date')?.value || '';

    if (!startDate && !endDate) {
        // No filter, reload all data
        const url = `/get-user-data?app=${encodeURIComponent(currentApp)}&${currentLookupType === 'email' ? 'email' : 'userId'}=${encodeURIComponent(currentUserId)}`;
        loadFilteredData(url);
        return;
    }

    showLoading(true);

    try {
        let url = `/get-user-data?app=${encodeURIComponent(currentApp)}&${currentLookupType === 'email' ? 'email' : 'userId'}=${encodeURIComponent(currentUserId)}`;
        if (startDate) url += `&startDate=${encodeURIComponent(startDate)}`;
        if (endDate) url += `&endDate=${encodeURIComponent(endDate)}`;

        await loadFilteredData(url);
    } catch (err) {
        showAlert(err.message || 'Failed to load data');
    } finally {
        showLoading(false);
    }
}

async function loadFilteredData(url) {
    const res = await fetch(url);
    const json = await res.json();

    if (!res.ok || !json.success) {
        throw new Error(json.message || 'Failed to load data');
    }

    currentUserData = json;
    renderUserDetail(json);
}

function clearDateFilter() {
    document.getElementById('ua-start-date').value = '';
    document.getElementById('ua-end-date').value = '';
    applyDateFilter();
}

function showLoading(show) {
    const overlay = document.getElementById('loadingOverlay');
    if (overlay) {
        overlay.style.display = show ? 'flex' : 'none';
    }
}

function showAlert(message) {
    const modal = document.getElementById('alert-modal');
    const messageEl = modal?.querySelector('.alert-message');
    const okBtn = document.getElementById('alert-ok');

    if (messageEl) messageEl.textContent = message;
    if (modal) modal.style.display = 'flex';

    const closeModal = () => {
        if (modal) modal.style.display = 'none';
        okBtn?.removeEventListener('click', closeModal);
    };

    okBtn?.addEventListener('click', closeModal);
}

function openDirectoryUserFromRow(button) {
    const userId = button?.dataset?.userid || '';
    if (!userId) return;
    openUserDetail(userId);
}

async function handleUaPayoutBlock(block) {
    if (!currentApp || !currentUserId) {
        showAlert('No user selected');
        return;
    }

    const reasonInput = document.getElementById('ua-payout-block-reason');
    const reason = String(reasonInput?.value || '').trim();

    if (block && !reason) {
        showAlert('Reason is required when blocking payouts');
        return;
    }

    showLoading(true);

    try {
        const res = await fetch('/block-payout', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                userId: currentUserId,
                email: document.getElementById('ua-profile-email')?.textContent || '',
                selectedApp: currentApp,
                reason: reason,
                block: !!block,
            }),
        });

        const json = await res.json();
        if (!res.ok || !json.success) {
            throw new Error(json.message || 'Failed to update payout block status');
        }

        showAlert(json.message || `Payouts ${block ? 'blocked' : 'unblocked'} successfully`);
        if (reasonInput && !block) reasonInput.value = '';

        const url = `/get-user-data?app=${encodeURIComponent(currentApp)}&userId=${encodeURIComponent(currentUserId)}`;
        await loadFilteredData(url);
    } catch (err) {
        showAlert(err.message || 'Failed to update payout block status');
    } finally {
        showLoading(false);
    }
}

function openDirectoryUserFromRow(button) {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    if (!button) return;

    const rawEmail = decodeURIComponent(String(button.dataset.email || '')).trim();
    const rawUserId = decodeURIComponent(String(button.dataset.userId || button.dataset.userid || '')).trim();

    const isValidEmail = rawEmail && rawEmail.includes('@') && !rawEmail.toLowerCase().includes('no email');

    if (rawUserId) {
        openUserDetail(rawUserId, 'userId');
    } else if (isValidEmail) {
        openUserDetail(rawEmail, 'email');
    } else {
        showAlert('❌ User identifier not found');
    }
}

function renderDailyChallengeTasks(dailyChallenge) {
    const headerStatusEl = document.getElementById('ua-dc-header-status');
    const containerEl = document.getElementById('ua-dc-container');
    if (!containerEl) return;

    if (!dailyChallenge || !dailyChallenge.config) {
        if (headerStatusEl) headerStatusEl.innerHTML = '<span style="color: var(--muted);">Disabled</span>';
        containerEl.innerHTML = '<div style="text-align: center; color: var(--muted); padding: 16px;">Daily Challenge configuration not found or disabled.</div>';
        return;
    }

    const config = dailyChallenge.config || {};
    const todayData = dailyChallenge.today || null;
    const history = Array.isArray(dailyChallenge.history) ? dailyChallenge.history : [];
    const activeTasks = (config.tasks || []).filter(t => t.isActive !== false);
    const rewardCoins = Number(config.rewardCoins) || 500;
    const rawProgress = todayData?.taskProgress || {};

    // Count completed tasks
    let completedTasks = 0;
    const taskRowsHtml = activeTasks.map(task => {
        const currentCount = Number(rawProgress[task.taskType] || (rawProgress.get ? rawProgress.get(task.taskType) : 0)) || 0;
        const targetCount = Number(task.targetCount) || 1;
        const isTaskDone = currentCount >= targetCount;
        if (isTaskDone) completedTasks++;
        const pct = Math.min(100, Math.round((currentCount / targetCount) * 100));

        return `
            <tr>
                <td style="font-weight: 600; color: #0f172a;">
                    <div style="display: flex; align-items: center; gap: 8px;">
                        <span style="font-size: 15px;">${isTaskDone ? '✅' : '⏳'}</span>
                        <div>
                            <div>${escapeHtml(task.title || task.taskType)}</div>
                            <span style="font-size: 11px; color: var(--muted); font-weight: 500;">Type: <code>${escapeHtml(task.taskType)}</code></span>
                        </div>
                    </div>
                </td>
                <td style="text-align: center; font-weight: 700;">
                    ${currentCount} / ${targetCount}
                </td>
                <td style="width: 140px;">
                    <div style="display: flex; align-items: center; gap: 8px;">
                        <div style="flex: 1; background: #e2e8f0; height: 6px; border-radius: 3px; overflow: hidden;">
                            <div style="width: ${pct}%; background: ${isTaskDone ? '#10b981' : '#6366f1'}; height: 100%;"></div>
                        </div>
                        <span style="font-size: 11px; font-weight: 700; color: ${isTaskDone ? '#10b981' : '#6366f1'};">${pct}%</span>
                    </div>
                </td>
                <td style="text-align: center;">
                    <span class="ua-status-chip ${isTaskDone ? 'ok' : 'pending'}">${isTaskDone ? 'Completed' : 'In Progress'}</span>
                </td>
            </tr>
        `;
    }).join('');

    const isAllDone = activeTasks.length > 0 && completedTasks >= activeTasks.length;
    const isClaimed = !!todayData?.claimedReward;

    // Header status badge
    if (headerStatusEl) {
        if (isClaimed) {
            headerStatusEl.innerHTML = `<span class="ua-status-chip ok"><i class="fa-solid fa-check-double"></i> Claimed (+${rewardCoins} Coins)</span>`;
        } else if (isAllDone) {
            headerStatusEl.innerHTML = `<span class="ua-status-chip" style="background: #fef3c7; color: #d97706; border: 1px solid #fde68a;"><i class="fa-solid fa-award"></i> 100% Done (Unclaimed)</span>`;
        } else {
            headerStatusEl.innerHTML = `<span class="ua-status-chip pending">${completedTasks}/${activeTasks.length} Tasks Done</span>`;
        }
    }

    containerEl.innerHTML = `
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; margin-bottom: 16px;">
            <div style="background: #f8fafc; border: 1px solid #e2e8f0; padding: 12px; border-radius: 8px;">
                <div style="font-size: 11px; font-weight: 700; color: var(--muted); text-transform: uppercase;">Today's Date</div>
                <div style="font-size: 14px; font-weight: 800; color: #0f172a;">${escapeHtml(dailyChallenge.todayDateStr || 'Today')}</div>
            </div>
            <div style="background: #f8fafc; border: 1px solid #e2e8f0; padding: 12px; border-radius: 8px;">
                <div style="font-size: 11px; font-weight: 700; color: var(--muted); text-transform: uppercase;">Tasks Progress</div>
                <div style="font-size: 14px; font-weight: 800; color: #6366f1;">${completedTasks} of ${activeTasks.length} Completed</div>
            </div>
            <div style="background: #f8fafc; border: 1px solid #e2e8f0; padding: 12px; border-radius: 8px;">
                <div style="font-size: 11px; font-weight: 700; color: var(--muted); text-transform: uppercase;">Reward Status</div>
                <div style="font-size: 14px; font-weight: 800; color: ${isClaimed ? '#10b981' : isAllDone ? '#d97706' : '#64748B'};">
                    ${isClaimed ? `Claimed (+${rewardCoins} Coins)` : isAllDone ? 'Ready to Claim' : 'Incomplete'}
                </div>
            </div>
            <div style="background: #f8fafc; border: 1px solid #e2e8f0; padding: 12px; border-radius: 8px; display: flex; flex-direction: column; justify-content: center; align-items: flex-start; gap: 6px;">
                <div style="font-size: 11px; font-weight: 700; color: #475569; text-transform: uppercase;">Admin Actions</div>
                <div style="display: flex; gap: 6px; flex-wrap: wrap;">
                    <button onclick="markCompleteUserDailyChallenge('${escapeHtml(currentUserId)}')" class="btn btn-sm" style="font-size: 11.5px; font-weight: 700; padding: 4px 9px; border-radius: 6px; background: #10b981; color: #ffffff; border: none; cursor: pointer;">
                        <i class="fa-solid fa-bolt"></i> Mark Complete & Award Coins
                    </button>
                    <button onclick="resetUserDailyChallenge('${escapeHtml(currentUserId)}')" class="btn btn-sm" style="font-size: 11.5px; font-weight: 700; padding: 4px 9px; border-radius: 6px; background: #e11d48; color: #ffffff; border: none; cursor: pointer;">
                        <i class="fa-solid fa-rotate-left"></i> Reset
                    </button>
                </div>
            </div>
        </div>

        <div style="overflow-x: auto;">
            <table class="ua-details-table" style="margin-bottom: 0;">
                <thead>
                    <tr style="background: #f1f5f9;">
                        <th style="padding: 8px 12px; text-align: left; font-size: 11px; font-weight: 800; color: #475569; text-transform: uppercase;">Task</th>
                        <th style="padding: 8px 12px; text-align: center; font-size: 11px; font-weight: 800; color: #475569; text-transform: uppercase;">Target</th>
                        <th style="padding: 8px 12px; text-align: left; font-size: 11px; font-weight: 800; color: #475569; text-transform: uppercase;">Progress</th>
                        <th style="padding: 8px 12px; text-align: center; font-size: 11px; font-weight: 800; color: #475569; text-transform: uppercase;">Status</th>
                    </tr>
                </thead>
                <tbody>
                    ${taskRowsHtml || '<tr><td colspan="4" style="text-align: center; color: var(--muted); padding: 12px;">No active tasks</td></tr>'}
                </tbody>
            </table>
        </div>

        ${history.length > 0 ? `
            <div style="margin-top: 16px;">
                <div style="font-size: 12px; font-weight: 800; color: #475569; text-transform: uppercase; margin-bottom: 8px;">Recent Days Challenge History</div>
                <div style="display: flex; gap: 8px; flex-wrap: wrap;">
                    ${history.map(h => `
                        <div style="background: #f8fafc; border: 1px solid #e2e8f0; padding: 6px 10px; border-radius: 6px; font-size: 11px;">
                            <span style="font-weight: 700; color: #0f172a;">${escapeHtml(h.dateStr)}:</span> 
                            <span style="color: ${h.claimedReward ? '#10b981' : '#64748b'}; font-weight: 700;">${h.claimedReward ? `✓ Claimed (+${h.rewardCoinsEarned || rewardCoins})` : 'Incomplete'}</span>
                        </div>
                    `).join('')}
                </div>
            </div>
        ` : ''}
    `;
}

async function markCompleteUserDailyChallenge(userId) {
    if (!userId) return;
    if (!confirm(`Are you sure you want to mark today's Daily Challenge as 100% COMPLETED and award reward coins to User ID: ${userId}?`)) {
        return;
    }
    try {
        const response = await fetch('/admin/daily-challenge/force-complete-user', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify({ userId: userId })
        });
        const data = await response.json();
        if (data.success) {
            if (typeof toastr !== 'undefined') toastr.success(data.message);
            else alert(data.message);
            if (typeof fetchUserActivity === 'function') {
                fetchUserActivity();
            }
        } else {
            if (typeof toastr !== 'undefined') toastr.error(data.message);
            else alert(data.message);
        }
    } catch (err) {
        console.error('Error force completing daily challenge:', err);
        alert('Failed to force complete challenge: ' + err.message);
    }
}

async function resetUserDailyChallenge(userId) {
    if (!userId) return;
    if (!confirm(`Are you sure you want to reset Daily Challenge progress for User ID: ${userId}? This will reset today's tasks back to 0 so the user can play again.`)) {
        return;
    }
    try {
        const response = await fetch('/admin/daily-challenge/reset-user-progress', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify({ userId: userId })
        });
        const data = await response.json();
        if (data.success) {
            if (typeof toastr !== 'undefined') toastr.success(data.message);
            else alert(data.message);
            if (typeof fetchUserActivity === 'function') {
                fetchUserActivity();
            }
        } else {
            if (typeof toastr !== 'undefined') toastr.error(data.message);
            else alert(data.message);
        }
    } catch (err) {
        console.error('Error resetting daily challenge:', err);
        alert('Failed to reset daily challenge: ' + err.message);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    initUserActivity();
});