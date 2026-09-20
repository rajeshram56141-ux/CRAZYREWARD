function handlePayoutInlineUserSearch() {
    const inputEl = document.getElementById('payout-user-search-input');
    const query = String(inputEl?.value || '').trim();
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    if (!selectedApp) {
        if (typeof showAlert === 'function') showAlert('Please select app first');
        else alert('Please select app first');
        return;
    }

    if (!query) {
        if (typeof showAlert === 'function') showAlert('Please enter User Email, User ID, or Referral Code');
        else alert('Please enter User Email, User ID, or Referral Code');
        return;
    }

    if (typeof openUserProfile === 'function') {
        openUserProfile(query, selectedApp, 'auto');
    }
}

function escapePayoutHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function formatPayoutNumber(value, digits = 0) {
    return new Intl.NumberFormat('en-IN', {
        maximumFractionDigits: digits,
        minimumFractionDigits: digits,
    }).format(Number(value) || 0);
}

function formatPayoutDate(value) {
    if (!value) return 'N/A';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return 'N/A';
    return date.toLocaleString('en-IN');
}

function methodDataAsText(data) {
    if (!data || typeof data !== 'object') return '{}';
    try {
        return JSON.stringify(data, null, 2);
    } catch {
        return '{}';
    }
}

function setPendingCardBusy(card, isBusy) {
    if (!card) return;
    card.classList.toggle('is-processing', !!isBusy);
    const buttons = card.querySelectorAll('.pending-action-btn');
    buttons.forEach((btn) => {
        btn.disabled = !!isBusy;
    });
}

async function callHandlePayoutAction(card, action, extraPayload = {}) {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const orderId = String(card?.dataset.orderId || '').trim();
    const userId = String(card?.dataset.userId || '').trim();

    if (!selectedApp) throw new Error('Please select app first');
    if (!orderId) throw new Error('Invalid payout order id');

    const payload = {
        userId,
        orderId,
        action,
        app: selectedApp,
        ...extraPayload,
    };

    const res = await fetch('/handle-payout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
    });

    let json = {};
    try {
        json = await res.json();
    } catch (_) {
        json = {};
    }

    const message = String(json?.message || '').trim() || 'Request processed';

    if (action === 'proceed' && res.status === 202) {
        return { ok: true, pending: true, message };
    }

    if (!res.ok || json.success === false) {
        throw new Error(message);
    }

    return { ok: true, pending: false, message };
}

window.allPendingPayoutRequests = [];

async function loadPendingPayoutRequests() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const listEl = document.getElementById('pending-payout-list');
    const countEl = document.getElementById('pending-count');

    if (!selectedApp) {
        listEl.innerHTML = '<div class="pending-payout-empty">Please select app first.</div>';
        if (countEl) countEl.textContent = '0';
        return;
    }

    listEl.innerHTML = '<div class="pending-payout-empty">Loading pending payout requests...</div>';

    try {
        const res = await fetch('/pending-payout-requests', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ selectedApp }),
        });
        const json = await res.json();

        if (!res.ok || !json.success) {
            throw new Error(json.message || 'Failed to fetch pending payouts');
        }

        window.allPendingPayoutRequests = json.requests || [];
        filterPayoutsByDate();
    } catch (err) {
        console.error(err);
        listEl.innerHTML = `<div class="pending-payout-empty error">${escapePayoutHtml(err.message || 'Failed to load data')}</div>`;
        if (countEl) countEl.textContent = '0';
    }
}

function onPayoutDateRangeChange() {
    const range = document.getElementById('payout-date-range')?.value || 'all';
    const startEl = document.getElementById('payout-start-date');
    const endEl = document.getElementById('payout-end-date');

    const today = new Date().toISOString().split('T')[0];

    if (range === 'today') {
        if (startEl) { startEl.value = today; startEl.disabled = true; }
        if (endEl) { endEl.value = today; endEl.disabled = true; }
    } else if (range === 'yesterday') {
        const yDate = new Date();
        yDate.setDate(yDate.getDate() - 1);
        const yStr = yDate.toISOString().split('T')[0];
        if (startEl) { startEl.value = yStr; startEl.disabled = true; }
        if (endEl) { endEl.value = yStr; endEl.disabled = true; }
    } else if (range === 'custom') {
        if (startEl) startEl.disabled = false;
        if (endEl) endEl.disabled = false;
    } else {
        if (startEl) { startEl.value = ''; startEl.disabled = true; }
        if (endEl) { endEl.value = ''; endEl.disabled = true; }
    }

    filterPayoutsByDate();
}

function getPayoutTimestampMs(item) {
    if (!item) return 0;
    const raw = item.timestamp || item.createdAt || item.date || item.time;
    if (!raw) return 0;
    const t = new Date(raw).getTime();
    return Number.isNaN(t) ? 0 : t;
}

window.selectedPayoutMethodTab = 'all';

function renderMethodTabs(dateFilteredRequests) {
    const tabsContainer = document.getElementById('payout-method-tabs');
    if (!tabsContainer) return;

    const list = Array.isArray(dateFilteredRequests) ? dateFilteredRequests : [];
    const methodCounts = {};
    const totalCount = list.length;

    list.forEach(item => {
        const name = String(item.methodName || 'Unknown').trim();
        methodCounts[name] = (methodCounts[name] || 0) + 1;
    });

    const activeTab = window.selectedPayoutMethodTab || 'all';

    let html = `
        <button type="button" class="payout-tab-btn ${activeTab === 'all' ? 'active' : ''}" onclick="selectPayoutMethodTab('all')">
            <span>All Methods</span>
            <span class="payout-tab-count">${totalCount}</span>
        </button>
    `;

    Object.keys(methodCounts).sort().forEach(methodName => {
        const count = methodCounts[methodName];
        const isActive = activeTab.toLowerCase() === methodName.toLowerCase();
        const isUpiTab = methodName.toLowerCase().includes('upi');

        html += `
            <button type="button" class="payout-tab-btn ${isActive ? 'active' : ''}" onclick="selectPayoutMethodTab('${escapePayoutHtml(methodName)}')">
                <span>${escapePayoutHtml(methodName)}</span>
                <span class="payout-tab-count">${count}</span>
            </button>
        `;

        if (isUpiTab) {
            html += `
                <button type="button" onclick="startContinuousUpiPay()" style="background:#2563eb; color:#fff; border:none; padding:7px 14px; border-radius:30px; font-size:12.5px; font-weight:800; cursor:pointer; display:inline-flex; align-items:center; gap:6px; box-shadow:0 2px 8px rgba(37,99,235,0.25);">
                    <span>Quick Pay UPI</span>
                    <span style="background:rgba(255,255,255,0.25); padding:1px 6px; border-radius:10px; font-size:11px;">${count}</span>
                </button>
            `;
        }
    });

    tabsContainer.innerHTML = html;
}

function selectPayoutMethodTab(methodName) {
    window.selectedPayoutMethodTab = methodName || 'all';
    filterPayoutsByDate();
}

function filterPayoutsByDate() {
    const range = document.getElementById('payout-date-range')?.value || 'all';
    const startVal = document.getElementById('payout-start-date')?.value;
    const endVal = document.getElementById('payout-end-date')?.value;

    let dateFiltered = window.allPendingPayoutRequests || [];

    if (range !== 'all') {
        if (startVal) {
            const startTime = new Date(startVal + 'T00:00:00').getTime();
            dateFiltered = dateFiltered.filter(item => {
                const itemTime = getPayoutTimestampMs(item);
                return itemTime === 0 || itemTime >= startTime;
            });
        }
        if (endVal) {
            const endTime = new Date(endVal + 'T23:59:59').getTime();
            dateFiltered = dateFiltered.filter(item => {
                const itemTime = getPayoutTimestampMs(item);
                return itemTime === 0 || itemTime <= endTime;
            });
        }
    }

    renderMethodTabs(dateFiltered);

    let finalFiltered = dateFiltered;
    const activeTab = window.selectedPayoutMethodTab || 'all';
    if (activeTab !== 'all') {
        finalFiltered = dateFiltered.filter(item => {
            return String(item.methodName || '').trim().toLowerCase() === activeTab.trim().toLowerCase();
        });
    }

    renderPendingPayoutCards(finalFiltered);
    const countEl = document.getElementById('pending-count');
    if (countEl) countEl.textContent = String(finalFiltered.length);
}

function clearPayoutDateFilter() {
    const rangeEl = document.getElementById('payout-date-range');
    if (rangeEl) rangeEl.value = 'all';
    window.selectedPayoutMethodTab = 'all';
    onPayoutDateRangeChange();
}

function renderPendingPayoutCards(requests) {
    const listEl = document.getElementById('pending-payout-list');
    const rows = Array.isArray(requests) ? requests : [];

    if (!rows.length) {
        listEl.innerHTML = '<div class="pending-payout-empty">No pending payout requests found.</div>';
        return;
    }

    const cards = rows.map((item) => {
        const methodName = String(item.methodName || 'Unknown');
        const email = String(item.email || '');
        const userId = String(item.userId || '');
        const orderId = String(item.orderId || '');
        const methodDataText = methodDataAsText(item.methodData || {});

        return `
            <div class="pending-payout-card"
                data-user-id="${escapePayoutHtml(userId)}"
                data-email="${escapePayoutHtml(email)}"
                data-order-id="${escapePayoutHtml(orderId)}"
                data-amount="${Number(item.amount) || 0}"
                data-coins="${Number(item.coins) || 0}"
                data-method-name="${escapePayoutHtml(methodName)}">

                <div class="pending-payout-head">
                    <div class="pending-payout-title">Order: ${escapePayoutHtml(orderId || 'N/A')}</div>
                    <span class="pending-payout-status">PENDING</span>
                </div>

                <div class="pending-payout-grid">
                    <div class="pending-payout-item">
                        <span>Amount</span>
                        <strong>₹${formatPayoutNumber(item.amount, 2)}</strong>
                    </div>
                    <div class="pending-payout-item">
                        <span>Coins</span>
                        <strong>${formatPayoutNumber(item.coins, 0)}</strong>
                    </div>
                    <div class="pending-payout-item">
                        <span>Method</span>
                        <strong>${escapePayoutHtml(methodName)}</strong>
                    </div>
                    <div class="pending-payout-item">
                        <span>User ID</span>
                        <strong>${escapePayoutHtml(userId || 'N/A')}</strong>
                    </div>
                    <div class="pending-payout-item">
                        <span>Email</span>
                        <strong>${escapePayoutHtml(email || 'N/A')}</strong>
                    </div>
                    <div class="pending-payout-item">
                        <span>Created</span>
                        <strong>${escapePayoutHtml(formatPayoutDate(item.timestamp))}</strong>
                    </div>
                </div>

                <div class="pending-method-block">
                    <div class="pending-method-label">${escapePayoutHtml(methodName)}: {}</div>
                    <pre>${escapePayoutHtml(methodDataText)}</pre>
                </div>

                <div class="pending-payout-actions">
                    <button class="pending-action-btn info" onclick="checkPayoutUserDetails(this)">Check User Details</button>
                    <button class="pending-action-btn success" onclick="proceedPendingPayout(this)">Proceed</button>
                    <button class="pending-action-btn danger" onclick="openRejectPayoutModal(this)">Reject</button>
                    <button class="pending-action-btn delete" onclick="deletePendingPayout(this)">Delete</button>
                </div>
            </div>
        `;
    }).join('');

    listEl.innerHTML = cards;
}

function checkPayoutUserDetails(button) {
    const card = button.closest('.pending-payout-card');
    if (!card) return;

    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const email = String(card.dataset.email || '').trim();
    const userId = String(card.dataset.userId || '').trim();
    const orderId = String(card.dataset.orderId || '').trim();

    if (!selectedApp) {
        showAlert('❌ Please select app first');
        return;
    }

    if (email) {
        openUserProfile(email, selectedApp, 'auto', orderId);
        return;
    }

    if (userId) {
        openUserProfile(userId, selectedApp, 'userId', orderId);
        return;
    }

    showAlert('❌ User email/userId not found for this request');
}

let currentUpiPayoutContext = null;

function isUpiPayoutMethod(item) {
    if (!item) return false;
    const name = String(item.methodName || '').trim().toLowerCase();
    return name === 'upi' || name.includes('upi');
}

function extractUpiVpa(item) {
    if (!item) return '';
    let mData = item.methodData || {};
    if (typeof mData === 'string') {
        try { mData = JSON.parse(mData); } catch (_) {}
    }
    const possible = [
        mData.upiId, mData.upi_id, mData.vpa, mData.upi, item.upiId, item.vpa
    ];
    for (const val of possible) {
        if (val && typeof val === 'string' && val.trim()) {
            return val.trim();
        }
    }
    return '';
}

function openUpiPayoutModal(item, upiVpa) {
    const modal = document.getElementById('upi-payout-modal');
    if (!modal) return;

    document.getElementById('upi-step-select').style.display = 'block';
    document.getElementById('upi-step-manual').style.display = 'none';
    const titleEl = document.getElementById('upi-modal-title');
    if (titleEl) titleEl.textContent = `${item.methodName || 'Payout'} Process (${item.orderId || 'Order'})`;

    modal.style.display = 'flex';
}

function closeUpiPayoutModal() {
    const modal = document.getElementById('upi-payout-modal');
    if (modal) modal.style.display = 'none';
    currentUpiPayoutContext = null;
}

function handleUpiSelectMode(mode) {
    if (!currentUpiPayoutContext) return;
    const { card, item, upiVpa } = currentUpiPayoutContext;

    if (mode === 'api') {
        closeUpiPayoutModal();
        showConfirm(`Process order ${item.orderId || ''} via API Gateway?`, async (ok) => {
            if (!ok) return;
            try {
                setPendingCardBusy(card, true);
                showLoading();
                const result = await callHandlePayoutAction(card, 'proceed');
                await loadPendingPayoutRequests();
                showAlert(result.message || 'API payout request processed.');
            } catch (err) {
                await loadPendingPayoutRequests();
                showAlert(`❌ ${escapePayoutHtml(err.message || 'API Process Failed')}`);
            } finally {
                hideLoading();
                setPendingCardBusy(card, false);
            }
        });
    } else if (mode === 'manual') {
        document.getElementById('upi-step-select').style.display = 'none';
        document.getElementById('upi-step-manual').style.display = 'block';

        const amount = Number(item.amount) || 0;
        const isUpi = isUpiPayoutMethod(item);

        const vpaEl = document.getElementById('upi-display-vpa');
        const amtEl = document.getElementById('upi-display-amount');
        const labelEl = document.getElementById('upi-recipient-label');

        if (amtEl) amtEl.textContent = `₹${formatPayoutNumber(amount, 2)}`;

        const qrContainer = document.getElementById('manual-qr-container');
        const voucherContainer = document.getElementById('manual-voucher-container');
        const voucherInput = document.getElementById('manual-voucher-input');
        const refIdInput = document.getElementById('manual-refid-input');
        if (voucherInput) voucherInput.value = '';
        if (refIdInput) refIdInput.value = '';

        if (isUpi) {
            if (labelEl) labelEl.textContent = 'Recipient UPI ID / VPA';
            if (vpaEl) vpaEl.textContent = upiVpa || 'N/A';
            if (qrContainer) qrContainer.style.display = 'flex';
            if (voucherContainer) voucherContainer.style.display = 'block';

            const payeeName = String(item.email || item.userId || 'User').split('@')[0];
            const upiNote = 'Crazyreward Payout';
            const upiUrl = `upi://pay?pa=${encodeURIComponent(upiVpa)}&pn=${encodeURIComponent(payeeName)}&am=${amount}&tn=${encodeURIComponent(upiNote)}&cu=INR`;
            const qrImgUrl = `https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${encodeURIComponent(upiUrl)}`;

            const qrImg = document.getElementById('upi-qr-img');
            if (qrImg) qrImg.src = qrImgUrl;
        } else {
            if (labelEl) labelEl.textContent = `Recipient Details (${item.methodName || 'Payout'})`;
            if (vpaEl) vpaEl.textContent = `Email/User: ${item.email || item.userId || 'N/A'}`;
            if (qrContainer) qrContainer.style.display = 'none';
            if (voucherContainer) voucherContainer.style.display = 'block';
        }
    }
}

async function handleUpiManualAction(action) {
    if (!currentUpiPayoutContext) return;
    const { card, item } = currentUpiPayoutContext;

    if (action === 'reject') {
        closeUpiPayoutModal();
        openRejectPayoutModal(card || item);
        return;
    }

    const voucherInput = document.getElementById('manual-voucher-input');
    const refIdInput = document.getElementById('manual-refid-input');
    const redeemCode = voucherInput ? voucherInput.value.trim() : '';
    const refId = refIdInput ? refIdInput.value.trim() : '';

    closeUpiPayoutModal();

    showConfirm(`Mark Success for order ${item.orderId || ''}?`, async (ok) => {
        if (!ok) return;

        try {
            setPendingCardBusy(card, true);
            showLoading();

            const payload = {
                userId: item.userId || card.dataset.userId,
                orderId: item.orderId || card.dataset.orderId,
                action,
                app: String(document.getElementById('appSelect')?.value || '').trim(),
                redeemCode,
                refId
            };

            const res = await fetch('/handle-payout', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload),
            });
            const json = await res.json();

            if (!res.ok || json.success === false) {
                throw new Error(json.message || 'Action failed');
            }

            await loadPendingPayoutRequests();
            showAlert(`✅ ${escapePayoutHtml(json.message || 'Action completed successfully')}`);
        } catch (err) {
            showAlert(`❌ ${escapePayoutHtml(err.message || 'Action failed')}`);
        } finally {
            hideLoading();
            setPendingCardBusy(card, false);
        }
    });
}

window.continuousUpiQueue = [];
window.continuousUpiIndex = 0;

function startContinuousUpiPay() {
    const list = window.allPendingPayoutRequests || [];
    const upiList = list.filter(item => {
        const methodName = String(item.methodName || '').toLowerCase();
        const vpa = extractUpiVpa(item);
        return methodName.includes('upi') || vpa.includes('@');
    });

    if (!upiList.length) {
        showAlert('ℹ️ No pending UPI payout requests found.');
        return;
    }

    window.continuousUpiQueue = upiList;
    window.continuousUpiIndex = 0;

    openContinuousUpiModal();
}

function openContinuousUpiModal() {
    const modal = document.getElementById('continuous-upi-modal');
    if (!modal) return;

    renderCurrentContinuousUpiItem();
    modal.style.display = 'flex';
}

function closeContinuousUpiModal() {
    const modal = document.getElementById('continuous-upi-modal');
    if (modal) modal.style.display = 'none';
    window.continuousUpiQueue = [];
    window.continuousUpiIndex = 0;
}

function renderCurrentContinuousUpiItem() {
    const queue = window.continuousUpiQueue || [];
    const idx = window.continuousUpiIndex || 0;

    if (idx >= queue.length) {
        closeContinuousUpiModal();
        showAlert('🎉 All pending UPI payouts in queue completed!', async () => {
            await loadPendingPayoutRequests();
        });
        return;
    }

    const item = queue[idx];
    const upiVpa = extractUpiVpa(item);
    const amount = Number(item.amount) || 0;

    const chipEl = document.getElementById('c-upi-progress-chip');
    const emailEl = document.getElementById('c-upi-email');
    const uidEl = document.getElementById('c-upi-uid');
    const vpaEl = document.getElementById('c-upi-vpa');
    const orderEl = document.getElementById('c-upi-order-id');
    const amtEl = document.getElementById('c-upi-amount');

    if (chipEl) chipEl.textContent = `${idx + 1} of ${queue.length} Pending`;
    if (emailEl) emailEl.textContent = item.email || 'N/A';
    if (uidEl) uidEl.textContent = item.userId || 'N/A';
    if (vpaEl) vpaEl.textContent = upiVpa || 'N/A';
    if (orderEl) orderEl.textContent = `Order: ${item.orderId || 'N/A'}`;
    if (amtEl) amtEl.textContent = `₹${formatPayoutNumber(amount, 2)}`;
}

function getUpiDeepLink(appType, vpa, payeeName, amount, note) {
    const params = `pa=${encodeURIComponent(vpa)}&pn=${encodeURIComponent(payeeName)}&am=${amount}&tn=${encodeURIComponent(note)}&cu=INR`;
    if (appType === 'gpay') return `tez://upi/pay?${params}`;
    if (appType === 'phonepe') return `phonepe://pay?${params}`;
    if (appType === 'paytm') return `paytmmp://pay?${params}`;
    return `upi://pay?${params}`;
}

function launchUpiAppForCurrentQueueItem(appType = 'generic') {
    const queue = window.continuousUpiQueue || [];
    const idx = window.continuousUpiIndex || 0;
    if (idx >= queue.length) return;

    const item = queue[idx];
    const upiVpa = extractUpiVpa(item);
    const amount = Number(item.amount) || 0;
    const payeeName = String(item.email || item.userId || 'User').split('@')[0];
    const upiNote = 'Crazyreward Payout';

    const upiUrl = getUpiDeepLink(appType, upiVpa, payeeName, amount, upiNote);
    window.location.href = upiUrl;
}

async function processContinuousUpiAction(action) {
    const queue = window.continuousUpiQueue || [];
    const idx = window.continuousUpiIndex || 0;
    if (idx >= queue.length) return;

    const item = queue[idx];

    if (action === 'reject') {
        openRejectPayoutModal(item);
        return;
    }

    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    try {
        showLoading();
        const payload = {
            userId: item.userId,
            orderId: item.orderId,
            action,
            app: selectedApp
        };

        const res = await fetch('/handle-payout', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        const json = await res.json();

        if (!res.ok || json.success === false) {
            throw new Error(json.message || 'Action failed');
        }

        window.continuousUpiIndex = idx + 1;
        await loadPendingPayoutRequests();
        renderCurrentContinuousUpiItem();
    } catch (err) {
        showAlert(`❌ ${escapePayoutHtml(err.message || 'Action failed')}`);
    } finally {
        hideLoading();
    }
}

function proceedPendingPayout(button) {
    const card = button.closest('.pending-payout-card');
    if (!card) return;
    const orderId = String(card.dataset.orderId || '').trim() || 'N/A';

    const item = (window.allPendingPayoutRequests || []).find(r => String(r.orderId || r.id) === orderId) || {
        orderId,
        methodName: card.dataset.methodName,
        userId: card.dataset.userId,
        email: card.dataset.email,
        amount: card.dataset.amount,
    };

    const upiVpa = extractUpiVpa(item);

    currentUpiPayoutContext = { card, item, upiVpa };
    openUpiPayoutModal(item, upiVpa);
}

let currentRejectContext = null;

function openRejectPayoutModal(target) {
    let card = null;
    let item = null;

    if (target && target.nodeType) {
        card = target.closest('.pending-payout-card');
    }

    const orderId = card ? String(card.dataset.orderId || '').trim() : String(target?.orderId || target?.id || '').trim();
    const userId = card ? String(card.dataset.userId || '').trim() : String(target?.userId || '').trim();
    const email = card ? String(card.dataset.email || '').trim() : String(target?.email || '').trim();
    const amount = card ? Number(card.dataset.amount || 0) : Number(target?.amount || 0);

    item = (window.allPendingPayoutRequests || []).find(r => String(r.orderId || r.id) === orderId) || {
        orderId,
        userId,
        email,
        amount,
    };

    currentRejectContext = { card, item, orderId, userId };

    const modal = document.getElementById('reject-payout-modal');
    if (!modal) return;

    const subTitle = document.getElementById('reject-modal-subtitle');
    const userEl = document.getElementById('reject-modal-user');
    const amtEl = document.getElementById('reject-modal-amount');

    if (subTitle) subTitle.textContent = `Order: ${orderId || 'N/A'}`;
    if (userEl) userEl.textContent = email || userId || 'N/A';
    if (amtEl) amtEl.textContent = `₹${formatPayoutNumber(Number(item.amount) || amount || 0, 2)}`;

    const select = document.getElementById('reject-preset-select');
    if (select) select.value = '';
    const textarea = document.getElementById('reject-reason-textarea');
    if (textarea) textarea.value = '';

    modal.style.display = 'flex';
}

function closeRejectPayoutModal() {
    const modal = document.getElementById('reject-payout-modal');
    if (modal) modal.style.display = 'none';
    currentRejectContext = null;
}

function onRejectPresetChanged(val) {
    const textarea = document.getElementById('reject-reason-textarea');
    if (!textarea) return;
    if (val === '__custom__') {
        textarea.value = '';
        textarea.focus();
    } else if (val) {
        textarea.value = val;
    }
}

async function confirmRejectPayoutWithReason() {
    if (!currentRejectContext) return;
    const { card, item, orderId, userId } = currentRejectContext;

    const textarea = document.getElementById('reject-reason-textarea');
    const reason = textarea ? textarea.value.trim() : '';

    const confirmBtn = document.getElementById('reject-modal-confirm-btn');
    if (confirmBtn) confirmBtn.disabled = true;

    try {
        if (card) setPendingCardBusy(card, true);
        showLoading();

        const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
        const payload = {
            userId: userId || item?.userId || card?.dataset.userId,
            orderId: orderId || item?.orderId || card?.dataset.orderId,
            action: 'reject',
            app: selectedApp,
            reason: reason || 'Redeem Declined by Admin',
        };

        const res = await fetch('/handle-payout', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });

        const json = await res.json();
        if (!res.ok || json.success === false) {
            throw new Error(json.message || 'Reject failed');
        }

        closeRejectPayoutModal();
        await loadPendingPayoutRequests();
        showAlert(`✅ ${escapePayoutHtml(json.message || 'Payout rejected and refunded successfully.')}`);
    } catch (err) {
        showAlert(`❌ ${escapePayoutHtml(err.message || 'Failed to reject payout')}`);
    } finally {
        hideLoading();
        if (confirmBtn) confirmBtn.disabled = false;
        if (card) setPendingCardBusy(card, false);
    }
}

function rejectPendingPayout(button) {
    openRejectPayoutModal(button);
}

function deletePendingPayout(button) {
    const card = button.closest('.pending-payout-card');
    if (!card) return;
    const orderId = String(card.dataset.orderId || '').trim() || 'N/A';
    const userId = String(card.dataset.userId || '').trim();
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    if (!selectedApp) {
        showAlert('❌ Please select app first');
        return;
    }

    showConfirm(`⚠️ Are you sure you want to permanently DELETE payout request ${orderId}?\nThis will remove the request from the list and database.`, async (ok) => {
        if (!ok) return;

        try {
            setPendingCardBusy(card, true);
            showLoading();

            const payload = {
                userId,
                orderId,
                action: 'delete',
                app: selectedApp,
            };

            const res = await fetch('/handle-payout', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload),
            });

            const json = await res.json();
            if (!res.ok || json.success === false) {
                throw new Error(json.message || 'Failed to delete payout request');
            }

            await loadPendingPayoutRequests();
            showAlert(`🗑️ ${escapePayoutHtml(json.message || 'Payout request deleted successfully.')}`);
        } catch (err) {
            showAlert(`❌ ${escapePayoutHtml(err.message || 'Failed to delete payout')}`);
        } finally {
            hideLoading();
            setPendingCardBusy(card, false);
        }
    });
}

async function bulkSendPayoutRequests() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const countInput = document.getElementById('bulk-count');
    const sendBtn = document.getElementById('bulk-send-btn');
    const progressEl = document.getElementById('bulk-progress');
    const progressFill = document.getElementById('bulk-progress-fill');
    const progressText = document.getElementById('bulk-progress-text');
    const resultEl = document.getElementById('bulk-result');

    if (!selectedApp) {
        showAlert('❌ Please select app first');
        return;
    }

    const count = Math.max(1, Math.min(500, parseInt(countInput?.value || '5', 10) || 5));

    // Fetch current pending list
    let pendingRequests = [];
    try {
        const res = await fetch('/pending-payout-requests', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ selectedApp }),
        });
        const json = await res.json();

        if (!res.ok || !json.success) {
            throw new Error(json.message || 'Failed to fetch pending payouts');
        }

        pendingRequests = (json.requests || []).filter(r => r.status === 'pending');
    } catch (err) {
        showAlert(`❌ ${err.message || 'Failed to load pending requests'}`);
        return;
    }

    if (!pendingRequests.length) {
        showAlert('ℹ️ No pending payout requests found.');
        return;
    }

    const toProcess = pendingRequests.slice(0, count);
    const totalCount = toProcess.length;

    showConfirm(`Send ${totalCount} payout request${totalCount > 1 ? 's' : ''} for processing?`, async (ok) => {
        if (!ok) return;

        // Disable UI
        sendBtn.disabled = true;
        sendBtn.classList.add('is-busy');
        countInput.disabled = true;
        progressEl.style.display = 'block';
        resultEl.style.display = 'none';
        progressFill.style.width = '0%';
        progressText.textContent = `Processing 0 / ${totalCount}...`;

        let successCount = 0;
        let failedCount = 0;
        const failedOrders = [];

        for (let i = 0; i < toProcess.length; i++) {
            const item = toProcess[i];
            const percent = Math.round(((i + 1) / totalCount) * 100);

            try {
                const res = await fetch('/handle-payout', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        userId: item.userId || '',
                        orderId: item.orderId || item.id || '',
                        action: 'proceed',
                        app: selectedApp,
                    }),
                });

                let json = {};
                try { json = await res.json(); } catch (_) { json = {}; }

                if (res.ok && json.success !== false) {
                    successCount++;
                } else {
                    failedCount++;
                    failedOrders.push({ orderId: item.orderId, reason: json.message || 'Failed' });
                }
            } catch (err) {
                failedCount++;
                failedOrders.push({ orderId: item.orderId, reason: err.message || 'Network error' });
            }

            // Update progress
            progressFill.style.width = `${percent}%`;
            progressText.textContent = `Processing ${i + 1} / ${totalCount}... (✅ ${successCount} | ❌ ${failedCount})`;
        }

        // Show result
        progressText.textContent = `Done! ✅ ${successCount} success | ❌ ${failedCount} failed out of ${totalCount}`;

        let resultHtml = `<div class="bulk-result-summary">`;
        resultHtml += `<div class="bulk-result-stat success"><span>✅</span> ${successCount} Sent</div>`;
        resultHtml += `<div class="bulk-result-stat failed"><span>❌</span> ${failedCount} Failed</div>`;
        resultHtml += `</div>`;

        if (failedOrders.length) {
            resultHtml += `<div class="bulk-result-failures"><strong>Failed Orders:</strong><ul>`;
            failedOrders.forEach(f => {
                resultHtml += `<li><strong>${escapePayoutHtml(f.orderId)}</strong>: ${escapePayoutHtml(f.reason)}</li>`;
            });
            resultHtml += `</ul></div>`;
        }

        resultEl.innerHTML = resultHtml;
        resultEl.style.display = 'block';

        // Re-enable UI
        sendBtn.disabled = false;
        sendBtn.classList.remove('is-busy');
        countInput.disabled = false;

        // Refresh list
        await loadPendingPayoutRequests();
    });
}

document.getElementById('appSelect')?.addEventListener('change', () => {
    loadPendingPayoutRequests();
});

document.addEventListener('DOMContentLoaded', () => {
    loadPendingPayoutRequests();
});
