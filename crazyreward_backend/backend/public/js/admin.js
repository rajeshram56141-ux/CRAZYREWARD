function toggleSubMenu(event, groupId) {
    if (event) {
        if (event.preventDefault) event.preventDefault();
        if (event.stopPropagation) event.stopPropagation();
    }
    const el = document.getElementById(groupId);
    if (el) {
        el.classList.toggle('open');
    }
}

function toggleDropdown() {
    const d = document.getElementById("dropdown");
    if (d) {
        d.style.display =
            d.style.display === "block" ? "none" : "block";
    }
}

document.addEventListener("click", (e) => {
    const nav = document.querySelector(".nav-right");
    const dropdown = document.getElementById("dropdown");
    if (nav && dropdown && !nav.contains(e.target)) {
        dropdown.style.display = "none";
    }
});

function showLoading() {
    document.getElementById('loadingOverlay').style.display = 'flex';
}

function hideLoading() {
    document.getElementById('loadingOverlay').style.display = 'none';
}

function openModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) modal.classList.add('is-open');
    return modal;
}

function closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) modal.classList.remove('is-open');
}

function showConfirm(messageOrTitle, callbackOrMessage, maybeCallback) {
    let title = 'Confirm this action?';
    let message = '';
    let callback = null;

    if (typeof callbackOrMessage === 'function') {
        message = messageOrTitle;
        callback = callbackOrMessage;
    } else if (typeof maybeCallback === 'function') {
        title = messageOrTitle;
        message = callbackOrMessage;
        callback = maybeCallback;
    } else if (typeof callbackOrMessage === 'string') {
        title = messageOrTitle;
        message = callbackOrMessage;
    } else {
        message = messageOrTitle;
    }

    const modal = openModal('confirm-modal');
    if (!modal) return Promise.resolve(false);

    const titleEl = modal.querySelector('h3');
    if (titleEl && title) titleEl.textContent = title;
    const msgEl = modal.querySelector('.confirm-message');
    if (msgEl) msgEl.textContent = message;

    return new Promise((resolve) => {
        const okBtn = document.getElementById('confirm-ok');
        const cancelBtn = document.getElementById('confirm-cancel');

        if (okBtn) {
            okBtn.onclick = () => {
                closeModal('confirm-modal');
                if (callback) callback(true);
                resolve(true);
            };
        }
        if (cancelBtn) {
            cancelBtn.onclick = () => {
                closeModal('confirm-modal');
                if (callback) callback(false);
                resolve(false);
            };
        }
    });
}

function showAlert(message, callback) {
    const modal = openModal('alert-modal');
    if (!modal) return Promise.resolve(true);

    const msgEl = modal.querySelector('.alert-message');
    if (msgEl) msgEl.innerHTML = message;

    return new Promise((resolve) => {
        const okBtn = document.getElementById('alert-ok');
        if (okBtn) {
            okBtn.onclick = () => {
                closeModal('alert-modal');
                if (callback) callback(true);
                resolve(true);
            };
        } else {
            resolve(true);
        }
    });
}

function openActionFormModal(options = {}) {
    const modal = document.getElementById('action-form-modal');
    if (!modal) return null;

    const title = String(options.title || 'Action').trim();
    const subtitle = String(options.subtitle || '').trim();
    const submitText = String(options.submitText || 'Submit').trim();
    const fields = Array.isArray(options.fields) ? options.fields : [];

    const titleEl = document.getElementById('action-form-title');
    const subtitleEl = document.getElementById('action-form-sub');
    const fieldsWrap = document.getElementById('action-form-fields');
    const submitBtn = document.getElementById('action-form-submit');
    const cancelBtn = document.getElementById('action-form-cancel');

    if (!titleEl || !subtitleEl || !fieldsWrap || !submitBtn || !cancelBtn) {
        return null;
    }

    titleEl.textContent = title;
    subtitleEl.textContent = subtitle;
    submitBtn.textContent = submitText;
    fieldsWrap.innerHTML = fields.map((field) => {
        const key = escapeWalletHtml(field.key || '');
        const label = escapeWalletHtml(field.label || field.key || '');
        const type = String(field.type || 'text').trim();
        const placeholder = escapeWalletHtml(field.placeholder || '');
        const required = field.required ? 'required' : '';
        const value = escapeWalletHtml(field.value || '');

        if (type === 'textarea') {
            return `
                <label class="action-form-field" data-field-container="${key}">
                    <span>${label}</span>
                    <textarea data-action-field="${key}" placeholder="${placeholder}" ${required}>${value}</textarea>
                </label>
            `;
        }

        if (type === 'select') {
            const optionsHtml = (field.options || []).map(opt => {
                const optVal = typeof opt === 'object' ? opt.value : opt;
                const optLabel = typeof opt === 'object' ? opt.label : opt;
                const isSel = String(optVal) === String(value) ? 'selected' : '';
                return `<option value="${escapeWalletHtml(optVal)}" ${isSel}>${escapeWalletHtml(optLabel)}</option>`;
            }).join('');

            return `
                <label class="action-form-field" data-field-container="${key}">
                    <span>${label}</span>
                    <select data-action-field="${key}" ${required}>
                        ${optionsHtml}
                    </select>
                </label>
            `;
        }

        if (type === 'country-chips') {
            const popular = ['GLOBAL', 'IN', 'BD', 'PK', 'NP', 'LK', 'US', 'GB', 'CA', 'AE'];
            const defaultSelected = (value || '').split(',').map(c => c.trim().toUpperCase()).filter(Boolean);
            const chipsHtml = popular.map(country => {
                const isSelected = defaultSelected.includes(country);
                return `
                    <span class="wallet-country-chip ${isSelected ? 'selected' : ''}" 
                          onclick="toggleCountryChip(this)" 
                          data-country="${country}">
                        ${country}
                    </span>
                `;
            }).join('');

            return `
                <div class="action-form-field wallet-country-chips-wrapper" data-field-container="${key}" data-action-chips-field="${key}">
                    <span>${label}</span>
                    <div class="wallet-country-chips-list">
                        ${chipsHtml}
                    </div>
                    <div class="wallet-country-custom-row" style="margin-top: 6px; display: flex; gap: 6px;">
                        <input type="text" placeholder="Code (e.g. US)" class="wallet-input-custom-country" style="flex: 1; padding: 4px 8px; font-size: 12px; border: 1px solid #cbd5e1; border-radius: 6px; text-transform: uppercase;">
                        <button type="button" class="wallet-btn-custom-country" onclick="addCustomCountryChip(this, '${key}')" style="background: #475569; color: #fff; border: none; border-radius: 6px; padding: 4px 10px; font-size: 12px; font-weight: 600; cursor: pointer;">Add</button>
                    </div>
                </div>
            `;
        }

        return `
            <label class="action-form-field" data-field-container="${key}">
                <span>${label}</span>
                <input data-action-field="${key}" type="${escapeWalletHtml(type)}" placeholder="${placeholder}" value="${value}" ${required} />
            </label>
        `;
    }).join('');

    submitBtn.disabled = false;
    submitBtn.onclick = async () => {
        try {
            const values = {};
            const inputs = Array.from(fieldsWrap.querySelectorAll('[data-action-field]'));
            for (const input of inputs) {
                const key = String(input.getAttribute('data-action-field') || '').trim();
                if (!key) continue;
                values[key] = String(input.value || '').trim();
            }

            // Also extract action chips field
            const chipWrappers = Array.from(fieldsWrap.querySelectorAll('[data-action-chips-field]'));
            for (const wrapper of chipWrappers) {
                const key = String(wrapper.getAttribute('data-action-chips-field') || '').trim();
                if (!key) continue;
                const selected = Array.from(wrapper.querySelectorAll('.wallet-country-chip.selected'))
                    .map(c => String(c.dataset.country || '').trim().toUpperCase());
                values[key] = selected.join(', ');
            }

            if (typeof options.onSubmit === 'function') {
                submitBtn.disabled = true;
                await options.onSubmit(values);
            }
        } finally {
            submitBtn.disabled = false;
        }
    };

    cancelBtn.onclick = () => closeModal('action-form-modal');
    openModal('action-form-modal');
    return modal;
}

function escapeWalletHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function parseCsvInput(value) {
    return String(value || '')
        .split(',')
        .map((item) => item.trim())
        .filter(Boolean);
}

async function fetchWalletCatalogData(selectedApp) {
    const res = await fetch(`/wallet-catalog?app=${encodeURIComponent(selectedApp)}`);
    const json = await res.json();

    if (!res.ok || !json.success) {
        throw new Error(json.message || 'Failed to load wallet catalog');
    }

    return json.methods || [];
}

async function openWalletManager() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    if (!selectedApp) {
        showAlert('❌ Please select app first');
        return;
    }

    openModal('wallet-modal');
    await refreshWalletManager();
}

function closeWalletModal() {
    closeModal('wallet-modal');
}

async function refreshWalletManager() {
    const modalBody = document.getElementById('wallet-modal-body');
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    if (!selectedApp) {
        modalBody.innerHTML = '<div class="wallet-placeholder error">Please select app first.</div>';
        return;
    }

    modalBody.innerHTML = '<div class="wallet-placeholder loading">Loading wallet catalog...</div>';

    try {
        const methods = await fetchWalletCatalogData(selectedApp);
        renderWalletCatalog(methods, selectedApp);
    } catch (err) {
        modalBody.innerHTML = `<div class="wallet-placeholder error">${escapeWalletHtml(err.message || 'Failed to load wallet catalog')}</div>`;
    }
}

function renderCountryChips(selectedCountries, fieldName) {
    const popular = ['GLOBAL', 'IN', 'BD', 'PK', 'NP', 'LK', 'US', 'GB', 'CA', 'AE'];
    const selectedNormalized = (selectedCountries || []).map(c => String(c).toUpperCase().trim()).filter(Boolean);
    const allChips = Array.from(new Set([...popular, ...selectedNormalized])).map(c => c.toUpperCase().trim()).filter(Boolean);

    return allChips.map(country => {
        const isSelected = selectedNormalized.includes(country);
        return `
            <span class="wallet-country-chip ${isSelected ? 'selected' : ''}" 
                  onclick="toggleCountryChip(this)" 
                  data-country="${country}">
                ${country}
            </span>
        `;
    }).join('');
}

function toggleCountryChip(chip) {
    chip.classList.toggle('selected');
}

function addCustomCountryChip(button, fieldName) {
    const wrapper = button.closest('.wallet-country-chips-wrapper');
    if (!wrapper) return;
    const input = wrapper.querySelector('.wallet-input-custom-country');
    if (!input) return;
    const code = String(input.value || '').toUpperCase().trim().replace(/[^A-Z]/g, '');
    if (!code) return;

    const list = wrapper.querySelector('.wallet-country-chips-list');
    let existingChip = Array.from(list.querySelectorAll('.wallet-country-chip')).find(c => c.dataset.country === code);
    if (existingChip) {
        existingChip.classList.add('selected');
    } else {
        const newChip = document.createElement('span');
        newChip.className = 'wallet-country-chip selected';
        newChip.onclick = function () { toggleCountryChip(this); };
        newChip.dataset.country = code;
        newChip.textContent = code;
        list.appendChild(newChip);
    }
    input.value = '';
}

function renderWalletCatalog(methods, selectedApp) {
    const modalBody = document.getElementById('wallet-modal-body');
    const methodList = Array.isArray(methods) ? methods : [];

    if (!methodList.length) {
        modalBody.innerHTML = '<div class="wallet-placeholder">No wallet methods found in this app.</div>';
        return;
    }

    // Save methods to window map for modal editing
    window.WALLET_METHODS_MAP = window.WALLET_METHODS_MAP || {};
    methodList.forEach(m => { window.WALLET_METHODS_MAP[m.id] = m; });

    const methodCards = methodList.map((method) => {
        const methodId = String(method.id || '').trim();
        const methodSafe = escapeWalletHtml(methodId);
        const denominations = Array.isArray(method.denominations) ? method.denominations : [];

        const denomRows = denominations.map((denom) => {
            const denomId = escapeWalletHtml(denom.id || '');
            const amount = Number(denom.amount) || 0;
            const coins = Number(denom.coins) || 0;
            const enabled = !!denom.enabled;

            return `
                <div class="wallet-denom-row" data-old-id="${denomId}" style="display:grid; grid-template-columns:80px 80px 1fr 90px 65px 45px; gap:6px; align-items:center; margin-bottom:6px;">
                    <input type="number" class="wallet-denom-amount" min="1" value="${amount}" style="padding:6px 8px; font-weight:700; border-radius:6px; border:1px solid #cbd5e1;">
                    <input type="number" class="wallet-denom-coins" min="1" value="${coins}" style="padding:6px 8px; font-weight:700; border-radius:6px; border:1px solid #cbd5e1;">
                    <input type="text" class="wallet-denom-subtitle" value="${escapeWalletHtml(denom.subtitle || '')}" placeholder="Subtitle (Optional)" style="padding:6px 8px; border-radius:6px; border:1px solid #cbd5e1;">
                    <select class="wallet-denom-enabled" style="padding:6px 4px; border-radius:6px; border:1px solid #cbd5e1; font-weight:600; font-size:12px;">
                        <option value="true" ${enabled ? 'selected' : ''}>Active</option>
                        <option value="false" ${!enabled ? 'selected' : ''}>Disabled</option>
                    </select>
                    <button class="wallet-denom-btn" onclick="saveWalletDenomination(this)" style="padding:6px 8px; border-radius:6px; font-size:12px;">Save</button>
                    <button class="wallet-denom-btn" onclick="deleteWalletDenominationFromDashboard(this)" style="padding:6px 8px; border-radius:6px; background:#dc2626; color:#fff; font-size:12px;">✕</button>
                </div>
            `;
        }).join('');

        return `
            <div class="wallet-method-card" data-method-id="${methodSafe}" style="background:#fff; border:1px solid #e2e8f0; border-radius:18px; padding:18px; margin-bottom:16px; box-shadow:0 4px 12px rgba(0,0,0,0.03);">
                <div class="wallet-method-head" style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px; padding-bottom:12px; border-bottom:1px solid #f1f5f9;">
                    <div style="display:flex; align-items:center; gap:10px;">
                        ${method.image ? `<img src="${escapeWalletHtml(method.image)}" style="width:36px; height:36px; object-fit:contain; border-radius:8px; background:#f8fafc; padding:3px; border:1px solid #e2e8f0;">` : '<div style="font-size:18px; color:#64748b;"><i class="fa-solid fa-credit-card"></i></div>'}
                        <div>
                            <h4 style="margin:0; font-size:15px; font-weight:800; color:#0f172a;">${escapeWalletHtml(method.title || methodSafe)}</h4>
                            <div style="display:flex; gap:6px; margin-top:4px; align-items:center; flex-wrap:wrap;">
                                <span style="font-size:10.5px; font-weight:700; padding:2px 7px; border-radius:999px; background:${method.enabled ? 'rgba(22, 163, 74, 0.1)' : 'rgba(239, 68, 68, 0.1)'}; color:${method.enabled ? '#16a34a' : '#ef4444'};">
                                    ${method.enabled ? '● Active' : '● Disabled'}
                                </span>
                                <span style="font-size:10.5px; font-weight:700; padding:2px 7px; border-radius:999px; background:${method.autoPayment ? 'rgba(37, 99, 235, 0.1)' : 'rgba(245, 158, 11, 0.1)'}; color:${method.autoPayment ? '#2563eb' : '#d97706'};">
                                    ${method.autoPayment ? '<i class="fa-solid fa-bolt" style="font-size:10px; margin-right:3px;"></i> Instant Auto' : '<i class="fa-solid fa-clock" style="font-size:10px; margin-right:3px;"></i> Manual'}
                                </span>
                                <span class="wallet-rank-chip" style="font-size:10.5px; padding:2px 7px; border-radius:999px;">Rank ${Number(method.rank) || 0}</span>
                            </div>
                        </div>
                    </div>
                    <div style="display:flex; gap:6px; align-items:center;">
                        <button type="button" class="wallet-save-method-btn" onclick="openEditWalletMethodModalFromDashboard('${methodSafe}')" style="background:#052e1f; color:#fff; padding:6px 12px; font-size:12px; border-radius:8px; border:none; cursor:pointer; font-weight:700; display:flex; align-items:center; gap:4px;"><i class="fa-solid fa-pen-to-square"></i> Edit</button>
                        <button type="button" class="wallet-duplicate-method-btn" onclick="duplicateWalletMethod(this)" style="padding:6px 10px; font-size:12px; border-radius:8px; margin-left:0;" title="Duplicate"><i class="fa-solid fa-copy"></i></button>
                        <button type="button" class="wallet-delete-method-btn" onclick="deleteWalletMethod(this)" style="padding:6px 10px; font-size:12px; border-radius:8px; margin-left:0;" title="Delete"><i class="fa-solid fa-trash-can"></i></button>
                    </div>
                </div>

                <div class="wallet-denom-section" style="margin-top: 10px; padding-top: 0; border-top:none;">
                    <div class="wallet-denom-title" style="font-size:12.5px; font-weight:800; color:#052e1f; margin-bottom:8px;"><i class="fa-solid fa-coins" style="margin-right:4px; color:#d97706;"></i> Denominations (Amounts & Coins)</div>
                    <div class="wallet-denom-list">
                        ${denomRows || '<div class="wallet-denom-empty">No denominations found.</div>'}
                        <div class="wallet-denom-row new" data-old-id="" style="display:grid; grid-template-columns:80px 80px 1fr 90px 100px; gap:6px; align-items:center; margin-top:8px; background:#f8fafc; padding:6px 8px; border-radius:10px; border:1px dashed #cbd5e1;">
                            <input type="number" class="wallet-denom-amount" min="1" placeholder="Amount (₹)" style="padding:6px 8px; font-weight:700; border-radius:6px; border:1px solid #cbd5e1; background:#fff;">
                            <input type="number" class="wallet-denom-coins" min="1" placeholder="Coins" style="padding:6px 8px; font-weight:700; border-radius:6px; border:1px solid #cbd5e1; background:#fff;">
                            <input type="text" class="wallet-denom-subtitle" placeholder="Subtitle (Optional)" style="padding:6px 8px; border-radius:6px; border:1px solid #cbd5e1; background:#fff;">
                            <select class="wallet-denom-enabled" style="padding:6px; border-radius:6px; border:1px solid #cbd5e1; background:#fff; font-weight:600; font-size:12px;">
                                <option value="true" selected>Active</option>
                                <option value="false">Disabled</option>
                            </select>
                            <button class="wallet-denom-btn add" onclick="saveWalletDenomination(this)" style="padding:6px 12px; font-weight:800; background:#16a34a; font-size:12px; display:flex; align-items:center; justify-content:center; gap:4px;"><i class="fa-solid fa-plus"></i> Add</button>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }).join('');

    modalBody.innerHTML = `
        <div class="wallet-app-badge" style="margin-bottom:14px; font-weight:700; color:#052e1f;">App: ${escapeWalletHtml(selectedApp)}</div>
        <div class="wallet-method-grid">${methodCards}</div>
    `;
}

function openEditWalletMethodModalFromDashboard(methodId) {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const method = (window.WALLET_METHODS_MAP && window.WALLET_METHODS_MAP[methodId]) || {};

    openActionFormModal({
        title: `Edit Payout Method: ${method.title || methodId}`,
        subtitle: `Update settings for ${methodId} in app ${selectedApp}`,
        submitText: 'Save Changes',
        fields: [
            { key: 'title', label: 'Display Title', type: 'text', value: method.title || '', required: true },
            { key: 'symbol', label: 'Currency Symbol', type: 'text', value: method.symbol || '₹', required: true },
            { key: 'rank', label: 'Display Rank', type: 'number', value: method.rank || 0, required: true },
            { key: 'image', label: 'Image Icon URL', type: 'text', value: method.image || '', required: false },
            { key: 'validators', label: 'Validators (comma-separated)', type: 'text', value: (method.validators || []).join(', '), required: false },
            { key: 'hints', label: 'Custom Hints (JSON)', type: 'text', value: JSON.stringify(method.hints || {}), required: false },
            {
                key: 'autoPayment',
                label: 'Auto Payment',
                type: 'select',
                value: method.autoPayment ? 'true' : 'false',
                options: [
                    { value: 'true', label: 'Instant Automatic' },
                    { value: 'false', label: 'Manual Approval' }
                ]
            },
            {
                key: 'enabled',
                label: 'Status',
                type: 'select',
                value: method.enabled ? 'true' : 'false',
                options: [
                    { value: 'true', label: 'Active (Enabled)' },
                    { value: 'false', label: 'Disabled' }
                ]
            }
        ],
        onSubmit: async (values) => {
            let hints = {};
            if (values.hints) {
                try {
                    hints = JSON.parse(values.hints);
                } catch (e) {
                    showAlert('❌ Invalid JSON format for Custom Hints');
                    return;
                }
            }

            const payload = {
                selectedApp,
                methodId,
                title: String(values.title || '').trim(),
                symbol: String(values.symbol || '₹').trim(),
                image: String(values.image || '').trim(),
                rank: Number(values.rank) || 0,
                country: method.country || ['GLOBAL', 'IN'],
                ex_country: method.ex_country || [],
                validators: parseCsvInput(values.validators || ''),
                hints,
                enabled: values.enabled === 'true',
                autoPayment: values.autoPayment === 'true'
            };

            try {
                const res = await fetch('/wallet-catalog/method', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                const json = await res.json();
                if (!res.ok || !json.success) throw new Error(json.message || 'Failed to save method');

                closeModal('action-form-modal');
                showAlert(`✅ Payout method "${payload.title}" saved!`, () => {
                    refreshWalletManager();
                });
            } catch (err) {
                showAlert(`❌ Error: ${err.message || 'Save failed'}`);
            }
        }
    });
}

async function deleteWalletDenominationFromDashboard(button) {
    const row = button.closest('.wallet-denom-row');
    const card = button.closest('.wallet-method-card');
    if (!row || !card) return;

    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const methodId = String(card.dataset.methodId || '').trim();
    const oldDenominationId = String(row.dataset.oldId || '').trim();

    if (!oldDenominationId) {
        row.remove();
        return;
    }

    showConfirm('Are you sure you want to delete this denomination?', async (confirmed) => {
        if (!confirmed) return;
        try {
            const res = await fetch('/wallet-catalog/denomination', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    selectedApp,
                    methodId,
                    oldDenominationId,
                    delete: true
                })
            });
            const json = await res.json();
            if (!res.ok || !json.success) throw new Error(json.message || 'Failed to delete denomination');

            showAlert('✅ Denomination deleted!', () => {
                refreshWalletManager();
            });
        } catch (err) {
            showAlert(`❌ Error: ${err.message || 'Delete failed'}`);
        }
    });
}

async function saveWalletMethod(button) {
    const card = button.closest('.wallet-method-card');
    if (!card) return;

    const statusEl = card.querySelector('.wallet-method-status');
    const methodId = String(card.dataset.methodId || '').trim();
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    let hints = {};
    const hintsRaw = card.querySelector('.wallet-input-hints')?.value || '{}';
    try {
        hints = JSON.parse(hintsRaw);
    } catch (e) {
        if (statusEl) statusEl.textContent = '❌ Invalid Hints JSON';
        alert('Invalid Custom Hints JSON format. Please write valid JSON like {"upiId": "Enter UPI ID"}');
        return;
    }

    const countryChips = Array.from(card.querySelectorAll('.wallet-country-chips-wrapper[data-field="country"] .wallet-country-chip.selected'))
        .map(chip => String(chip.dataset.country || '').trim().toUpperCase());
    const exCountryChips = Array.from(card.querySelectorAll('.wallet-country-chips-wrapper[data-field="ex_country"] .wallet-country-chip.selected'))
        .map(chip => String(chip.dataset.country || '').trim().toUpperCase());

    const payload = {
        selectedApp,
        methodId,
        title: card.querySelector('.wallet-input-title')?.value || '',
        rank: Number(card.querySelector('.wallet-input-rank')?.value || 0),
        image: card.querySelector('.wallet-input-image')?.value || '',
        symbol: card.querySelector('.wallet-input-symbol')?.value || '',
        country: countryChips,
        ex_country: exCountryChips,
        validators: parseCsvInput(card.querySelector('.wallet-input-validators')?.value || ''),
        hints,
        enabled: String(card.querySelector('.wallet-input-enabled')?.value || 'false') === 'true',
        autoPayment: String(card.querySelector('.wallet-input-auto-payment')?.value || 'false') === 'true',
    };

    try {
        if (statusEl) statusEl.textContent = 'Saving...';
        const res = await fetch('/wallet-catalog/method', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to update method');

        if (statusEl) statusEl.textContent = 'Saved';
        await refreshWalletManager();
    } catch (err) {
        if (statusEl) statusEl.textContent = `Error: ${err.message || 'Save failed'}`;
    }
}

async function deleteWalletMethod(button) {
    const card = button.closest('.wallet-method-card, .wallet-card');
    if (!card) return;

    const statusEl = card.querySelector('.wallet-method-status');
    const methodId = String(card.dataset.methodId || '').trim();
    const appEl = document.getElementById('appSelect');
    const selectedApp = String((appEl && appEl.value) || '').trim();

    showConfirm(`Are you sure you want to delete payout method: ${methodId}? All its denominations will also be deleted.`, async (confirmed) => {
        if (!confirmed) return;

        try {
            if (statusEl) statusEl.textContent = 'Deleting...';
            const res = await fetch('/wallet-catalog/method/delete', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ selectedApp, methodId }),
            });
            const json = await res.json();
            if (!res.ok || !json.success) throw new Error(json.message || 'Failed to delete method');

            if (typeof showAlert === 'function') {
                showAlert(`✅ ${methodId} has been deleted successfully!`, () => {
                    if (typeof closeModal === 'function') closeModal('wallet-modal');
                    if (typeof refreshWalletManager === 'function') refreshWalletManager();
                    else location.reload();
                });
            } else {
                card.remove();
            }
        } catch (err) {
            if (statusEl) statusEl.textContent = `Error: ${err.message || 'Delete failed'}`;
            else alert(err.message || 'Delete failed');
        }
    });
}

async function duplicateWalletMethod(button) {
    const card = button.closest('.wallet-method-card, .wallet-card');
    if (!card) return;

    const statusEl = card.querySelector('.wallet-method-status');
    const sourceMethodId = String(card.dataset.methodId || '').trim();
    const appEl = document.getElementById('appSelect');
    const selectedApp = String((appEl && appEl.value) || '').trim();

    if (typeof openActionFormModal === 'function') {
        openActionFormModal({
            title: 'Duplicate Payout Method',
            subtitle: `Duplicate method "${sourceMethodId}" in app: ${selectedApp}`,
            submitText: 'Duplicate Method',
            fields: [
                { key: 'targetMethodId', label: 'New Method ID (lowercase alphanumeric)', type: 'text', placeholder: 'e.g. upi_new, paytm_2', required: true }
            ],
            onSubmit: async (values) => {
                const targetMethodId = String(values.targetMethodId || '').trim().toLowerCase().replace(/[^a-z0-9_-]/g, '');
                if (!targetMethodId) {
                    showAlert('❌ Invalid Target Method ID');
                    return;
                }

                if (targetMethodId === sourceMethodId) {
                    showAlert('❌ Target Method ID must be different from Source Method ID');
                    return;
                }

                try {
                    if (statusEl) statusEl.textContent = 'Duplicating...';
                    const res = await fetch('/wallet-catalog/method/duplicate', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            selectedApp,
                            sourceMethodId,
                            targetMethodId
                        })
                    });

                    const json = await res.json();
                    if (!res.ok || !json.success) throw new Error(json.message || 'Failed to duplicate method');

                    closeModal('action-form-modal');
                    showAlert(`✅ Method duplicated successfully to "${targetMethodId}"!`, () => {
                        refreshWalletManager();
                    });
                } catch (err) {
                    showAlert(`❌ Error: ${err.message || 'Operation failed'}`);
                    if (statusEl) statusEl.textContent = `Error: ${err.message || 'Duplicate failed'}`;
                }
            }
        });
    } else {
        const targetMethodId = prompt(`Duplicate ${sourceMethodId} as new Method ID:`, `${sourceMethodId}_copy`);
        if (!targetMethodId) return;

        try {
            const res = await fetch('/wallet-catalog/method/duplicate', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ selectedApp, sourceMethodId, targetMethodId })
            });
            const json = await res.json();
            if (!res.ok || !json.success) throw new Error(json.message || 'Failed to duplicate method');
            location.reload();
        } catch (err) {
            alert(err.message || 'Duplicate failed');
        }
    }
}

async function saveAllDenominations(button) {
    const card = button.closest('.wallet-method-card, .wallet-card');
    if (!card) return;

    const statusEl = card.querySelector('.wallet-all-denom-status');
    const appEl = document.getElementById('appSelect');
    const selectedApp = String((appEl && appEl.value) || '').trim();
    const methodId = String(card.dataset.methodId || '').trim();

    // Find all rows
    const rows = card.querySelectorAll('.wallet-denom-row, .denom-row');
    const denominations = [];

    for (const row of rows) {
        const amountEl = row.querySelector('.wallet-denom-amount');
        const coinsEl = row.querySelector('.wallet-denom-coins');
        const enabledEl = row.querySelector('.wallet-denom-enabled');
        const oldDenominationId = String(row.dataset.oldId || '').trim();

        const amountVal = amountEl ? amountEl.value : '';
        const coinsVal = coinsEl ? coinsEl.value : '';

        // If it's the "new" row and both are empty, ignore it
        if (row.classList.contains('new') && !amountVal && !coinsVal) {
            continue;
        }

        const amount = Number(amountVal || 0);
        const coins = Number(coinsVal || 0);
        const enabled = String(enabledEl ? enabledEl.value : 'true') === 'true';

        if (!Number.isFinite(amount) || amount <= 0 || !Number.isFinite(coins) || coins <= 0) {
            if (statusEl) statusEl.textContent = '❌ Invalid amount/coins in one of the rows';
            alert('Please check denomination inputs. Amount and Coins must be numbers greater than 0.');
            return;
        }

        denominations.push({
            oldDenominationId,
            amount,
            coins,
            enabled
        });
    }

    try {
        if (statusEl) statusEl.textContent = 'Saving all...';
        const res = await fetch('/wallet-catalog/denominations/save-all', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                selectedApp,
                methodId,
                denominations
            })
        });

        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to save denominations');

        if (statusEl) statusEl.textContent = 'All Saved';
        if (typeof refreshWalletManager === 'function') await refreshWalletManager();
        else location.reload();
    } catch (err) {
        if (statusEl) statusEl.textContent = `Error: ${err.message || 'Save failed'}`;
        else alert(err.message || 'Save failed');
    }
}

async function saveWalletDenomination(button) {
    const row = button.closest('.wallet-denom-row, .denom-row');
    const card = button.closest('.wallet-method-card, .wallet-card');
    if (!row || !card) return;

    const statusEl = row.querySelector('.wallet-row-status');
    const appEl = document.getElementById('appSelect');
    const selectedApp = String((appEl && appEl.value) || '').trim();
    const methodId = String(card.dataset.methodId || '').trim();
    const oldDenominationId = String(row.dataset.oldId || '').trim();
    const amountEl = row.querySelector('.wallet-denom-amount');
    const coinsEl = row.querySelector('.wallet-denom-coins');
    const subtitleEl = row.querySelector('.wallet-denom-subtitle');
    const enabledEl = row.querySelector('.wallet-denom-enabled');
    const amount = Number(amountEl ? amountEl.value : 0);
    const coins = Number(coinsEl ? coinsEl.value : 0);
    const subtitle = String(subtitleEl ? subtitleEl.value : '').trim();
    const enabled = String(enabledEl ? enabledEl.value : 'true') === 'true';

    if (!Number.isFinite(amount) || amount <= 0 || !Number.isFinite(coins) || coins <= 0) {
        if (statusEl) statusEl.textContent = 'Invalid amount/coins';
        alert('Please enter valid Amount and Coins (> 0)');
        return;
    }

    try {
        if (statusEl) statusEl.textContent = 'Saving...';
        const res = await fetch('/wallet-catalog/denomination', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                selectedApp,
                methodId,
                oldDenominationId,
                amount,
                coins,
                enabled,
                subtitle
            }),
        });

        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to save denomination');

        if (statusEl) statusEl.textContent = row.classList.contains('new') ? 'Added' : 'Saved';
        if (typeof refreshWalletManager === 'function') await refreshWalletManager();
        else location.reload();
    } catch (err) {
        if (statusEl) statusEl.textContent = `Error: ${err.message || 'Save failed'}`;
        else alert(err.message || 'Save failed');
    }
}

window.WALLET_PRESETS = window.WALLET_PRESETS || {
    googleplay: {
        methodId: 'googleplay',
        title: 'Google Play',
        symbol: '₹',
        image: 'https://cdn-icons-png.flaticon.com/512/888/888857.png',
        rank: '1',
        country: 'IN, GLOBAL',
        validators: 'email',
        hints: JSON.stringify({ email: 'Enter email to receive Google Play Redeem code' }),
        autoPayment: 'true'
    },
    amazon: {
        methodId: 'amazon',
        title: 'Amazon Pay',
        symbol: '₹',
        image: 'https://cdn-icons-png.flaticon.com/512/5968/5968208.png',
        rank: '2',
        country: 'IN, GLOBAL',
        validators: 'email',
        hints: JSON.stringify({ email: 'Enter email to receive Amazon Pay gift card' }),
        autoPayment: 'true'
    },
    flipkart: {
        methodId: 'flipkart',
        title: 'Flipkart Voucher',
        symbol: '₹',
        image: 'https://cdn-icons-png.flaticon.com/512/5968/5968532.png',
        rank: '3',
        country: 'IN, GLOBAL',
        validators: 'email',
        hints: JSON.stringify({ email: 'Enter email to receive Flipkart gift card' }),
        autoPayment: 'true'
    },
    upi: {
        methodId: 'upi',
        title: 'UPI Transfer',
        symbol: '₹',
        image: 'https://cdn-icons-png.flaticon.com/512/10101/10101736.png',
        rank: '4',
        country: 'IN',
        validators: 'upiId, name',
        hints: JSON.stringify({ upiId: 'Enter your UPI ID / VPA', name: 'Enter account holder full name' }),
        autoPayment: 'false'
    },
    other: {
        methodId: '',
        title: '',
        symbol: '₹',
        image: '',
        rank: '5',
        country: 'IN, GLOBAL',
        validators: '',
        hints: '{}',
        autoPayment: 'false'
    }
};
var WALLET_PRESETS = window.WALLET_PRESETS;

function openAddWalletMethodModal() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    if (!selectedApp) {
        showAlert('❌ Please select app first');
        return;
    }

    const defaultPreset = WALLET_PRESETS.googleplay;

    const modal = openActionFormModal({
        title: 'Add Payout Method',
        subtitle: `Create a new redeem/payout method for app: ${selectedApp}`,
        submitText: 'Create Method',
        fields: [
            {
                key: 'methodPreset',
                label: 'Payment Method Type (Select Provider)',
                type: 'select',
                value: 'googleplay',
                options: [
                    { value: 'googleplay', label: 'Google Play (PR) - Gift Card Code' },
                    { value: 'amazon', label: 'Amazon Pay (AR) - Gift Card' },
                    { value: 'flipkart', label: 'Flipkart (FP) - Gift Voucher' },
                    { value: 'upi', label: 'UPI - Direct Instant / Manual' },
                    { value: 'other', label: 'Other / Custom Method...' }
                ],
                required: true
            },
            {
                key: 'customMethodId',
                label: 'Custom Method ID (Only for Other)',
                type: 'text',
                placeholder: 'e.g. paytm, paypal, crypto',
                value: '',
                required: false
            },
            { key: 'title', label: 'Display Title', type: 'text', placeholder: 'e.g. Google Play', required: true, value: defaultPreset.title },
            { key: 'symbol', label: 'Currency Symbol', type: 'text', placeholder: 'e.g. ₹', required: true, value: defaultPreset.symbol },
            {
                key: 'autoPayment',
                label: 'Auto Payment (Instant Automated Voucher/Payout)',
                type: 'select',
                value: defaultPreset.autoPayment,
                options: [
                    { value: 'true', label: 'Instant Automatic' },
                    { value: 'false', label: 'Manual Approval' }
                ]
            },
            { key: 'rank', label: 'Display Rank (Order)', type: 'number', placeholder: 'e.g. 1', required: true, value: defaultPreset.rank }
        ],
        onSubmit: async (values) => {
            let methodId = '';
            const presetKey = values.methodPreset || 'googleplay';
            const presetData = WALLET_PRESETS[presetKey] || WALLET_PRESETS.other;

            if (presetKey === 'other') {
                methodId = String(values.customMethodId || '').trim().toLowerCase().replace(/[^a-z0-9_-]/g, '');
                if (!methodId) {
                    showAlert('❌ Please enter a valid Custom Method ID for "Other"');
                    return;
                }
            } else {
                methodId = presetKey;
            }

            let hints = {};
            if (presetData.hints) {
                try {
                    hints = JSON.parse(presetData.hints);
                } catch (e) {
                    hints = {};
                }
            }

            const payload = {
                selectedApp,
                methodId,
                title: String(values.title || presetData.title || '').trim(),
                symbol: String(values.symbol || presetData.symbol || '₹').trim(),
                image: String(presetData.image || '').trim(),
                rank: Number(values.rank) || 0,
                country: parseCsvInput(presetData.country || 'IN, GLOBAL'),
                ex_country: [],
                validators: parseCsvInput(presetData.validators || ''),
                hints,
                enabled: true,
                autoPayment: String(values.autoPayment || presetData.autoPayment || 'false') === 'true'
            };

            try {
                const res = await fetch('/wallet-catalog/method', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                const json = await res.json();
                if (!res.ok || !json.success) throw new Error(json.message || 'Failed to create method');

                closeModal('action-form-modal');
                showAlert(`✅ Payout method "${payload.title}" (${methodId}) created successfully!`, () => {
                    refreshWalletManager();
                });
            } catch (err) {
                showAlert(`❌ Error: ${err.message || 'Operation failed'}`);
            }
        }
    });

    if (modal) {
        const fieldsWrap = document.getElementById('action-form-fields');
        const presetSelect = fieldsWrap?.querySelector('[data-action-field="methodPreset"]');
        const customIdContainer = fieldsWrap?.querySelector('[data-field-container="customMethodId"]');
        const titleInput = fieldsWrap?.querySelector('[data-action-field="title"]');
        const symbolInput = fieldsWrap?.querySelector('[data-action-field="symbol"]');
        const rankInput = fieldsWrap?.querySelector('[data-action-field="rank"]');
        const autoPaymentSelect = fieldsWrap?.querySelector('[data-action-field="autoPayment"]');

        const updateFieldsForPreset = (val) => {
            const data = WALLET_PRESETS[val] || WALLET_PRESETS.other;
            if (customIdContainer) {
                customIdContainer.style.display = val === 'other' ? 'grid' : 'none';
            }
            if (val !== 'other') {
                if (titleInput) titleInput.value = data.title;
                if (symbolInput) symbolInput.value = data.symbol;
                if (rankInput) rankInput.value = data.rank;
                if (autoPaymentSelect) autoPaymentSelect.value = data.autoPayment;
            }
        };

        if (presetSelect) {
            presetSelect.addEventListener('change', (e) => {
                updateFieldsForPreset(e.target.value);
            });
            updateFieldsForPreset(presetSelect.value);
        }
    }
}

let appDataEditorState = {
    appData: {},
    offersSettings: {},
    referralSettings: {},
};
let appDataActiveTab = 'app';

let appStatsState = {
    range: 'today',
    startDate: '',
    endDate: '',
};

function isPlainObjectClient(value) {
    return !!value && typeof value === 'object' && !Array.isArray(value);
}

function toDateTimeLocalInputValue(value) {
    if (!value) return '';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '';

    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    const hh = String(date.getHours()).padStart(2, '0');
    const mm = String(date.getMinutes()).padStart(2, '0');
    return `${y}-${m}-${d}T${hh}:${mm}`;
}

function setAppDataStatus(message, type = 'info') {
    const status = document.getElementById('app-data-status');
    if (!status) return;
    status.className = `app-data-status ${type}`;
    status.textContent = String(message || '');
}

async function fetchAppDataConfig(selectedApp) {
    const res = await fetch(`/app-data-config?app=${encodeURIComponent(selectedApp)}`);
    const json = await res.json();

    if (!res.ok || !json.success) {
        throw new Error(json.message || 'Failed to load app data');
    }

    return {
        appData: isPlainObjectClient(json.appData) ? json.appData : {},
        offersSettings: isPlainObjectClient(json.offersSettings) ? json.offersSettings : {},
        referralSettings: isPlainObjectClient(json.referralSettings) ? json.referralSettings : {},
    };
}

async function openAppDataManager() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    if (!selectedApp) {
        showAlert('❌ Please select app first');
        return;
    }

    openModal('app-data-modal');
    await refreshAppDataManager();
}

function closeAppDataModal() {
    closeModal('app-data-modal');
}

async function refreshAppDataManager() {
    const modalBody = document.getElementById('app-data-editor-container') || document.getElementById('app-data-modal-body');
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    if (!selectedApp) {
        modalBody.innerHTML = '<div class="app-data-placeholder error">Please select app first.</div>';
        return;
    }

    modalBody.innerHTML = '<div class="app-data-placeholder loading">Loading app data...</div>';

    try {
        appDataEditorState = await fetchAppDataConfig(selectedApp);
        renderAppDataEditor(selectedApp);
    } catch (err) {
        modalBody.innerHTML = `<div class="app-data-placeholder error">${escapeWalletHtml(err.message || 'Failed to load app data')}</div>`;
    }
}

function normalizeAppDataTabKey(tab) {
    return ['app', 'adsConfig', 'offers', 'referral', 'welcomePopup', 'howToUse', 'banners', 'manageScreens'].includes(String(tab || '').trim()) ? String(tab).trim() : 'app';
}

function switchAppDataTab(tab) {
    appDataActiveTab = normalizeAppDataTabKey(tab);
    const modalBody = document.getElementById('app-data-editor-container') || document.getElementById('app-data-modal-body');
    if (!modalBody) return;

    modalBody.querySelectorAll('.app-data-tab-btn').forEach((btn) => {
        const isActive = String(btn.dataset.tab || '') === appDataActiveTab;
        btn.classList.toggle('active', isActive);
    });

    modalBody.querySelectorAll('.app-data-tab-panel').forEach((panel) => {
        const isActive = String(panel.dataset.tab || '') === appDataActiveTab;
        panel.classList.toggle('active', isActive);
    });
}

const ALL_APP_ROUTES = [
    // --- Core / Home Features ---
    { value: 'app://dashboard', label: 'Dashboard / Home' },
    { value: 'app://daily_tasks', label: 'Daily Tasks Screen' },
    { value: 'app://daily_task_history', label: 'Daily Task History Screen' },
    { value: 'app://daily_task_details', label: 'Daily Task Details Screen' },
    { value: 'app://daily_challenge', label: 'Daily Challenge Screen' },
    { value: 'app://battle_arena', label: 'Battle Arena (Splash)' },
    { value: 'app://battle_arena_game', label: 'Battle Arena (Game Room)' },
    { value: 'app://battle_leaderboard', label: 'Battle Leaderboard Screen' },
    { value: 'app://battle_leaderboard_history', label: 'Battle Leaderboard History' },
    { value: 'app://my_matches', label: 'Battle My Matches Screen' },
    { value: 'app://diamond_catch', label: 'Diamond Catch Screen' },
    { value: 'app://follow', label: 'Follow & Earn Screen' },
    { value: 'app://more_apps', label: 'More Apps / Installs Screen' },
    { value: 'app://super_offer', label: 'Super Offer Screen' },
    { value: 'app://offerwall', label: 'Offerwall Screen' },
    { value: 'app://play_games', label: 'Play Games Screen' },
    { value: 'app://watch_earn', label: 'Watch & Earn Screen' },
    { value: 'app://watch_earn_category', label: 'Watch & Earn Category Screen' },
    { value: 'app://watch_earn_details', label: 'Watch & Earn Details Screen' },
    { value: 'app://read_earn', label: 'Read & Earn Screen' },
    { value: 'app://read_earn_verification', label: 'Read & Earn Verification' },
    { value: 'app://giveaway', label: 'Giveaway Screen' },
    { value: 'app://giveaway_details', label: 'Giveaway Details Screen' },
    { value: 'app://promo_code', label: 'Promo Code Screen' },
    { value: 'app://level_program', label: 'Level Program / Refer Screen' },
    { value: 'app://leaderboard', label: 'Leaderboard / Rank Screen' },

    // --- Wallet & Transactions ---
    { value: 'app://wallet', label: 'Wallet Screen' },
    { value: 'app://withdrawal_history', label: 'Withdrawal History' },
    { value: 'app://withdrawal_history_details', label: 'Withdrawal History Details' },
    { value: 'app://task_history', label: 'Task History Screen' },

    // --- Profile & Help ---
    { value: 'app://notifications', label: 'Notifications Screen' },
    { value: 'app://services', label: 'Services Screen' },
    { value: 'app://contact_support', label: 'Contact Support Screen' },
    { value: 'app://how_to_use', label: 'How To Use Screen' },
    { value: 'app://change_language', label: 'Change Language Screen' },
    { value: 'app://edit_account_details', label: 'Edit Account Details' },

    // --- Onboarding & Auth ---
    { value: 'app://splash', label: 'Splash Screen' },
    { value: 'app://onboarding', label: 'Onboarding Screen' },
    { value: 'app://authentication', label: 'Authentication Screen' },
    { value: 'app://account_details', label: 'Account Details Screen' },

    // --- System & Status Screens ---
    { value: 'app://something_went_wrong', label: '1. Something Went Wrong Screen' },
    { value: 'app://vpn', label: '2. VPN Screen' },
    { value: 'app://update', label: '3. Update Screen' },
    { value: 'app://maintenance', label: '4. Maintenance Screen' },
    { value: 'app://unsecure_device', label: '5. Unsecure Device Screen' },
    { value: 'app://account_blocked', label: '6. Account Blocked Screen' },
    { value: 'app://no_internet', label: '7. No Internet Screen' },
    { value: 'app://account_deleted', label: '8. Account Deleted Screen' }
];

const SCREEN_BANNER_DEFINITIONS = {
    allScreens: {
        key: 'allScreens',
        name: '🌟 All Screens (Global / Everywhere)',
        icon: 'fa-solid fa-globe',
        desc: 'Broadcast to ALL screens where banners are placed across the mobile app'
    },
    redeemScreen: {
        key: 'redeemScreen',
        name: 'Redeem / Wallet Screen',
        icon: 'fa-solid fa-wallet',
        desc: 'Displayed in Wallet/Redeem screen right above payout methods'
    },
    superOfferScreen: {
        key: 'superOfferScreen',
        name: 'Super Offer Screen',
        icon: 'fa-solid fa-bolt',
        desc: 'Displayed in Super Offer screen right below mission stats'
    },
    playGamesScreen: {
        key: 'playGamesScreen',
        name: 'Play Games Screen',
        icon: 'fa-solid fa-gamepad',
        desc: 'Displayed on Play Games screen above games list'
    },
    readEarnScreen: {
        key: 'readEarnScreen',
        name: 'Read & Earn Screen',
        icon: 'fa-solid fa-book-open',
        desc: 'Displayed on Read & Earn screen above articles list'
    },
    watchVideoScreen: {
        key: 'watchVideoScreen',
        name: 'Watch Video Screen',
        icon: 'fa-solid fa-play',
        desc: 'Displayed on Watch Video screen above video categories'
    },
    offerwallScreen: {
        key: 'offerwallScreen',
        name: 'Offerwalls Screen',
        icon: 'fa-solid fa-briefcase',
        desc: 'Displayed on CPA Offerwalls & Surveys screen'
    },
    battleScreen: {
        key: 'battleScreen',
        name: 'Battle Arena Screen',
        icon: 'fa-solid fa-trophy',
        desc: 'Displayed on Battle Arena screen'
    },
    promoCodeScreen: {
        key: 'promoCodeScreen',
        name: 'Promo Code Screen',
        icon: 'fa-solid fa-ticket',
        desc: 'Displayed on Promo Code redemption screen'
    },
    dailyChallengeScreen: {
        key: 'dailyChallengeScreen',
        name: 'Daily Challenge Screen',
        icon: 'fa-solid fa-calendar-check',
        desc: 'Displayed on Daily Challenge & streak screen'
    },
    leaderboardScreen: {
        key: 'leaderboardScreen',
        name: 'Leaderboard Screen',
        icon: 'fa-solid fa-ranking-star',
        desc: 'Displayed on Main Leaderboard screen'
    },
    inviteScreen: {
        key: 'inviteScreen',
        name: 'Invite / Refer Screen',
        icon: 'fa-solid fa-user-plus',
        desc: 'Displayed on Refer & Earn / Invite Friends screen'
    }
};

function getScreenBannerCardHtml(screenKey, b = {}) {
    const sc = SCREEN_BANNER_DEFINITIONS[screenKey] || {
        key: screenKey,
        name: screenKey,
        icon: 'fa-solid fa-mobile-screen',
        desc: 'Custom in-app screen banner'
    };
    const clickUrlVal = String(b.clickUrl || '').trim();
    const isAppRoute = clickUrlVal.startsWith('app://');
    const isGlobal = screenKey === 'allScreens';

    return `
        <div class="screen-banner-card" data-screen="${sc.key}" style="background: #ffffff; border: 1.5px solid ${isGlobal ? '#f59e0b' : '#dbe5f3'}; border-radius: 10px; padding: 18px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); position: relative; ${isGlobal ? 'background: linear-gradient(180deg, #fffdf5 0%, #ffffff 50px);' : ''}">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; flex-wrap: wrap; gap: 10px;">
                <div>
                    <h5 style="margin: 0; font-size: 15px; color: #1e293b; display: flex; align-items: center; gap: 8px;">
                        <i class="${sc.icon}" style="color: ${isGlobal ? '#d97706' : '#7c3aed'}; font-size: 16px;"></i> ${sc.name}
                        ${isGlobal ? `<span style="background: #fef3c7; color: #92400e; border: 1px solid #fde68a; padding: 2px 8px; border-radius: 6px; font-size: 10.5px; font-weight: 800; text-transform: uppercase;">Global: Applies Everywhere</span>` : ''}
                    </h5>
                    <span style="font-size: 12px; color: #64748b;">${sc.desc}</span>
                </div>
                <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                    <div class="screen-banner-click-badge" id="banner-total-clicks-badge-${sc.key}" style="display: inline-flex; align-items: center; gap: 6px; background: #f0fdf4; border: 1px solid #bbf7d0; color: #166534; padding: 5px 11px; border-radius: 6px; font-size: 12px; font-weight: 700; box-shadow: 0 1px 2px rgba(0,0,0,0.03);" title="Total All-Time Clicks">
                        <i class="fa-solid fa-arrow-pointer" style="color: #16a34a; font-size: 11px;"></i>
                        <span>Clicks: <strong id="banner-total-clicks-val-${sc.key}">0</strong></span>
                    </div>
                    <button type="button" class="screen-banner-stats-btn" onclick="openScreenBannerStatsModal('${sc.key}', '${escapeWalletHtml(sc.name)}')" title="View Click Statistics" style="background: linear-gradient(135deg, #0284c7 0%, #0369a1 100%); color: white; border: none; padding: 6px 13px; border-radius: 6px; font-weight: 700; font-size: 12px; cursor: pointer; display: flex; align-items: center; gap: 6px; box-shadow: 0 2px 4px rgba(2, 132, 199, 0.25); transition: transform 0.15s ease;" onmouseover="this.style.transform='translateY(-1px)'" onmouseout="this.style.transform='translateY(0)'">
                        <i class="fa-solid fa-chart-line"></i> Stats
                    </button>
                    <label style="font-size: 13px; font-weight: 600; color: #334155; margin-left: 4px;">Status:</label>
                    <select class="screen-banner-enabled" style="padding: 6px 12px; border: 1px solid #cbd5e1; border-radius: 6px; background: white; font-weight: bold;">
                        <option value="true" ${b.enabled !== false ? 'selected' : ''}>Enabled</option>
                        <option value="false" ${b.enabled === false ? 'selected' : ''}>Disabled</option>
                    </select>
                    <button type="button" onclick="removeScreenBannerCard('${sc.key}')" style="background: #fee2e2; color: #dc2626; border: 1px solid #fca5a5; padding: 6px 12px; border-radius: 6px; font-weight: 700; font-size: 12px; cursor: pointer; display: flex; align-items: center; gap: 5px; transition: background 0.15s ease;" onmouseover="this.style.background='#fecaca'" onmouseout="this.style.background='#fee2e2'" title="Remove banner from this screen">
                        <i class="fa-solid fa-trash-can"></i> Remove
                    </button>
                </div>
            </div>

            <div style="display: grid; grid-template-columns: 1.5fr 1fr 1.5fr; gap: 14px; align-items: start;">
                <div>
                    <label style="display: block; font-weight: 600; font-size: 12.5px; margin-bottom: 5px; color: #334155;">
                        Banner Image URL (700x200 px)
                    </label>
                    <input type="text" class="screen-banner-imageUrl" value="${escapeWalletHtml(b.imageUrl || '')}" placeholder="https://.../banner_700x200.png" oninput="updateScreenBannerPreview(this)" style="width: 100%; padding: 8px 12px; border: 1px solid #cbd5e1; border-radius: 6px; box-sizing: border-box;" />
                    <div class="screen-banner-preview" style="margin-top: 8px; max-width: 320px; aspect-ratio: 700/200; background: #f8fafc; border: 1px dashed #cbd5e1; border-radius: 8px; overflow: hidden; display: flex; align-items: center; justify-content: center; position: relative;">
                        ${b.imageUrl ? `<img src="${escapeWalletHtml(b.imageUrl)}" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.style.display='none'" />${!isAppRoute ? `<div style="position: absolute; top: 6px; right: 6px; background: rgba(0,0,0,0.65); color: white; border-radius: 50%; width: 20px; height: 20px; display: flex; align-items: center; justify-content: center; font-size: 9px; font-weight: bold; border: 1px solid rgba(255,255,255,0.6);">AD</div>` : ''}` : `<span style="font-size: 11px; color: #94a3b8;"><i class="fa-regular fa-image"></i> 700 x 200 Preview</span>`}
                    </div>
                </div>

                <div>
                    <label style="display: block; font-weight: 600; font-size: 12.5px; margin-bottom: 5px; color: #334155;">
                        Target Type
                    </label>
                    <select class="screen-banner-targetType" onchange="toggleScreenBannerClickType(this)" style="width: 100%; padding: 8px 12px; border: 1px solid #cbd5e1; border-radius: 6px; background: white;">
                        <option value="web" ${!isAppRoute ? 'selected' : ''}>External / Web URL</option>
                        <option value="app" ${isAppRoute ? 'selected' : ''}>In-App Screen</option>
                    </select>
                </div>

                <div>
                    <div class="screen-banner-web-group" style="display: ${isAppRoute ? 'none' : 'block'};">
                        <label style="display: block; font-weight: 600; font-size: 12.5px; margin-bottom: 5px; color: #334155;">
                            Web Target / Redirect URL
                        </label>
                        <input type="text" class="screen-banner-webUrl" value="${isAppRoute ? '' : escapeWalletHtml(clickUrlVal)}" placeholder="https://example.com/offer" style="width: 100%; padding: 8px 12px; border: 1px solid #cbd5e1; border-radius: 6px; box-sizing: border-box;" />
                    </div>
                    <div class="screen-banner-app-group" style="display: ${isAppRoute ? 'block' : 'none'};">
                        <label style="display: block; font-weight: 600; font-size: 12.5px; margin-bottom: 5px; color: #334155;">
                            Select In-App Screen
                        </label>
                        <select class="screen-banner-appRoute" style="width: 100%; padding: 8px 12px; border: 1px solid #cbd5e1; border-radius: 6px; background: white; box-sizing: border-box;">
                            ${getAppRoutesOptionsHtml(clickUrlVal)}
                        </select>
                    </div>
                </div>
            </div>
        </div>
    `;
}

function getAppRoutesOptionsHtml(selectedValue) {
    return ALL_APP_ROUTES.map(r =>
        `<option value="${r.value}" ${selectedValue === r.value ? 'selected' : ''}>${r.label}</option>`
    ).join('');
}

function addHomeBannerRow() {
    const list = document.getElementById('home-banners-list');
    if (!list) return;

    const row = document.createElement('div');
    row.className = 'home-banner-row';
    row.style = 'background: #f8fafc; padding: 15px; border-radius: 8px; margin-bottom: 12px; border: 1px solid #dbe5f3; display: flex; flex-direction: column; gap: 8px;';
    const index = list.children.length + 1;
    row.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: center;">
            <span style="font-weight: bold; color: #1e3a8a;">Banner #${index} (New)</span>
            <button type="button" class="app-data-row-remove" onclick="this.closest('.home-banner-row')?.remove()" style="background: #ef4444; color: white; border: none; padding: 4px 8px; border-radius: 4px; cursor: pointer; font-size: 12px;">Remove</button>
        </div>
        <div style="display: grid; grid-template-columns: 1.5fr 1fr 1.5fr 0.8fr; gap: 10px;">
            <label style="display: flex; flex-direction: column; gap: 4px; font-weight: 500; font-size: 13px;">Image URL (Firebase or Web URL)
                <input class="home-banner-imageUrl" type="text" value="" placeholder="https://..." style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px;" />
            </label>
            <label style="display: flex; flex-direction: column; gap: 4px; font-weight: 500; font-size: 13px;">Target Type
                <select class="home-banner-targetType" onchange="toggleBannerClickType(this)" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; background: white;">
                    <option value="web" selected>Web URL</option>
                    <option value="app">In-App Screen</option>
                </select>
            </label>
            <label class="banner-target-web-group" style="display: flex; flex-direction: column; gap: 4px; font-weight: 500; font-size: 13px;">Click Target / URL
                <input class="home-banner-webUrl" type="text" value="" placeholder="https://..." style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; width: 100%;" />
            </label>
            <label class="banner-target-app-group" style="display: none; flex-direction: column; gap: 4px; font-weight: 500; font-size: 13px;">Select Screen
                <select class="home-banner-appRoute" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; background: white; width: 100%;">
                    ${getAppRoutesOptionsHtml('')}
                </select>
            </label>
            <label style="display: flex; flex-direction: column; gap: 4px; font-weight: 500; font-size: 13px;">Status
                <select class="home-banner-enabled" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; background: white;">
                    <option value="true" selected>Enabled</option>
                    <option value="false">Disabled</option>
                </select>
            </label>
        </div>
    `;

    list.appendChild(row);
    row.querySelector('.home-banner-imageUrl')?.focus();
}

function toggleBannerClickType(selectEl) {
    const row = selectEl.closest('.home-banner-row');
    if (!row) return;
    const type = selectEl.value;
    const webGroup = row.querySelector('.banner-target-web-group');
    const appGroup = row.querySelector('.banner-target-app-group');
    if (type === 'app') {
        if (webGroup) webGroup.style.display = 'none';
        if (appGroup) appGroup.style.display = 'flex';
    } else {
        if (webGroup) webGroup.style.display = 'flex';
        if (appGroup) appGroup.style.display = 'none';
    }
}

function getExtraFieldsHtml(provider, config = {}) {
    const cleanName = String(provider || '').toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '');
    let inputs = '';

    const standardKeys = [
        'pubscale', 'growdeck', 'playtimeads', 'tapjoy', 'notik', 'cpidroid',
        'taskwall', 'adjoe', 'timewall', 'bitlabs', 'cpxresearch', 'pollfish',
        'inbrain', 'tapresearch', 'theoremreach', 'yuno', 'sushiads', 'wannads',
        'lootably', 'adscendmedia'
    ];

    const isCustom = cleanName === 'custom' || config.customName || !standardKeys.includes(cleanName);

    if (isCustom) {
        inputs += `
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; width:100%;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">Custom Provider Key / Name *:</label>
                <input type="text" class="app-data-offer-provider-custom" value="${escapeWalletHtml(config.customName || config.provider || provider || '')}" placeholder="e.g. MyCustomOffer" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px; width:100%;" />
            </div>
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; width:100%;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">Icon / Logo URL (Firebase or Web URL):</label>
                <input type="text" class="app-data-offer-iconurl" value="${escapeWalletHtml(config.iconUrl || '')}" placeholder="https://... (or leave empty)" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px; width:100%;" />
            </div>
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; width:100%;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">URL *:</label>
                <input type="text" class="app-data-offer-url" value="${escapeWalletHtml(config.url || '')}" placeholder="https://... (Leave empty to use .env key)" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px; width:100%;" />
                <span style="font-size:10px; color:#64748b; font-weight:bold; margin-top:2px;">Placeholders allowed: {USER_ID}, {USER_EMAIL}, {DEVICE_ID}, {USER_GAID}</span>
            </div>
        `;
    } else if (cleanName === 'pubscale' || cleanName === 'cpxresearch') {
        inputs += `
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; flex:1; min-width:200px;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">App ID *:</label>
                <input type="text" class="app-data-offer-appid" value="${escapeWalletHtml(config.appId || '')}" placeholder="Enter App ID (Leave empty to use .env key)" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px;" />
            </div>
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; flex:1; min-width:200px;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">Secret Key / Key (Optional):</label>
                <input type="text" class="app-data-offer-secretkey" value="${escapeWalletHtml(config.secretKey || '')}" placeholder="Enter Key (Leave empty to use .env key)" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px;" />
            </div>
        `;
    } else if (cleanName === 'growdeck') {
        inputs += `
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; flex:1; min-width:200px;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">App ID *:</label>
                <input type="text" class="app-data-offer-appid" value="${escapeWalletHtml(config.appId || '')}" placeholder="Enter App ID (Leave empty to use .env key)" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px;" />
            </div>
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; flex:1; min-width:200px;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">Secret Key *:</label>
                <input type="text" class="app-data-offer-secretkey" value="${escapeWalletHtml(config.secretKey || '')}" placeholder="Enter Secret Key (Leave empty to use .env key)" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px;" />
            </div>
        `;
    } else if (cleanName === 'bitlabs') {
        inputs += `
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; flex:1; min-width:200px;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">Token *:</label>
                <input type="text" class="app-data-offer-token" value="${escapeWalletHtml(config.token || '')}" placeholder="Enter Token (Leave empty to use .env key)" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px;" />
            </div>
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; flex:1; min-width:200px;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">Secret Key / Key (Optional):</label>
                <input type="text" class="app-data-offer-secretkey" value="${escapeWalletHtml(config.secretKey || '')}" placeholder="Enter Key (Leave empty to use .env key)" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px;" />
            </div>
        `;
    } else if (cleanName === 'playtimeads') {
        inputs += `
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; flex:1; min-width:200px;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">App Key *:</label>
                <input type="text" class="app-data-offer-appkey" value="${escapeWalletHtml(config.appKey || '')}" placeholder="Enter App Key (Leave empty to use .env key)" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px;" />
            </div>
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; flex:1; min-width:200px;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">Secret Key / Key (Optional):</label>
                <input type="text" class="app-data-offer-secretkey" value="${escapeWalletHtml(config.secretKey || '')}" placeholder="Enter Key (Leave empty to use .env key)" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px;" />
            </div>
        `;
    } else if (['timewall', 'theoremreach', 'wannads', 'taskwall', 'sushiads'].includes(cleanName)) {
        inputs += `
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; width:100%;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">Webview / Offerwall URL *:</label>
                <input type="text" class="app-data-offer-url" value="${escapeWalletHtml(config.url || '')}" placeholder="https://... (Leave empty to use .env key)" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px; width:100%;" />
                <span style="font-size:10px; color:#64748b; font-weight:bold; margin-top:2px;">Placeholders allowed: {USER_ID}, {USER_EMAIL}, {DEVICE_ID}, {USER_GAID}</span>
            </div>
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; width:100%;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">API Key / Password (Optional):</label>
                <input type="text" class="app-data-offer-secretkey" value="${escapeWalletHtml(config.secretKey || config.apiKey || '')}" placeholder="Enter API Key / Password (Leave empty to use .env key)" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px; width:100%;" />
            </div>
        `;
    } else {
        inputs += `
            <div class="offer-field-wrap" style="display:flex; flex-direction:column; gap:4px; width:100%;">
                <label style="font-weight:bold; font-size:12px; color:#475569;">Webview / Offerwall URL *:</label>
                <input type="text" class="app-data-offer-url" value="${escapeWalletHtml(config.url || '')}" placeholder="https://... (Leave empty to use .env key)" style="padding:6px 10px; border:1px solid #cbd5e1; border-radius:4px; width:100%;" />
                <span style="font-size:10px; color:#64748b; font-weight:bold; margin-top:2px;">Placeholders allowed: {USER_ID}, {USER_EMAIL}, {DEVICE_ID}, {USER_GAID}</span>
            </div>
        `;
    }
    return `<div class="offer-extra-fields" style="display:flex; gap:12px; margin-top:8px; flex-wrap:wrap;">${inputs}</div>`;
}
window.getExtraFieldsHtml = getExtraFieldsHtml;

const OFFER_PROVIDERS_LIST = [
    { value: 'PubScale', label: 'PubScale (App ID)' },
    { value: 'CPXResearch', label: 'CPX Research (App ID)' },
    { value: 'GrowDeck', label: 'GrowDeck (App ID + Secret Key)' },
    { value: 'BitLabs', label: 'BitLabs (Token)' },
    { value: 'PlaytimeAds', label: 'Playtime Ads (App Key)' },
    { value: 'Tapjoy', label: 'Tapjoy (URL)' },
    { value: 'Notik', label: 'Notik (URL)' },
    { value: 'CPIDroid', label: 'CPIDroid (URL)' },
    { value: 'Taskwall', label: 'Taskwall (URL)' },
    { value: 'Adjoe', label: 'Adjoe (URL)' },
    { value: 'TimeWall', label: 'TimeWall (URL)' },
    { value: 'Wannads', label: 'Wannads (URL)' },
    { value: 'Lootably', label: 'Lootably (URL)' },
    { value: 'SushiAds', label: 'SushiAds (URL)' },
    { value: 'TheoremReach', label: 'TheoremReach (URL / App ID)' },
    { value: 'Custom', label: 'Custom / Other Provider (Name + URL)' },
];

function onOfferProviderSelectChange(selectEl) {
    const row = selectEl.closest('.app-data-offer-row');
    if (!row) return;
    const provider = selectEl.value;
    row.dataset.provider = provider;

    const wrap = row.querySelector('.offer-extra-fields-wrap');
    if (wrap) {
        wrap.innerHTML = getExtraFieldsHtml(provider, {});
    }
}
window.onOfferProviderSelectChange = onOfferProviderSelectChange;

function addOfferProviderRow() {
    const list = document.querySelector('.app-data-offer-list');
    if (!list) return;

    const empty = list.querySelector('.app-data-empty');
    if (empty) empty.remove();

    const optionsHtml = OFFER_PROVIDERS_LIST.map(p =>
        `<option value="${p.value}">${p.label}</option>`
    ).join('');

    const defaultProvider = OFFER_PROVIDERS_LIST[0].value;

    const row = document.createElement('div');
    row.className = 'app-data-offer-row is-new';
    row.dataset.provider = defaultProvider;
    row.style = 'background: #f8fafc; padding: 12px 16px; border-radius: 8px; margin-bottom: 12px; border: 1px solid #cbd5e1;';
    row.innerHTML = `
        <div class="app-data-offer-main" style="display: flex; gap: 12px; align-items: center; flex-wrap: wrap;">
            <div style="display: flex; flex-direction: column; gap: 2px;">
                <span style="font-size: 11px; font-weight: bold; color: #475569;">Select Provider *</span>
                <select class="app-data-offer-provider-select" onchange="window.onOfferProviderSelectChange(this)" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 6px; font-weight: bold; background: white; min-width: 200px;">
                    ${optionsHtml}
                </select>
            </div>
            <div style="display: flex; flex-direction: column; gap: 2px;">
                <span style="font-size: 11px; font-weight: bold; color: #475569;">Status</span>
                <select class="app-data-offer-enabled" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 6px; background: white;">
                    <option value="true" selected>Enabled</option>
                    <option value="false">Disabled</option>
                </select>
            </div>
            <div style="display: flex; flex-direction: column; gap: 2px;">
                <span style="font-size: 11px; font-weight: bold; color: #475569;">Rank</span>
                <input type="number" class="app-data-offer-rank" min="0" value="1" placeholder="Rank" style="width: 70px; padding: 8px; border: 1px solid #cbd5e1; border-radius: 6px;" />
            </div>
            <span class="app-data-row-meta" style="background: #3b82f6; color: white; padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: bold; margin-top: 14px;">New</span>
            <button type="button" class="app-data-row-remove" onclick="this.closest('.app-data-offer-row')?.remove()" style="margin-left: auto; background: #ef4444; color: white; border: none; padding: 6px 12px; border-radius: 6px; cursor: pointer; font-size: 12px; font-weight: bold; margin-top: 14px;">Remove</button>
        </div>
        <div class="offer-extra-fields-wrap" style="margin-top: 10px;">
            ${getExtraFieldsHtml(defaultProvider, {})}
        </div>
    `;

    list.appendChild(row);
}
window.addOfferProviderRow = addOfferProviderRow;

function addReferralCategoryRow() {
    const list = document.querySelector('.app-data-ref-list');
    if (!list) return;

    const categories = [
        'Offerwall',
        'Survey',
        'Watch & Earn',
        'Read & Earn',
        'Daily Tasks',
        'Play Games',
        'Promo Code',
        'Giveaway',
        'Super Offer'
    ];

    const optionsHtml = categories.map(cat => `<option value="${cat}">${cat}</option>`).join('');

    const row = document.createElement('div');
    row.className = 'app-data-ref-row is-new';
    row.innerHTML = `
        <select class="app-data-ref-category" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; background: white;">
            ${optionsHtml}
        </select>
        <input type="number" class="app-data-ref-first" min="0" value="0" />
        <input type="number" class="app-data-ref-second" min="0" value="0" />
        <input type="number" class="app-data-ref-third" min="0" value="0" />
        <button type="button" class="app-data-row-remove" onclick="this.closest('.app-data-ref-row')?.remove()">Remove</button>
    `;

    list.appendChild(row);
    row.querySelector('.app-data-ref-category')?.focus();
}

function toggleUrlConfigValueType(selectEl) {
    const row = selectEl.closest('.app-data-url-row');
    if (!row) return;
    const type = selectEl.value;
    const customInput = row.querySelector('.app-data-url-value-custom');
    const selectDropdown = row.querySelector('.app-data-url-value-select');
    if (type === 'select') {
        if (customInput) customInput.style.display = 'none';
        if (selectDropdown) selectDropdown.style.display = 'block';
    } else {
        if (customInput) customInput.style.display = 'block';
        if (selectDropdown) selectDropdown.style.display = 'none';
    }
}

function addUrlConfigRow() {
    const list = document.querySelector('.app-data-url-list');
    if (!list) return;

    const row = document.createElement('div');
    row.className = 'app-data-url-row is-new';
    row.innerHTML = `
        <input type="text" class="app-data-url-key" placeholder="Key (e.g. supportMail)" />
        <div style="display: grid; grid-template-columns: 120px 1fr; gap: 8px; width: 100%;">
            <select class="app-data-url-type" onchange="toggleUrlConfigValueType(this)" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; background: white; width: 100%;">
                <option value="custom" selected>Custom URL</option>
                <option value="select">Select Screen</option>
            </select>
            <input type="text" class="app-data-url-value-custom" placeholder="Enter url" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; width: 100%; box-sizing: border-box;" />
            <select class="app-data-url-value-select" style="display: none; padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; background: white; width: 100%; box-sizing: border-box;">
                ${getAppRoutesOptionsHtml('')}
            </select>
        </div>
        <button type="button" class="app-data-row-remove" onclick="this.closest('.app-data-url-row')?.remove()" style="background: #ef4444; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer; font-size: 12px; font-weight: bold; width: 120px; text-align: center;">Remove</button>
    `;

    list.appendChild(row);
    row.querySelector('.app-data-url-key')?.focus();
}

function renderAppDataEditor(selectedApp) {
    const modalBody = document.getElementById('app-data-editor-container') || document.getElementById('app-data-modal-body');
    if (!modalBody) return;
    const appData = isPlainObjectClient(appDataEditorState.appData) ? appDataEditorState.appData : {};
    const offersSettings = isPlainObjectClient(appDataEditorState.offersSettings) ? appDataEditorState.offersSettings : {};
    const referralSettings = isPlainObjectClient(appDataEditorState.referralSettings) ? appDataEditorState.referralSettings : {};

    const maintenanceConfig = isPlainObjectClient(appData.maintenanceConfig) ? appData.maintenanceConfig : {};
    const streakConfig = isPlainObjectClient(appData.streakConfig) ? appData.streakConfig : {};
    const superOfferConfig = isPlainObjectClient(appData.superOfferConfig) ? appData.superOfferConfig : {};
    const howToUseConfig = isPlainObjectClient(appData.howToUseConfig) ? appData.howToUseConfig : {};
    const updateConfig = isPlainObjectClient(appData.updateConfig) ? appData.updateConfig : {};
    const urlConfig = isPlainObjectClient(appData.urlConfig) ? appData.urlConfig : {};
    const homeBanners = Array.isArray(appData.homeBanners) ? appData.homeBanners : [];
    const screenBanners = isPlainObjectClient(appData.screenBanners) ? appData.screenBanners : {};
    const earningConfig = isPlainObjectClient(appData.earningConfig) ? appData.earningConfig : {};
    const playtimeConfig = isPlainObjectClient(appData.playtimeConfig) ? appData.playtimeConfig : {};
    const adsConfig = isPlainObjectClient(appData.adsConfig) ? appData.adsConfig : {};
    const pendingConfigUpdates = isPlainObjectClient(appData.pendingConfigUpdates) ? appData.pendingConfigUpdates : {};

    const welcomePopup = isPlainObjectClient(appData.welcomePopup) ? appData.welcomePopup : {};
    const streakCoinsValue = Number(streakConfig.coins ?? appData.streakCoins) || 0;
    const pendingKeys = ['superOfferConfig']
        .filter((key) => isPlainObjectClient(pendingConfigUpdates[key]));
    const pendingApplyAt = pendingConfigUpdates.applyAt ? new Date(pendingConfigUpdates.applyAt) : null;
    const hasPending = pendingKeys.length > 0 && pendingApplyAt instanceof Date && !Number.isNaN(pendingApplyAt.getTime());
    const pendingLabel = hasPending
        ? pendingApplyAt.toLocaleString('en-IN', {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
            hour12: true,
            timeZone: 'Asia/Kolkata',
        })
        : '';

    const offersRows = Object.entries(offersSettings)
        .filter(([_, value]) => isPlainObjectClient(value) && Object.prototype.hasOwnProperty.call(value, 'enabled'))
        .sort((a, b) => (Number(a[1].rank) || 0) - (Number(b[1].rank) || 0))
        .map(([provider, config]) => {
            return `
                <div class="app-data-offer-row" data-provider="${escapeWalletHtml(provider)}" style="background: #ffffff; padding: 12px 16px; border-radius: 8px; margin-bottom: 12px; border: 1px solid #cbd5e1;">
                    <div class="app-data-offer-main" style="display: flex; gap: 12px; align-items: center;">
                        <div class="app-data-offer-name" style="font-weight: bold; color: #1e293b; min-width: 150px; font-size: 15px;">${escapeWalletHtml(provider)}</div>
                        <select class="app-data-offer-enabled" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 6px; background: white;">
                            <option value="true" ${config.enabled ? 'selected' : ''}>Enabled</option>
                            <option value="false" ${!config.enabled ? 'selected' : ''}>Disabled</option>
                        </select>
                        <input type="number" class="app-data-offer-rank" min="0" value="${Number(config.rank) || 0}" style="width: 70px; padding: 8px; border: 1px solid #cbd5e1; border-radius: 6px;" />
                        <span class="app-data-row-meta" style="background: #f1f5f9; color: #64748b; padding: 4px 8px; border-radius: 4px; font-size: 11px;">Existing</span>
                        <button type="button" class="app-data-row-remove" onclick="if(confirm('Delete ${escapeWalletHtml(provider)} provider?')) this.closest('.app-data-offer-row')?.remove()" style="margin-left: auto; background: #ef4444; color: white; border: none; padding: 6px 12px; border-radius: 6px; cursor: pointer; font-size: 12px; font-weight: bold;">Remove</button>
                    </div>
                    <div class="offer-extra-fields-wrap">
                        ${getExtraFieldsHtml(provider, config)}
                    </div>
                </div>
            `;
        })
        .join('');

    const firstLevel = isPlainObjectClient(referralSettings.firstLevel) ? referralSettings.firstLevel : {};
    const secondLevel = isPlainObjectClient(referralSettings.secondLevel) ? referralSettings.secondLevel : {};
    const thirdLevel = isPlainObjectClient(referralSettings.thirdLevel) ? referralSettings.thirdLevel : {};

    const defaultCategories = ['Offerwall', 'Survey'];
    const hasConfig = Object.keys(firstLevel).length > 0 || Object.keys(secondLevel).length > 0 || Object.keys(thirdLevel).length > 0;
    const referralCategories = Array.from(
        new Set([
            ...Object.keys(firstLevel),
            ...Object.keys(secondLevel),
            ...Object.keys(thirdLevel),
            ...(hasConfig ? [] : defaultCategories),
        ]),
    ).sort((a, b) => a.localeCompare(b));

    const referralRows = referralCategories.map((category) => `
        <div class="app-data-ref-row" data-category="${escapeWalletHtml(category)}">
            <div class="app-data-ref-name">${escapeWalletHtml(category)}</div>
            <input type="number" class="app-data-ref-first" min="0" value="${Number(firstLevel[category]) || 0}" />
            <input type="number" class="app-data-ref-second" min="0" value="${Number(secondLevel[category]) || 0}" />
            <input type="number" class="app-data-ref-third" min="0" value="${Number(thirdLevel[category]) || 0}" />
            <button type="button" class="app-data-row-remove" onclick="this.closest('.app-data-ref-row')?.remove()">Remove</button>
        </div>
    `).join('');

    const missions = Array.isArray(referralSettings.missions) ? referralSettings.missions : [];
    const referralMissionRows = missions.map((m, idx) => renderReferralMissionRowHtml(m, idx)).join('') || '<div class="app-data-empty" style="padding: 20px; text-align: center; color: #94a3b8;">No referral missions added yet. Click "+ Add Mission" to create one.</div>';

    const defaultUrlKeys = [
        'instagramLink',
        'privacyPolicy',
        'supportMail',
        'termsOfService',
        'dailyTaskTutorial',
        'playGamesTutorial',
        'giveawayTutorial',
        'taskTutorial',
        'surveyTutorial',
        'readEarnTutorial',
        'watchEarnTutorial',
    ];
    const excludedKeys = ['telegramLink', 'whatsappLink', 'youtubeLink'];
    const urlKeys = Array.from(new Set([
        ...defaultUrlKeys,
        ...Object.keys(urlConfig),
    ])).filter(key => !excludedKeys.includes(key));
    const urlRows = urlKeys.map((key) => {
        const val = String(urlConfig[key] || '').trim();
        const isAppRoute = val.startsWith('app://');
        return `
        <div class="app-data-url-row" data-key="${escapeWalletHtml(key)}">
            <input type="text" class="app-data-url-key" value="${escapeWalletHtml(key)}" />
            <div style="display: grid; grid-template-columns: 120px 1fr; gap: 8px; width: 100%;">
                <select class="app-data-url-type" onchange="toggleUrlConfigValueType(this)" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; background: white; width: 100%;">
                    <option value="custom" ${!isAppRoute ? 'selected' : ''}>Custom URL</option>
                    <option value="select" ${isAppRoute ? 'selected' : ''}>Select Screen</option>
                </select>
                <input type="text" class="app-data-url-value-custom" value="${isAppRoute ? '' : escapeWalletHtml(val)}" placeholder="Enter Url" style="display: ${isAppRoute ? 'none' : 'block'}; padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; width: 100%; box-sizing: border-box;" />
                <select class="app-data-url-value-select" style="display: ${isAppRoute ? 'block' : 'none'}; padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; background: white; width: 100%; box-sizing: border-box;">
                    ${getAppRoutesOptionsHtml(val)}
                </select>
            </div>
        </div>
        `;
    }).join('');

    modalBody.innerHTML = `
        <div class="app-data-app-badge">App: ${escapeWalletHtml(selectedApp)}</div>
        ${hasPending ? `
            <div class="app-data-pending-banner">
                Pending update: <strong>${escapeWalletHtml(pendingKeys.join(', '))}</strong> will auto-apply on
                <strong>${escapeWalletHtml(pendingLabel)} IST</strong>.
            </div>
        ` : ''}

        <div class="app-data-tabs">
            <button type="button" class="app-data-tab-btn" data-tab="app" onclick="switchAppDataTab('app')">App Settings</button>
            <button type="button" class="app-data-tab-btn" data-tab="adsConfig" onclick="switchAppDataTab('adsConfig')"><i class="fa-solid fa-rectangle-ad"></i> Ads Config</button>
            <button type="button" class="app-data-tab-btn" data-tab="manageScreens" onclick="switchAppDataTab('manageScreens')">Manage Screens</button>
            <button type="button" class="app-data-tab-btn" data-tab="referral" onclick="switchAppDataTab('referral')">Referral Settings</button>
            <button type="button" class="app-data-tab-btn" data-tab="welcomePopup" onclick="switchAppDataTab('welcomePopup')">Welcome Popup</button>
            <button type="button" class="app-data-tab-btn" data-tab="howToUse" onclick="switchAppDataTab('howToUse')">How Use</button>
            <button type="button" class="app-data-tab-btn" data-tab="banners" onclick="switchAppDataTab('banners')"><i class="fa-solid fa-images"></i> Banners</button>
        </div>

        <div class="app-data-tab-panel" data-tab="app">
            <div class="app-data-section">
                <div class="app-data-section-head">
                    <h4>App Settings</h4>
                    <button class="app-data-save-btn" onclick="saveAppDataCore()">Save App Data</button>
                </div>
                <div class="app-data-layout">
                    <!-- 1. Coin Conversion Rate -->
                    <div class="app-data-block">
                        <div class="app-data-block-header" style="display: flex; justify-content: space-between; align-items: center;">
                            <div style="display: flex; align-items: center; gap: 8px;">
                                <div class="app-data-block-icon"><i class="fa-solid fa-coins"></i></div>
                                <h5 style="margin: 0;">Coin Conversion Rate</h5>
                            </div>
                            <label style="display: flex; align-items: center; gap: 6px; cursor: pointer; margin: 0; font-size: 13px; font-weight: 700; color: #052e1f; background: #ecfdf5; padding: 4px 10px; border-radius: 8px; border: 1px solid #a7f3d0;">
                                <input type="checkbox" id="appdata-showCoinConversionRate" ${appData.showCoinConversionRate ? 'checked' : ''} style="width: 17px; height: 17px; accent-color: #059669; cursor: pointer;" />
                                Show in App
                            </label>
                        </div>
                        <label>
                            Value in Coins for 1 Rupee (INR)
                            <div style="display: flex; align-items: center; gap: 8px; margin-top: 4px;">
                                <span style="font-weight: 800; font-size: 15px; color: #052e1f; white-space: nowrap;">₹ 1.00 =</span>
                                <input id="appdata-conversionRate" type="number" min="1" step="1" value="${Number(appData.conversionRate) || 150}" style="font-size: 15px; font-weight: 800; width: 130px;" />
                                <span style="font-weight: 800; font-size: 15px; color: #052e1f;">Coins</span>
                            </div>
                            <small style="color: #64748b; font-size: 11.5px; font-weight: 500; margin-top: 4px; line-height: 1.4;">
                                Admin dashboard, user earnings in ₹, bonus coins, and task revenue calculate using this rate. Toggle "Show in App" on/off to control visibility of the ₹ balance on Home & Redeem screens.
                            </small>
                        </label>
                    </div>

                    <!-- 2. General Settings -->
                    <div class="app-data-block">
                        <div class="app-data-block-header">
                            <div class="app-data-block-icon"><i class="fa-solid fa-sliders"></i></div>
                            <h5>General Settings</h5>
                        </div>
                        <label>Signup Bonus Type
                            <select id="appdata-signupBonusMode">
                                <option value="signup_direct" ${appData.signupBonusMode !== 'referral_code' ? 'selected' : ''}>Direct Signup Bonus (On Registration)</option>
                                <option value="referral_code" ${appData.signupBonusMode === 'referral_code' ? 'selected' : ''}>Referral Bonus (Only On Refer Code)</option>
                            </select>
                        </label>
                        <div class="app-data-inline-grid">
                            <label>Signup Coins
                                <input id="appdata-signupCoins" type="number" min="0" value="${Number(appData.signupCoins) || 0}" />
                            </label>
                            <label>Game Rewarded Ads
                                <select id="appdata-gameRewardedAds">
                                    <option value="true" ${appData.gameRewardedAds === true ? 'selected' : ''}>True</option>
                                    <option value="false" ${appData.gameRewardedAds !== true ? 'selected' : ''}>False</option>
                                </select>
                            </label>
                        </div>
                        <label>Share Text
                            <textarea id="appdata-shareText" rows="2" placeholder="Use referral link to get reward!">${escapeWalletHtml(appData.shareText || '')}</textarea>
                        </label>
                    </div>

                    <!-- 3. Payment Gateway Settings -->
                    <div class="app-data-block">
                        <div class="app-data-block-header">
                            <div class="app-data-block-icon"><i class="fa-solid fa-credit-card"></i></div>
                            <h5>Payment Gateway Settings</h5>
                        </div>
                        <label>Payout API URL
                            <input id="appdata-payoutApiUrl" type="text" value="${escapeWalletHtml(appData.payoutApiUrl || '')}" placeholder="https://payment.appxo.in/user/api/payment-request.php" />
                        </label>
                        <label>Payout API Token
                            <input id="appdata-payoutApiToken" type="text" value="${escapeWalletHtml(appData.payoutApiToken || '')}" placeholder="Enter Payout API Token..." />
                        </label>
                    </div>

                    <!-- 4. Push Notification (OneSignal) -->
                    <div class="app-data-block">
                        <div class="app-data-block-header">
                            <div class="app-data-block-icon"><i class="fa-solid fa-bell"></i></div>
                            <h5>Push Notification (OneSignal)</h5>
                        </div>
                        <label>OneSignal App ID
                            <input id="appdata-oneSignalAppId" type="text" value="${escapeWalletHtml(appData.oneSignalAppId || '')}" placeholder="Enter OneSignal App ID..." />
                        </label>
                        <label>OneSignal REST API Key (Optional)
                            <input id="appdata-oneSignalApiKey" type="password" value="${escapeWalletHtml(appData.oneSignalApiKey || '')}" placeholder="Enter OneSignal REST API Key..." />
                        </label>
                    </div>

                    <!-- 5. PlayTime Banner Config -->
                    <div class="app-data-block">
                        <div class="app-data-block-header">
                            <div class="app-data-block-icon"><i class="fa-solid fa-gamepad"></i></div>
                            <h5>PlayTime Banner Config</h5>
                        </div>
                        <div class="app-data-inline-grid">
                            <label>Enable Banner
                                <select id="appdata-playtime-enabled">
                                    <option value="true" ${playtimeConfig.enabled === true ? 'selected' : ''}>True (Visible)</option>
                                    <option value="false" ${playtimeConfig.enabled !== true ? 'selected' : ''}>False (Hidden)</option>
                                </select>
                            </label>
                            <label>Target Offerwall Provider
                                <select id="appdata-playtime-offerwallName">
                                    <option value="playtimeAds" ${playtimeConfig.offerwallName === 'playtimeAds' || !playtimeConfig.offerwallName ? 'selected' : ''}>PlaytimeAds</option>
                                    <option value="growDeck" ${playtimeConfig.offerwallName === 'growDeck' ? 'selected' : ''}>GrowDeck</option>
                                    <option value="pubscale" ${playtimeConfig.offerwallName === 'pubscale' ? 'selected' : ''}>PubScale</option>
                                    <option value="bitlabs" ${playtimeConfig.offerwallName === 'bitlabs' ? 'selected' : ''}>BitLabs</option>
                                    <option value="tapjoy" ${playtimeConfig.offerwallName === 'tapjoy' ? 'selected' : ''}>Tapjoy</option>
                                    <option value="adjoe" ${playtimeConfig.offerwallName === 'adjoe' ? 'selected' : ''}>Adjoe</option>
                                    <option value="timewall" ${playtimeConfig.offerwallName === 'timewall' ? 'selected' : ''}>Timewall</option>
                                    <option value="sushiads" ${playtimeConfig.offerwallName === 'sushiads' ? 'selected' : ''}>SushiAds</option>
                                    <option value="wannads" ${playtimeConfig.offerwallName === 'wannads' ? 'selected' : ''}>Wannads</option>
                                </select>
                            </label>
                        </div>
                        <label>Banner Title
                            <input id="appdata-playtime-title" type="text" value="${escapeWalletHtml(playtimeConfig.title || 'PlayTime')}" />
                        </label>
                        <label>Banner Subtitle
                            <input id="appdata-playtime-subtitle" type="text" value="${escapeWalletHtml(playtimeConfig.subtitle || 'Win up to 1,00,000 Coins playing by games per minutes')}" />
                        </label>
                    </div>

                    <!-- 6. My Earning Config -->
                    <div class="app-data-block">
                        <div class="app-data-block-header">
                            <div class="app-data-block-icon"><i class="fa-solid fa-chart-line"></i></div>
                            <h5>My Earning Config</h5>
                        </div>
                        <div class="app-data-inline-grid">
                            <label>Ad eCPM ($)
                                <input id="appdata-earning-adEcpm" type="number" step="0.01" min="0" value="${earningConfig.adEcpm !== undefined ? earningConfig.adEcpm : 1.00}" />
                            </label>
                            <label>Offerwall Rate (Coins / $1)
                                <input id="appdata-earning-offerwallRate" type="number" min="1" value="${earningConfig.offerwallRate !== undefined ? earningConfig.offerwallRate : 5100}" />
                            </label>
                        </div>
                        <label>Read & Earn Rate ($ per 1000 plays)
                            <input id="appdata-earning-readEarnRate" type="number" step="0.01" min="0" value="${earningConfig.readEarnRate !== undefined ? earningConfig.readEarnRate : 1.00}" />
                        </label>
                    </div>

                    <!-- 7. Maintenance Mode -->
                    <div class="app-data-block">
                        <div class="app-data-block-header">
                            <div class="app-data-block-icon"><i class="fa-solid fa-triangle-exclamation"></i></div>
                            <h5>Maintenance Mode</h5>
                        </div>
                        <label>Status
                            <select id="appdata-maintenance-enabled" onchange="toggleMaintenanceExcludeField()">
                                <option value="true" ${maintenanceConfig.enabled ? 'selected' : ''}>Enabled (Maintenance Active)</option>
                                <option value="false" ${!maintenanceConfig.enabled ? 'selected' : ''}>Disabled (App Running)</option>
                            </select>
                        </label>
                        <label>Completed At
                            <input id="appdata-maintenance-completedAt" type="datetime-local" value="${toDateTimeLocalInputValue(maintenanceConfig.completedAt)}" />
                        </label>
                        <div id="appdata-maintenance-exclude-wrap" style="display: ${maintenanceConfig.enabled ? 'block' : 'none'}; margin-top: 10px;">
                            <label>Exclude User IDs (Optional)
                                <textarea id="appdata-maintenance-excludedUserIds" rows="2" placeholder="e.g. 64a1b2c3d4e5f6, 64a1b2c3d4e5f7">${Array.isArray(maintenanceConfig.excludedUserIds) ? maintenanceConfig.excludedUserIds.join(', ') : (maintenanceConfig.excludedUserIds || '')}</textarea>
                                <small style="color: #6b7280; font-size: 11px; display: block; margin-top: 3px;">Users with these IDs will skip maintenance and can use the app normally (comma separated).</small>
                            </label>
                        </div>
                    </div>

                    <!-- 8. App Update Config -->
                    <div class="app-data-block">
                        <div class="app-data-block-header">
                            <div class="app-data-block-icon"><i class="fa-solid fa-cloud-arrow-up"></i></div>
                            <h5>App Update Config</h5>
                        </div>
                        <div class="app-data-inline-grid">
                            <label>Current Build Number
                                <input id="appdata-update-build" type="number" min="0" value="${Number(updateConfig.currentBuildNumber) || 0}" />
                            </label>
                            <label>Current Version
                                <input id="appdata-update-version" type="text" value="${escapeWalletHtml(updateConfig.currentVersion || '')}" placeholder="1.0.0" />
                            </label>
                        </div>
                        <label>Update Message
                            <textarea id="appdata-update-message" rows="2" placeholder="What's new in this version...">${escapeWalletHtml(updateConfig.message || '')}</textarea>
                        </label>
                    </div>

                    <!-- 9. URL Config (Full Width) -->
                    <div class="app-data-block app-data-block-wide">
                        <div class="app-data-block-header">
                            <div class="app-data-block-icon"><i class="fa-solid fa-link"></i></div>
                            <h5>URL & Screen Navigation Config</h5>
                        </div>
                        <div class="app-data-url-header">
                            <span>Key</span>
                            <span>Value / Target Screen</span>
                        </div>
                        <div class="app-data-url-list">${urlRows || '<div class="app-data-empty">No urlConfig fields found.</div>'}</div>
                    </div>
                </div>
            </div>
        </div>

        <div class="app-data-tab-panel" data-tab="adsConfig">
            <div class="app-data-section">
                <div class="app-data-section-head">
                    <h4>Ads Configuration (TopOn Ad Units)</h4>
                    <button class="app-data-save-btn" onclick="saveAdsConfig()">Save Ads Config</button>
                </div>
                <div class="app-data-layout">
                    <div class="app-data-block app-data-block-wide">
                        <div class="app-data-block-header">
                            <div class="app-data-block-icon"><i class="fa-solid fa-rectangle-ad"></i></div>
                            <h5>TopOn Ad Units & Global Toggle</h5>
                        </div>
                        <p style="color: #475569; font-size: 12.5px; margin-bottom: 16px;">
                            Configure TopOn ad unit IDs and master toggle for the mobile app.
                        </p>
                        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 14px;">
                            <label>Interstitial Ad Unit ID
                                <input id="appdata-ads-interstitialKey" type="text" value="${escapeWalletHtml(adsConfig.interstitialKey || '')}" placeholder="Enter Interstitial Ad Unit ID..." />
                            </label>
                            <label>Rewarded Ad Unit ID
                                <input id="appdata-ads-rewardedKey" type="text" value="${escapeWalletHtml(adsConfig.rewardedKey || '')}" placeholder="Enter Rewarded Ad Unit ID..." />
                            </label>
                            <label>Native Ad Unit ID
                                <input id="appdata-ads-nativeKey" type="text" value="${escapeWalletHtml(adsConfig.nativeKey || '')}" placeholder="Enter Native Ad Unit ID..." />
                            </label>
                            <label>Banner Ad Unit ID
                                <input id="appdata-ads-bannerKey" type="text" value="${escapeWalletHtml(adsConfig.bannerKey || '')}" placeholder="Enter Banner Ad Unit ID..." />
                            </label>
                            <label>Global Ads Master Toggle
                                <select id="appdata-ads-enabled">
                                    <option value="true" ${adsConfig.enabled !== false ? 'selected' : ''}>True (Ads Active)</option>
                                    <option value="false" ${adsConfig.enabled === false ? 'selected' : ''}>False (Ads Disabled Globally)</option>
                                </select>
                            </label>
                            <label>Home Screen Native Ad Toggle
                                <select id="appdata-ads-homeNativeEnabled">
                                    <option value="true" ${adsConfig.homeNativeEnabled !== false ? 'selected' : ''}>True (Show on Home)</option>
                                    <option value="false" ${adsConfig.homeNativeEnabled === false ? 'selected' : ''}>False (Hide on Home)</option>
                                </select>
                            </label>
                            <label>Super Offer Screen Native Ad
                                <select id="appdata-ads-superOfferNativeEnabled">
                                    <option value="true" ${adsConfig.superOfferNativeEnabled !== false ? 'selected' : ''}>True (Show on Super Offer)</option>
                                    <option value="false" ${adsConfig.superOfferNativeEnabled === false ? 'selected' : ''}>False (Hide on Super Offer)</option>
                                </select>
                            </label>
                            <label>Daily Challenge Screen Native Ad
                                <select id="appdata-ads-dailyChallengeNativeEnabled">
                                    <option value="true" ${adsConfig.dailyChallengeNativeEnabled !== false ? 'selected' : ''}>True (Show on Daily Challenge)</option>
                                    <option value="false" ${adsConfig.dailyChallengeNativeEnabled === false ? 'selected' : ''}>False (Hide on Daily Challenge)</option>
                                </select>
                            </label>
                            <label>Play Games Screen Native Ad
                                <select id="appdata-ads-playGamesNativeEnabled">
                                    <option value="true" ${adsConfig.playGamesNativeEnabled !== false ? 'selected' : ''}>True (Show on Play Games)</option>
                                    <option value="false" ${adsConfig.playGamesNativeEnabled === false ? 'selected' : ''}>False (Hide on Play Games)</option>
                                </select>
                            </label>
                            <label>Watch Video Screen Native Ad
                                <select id="appdata-ads-watchVideoNativeEnabled">
                                    <option value="true" ${adsConfig.watchVideoNativeEnabled !== false ? 'selected' : ''}>True (Show on Watch Video)</option>
                                    <option value="false" ${adsConfig.watchVideoNativeEnabled === false ? 'selected' : ''}>False (Hide on Watch Video)</option>
                                </select>
                            </label>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="app-data-tab-panel" data-tab="referral">
            <!-- Sub-tabs navigation inside Referral Settings -->
            <div style="display: flex; gap: 10px; margin-bottom: 18px; border-bottom: 2px solid #e2e8f0; padding-bottom: 12px;">
                <button type="button" class="app-data-subtab-btn active" id="ref-subtab-btn-levels" onclick="switchReferralSubTab('levels')" style="padding: 9px 20px; border-radius: 8px; font-weight: 700; font-size: 13px; cursor: pointer; border: 1px solid #8b5cf6; background: #8b5cf6; color: white; transition: all 0.2s;">Referral Levels</button>
                <button type="button" class="app-data-subtab-btn" id="ref-subtab-btn-missions" onclick="switchReferralSubTab('missions')" style="padding: 9px 20px; border-radius: 8px; font-weight: 700; font-size: 13px; cursor: pointer; border: 1px solid #cbd5e1; background: #f8fafc; color: #475569; transition: all 0.2s;">Referral Missions</button>
            </div>

            <!-- Subtab 1: Referral Level Commission -->
            <div class="referral-subtab-panel" id="ref-subtab-levels">
                <div class="app-data-section">
                    <div class="app-data-section-head">
                        <h4>Referral Level & Bonus Settings</h4>
                        <div class="app-data-section-actions">
                            <button class="app-data-save-btn" onclick="saveReferralSettings()">Save Referral Settings</button>
                        </div>
                    </div>

                    <!-- GRID CONTAINER: BOTH CARDS IN ONE LINE -->
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 16px; align-items: stretch;">
                        <!-- 1. DIRECT REFERRER JOINING BONUS CARD -->
                        <div class="app-data-block" style="margin-bottom: 0; background: #faf5ff; border: 1px solid #d8b4fe; border-radius: 8px; padding: 16px; display: flex; flex-direction: column;">
                            <h5 style="color: #6b21a8; margin: 0 0 6px; display: flex; align-items: center; gap: 8px;">
                                <i class="fa-solid fa-gift"></i> Direct Referrer Joining Bonus
                            </h5>
                            <p style="color: #4b5563; font-size: 12.5px; margin: 0 0 14px;">
                                Reward the user whose referral code was used when a new friend joins. If set to 0, referrer gets nothing upon joining.
                            </p>
                            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-top: auto;">
                                <label style="font-weight: 600; color: #374151; font-size: 13px;">
                                    Referrer Bonus Coins
                                    <input type="number" id="appdata-ref-bonus-coins" min="0" value="${Number(referralSettings.referrerBonusCoins) || 0}" placeholder="e.g. 100" style="margin-top: 6px; width: 100%;" />
                                </label>
                                <label style="font-weight: 600; color: #374151; font-size: 13px;">
                                    Unlock Condition (Trigger Task)
                                    <select id="appdata-ref-bonus-condition" style="margin-top: 6px; width: 100%; padding: 8px; border: 1px solid #cbd5e1; border-radius: 6px; background: white;">
                                        <option value="none" ${(referralSettings.referrerBonusCondition || 'none') === 'none' ? 'selected' : ''}>None (Instant on Referral Apply)</option>
                                        <option value="any_task" ${referralSettings.referrerBonusCondition === 'any_task' ? 'selected' : ''}>Any Task (First Completion of Any Task)</option>
                                        <option value="super_offer" ${referralSettings.referrerBonusCondition === 'super_offer' ? 'selected' : ''}>Super Offer (Referred Friend Completes 1 Super Offer)</option>
                                        <option value="daily_task" ${referralSettings.referrerBonusCondition === 'daily_task' ? 'selected' : ''}>Daily Task (Referred Friend Completes 1 Daily Task)</option>
                                        <option value="watch_earn" ${referralSettings.referrerBonusCondition === 'watch_earn' ? 'selected' : ''}>Watch & Earn (Referred Friend Completes 1 Video Task)</option>
                                        <option value="read_earn" ${referralSettings.referrerBonusCondition === 'read_earn' ? 'selected' : ''}>Read & Earn (Referred Friend Completes 1 Article)</option>
                                        <option value="play_games" ${referralSettings.referrerBonusCondition === 'play_games' ? 'selected' : ''}>Play Games (Referred Friend Plays 1 Game Session)</option>
                                        <option value="offerwall" ${referralSettings.referrerBonusCondition === 'offerwall' ? 'selected' : ''}>Offerwall / Survey (Referred Friend Completes 1 Offerwall Offer)</option>
                                    </select>
                                </label>
                            </div>
                        </div>

                        <!-- 2. REWARD MODE SELECTION -->
                        <div class="app-data-block" style="margin-bottom: 0; background: #f0fdf4; border: 1px solid #86efac; border-radius: 8px; padding: 16px; display: flex; flex-direction: column;">
                            <h5 style="color: #166534; margin: 0 0 6px; display: flex; align-items: center; gap: 8px;">
                                <i class="fa-solid fa-sliders"></i> Referral Commission Mode
                            </h5>
                            <p style="color: #4b5563; font-size: 12.5px; margin: 0 0 14px;">
                                Choose whether to use a flat % for direct 1st level only, or multi-level task-wise rules.
                            </p>
                            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-top: auto;">
                                <label style="font-weight: 600; color: #374151; font-size: 13px;">
                                    Commission Mode
                                    <select id="appdata-ref-reward-mode" onchange="toggleReferralRewardMode(this.value)" style="margin-top: 6px; width: 100%; padding: 8px; border: 1px solid #cbd5e1; border-radius: 6px; background: white; font-weight: 700;">
                                        <option value="all" ${(referralSettings.rewardMode || 'all') === 'all' ? 'selected' : ''}>ALL (% Mode - 1st Level Direct Only)</option>
                                        <option value="taskWise" ${referralSettings.rewardMode === 'taskWise' ? 'selected' : ''}>TASK WISE (Multi-Level Category Mode)</option>
                                    </select>
                                </label>

                                <!-- ALL Mode Percentage Input -->
                                <div id="ref-all-mode-container" style="${(referralSettings.rewardMode || 'all') === 'all' ? 'display: block;' : 'display: none;'}">
                                    <label style="font-weight: 600; color: #374151; font-size: 13px;">
                                        Commission % (Direct 1st Level)
                                        <div style="display: flex; align-items: center; gap: 6px; margin-top: 6px;">
                                            <input type="number" id="appdata-ref-all-commission-percent" min="0" max="100" value="${Number(referralSettings.allCommissionPercent) || 10}" placeholder="e.g. 10" style="width: 100%;" />
                                            <span style="font-weight: bold; color: #475569;">%</span>
                                        </div>
                                    </label>
                                    <p style="margin: 6px 0 0; color: #64748b; font-size: 11px;">
                                        Awarded ONLY on actual coin tasks.
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- 3. TASK-WISE CATEGORIES SECTION (Shown only when Task Wise mode is active) -->
                    <div id="ref-taskwise-container" style="${referralSettings.rewardMode === 'taskWise' ? 'display: block;' : 'display: none;'}">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                            <div>
                                <h5 style="margin: 0; color: #334155;">Task / Category Commission Table</h5>
                                <p style="margin: 2px 0 0; font-size: 12px; color: #64748b;">Configure 1st, 2nd, and 3rd level commissions per category. The "Level" tab will be visible in the app.</p>
                            </div>
                            <button type="button" class="app-data-add-btn" onclick="addReferralCategoryRow()">+ Add Category</button>
                        </div>
                        <div class="app-data-ref-header">
                            <span>Category</span>
                            <span>First Level</span>
                            <span>Second Level</span>
                            <span>Third Level</span>
                            <span>Action</span>
                        </div>
                        <div class="app-data-ref-list">${referralRows || '<div class="app-data-empty">No referral categories found.</div>'}</div>
                    </div>
                </div>
            </div>

            <!-- Subtab 2: Referral Missions -->
            <div class="referral-subtab-panel" id="ref-subtab-missions" style="display: none;">
                <div class="app-data-section">
                    <div class="app-data-section-head">
                        <h4>Referral Missions</h4>
                        <div class="app-data-section-actions">
                            <button type="button" class="app-data-add-btn" onclick="addReferralMissionRow()">+ Add Mission</button>
                            <button type="button" class="app-data-save-btn" onclick="saveReferralMissions()">Save Missions</button>
                        </div>
                    </div>

                    <div class="app-data-block" style="margin-bottom: 16px;">
                        <div style="display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; background: #f8fafc; border-radius: 8px; border: 1px solid #e2e8f0; margin-bottom: 12px;">
                            <div>
                                <strong style="color: #1e293b; font-size: 14px;">Enable Referral Missions</strong>
                                <p style="margin: 4px 0 0; color: #64748b; font-size: 12px;">When turned OFF, missions will be hidden in the app by default.</p>
                            </div>
                            <label style="display: flex; align-items: center; gap: 8px; cursor: pointer;">
                                <input type="checkbox" id="appdata-referral-missions-enabled" ${referralSettings.missionsEnabled ? 'checked' : ''} style="width: 20px; height: 20px; accent-color: #8b5cf6; cursor: pointer;">
                                <span style="font-weight: 600; color: #334155; font-size: 13px;">Active</span>
                            </label>
                        </div>
                        <label style="display: block; font-weight: 600; color: #334155; font-size: 13px;">
                            Mission Sub-Description (Visible below 'Referral Missions' text in App)
                            <input id="appdata-referral-missions-subtitle" type="text" value="${escapeWalletHtml(referralSettings.missionsSubtitle || referralSettings.missionsDescription || '')}" placeholder="e.g. Complete missions to earn instant bonuses" style="margin-top: 6px; width: 100%;" />
                        </label>
                    </div>

                    <div class="app-data-ref-mission-header" style="display: grid; grid-template-columns: 90px 110px 150px 120px 1fr 95px 75px; gap: 10px; font-weight: bold; color: #475569; padding: 8px 12px; background: #f1f5f9; border-radius: 6px; margin-bottom: 8px; font-size: 13px;">
                        <span>Target</span>
                        <span>Reward Coins</span>
                        <span>Criteria Type</span>
                        <span>Req. Per Friend</span>
                        <span>Mission Title</span>
                        <span>Status</span>
                        <span style="text-align: center;">Action</span>
                    </div>

                    <div class="app-data-ref-mission-list">
                        ${referralMissionRows}
                    </div>
                </div>
            </div>
        </div>

        <div class="app-data-tab-panel" data-tab="welcomePopup">
            <div class="app-data-section">
                <div class="app-data-section-head">
                    <h4>Welcome Popup Settings</h4>
                    <button class="app-data-save-btn" onclick="saveWelcomePopupSettings()">Save Welcome Popup</button>
                </div>
                <div class="app-data-layout">
                    <div class="app-data-block">
                        <h5>Status & Cap</h5>
                        <label>Welcome Popup Enabled
                            <select id="welcomePopup-enabled">
                                <option value="true" ${welcomePopup.enabled === true ? 'selected' : ''}>True</option>
                                <option value="false" ${welcomePopup.enabled !== true ? 'selected' : ''}>False</option>
                            </select>
                        </label>
                        <label>Frequency Cap (0 = unlimited)
                            <input id="welcomePopup-cap" type="number" min="0" value="${Number(welcomePopup.cap ?? 0)}" />
                        </label>
                    </div>

                    <div class="app-data-block app-data-block-wide">
                        <h5>Content & Action</h5>
                        <label>Banner Image URL
                            <input id="welcomePopup-imageUrl" type="text" value="${escapeWalletHtml(welcomePopup.imageUrl || '')}" placeholder="https://..." />
                        </label>
                        <label>Title
                            <input id="welcomePopup-title" type="text" value="${escapeWalletHtml(welcomePopup.title || '')}" placeholder="Welcome Title" />
                        </label>
                        <label>Message Text
                            <textarea id="welcomePopup-message" rows="3" placeholder="Enter message details...">${escapeWalletHtml(welcomePopup.message || '')}</textarea>
                        </label>
                        <div class="app-data-inline-grid">
                            <label>Button Name
                                <input id="welcomePopup-buttonName" type="text" value="${escapeWalletHtml(welcomePopup.buttonName || '')}" placeholder="Claim Now" />
                            </label>
                            <label>Button Click URL
                                <input id="welcomePopup-buttonClickUrl" type="text" value="${escapeWalletHtml(welcomePopup.buttonClickUrl || '')}" placeholder="https://.../{UserId}" />
                            </label>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="app-data-tab-panel" data-tab="howToUse">
            <div class="app-data-section">
                <div class="app-data-section-head">
                    <h4>How to Use Settings</h4>
                    <div style="display: flex; gap: 8px; align-items: center;">
                        <button type="button" class="app-data-enable-btn" onclick="toggleAllHowToUse(true)">Enable All</button>
                        <button type="button" class="app-data-disable-btn" onclick="toggleAllHowToUse(false)">Disable All</button>
                        <button class="app-data-save-btn" onclick="saveHowToUseSettings()">Save How to Use</button>
                    </div>
                </div>
                <div class="app-data-layout">
                    <div class="app-data-block app-data-block-wide">
                        <h5>How to Use Config</h5>
                        <div style="margin-top: 15px;">
                            ${(() => {
            const howToUseKeys = {
                aToZ: "How To Use Crazyreward?",
                dailyTask: "Daily Task",
                dailyChallenge: "Daily Challenge",
                battleArena: "Battle Arena",
                hotOffer: "Hot Offer",
                giveaway: "Giveaway",
                offerwall: "Offerwall",
                survey: "Survey",
                playGames: "Play Games",
                readEarn: "Read & Earn",
                watchEarn: "Watch & Earn",
                playWin: "Play & Win",
                promoCode: "Promo Code",
                referral: "Referral",
                leaderboard: "Leaderboard"
            };

            const defaultHowToUseData = {
                aToZ: {
                    title: "How To Use Crazyreward?",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Browse our complete guide to understand the app ecosystem.",
                        "Learn tips and tricks on how to maximize daily coin earnings.",
                        "Understand the terms, rules, and withdrawal policies.",
                        "Reach out to Support Tickets if you need help with anything."
                    ]
                },
                dailyTask: {
                    title: "Daily Task",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Navigate to the Daily Task section.",
                        "Select an active task from the list.",
                        "Follow the instructions for the task.",
                        "Submit verification details to claim rewards."
                    ]
                },
                dailyChallenge: {
                    title: "Daily Challenge",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Open the Daily Challenge section from the Home screen.",
                        "Check today’s available challenge goal.",
                        "Complete the required activities before midnight.",
                        "Claim your extra bonus rewards upon completion."
                    ]
                },
                battleArena: {
                    title: "Battle Arena",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Enter the Battle Arena section.",
                        "Join an active battle match or matchmaking queue.",
                        "Outscore your opponent in the battle game.",
                        "Winner collects the grand coin prize pool!"
                    ]
                },
                hotOffer: {
                    title: "Hot Offer",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Open the Hot Offers section on the homepage.",
                        "Ensure you have the required gems balance.",
                        "Complete the necessary steps (e.g. watch ads or install).",
                        "Tap 'Claim Coins' to claim your big bonus instantly."
                    ]
                },
                giveaway: {
                    title: "Giveaway",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Open the Giveaway section.",
                        "Select a live giveaway tournament or raffle.",
                        "Click 'Join Giveaway' to register your entry.",
                        "Wait for the draw timer to complete and check winners."
                    ]
                },
                offerwall: {
                    title: "Offerwall",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Open the Offerwalls page.",
                        "Choose any active Offerwall partner (e.g. AdGate, PubScale).",
                        "Select a task (e.g., download an app or complete a quiz).",
                        "Complete the task exactly as specified to receive rewards."
                    ]
                },
                survey: {
                    title: "Survey",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Go to the Surveys tab.",
                        "Choose an available survey router (e.g. CPX Research).",
                        "Answer the profile questions truthfully.",
                        "Complete the survey to earn high coin payouts."
                    ]
                },
                playGames: {
                    title: "Play Games",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Choose your favorite game from the 'Play Games' section.",
                        "Play games and score points to generate gems.",
                        "Maintain gameplay to accumulate coins dynamically.",
                        "Redeem top rewards with your earned gems and coins."
                    ]
                },

                readEarn: {
                    title: "Read & Earn",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Tap on the 'Read Now' button to open an article.",
                        "Read or browse the page for the specified time limit.",
                        "Copy the article URL from your browser address bar.",
                        "Paste the copied URL in the verification box to claim coins."
                    ]
                },
                watchEarn: {
                    title: "Watch & Earn",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Open the 'Watch & Earn' section.",
                        "Click on a video category or task.",
                        "Watch the complete video advertisement without skipping.",
                        "Your coins will be credited immediately after the video finishes."
                    ]
                },
                playWin: {
                    title: "Play & Win",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Enter the Play & Win lucky number contest.",
                        "Select your lucky numbers and place a ticket.",
                        "Submit your ticket and wait for the lottery draw.",
                        "If your number matches, you win the massive coin pool!"
                    ]
                },
                promoCode: {
                    title: "Promo Code",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Follow our social channels to find active promo codes.",
                        "Open the Promo Code section in the app.",
                        "Type or paste the valid code into the field.",
                        "Tap 'Redeem' to claim your free reward coins."
                    ]
                },
                referral: {
                    title: "Refer & Earn",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Go to the Invite tab to copy your unique referral link.",
                        "Share your link and code with friends and family.",
                        "Make sure your friend enters your code during signup.",
                        "Get high coin commissions whenever they complete tasks."
                    ]
                },
                leaderboard: {
                    title: "Leaderboard",
                    tutorialUrl: "https://www.youtube.com/watch?v=demo",
                    steps: [
                        "Earn coins and refer friends daily to collect points.",
                        "Check the Leaderboard tab to see your current rank.",
                        "Compete with top users to rank in the top positions.",
                        "Daily/weekly winners receive extra bonus coins!"
                    ]
                }
            };

            return Object.entries(howToUseKeys).map(([key, label]) => {
                const val = howToUseConfig[key] || {};
                const defaults = defaultHowToUseData[key] || {};

                const title = val.title || defaults.title || label;
                const tutorialUrl = val.tutorialUrl || defaults.tutorialUrl || '';
                const enabled = val.enabled !== false;

                let stepsStr = '';
                if (val.steps) {
                    stepsStr = Array.isArray(val.steps) ? val.steps.join('\n') : val.steps;
                } else if (defaults.steps) {
                    stepsStr = defaults.steps.join('\n');
                }

                return `
                                    <details style="background: #f8fafc; padding: 12px; border-radius: 8px; margin-bottom: 10px; border: 1px solid #dbe5f3; color: #334155;">
                                        <summary style="font-weight: bold; color: #1e3a8a; cursor: pointer; display: flex; align-items: center; justify-content: space-between;">
                                            <span>${label} (${key})</span>
                                            <span style="font-size: 11px; background: ${enabled ? '#dcfce7' : '#f1f5f9'}; color: ${enabled ? '#15803d' : '#475569'}; padding: 2px 8px; border-radius: 12px; font-weight: bold;">
                                                ${enabled ? 'Enabled' : 'Disabled'}
                                            </span>
                                        </summary>
                                        <div style="margin-top: 12px;" class="how-to-use-item-form" data-key="${key}">
                                            <div class="app-data-inline-grid" style="grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 10px;">
                                                <label>Status
                                                    <select class="how-to-use-enabled" style="width: 100%;">
                                                        <option value="true" ${enabled ? 'selected' : ''}>Enabled</option>
                                                        <option value="false" ${!enabled ? 'selected' : ''}>Disabled</option>
                                                    </select>
                                                </label>
                                                <label>Title
                                                    <input class="how-to-use-title" type="text" value="${escapeWalletHtml(title)}" style="width: 100%;" />
                                                </label>
                                            </div>
                                            <label style="display: block; margin-bottom: 10px;">Tutorial URL
                                                <input class="how-to-use-tutorialUrl" type="text" value="${escapeWalletHtml(tutorialUrl)}" placeholder="https://..." style="width: 100%;" />
                                            </label>
                                            <label style="display: block;">Instructions / Steps (One step per line)
                                                <textarea class="how-to-use-steps" rows="3" placeholder="Step 1...&#10;Step 2..." style="width: 100%; resize: vertical;">${escapeWalletHtml(stepsStr)}</textarea>
                                            </label>
                                        </div>
                                    </details>
                                    `;
            }).join('');
        })()}
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="app-data-tab-panel" data-tab="banners">
            <div style="display: flex; gap: 10px; margin-bottom: 16px; border-bottom: 2px solid #e2e8f0; padding-bottom: 8px;">
                <button type="button" id="subtab-btn-home-banners" class="banners-subtab-btn" onclick="switchBannersSubtab('home')" style="background: #3b82f6; color: white; border: none; padding: 8px 18px; border-radius: 6px; font-weight: bold; cursor: pointer; display: flex; align-items: center; gap: 6px;">
                    <i class="fa-solid fa-sliders"></i> Home Slider Banners
                </button>
                <button type="button" id="subtab-btn-screen-banners" class="banners-subtab-btn" onclick="switchBannersSubtab('screens')" style="background: #f1f5f9; color: #475569; border: 1px solid #cbd5e1; padding: 8px 18px; border-radius: 6px; font-weight: bold; cursor: pointer; display: flex; align-items: center; gap: 6px;">
                    <i class="fa-solid fa-mobile-screen"></i> Screen Banners
                </button>
            </div>

            <!-- Subtab 1: Home Slider Banners -->
            <div id="subtab-content-home-banners" class="banners-subtab-content">
                <div class="app-data-section">
                    <div class="app-data-section-head">
                        <h4>Home Slider Banners</h4>
                        <button class="app-data-save-btn" onclick="saveHomeBannersSettings()">Save Home Banners</button>
                    </div>
                    <div class="app-data-layout" style="display: block;">
                        <div id="home-banners-list" style="margin-bottom: 20px;">
                            ${homeBanners.map((banner, index) => {
            const clickUrlVal = String(banner.clickUrl || '').trim();
            const isAppRoute = clickUrlVal.startsWith('app://');
            return `
                                <div class="home-banner-row" style="background: #f8fafc; padding: 15px; border-radius: 8px; margin-bottom: 12px; border: 1px solid #dbe5f3; display: flex; flex-direction: column; gap: 8px;">
                                    <div style="display: flex; justify-content: space-between; align-items: center;">
                                        <span style="font-weight: bold; color: #1e3a8a;">Banner #${index + 1}</span>
                                        <button type="button" class="app-data-row-remove" onclick="this.closest('.home-banner-row')?.remove()" style="background: #ef4444; color: white; border: none; padding: 4px 8px; border-radius: 4px; cursor: pointer; font-size: 12px;">Remove</button>
                                    </div>
                                    <div style="display: grid; grid-template-columns: 1.5fr 1fr 1.5fr 0.8fr; gap: 10px;">
                                        <label style="display: flex; flex-direction: column; gap: 4px; font-weight: 500; font-size: 13px;">Image URL (Firebase or Web URL)
                                            <input class="home-banner-imageUrl" type="text" value="${escapeWalletHtml(banner.imageUrl || '')}" placeholder="https://..." style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px;" />
                                        </label>
                                        <label style="display: flex; flex-direction: column; gap: 4px; font-weight: 500; font-size: 13px;">Target Type
                                            <select class="home-banner-targetType" onchange="toggleBannerClickType(this)" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; background: white;">
                                                <option value="web" ${!isAppRoute ? 'selected' : ''}>Web URL</option>
                                                <option value="app" ${isAppRoute ? 'selected' : ''}>In-App Screen</option>
                                            </select>
                                        </label>
                                        <label class="banner-target-web-group" style="display: ${isAppRoute ? 'none' : 'flex'}; flex-direction: column; gap: 4px; font-weight: 500; font-size: 13px;">Click Target / URL
                                            <input class="home-banner-webUrl" type="text" value="${isAppRoute ? '' : escapeWalletHtml(clickUrlVal)}" placeholder="https://..." style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; width: 100%;" />
                                        </label>
                                        <label class="banner-target-app-group" style="display: ${isAppRoute ? 'flex' : 'none'}; flex-direction: column; gap: 4px; font-weight: 500; font-size: 13px;">Select Screen
                                            <select class="home-banner-appRoute" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; background: white; width: 100%;">
                                                ${getAppRoutesOptionsHtml(clickUrlVal)}
                                            </select>
                                        </label>
                                        <label style="display: flex; flex-direction: column; gap: 4px; font-weight: 500; font-size: 13px;">Status
                                            <select class="home-banner-enabled" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; background: white;">
                                                <option value="true" ${banner.enabled !== false ? 'selected' : ''}>Enabled</option>
                                                <option value="false" ${banner.enabled === false ? 'selected' : ''}>Disabled</option>
                                            </select>
                                        </label>
                                    </div>
                                </div>`;
        }).join('')}
                        </div>
                        <button type="button" class="app-data-add-btn" onclick="addHomeBannerRow()" style="background: #10b981; color: white; border: none; padding: 8px 16px; border-radius: 6px; cursor: pointer; font-weight: bold;">+ Add New Banner</button>
                    </div>
                </div>
            </div>

            <!-- Subtab 2: Screen Banners -->
            <div id="subtab-content-screen-banners" class="banners-subtab-content" style="display: none;">
                <div class="app-data-section">
                    <div class="app-data-section-head" style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
                        <div>
                            <h4 style="margin: 0; font-size: 17px; font-weight: 800; color: #1e293b;">Screen Banners</h4>
                            <p style="color: #64748b; font-size: 13px; margin: 4px 0 0 0;">
                                Add and configure banners for specific screens or broadcast a single banner to <strong>All Screens</strong>. Recommended size: <strong>700 x 200 px</strong> (Aspect ratio 3.5:1).
                            </p>
                        </div>
                        <div style="display: flex; gap: 10px; align-items: center; flex-wrap: wrap;">
                            <div style="display: flex; gap: 6px; align-items: center; background: #f1f5f9; padding: 4px 6px; border-radius: 8px; border: 1px solid #e2e8f0;">
                                <select id="screen-banner-add-select" style="padding: 7px 12px; border: 1px solid #cbd5e1; border-radius: 6px; background: white; font-weight: 600; font-size: 13px; color: #1e293b; outline: none; cursor: pointer;">
                                    <option value="">-- Select Screen to Add --</option>
                                    <option value="allScreens">🌟 All Screens (Global / Everywhere)</option>
                                    <option value="redeemScreen">Redeem / Wallet Screen</option>
                                    <option value="superOfferScreen">Super Offer Screen</option>
                                    <option value="playGamesScreen">Play Games Screen</option>
                                    <option value="readEarnScreen">Read & Earn Screen</option>
                                    <option value="watchVideoScreen">Watch Video Screen</option>
                                    <option value="offerwallScreen">Offerwalls Screen</option>
                                    <option value="battleScreen">Battle Arena Screen</option>
                                    <option value="promoCodeScreen">Promo Code Screen</option>
                                </select>
                                <button type="button" class="app-data-add-btn" onclick="addScreenBannerCard()" style="background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: white; border: none; padding: 7px 15px; border-radius: 6px; cursor: pointer; font-weight: 700; font-size: 13px; display: inline-flex; align-items: center; gap: 6px; box-shadow: 0 2px 4px rgba(16,185,129,0.25);">
                                    <i class="fa-solid fa-plus"></i> Add Banner
                                </button>
                            </div>
                            <button class="app-data-save-btn" onclick="saveScreenBannersSettings()">Save Screen Banners</button>
                        </div>
                    </div>

                    <div id="screen-banners-container" class="app-data-layout" style="display: flex; flex-direction: column; gap: 16px; margin-top: 18px;">
                        ${(() => {
                            const configuredKeys = Object.keys(screenBanners).filter(k => SCREEN_BANNER_DEFINITIONS[k]);
                            if (configuredKeys.length === 0) {
                                return `
                                    <div id="screen-banners-empty-placeholder" style="text-align: center; padding: 45px 20px; background: #f8fafc; border: 2px dashed #cbd5e1; border-radius: 12px;">
                                        <i class="fa-regular fa-images" style="font-size: 40px; color: #94a3b8; margin-bottom: 12px; display: block;"></i>
                                        <h5 style="margin: 0 0 6px 0; color: #334155; font-size: 16px; font-weight: 700;">No Screen Banners Configured</h5>
                                        <p style="margin: 0; color: #64748b; font-size: 13px;">Select a screen from the dropdown above and click <strong>"+ Add Banner"</strong> to add a banner card.</p>
                                    </div>
                                `;
                            }
                            return configuredKeys.map(k => getScreenBannerCardHtml(k, screenBanners[k])).join('');
                        })()}
                    </div>
                </div>
            </div>
            </div>
        </div>

        <div class="app-data-tab-panel" data-tab="manageScreens">
            <div class="app-data-section">
                <div class="app-data-section-head">
                    <h4>Manage App Screens & Features</h4>
                    <button class="app-data-save-btn" onclick="saveManageScreensSettings()">Save Screen Settings</button>
                </div>
                <p style="color: #64748b; font-size: 13px; margin-bottom: 20px;">
                    Control feature toggles and screen visibility for the mobile app. Turning off Offerwall/Surveys hides them from the Home Screen, while turning off feature screens (Watch & Earn, Read & Earn, Play Games, etc.) triggers a "Coming Soon" popup in the app.
                </p>
                <div class="app-data-layout" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 16px;">
                    ${(() => {
            const ss = appData.screenSettings || {};
            const screensList = [
                { key: 'offerwall', label: 'Task Offerwalls Section', desc: 'Enabled: Active | Disabled: Coming Soon | Hidden: Completely remove from App', category: 'Home Sections' },
                { key: 'survey', label: 'Surveys Section', desc: 'Enabled: Active | Disabled: Coming Soon | Hidden: Completely remove from App', category: 'Home Sections' },
                { key: 'watchAndEarn', label: 'Watch & Earn Screen', desc: 'Enabled: Active | Disabled: Coming Soon | Hidden: Completely hide card from Home Screen', category: 'Feature Screens' },
                { key: 'readAndEarn', label: 'Read & Earn Screen', desc: 'Enabled: Active | Disabled: Coming Soon | Hidden: Completely hide card from Home Screen', category: 'Feature Screens' },
                { key: 'playGames', label: 'Play Games Screen', desc: 'Enabled: Active | Disabled: Coming Soon | Hidden: Completely hide card from Home Screen', category: 'Feature Screens' },
                { key: 'dailyTasks', label: 'Daily Tasks Screen', desc: 'Enabled: Active | Disabled: Coming Soon | Hidden: Completely hide card from Home Screen', category: 'Feature Screens' },
                { key: 'dailyChallenge', label: 'Daily Challenge Screen', desc: 'Enabled: Active | Disabled: Coming Soon | Hidden: Completely hide card from Home Screen', category: 'Feature Screens' },
                { key: 'promoCode', label: 'Promo Code Screen', desc: 'Enabled: Active | Disabled: Coming Soon | Hidden: Completely hide card from Home Screen', category: 'Feature Screens' },
                { key: 'giveaway', label: 'Giveaway Screen', desc: 'Enabled: Active | Disabled: Coming Soon | Hidden: Completely hide card from Home Screen', category: 'Feature Screens' },
                { key: 'superOffer', label: 'Super Offer Screen', desc: 'Enabled: Active | Disabled: Coming Soon | Hidden: Completely hide card from Home Screen', category: 'Feature Screens' },
                { key: 'battleArena', label: 'Battle Arena Screen', desc: 'Enabled: Active | Disabled: Coming Soon | Hidden: Completely hide card from Home Screen', category: 'Feature Screens' }
            ];

            return screensList.map(s => {
                const val = ss[s.key];
                let status = 'enabled';
                if (val === 'hidden' || val === 'hide') {
                    status = 'hidden';
                } else if (val === false || val === 'false' || val === 'disabled') {
                    status = 'disabled';
                } else {
                    status = 'enabled';
                }

                return `
                                <div class="app-data-block" style="border: 1px solid #cbd5e1; padding: 16px; border-radius: 12px; background: #ffffff;">
                                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                                        <h5 style="margin: 0; font-size: 15px; font-weight: 800; color: #1e293b;">${s.label}</h5>
                                        <span style="font-size: 10px; font-weight: 800; padding: 2px 8px; border-radius: 20px; background: #e2e8f0; color: #475569;">${s.category}</span>
                                    </div>
                                    <p style="margin: 0 0 12px 0; font-size: 12px; color: #64748b;">${s.desc}</p>
                                    <label style="font-weight: 700; font-size: 13px;">Status:
                                        <select id="screen-toggle-${s.key}" style="margin-top: 4px; padding: 6px 10px; border-radius: 6px; border: 1px solid #cbd5e1; font-weight: 700; font-size: 13px; width: 100%;">
                                            <option value="enabled" ${status === 'enabled' ? 'selected' : ''}>🟢 Enabled (Active)</option>
                                            <option value="disabled" ${status === 'disabled' ? 'selected' : ''}>🟡 Disabled (Coming Soon Popup)</option>
                                            <option value="hidden" ${status === 'hidden' ? 'selected' : ''}>🔴 Hidden (Hide Card from Home Screen)</option>
                                        </select>
                                    </label>
                                </div>
                            `;
            }).join('');
        })()}
                </div>
            </div>
        </div>

        <div id="app-data-status" class="app-data-status"></div>
    `;

    switchAppDataTab(appDataActiveTab);
    fetchBannerClickCounts();
}

async function saveManageScreensSettings() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    if (!selectedApp) return;

    const screenKeys = ['offerwall', 'survey', 'watchAndEarn', 'readAndEarn', 'playGames', 'dailyTasks', 'dailyChallenge', 'promoCode', 'giveaway', 'superOffer', 'battleArena'];
    const screenSettings = {};

    for (const key of screenKeys) {
        const selectEl = document.getElementById(`screen-toggle-${key}`);
        if (selectEl) {
            screenSettings[key] = selectEl.value; // 'enabled', 'disabled', or 'hidden'
        }
    }

    try {
        showAlert('Saving screen settings...', 'loading');
        const res = await fetch('/app-data-config/screen-settings', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ selectedApp, screenSettings })
        });
        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to save screen settings');

        showAlert('Screen settings saved successfully!', 'success');
        setTimeout(refreshAppDataManager, 1000);
    } catch (err) {
        showAlert(err.message || 'Failed to save screen settings', 'error');
    }
}



function collectUrlConfigMap() {
    const urlConfig = {};

    // Pre-populate with Telegram, WhatsApp, and YouTube links to preserve them
    const excludedKeys = ['telegramLink', 'whatsappLink', 'youtubeLink'];
    const currentUrlConfig = appDataEditorState.appData?.urlConfig || {};
    for (const key of excludedKeys) {
        if (currentUrlConfig[key] !== undefined) {
            urlConfig[key] = currentUrlConfig[key];
        }
    }

    const rows = Array.from(document.querySelectorAll('.app-data-url-row'));
    const seen = new Set();

    for (const row of rows) {
        const key = String(row.querySelector('.app-data-url-key')?.value || '').trim();

        const typeSelect = row.querySelector('.app-data-url-type');
        let value = '';
        if (typeSelect) {
            const type = typeSelect.value;
            if (type === 'select') {
                value = String(row.querySelector('.app-data-url-value-select')?.value || '').trim();
            } else {
                value = String(row.querySelector('.app-data-url-value-custom')?.value || '').trim();
            }
        } else {
            value = String(row.querySelector('.app-data-url-value')?.value || '').trim();
        }

        if (!key && !value) continue;
        if (!key) {
            throw new Error('urlConfig key is required');
        }

        const normalizedKey = key.toLowerCase();
        if (seen.has(normalizedKey)) {
            throw new Error(`Duplicate urlConfig key: ${key}`);
        }
        seen.add(normalizedKey);
        urlConfig[key] = value;
    }

    return urlConfig;
}

async function saveAppDataCore() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const completedAtInput = String(document.getElementById('appdata-maintenance-completedAt')?.value || '').trim();

    try {
        setAppDataStatus('Saving appData...', 'loading');

        const payload = {
            selectedApp,
            appData: {
                conversionRate: document.getElementById('appdata-conversionRate')
                    ? Number(document.getElementById('appdata-conversionRate').value || 150)
                    : Number(appDataEditorState.appData?.conversionRate || 150),
                showCoinConversionRate: document.getElementById('appdata-showCoinConversionRate')
                    ? document.getElementById('appdata-showCoinConversionRate').checked
                    : Boolean(appDataEditorState.appData?.showCoinConversionRate),
                followCoins: document.getElementById('appdata-followCoins')
                    ? Number(document.getElementById('appdata-followCoins').value || 0)
                    : Number(appDataEditorState.appData?.followCoins || 0),
                signupBonusMode: document.getElementById('appdata-signupBonusMode')?.value || 'signup_direct',
                signupCoins: Number(document.getElementById('appdata-signupCoins')?.value || 0),
                gameRewardedAds: String(document.getElementById('appdata-gameRewardedAds')?.value || 'false') === 'true',
                shareText: String(document.getElementById('appdata-shareText')?.value || '').trim(),
                payoutApiUrl: String(document.getElementById('appdata-payoutApiUrl')?.value || '').trim(),
                payoutApiToken: String(document.getElementById('appdata-payoutApiToken')?.value || '').trim(),
                oneSignalAppId: String(document.getElementById('appdata-oneSignalAppId')?.value ?? appDataEditorState.appData?.oneSignalAppId ?? '').trim(),
                oneSignalApiKey: String(document.getElementById('appdata-oneSignalApiKey')?.value ?? appDataEditorState.appData?.oneSignalApiKey ?? '').trim(),
                adsConfig: {
                    interstitialKey: String(document.getElementById('appdata-ads-interstitialKey')?.value ?? appDataEditorState.appData?.adsConfig?.interstitialKey ?? '').trim(),
                    rewardedKey: String(document.getElementById('appdata-ads-rewardedKey')?.value ?? appDataEditorState.appData?.adsConfig?.rewardedKey ?? '').trim(),
                    nativeKey: String(document.getElementById('appdata-ads-nativeKey')?.value ?? appDataEditorState.appData?.adsConfig?.nativeKey ?? '').trim(),
                    bannerKey: String(document.getElementById('appdata-ads-bannerKey')?.value ?? appDataEditorState.appData?.adsConfig?.bannerKey ?? '').trim(),
                    enabled: document.getElementById('appdata-ads-enabled')
                        ? (String(document.getElementById('appdata-ads-enabled').value) === 'true')
                        : (appDataEditorState.appData?.adsConfig?.enabled !== false),
                    homeNativeEnabled: document.getElementById('appdata-ads-homeNativeEnabled')
                        ? (String(document.getElementById('appdata-ads-homeNativeEnabled').value) === 'true')
                        : (appDataEditorState.appData?.adsConfig?.homeNativeEnabled !== false),
                    superOfferNativeEnabled: document.getElementById('appdata-ads-superOfferNativeEnabled')
                        ? (String(document.getElementById('appdata-ads-superOfferNativeEnabled').value) === 'true')
                        : (appDataEditorState.appData?.adsConfig?.superOfferNativeEnabled !== false),
                    dailyChallengeNativeEnabled: document.getElementById('appdata-ads-dailyChallengeNativeEnabled')
                        ? (String(document.getElementById('appdata-ads-dailyChallengeNativeEnabled').value) === 'true')
                        : (appDataEditorState.appData?.adsConfig?.dailyChallengeNativeEnabled !== false),
                    playGamesNativeEnabled: document.getElementById('appdata-ads-playGamesNativeEnabled')
                        ? (String(document.getElementById('appdata-ads-playGamesNativeEnabled').value) === 'true')
                        : (appDataEditorState.appData?.adsConfig?.playGamesNativeEnabled !== false),
                    watchVideoNativeEnabled: document.getElementById('appdata-ads-watchVideoNativeEnabled')
                        ? (String(document.getElementById('appdata-ads-watchVideoNativeEnabled').value) === 'true')
                        : (appDataEditorState.appData?.adsConfig?.watchVideoNativeEnabled !== false),
                },
                earningConfig: {
                    adEcpm: Number(document.getElementById('appdata-earning-adEcpm')?.value || 1.00),
                    offerwallRate: Number(document.getElementById('appdata-earning-offerwallRate')?.value || 5100),
                    readEarnRate: Number(document.getElementById('appdata-earning-readEarnRate')?.value || 1.00),
                },
                playtimeConfig: {
                    enabled: String(document.getElementById('appdata-playtime-enabled')?.value || 'false') === 'true',
                    offerwallName: String(document.getElementById('appdata-playtime-offerwallName')?.value || 'playtimeAds').trim(),
                    title: String(document.getElementById('appdata-playtime-title')?.value || 'PlayTime').trim(),
                    subtitle: String(document.getElementById('appdata-playtime-subtitle')?.value || 'Win up to 1,00,000 Coins playing by games per minutes').trim(),
                },
                streakConfig: {
                    coins: document.getElementById('appdata-streak-coins')
                        ? Number(document.getElementById('appdata-streak-coins').value || 0)
                        : Number(appDataEditorState.appData?.streakConfig?.coins || 0),
                    rewardedAds: document.getElementById('appdata-streak-rewardedAds')
                        ? String(document.getElementById('appdata-streak-rewardedAds').value || 'false') === 'true'
                        : appDataEditorState.appData?.streakConfig?.rewardedAds === true,
                },
                maintenanceConfig: {
                    enabled: String(document.getElementById('appdata-maintenance-enabled')?.value || 'false') === 'true',
                    completedAt: completedAtInput ? new Date(completedAtInput).toISOString() : null,
                    excludedUserIds: String(document.getElementById('appdata-maintenance-excludedUserIds')?.value || '')
                        .split(/[\n,]+/)
                        .map(s => s.trim())
                        .filter(Boolean),
                },

                howToUseConfig: (() => {
                    const cfg = {};
                    document.querySelectorAll('.how-to-use-item-form').forEach(el => {
                        const key = el.getAttribute('data-key');
                        cfg[key] = {
                            enabled: el.querySelector('.how-to-use-enabled').value === 'true',
                            title: el.querySelector('.how-to-use-title').value.trim(),
                            tutorialUrl: el.querySelector('.how-to-use-tutorialUrl').value.trim(),
                            steps: el.querySelector('.how-to-use-steps').value.trim()
                        };
                    });
                    return cfg;
                })(),
                updateConfig: {
                    currentBuildNumber: Number(document.getElementById('appdata-update-build')?.value || 0),
                    currentVersion: String(document.getElementById('appdata-update-version')?.value || '').trim(),
                    message: String(document.getElementById('appdata-update-message')?.value || '').trim(),
                },
                urlConfig: collectUrlConfigMap(),
            },
        };

        const res = await fetch('/app-data-config/app-data', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to update appData');

        setAppDataStatus(json.message || 'appData updated successfully', 'success');
        await refreshAppDataManager();
    } catch (err) {
        setAppDataStatus(err.message || 'Failed to update appData', 'error');
    }
}

async function saveAdsConfig() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    try {
        setAppDataStatus('Saving Ads Configuration...', 'loading');
        const payload = {
            selectedApp,
            appData: {
                adsConfig: {
                    interstitialKey: String(document.getElementById('appdata-ads-interstitialKey')?.value || '').trim(),
                    rewardedKey: String(document.getElementById('appdata-ads-rewardedKey')?.value || '').trim(),
                    nativeKey: String(document.getElementById('appdata-ads-nativeKey')?.value || '').trim(),
                    bannerKey: String(document.getElementById('appdata-ads-bannerKey')?.value || '').trim(),
                    enabled: String(document.getElementById('appdata-ads-enabled')?.value || 'true') === 'true',
                    homeNativeEnabled: String(document.getElementById('appdata-ads-homeNativeEnabled')?.value || 'true') === 'true',
                    superOfferNativeEnabled: String(document.getElementById('appdata-ads-superOfferNativeEnabled')?.value || 'true') === 'true',
                    dailyChallengeNativeEnabled: String(document.getElementById('appdata-ads-dailyChallengeNativeEnabled')?.value || 'true') === 'true',
                    playGamesNativeEnabled: String(document.getElementById('appdata-ads-playGamesNativeEnabled')?.value || 'true') === 'true',
                    watchVideoNativeEnabled: String(document.getElementById('appdata-ads-watchVideoNativeEnabled')?.value || 'true') === 'true',
                }
            }
        };

        const res = await fetch('/app-data-config/app-data', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to update Ads Configuration');

        setAppDataStatus(json.message || 'Ads Configuration updated successfully', 'success');
        await refreshAppDataManager();
    } catch (err) {
        setAppDataStatus(err.message || 'Failed to update Ads Configuration', 'error');
    }
}

async function saveOffersSettings() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const rows = Array.from(document.querySelectorAll('.app-data-offer-row'));
    const offersSettings = {};

    try {
        if (!rows.length) throw new Error('No offer providers found');
        const providerKeys = new Set();

        for (const row of rows) {
            const providerSelect = row.querySelector('.app-data-offer-provider-select');
            const customInput = row.querySelector('.app-data-offer-provider-custom');
            let provider = String(
                (providerSelect && providerSelect.value)
                || row.dataset.provider
                || row.querySelector('.app-data-offer-name')?.textContent
                || ''
            ).trim();

            if (provider.toLowerCase() === 'custom') {
                provider = String(customInput?.value || '').trim();
            }
            const enabled = String(row.querySelector('.app-data-offer-enabled')?.value || 'false') === 'true';
            const rank = Number(row.querySelector('.app-data-offer-rank')?.value || 0);

            const appId = String(row.querySelector('.app-data-offer-appid')?.value || '').trim();
            const secretKey = String(row.querySelector('.app-data-offer-secretkey')?.value || '').trim();
            const token = String(row.querySelector('.app-data-offer-token')?.value || '').trim();
            const appKey = String(row.querySelector('.app-data-offer-appkey')?.value || '').trim();
            const url = String(row.querySelector('.app-data-offer-url')?.value || '').trim();

            if (!provider) throw new Error('Provider name is required');
            if (!Number.isFinite(rank) || rank < 0) throw new Error(`Invalid rank for ${provider}`);
            const normalizedKey = provider.toLowerCase();
            if (providerKeys.has(normalizedKey)) {
                throw new Error(`Duplicate provider: ${provider}`);
            }
            providerKeys.add(normalizedKey);

            offersSettings[provider] = {
                enabled,
                rank: Math.trunc(rank),
                appId,
                secretKey,
                token,
                appKey,
                url,
            };
        }

        setAppDataStatus('Saving offers settings...', 'loading');
        const res = await fetch('/app-data-config/offers-settings', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ selectedApp, offersSettings }),
        });

        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to update offers settings');

        setAppDataStatus('offersSettings updated successfully', 'success');
        await refreshAppDataManager();
    } catch (err) {
        setAppDataStatus(err.message || 'Failed to update offers settings', 'error');
    }
}

function toggleReferralRewardMode(mode) {
    const allContainer = document.getElementById('ref-all-mode-container');
    const taskWiseContainer = document.getElementById('ref-taskwise-container');
    if (mode === 'taskWise') {
        if (allContainer) allContainer.style.display = 'none';
        if (taskWiseContainer) taskWiseContainer.style.display = 'block';
    } else {
        if (allContainer) allContainer.style.display = 'block';
        if (taskWiseContainer) taskWiseContainer.style.display = 'none';
    }
}
window.toggleReferralRewardMode = toggleReferralRewardMode;

function toggleMaintenanceExcludeField() {
    const isEnabled = String(document.getElementById('appdata-maintenance-enabled')?.value || 'false') === 'true';
    const wrap = document.getElementById('appdata-maintenance-exclude-wrap');
    if (wrap) {
        wrap.style.display = isEnabled ? 'block' : 'none';
    }
}
window.toggleMaintenanceExcludeField = toggleMaintenanceExcludeField;

async function saveReferralSettings() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    const rewardMode = String(document.getElementById('appdata-ref-reward-mode')?.value || 'all').trim();
    const allCommissionPercent = Number(document.getElementById('appdata-ref-all-commission-percent')?.value) || 0;
    const referrerBonusCoins = Number(document.getElementById('appdata-ref-bonus-coins')?.value) || 0;
    const referrerBonusCondition = String(document.getElementById('appdata-ref-bonus-condition')?.value || 'none').trim();

    const rows = Array.from(document.querySelectorAll('.app-data-ref-row'));
    const referralSettings = {
        rewardMode,
        allCommissionPercent,
        referrerBonusCoins,
        referrerBonusCondition,
        firstLevel: {},
        secondLevel: {},
        thirdLevel: {},
    };

    try {
        if (rewardMode === 'taskWise') {
            if (!rows.length) throw new Error('No referral categories found. Please add at least one category for Task Wise mode.');
            const categoryKeys = new Set();

            for (const row of rows) {
                const category = String(
                    row.dataset.category
                    || row.querySelector('.app-data-ref-category')?.value
                    || '',
                ).trim();
                const first = Number(row.querySelector('.app-data-ref-first')?.value || 0);
                const second = Number(row.querySelector('.app-data-ref-second')?.value || 0);
                const third = Number(row.querySelector('.app-data-ref-third')?.value || 0);

                if (!category) throw new Error('Category name is required');
                if (![first, second, third].every((num) => Number.isFinite(num) && num >= 0)) {
                    throw new Error(`Invalid referral value for ${category}`);
                }
                const normalizedKey = category.toLowerCase();
                if (categoryKeys.has(normalizedKey)) {
                    throw new Error(`Duplicate category: ${category}`);
                }
                categoryKeys.add(normalizedKey);

                referralSettings.firstLevel[category] = first;
                referralSettings.secondLevel[category] = second;
                referralSettings.thirdLevel[category] = third;
            }
        } else {
            // ALL Mode preserves any existing category rows if present
            for (const row of rows) {
                const category = String(row.dataset.category || row.querySelector('.app-data-ref-category')?.value || '').trim();
                if (category) {
                    referralSettings.firstLevel[category] = Number(row.querySelector('.app-data-ref-first')?.value || 0);
                    referralSettings.secondLevel[category] = Number(row.querySelector('.app-data-ref-second')?.value || 0);
                    referralSettings.thirdLevel[category] = Number(row.querySelector('.app-data-ref-third')?.value || 0);
                }
            }
        }

        setAppDataStatus('Saving referral settings...', 'loading');
        const res = await fetch('/app-data-config/referral-settings', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ selectedApp, referralSettings }),
        });

        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to update referral settings');

        setAppDataStatus('referralSettings updated successfully', 'success');
        await refreshAppDataManager();
    } catch (err) {
        setAppDataStatus(err.message || 'Failed to update referral settings', 'error');
    }
}

function toggleReferralBonusInput(checkbox) {
    const box = document.getElementById('appdata-referral-bonus-box');
    if (!box) return;
    box.style.display = checkbox.checked ? 'block' : 'none';
    if (checkbox.checked) {
        document.getElementById('appdata-referral-bonus-coins')?.focus();
    }
}

function switchReferralSubTab(subtab) {
    const levelsPanel = document.getElementById('ref-subtab-levels');
    const missionsPanel = document.getElementById('ref-subtab-missions');
    const levelsBtn = document.getElementById('ref-subtab-btn-levels');
    const missionsBtn = document.getElementById('ref-subtab-btn-missions');

    if (subtab === 'missions') {
        if (levelsPanel) levelsPanel.style.display = 'none';
        if (missionsPanel) missionsPanel.style.display = 'block';
        if (levelsBtn) {
            levelsBtn.style.background = '#f8fafc';
            levelsBtn.style.color = '#475569';
            levelsBtn.style.borderColor = '#cbd5e1';
            levelsBtn.classList.remove('active');
        }
        if (missionsBtn) {
            missionsBtn.style.background = '#8b5cf6';
            missionsBtn.style.color = 'white';
            missionsBtn.style.borderColor = '#8b5cf6';
            missionsBtn.classList.add('active');
        }
    } else {
        if (levelsPanel) levelsPanel.style.display = 'block';
        if (missionsPanel) missionsPanel.style.display = 'none';
        if (levelsBtn) {
            levelsBtn.style.background = '#8b5cf6';
            levelsBtn.style.color = 'white';
            levelsBtn.style.borderColor = '#8b5cf6';
            levelsBtn.classList.add('active');
        }
        if (missionsBtn) {
            missionsBtn.style.background = '#f8fafc';
            missionsBtn.style.color = '#475569';
            missionsBtn.style.borderColor = '#cbd5e1';
            missionsBtn.classList.remove('active');
        }
    }
}

function getMissionCriteriaPlaceholder(type) {
    if (type === 'withdrawal') return 'Min Redemptions';
    if (type === 'offerwall') return 'Min Offers';
    if (type === 'survey') return 'Min Surveys';
    if (type === 'super_offer') return 'Min Super Offers';
    return 'N/A (Direct)';
}

function renderReferralMissionRowHtml(m = {}, idx = 0) {
    const target = Number(m.target) || 5;
    const reward = Number(m.reward) || 1000;
    const criteriaType = String(m.criteriaType || 'direct');
    const criteriaCount = Number(m.criteriaCount) || 1;
    const title = String(m.title || `Invite ${target} Friends`);
    const enabled = m.enabled !== false;
    const isDirect = criteriaType === 'direct';

    return `
        <div class="app-data-ref-mission-row" data-id="${escapeWalletHtml(m.id || `m_${idx}`)}" style="display: grid; grid-template-columns: 90px 110px 150px 120px 1fr 95px 75px; gap: 10px; align-items: center; padding: 10px 12px; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 6px; margin-bottom: 8px;">
            <input type="number" class="app-data-mission-target" min="1" value="${target}" placeholder="5" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; width: 100%; box-sizing: border-box;" />
            <input type="number" class="app-data-mission-reward" min="0" value="${reward}" placeholder="1000" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; width: 100%; box-sizing: border-box;" />
            <select class="app-data-mission-criteria-type" onchange="toggleMissionCriteria(this)" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; background: white; width: 100%; box-sizing: border-box; font-size: 13px;">
                <option value="direct" ${criteriaType === 'direct' ? 'selected' : ''}>Direct Invite</option>
                <option value="withdrawal" ${criteriaType === 'withdrawal' ? 'selected' : ''}>Withdrawal / Redeem</option>
                <option value="offerwall" ${criteriaType === 'offerwall' ? 'selected' : ''}>Offerwall Tasks</option>
                <option value="survey" ${criteriaType === 'survey' ? 'selected' : ''}>Surveys</option>
                <option value="super_offer" ${criteriaType === 'super_offer' ? 'selected' : ''}>Super Offer</option>
            </select>
            <input type="number" class="app-data-mission-criteria-count" min="1" value="${criteriaCount}" placeholder="${getMissionCriteriaPlaceholder(criteriaType)}" ${isDirect ? 'disabled style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; width: 100%; box-sizing: border-box; opacity: 0.4; background: #f1f5f9;"' : 'style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; width: 100%; box-sizing: border-box;"'} />
            <input type="text" class="app-data-mission-title" value="${escapeWalletHtml(title)}" placeholder="Mission Title" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; width: 100%; box-sizing: border-box;" />
            <select class="app-data-mission-enabled" style="padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; background: white; width: 100%; box-sizing: border-box;">
                <option value="true" ${enabled ? 'selected' : ''}>Active</option>
                <option value="false" ${!enabled ? 'selected' : ''}>Inactive</option>
            </select>
            <button type="button" class="app-data-row-remove" onclick="this.closest('.app-data-ref-mission-row')?.remove()" style="background: #ef4444; color: white; border: none; padding: 6px 10px; border-radius: 4px; cursor: pointer; font-size: 12px; font-weight: bold; width: 100%;">Remove</button>
        </div>
    `;
}

function addReferralMissionRow() {
    const list = document.querySelector('.app-data-ref-mission-list');
    if (!list) return;

    const empty = list.querySelector('.app-data-empty');
    if (empty) empty.remove();

    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = renderReferralMissionRowHtml({ target: 5, reward: 1000, criteriaType: 'direct', criteriaCount: 1, title: 'Invite 5 Friends', enabled: true }, Date.now());
    const row = tempDiv.firstElementChild;
    row.classList.add('is-new');
    list.appendChild(row);
    row.querySelector('.app-data-mission-target')?.focus();
}

function toggleMissionCriteria(selectEl) {
    const row = selectEl.closest('.app-data-ref-mission-row');
    if (!row) return;
    const countInput = row.querySelector('.app-data-mission-criteria-count');
    if (!countInput) return;
    const type = selectEl.value;
    if (type === 'direct') {
        countInput.disabled = true;
        countInput.style.opacity = '0.4';
        countInput.style.background = '#f1f5f9';
        countInput.placeholder = 'N/A (Direct)';
        countInput.value = '1';
    } else {
        countInput.disabled = false;
        countInput.style.opacity = '1';
        countInput.style.background = 'white';
        countInput.placeholder = getMissionCriteriaPlaceholder(type);
        if (!countInput.value || Number(countInput.value) <= 0) {
            countInput.value = '1';
        }
    }
}

async function saveReferralMissions() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const isEnabled = Boolean(document.getElementById('appdata-referral-missions-enabled')?.checked);
    const missionsSubtitle = String(document.getElementById('appdata-referral-missions-subtitle')?.value || '').trim();
    const rows = Array.from(document.querySelectorAll('.app-data-ref-mission-row'));
    const missions = [];

    for (const row of rows) {
        const target = Number(row.querySelector('.app-data-mission-target')?.value || 0);
        const reward = Number(row.querySelector('.app-data-mission-reward')?.value || 0);
        const title = String(row.querySelector('.app-data-mission-title')?.value || `Invite ${target} Friends`).trim();
        const criteriaType = String(row.querySelector('.app-data-mission-criteria-type')?.value || 'direct').trim();
        const criteriaCount = Number(row.querySelector('.app-data-mission-criteria-count')?.value || 1);
        const enabled = row.querySelector('.app-data-mission-enabled')?.value === 'true';

        if (target <= 0) {
            alert('Target invites must be greater than 0');
            return;
        }
        if (reward < 0) {
            alert('Reward coins cannot be negative');
            return;
        }
        if (criteriaType !== 'direct' && (!Number.isFinite(criteriaCount) || criteriaCount <= 0)) {
            alert('Required count per friend must be at least 1');
            return;
        }

        missions.push({
            id: `mission_${target}_${criteriaType}`,
            target,
            reward,
            title,
            criteriaType,
            criteriaCount: criteriaType === 'direct' ? 1 : Math.max(1, Math.round(criteriaCount)),
            enabled,
        });
    }

    try {
        setAppDataStatus('Saving referral missions...', 'loading');
        const res = await fetch('/app-data-config/referral-missions', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ selectedApp, missionsEnabled: isEnabled, missionsSubtitle, missions }),
        });

        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to update referral missions');

        setAppDataStatus('Referral missions updated successfully', 'success');
        await refreshAppDataManager();
    } catch (err) {
        setAppDataStatus(err.message || 'Failed to update referral missions', 'error');
    }
}

async function saveWelcomePopupSettings() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    try {
        setAppDataStatus('Saving welcome popup settings...', 'loading');

        const payload = {
            selectedApp,
            appData: {
                welcomePopup: {
                    enabled: String(document.getElementById('welcomePopup-enabled')?.value || 'false') === 'true',
                    imageUrl: String(document.getElementById('welcomePopup-imageUrl')?.value || '').trim(),
                    title: String(document.getElementById('welcomePopup-title')?.value || '').trim(),
                    message: String(document.getElementById('welcomePopup-message')?.value || '').trim(),
                    buttonName: String(document.getElementById('welcomePopup-buttonName')?.value || '').trim(),
                    buttonClickUrl: String(document.getElementById('welcomePopup-buttonClickUrl')?.value || '').trim(),
                    cap: Number(document.getElementById('welcomePopup-cap')?.value || 0),
                }
            }
        };

        const res = await fetch('/app-data-config/app-data', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to update welcome popup');

        setAppDataStatus('Welcome popup settings updated successfully', 'success');
        await refreshAppDataManager();
    } catch (err) {
        setAppDataStatus(err.message || 'Failed to update welcome popup', 'error');
    }
}

function toggleAllHowToUse(enable) {
    const selects = document.querySelectorAll('.how-to-use-enabled');
    selects.forEach(select => {
        select.value = enable ? 'true' : 'false';
    });
    document.querySelectorAll('.how-to-use-item-form').forEach(form => {
        const summaryBadge = form.previousElementSibling?.querySelector('span:last-child');
        if (summaryBadge) {
            summaryBadge.textContent = enable ? 'Enabled' : 'Disabled';
            summaryBadge.style.background = enable ? '#dcfce7' : '#f1f5f9';
            summaryBadge.style.color = enable ? '#15803d' : '#475569';
        }
    });
    setAppDataStatus(`All How to Use items set to ${enable ? 'ENABLED' : 'DISABLED'}. Click 'Save How to Use' to save changes.`, 'info');
}

async function saveHowToUseSettings() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    try {
        setAppDataStatus('Saving how to use settings...', 'loading');

        const payload = {
            selectedApp,
            appData: {
                howToUseConfig: (() => {
                    const cfg = {};
                    document.querySelectorAll('.how-to-use-item-form').forEach(el => {
                        const key = el.getAttribute('data-key');
                        cfg[key] = {
                            enabled: el.querySelector('.how-to-use-enabled').value === 'true',
                            title: el.querySelector('.how-to-use-title').value.trim(),
                            tutorialUrl: el.querySelector('.how-to-use-tutorialUrl').value.trim(),
                            steps: el.querySelector('.how-to-use-steps').value.trim()
                        };
                    });
                    return cfg;
                })(),
            }
        };

        const res = await fetch('/app-data-config/app-data', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to update how to use config');

        setAppDataStatus('How to Use settings updated successfully', 'success');
        await refreshAppDataManager();
    } catch (err) {
        setAppDataStatus(err.message || 'Failed to update how to use config', 'error');
    }
}

async function saveHomeBannersSettings() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    try {
        setAppDataStatus('Saving home banners...', 'loading');

        const banners = [];
        document.querySelectorAll('.home-banner-row').forEach((el) => {
            const imageUrl = String(el.querySelector('.home-banner-imageUrl')?.value || '').trim();
            const targetType = el.querySelector('.home-banner-targetType')?.value || 'web';
            let clickUrl = '';
            if (targetType === 'app') {
                clickUrl = String(el.querySelector('.home-banner-appRoute')?.value || '').trim();
            } else {
                clickUrl = String(el.querySelector('.home-banner-webUrl')?.value || '').trim();
            }
            const enabled = el.querySelector('.home-banner-enabled')?.value === 'true';
            if (imageUrl || clickUrl) {
                banners.push({ imageUrl, clickUrl, enabled });
            }
        });

        const payload = {
            selectedApp,
            appData: {
                homeBanners: banners,
            }
        };

        const res = await fetch('/app-data-config/app-data', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to update banners config');

        setAppDataStatus('Banners updated successfully', 'success');
        await refreshAppDataManager();
    } catch (err) {
        setAppDataStatus(err.message || 'Failed to update banners config', 'error');
    }
}

function switchBannersSubtab(tab) {
    const homeBtn = document.getElementById('subtab-btn-home-banners');
    const screenBtn = document.getElementById('subtab-btn-screen-banners');
    const homeContent = document.getElementById('subtab-content-home-banners');
    const screenContent = document.getElementById('subtab-content-screen-banners');

    if (tab === 'screens') {
        if (homeBtn) { homeBtn.style.background = '#f1f5f9'; homeBtn.style.color = '#475569'; homeBtn.style.border = '1px solid #cbd5e1'; }
        if (screenBtn) { screenBtn.style.background = '#3b82f6'; screenBtn.style.color = 'white'; screenBtn.style.border = 'none'; }
        if (homeContent) homeContent.style.display = 'none';
        if (screenContent) screenContent.style.display = 'block';
    } else {
        if (homeBtn) { homeBtn.style.background = '#3b82f6'; homeBtn.style.color = 'white'; homeBtn.style.border = 'none'; }
        if (screenBtn) { screenBtn.style.background = '#f1f5f9'; screenBtn.style.color = '#475569'; screenBtn.style.border = '1px solid #cbd5e1'; }
        if (homeContent) homeContent.style.display = 'block';
        if (screenContent) screenContent.style.display = 'none';
    }
}

function toggleScreenBannerClickType(selectEl) {
    const card = selectEl.closest('.screen-banner-card');
    if (!card) return;
    const isApp = selectEl.value === 'app';
    const webGroup = card.querySelector('.screen-banner-web-group');
    const appGroup = card.querySelector('.screen-banner-app-group');
    if (webGroup) webGroup.style.display = isApp ? 'none' : 'block';
    if (appGroup) appGroup.style.display = isApp ? 'block' : 'none';
    const imgInput = card.querySelector('.screen-banner-imageUrl');
    if (imgInput) updateScreenBannerPreview(imgInput);
}

function updateScreenBannerPreview(inputEl) {
    const card = inputEl.closest('.screen-banner-card');
    if (!card) return;
    const previewContainer = card.querySelector('.screen-banner-preview');
    if (!previewContainer) return;
    const url = inputEl.value.trim();
    const isApp = card.querySelector('.screen-banner-targetType')?.value === 'app';
    if (url) {
        const adBadgeHtml = !isApp ? `<div style="position: absolute; top: 6px; right: 6px; background: rgba(0,0,0,0.65); color: white; border-radius: 50%; width: 20px; height: 20px; display: flex; align-items: center; justify-content: center; font-size: 9px; font-weight: bold; border: 1px solid rgba(255,255,255,0.6);">AD</div>` : '';
        previewContainer.innerHTML = `<img src="${escapeWalletHtml(url)}" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.style.display='none'" />${adBadgeHtml}`;
    } else {
        previewContainer.innerHTML = `<span style="font-size: 11px; color: #94a3b8;"><i class="fa-regular fa-image"></i> 700 x 200 Preview</span>`;
    }
}

async function saveScreenBannersSettings() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    try {
        setAppDataStatus('Saving screen banners...', 'loading');

        const screenBanners = {};
        document.querySelectorAll('.screen-banner-card').forEach((el) => {
            const screenKey = el.getAttribute('data-screen');
            if (!screenKey) return;
            const imageUrl = String(el.querySelector('.screen-banner-imageUrl')?.value || '').trim();
            const targetType = el.querySelector('.screen-banner-targetType')?.value || 'web';
            let clickUrl = '';
            if (targetType === 'app') {
                clickUrl = String(el.querySelector('.screen-banner-appRoute')?.value || '').trim();
            } else {
                clickUrl = String(el.querySelector('.screen-banner-webUrl')?.value || '').trim();
            }
            const enabled = el.querySelector('.screen-banner-enabled')?.value === 'true';
            screenBanners[screenKey] = { imageUrl, clickUrl, enabled };
        });

        const payload = {
            selectedApp,
            appData: {
                screenBanners,
            }
        };

        const res = await fetch('/app-data-config/app-data', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to update screen banners');

        setAppDataStatus('Screen banners updated successfully', 'success');
        await refreshAppDataManager();
    } catch (err) {
        setAppDataStatus(err.message || 'Failed to update screen banners', 'error');
    }
}

async function openScreenBannerStatsModal(screenKey, screenName) {
    let modal = document.getElementById('screen-banner-stats-modal');
    if (!modal) {
        modal = document.createElement('div');
        modal.id = 'screen-banner-stats-modal';
        modal.className = 'modal-backdrop';
        modal.style.cssText = 'position: fixed; inset: 0; background: rgba(15, 23, 42, 0.65); backdrop-filter: blur(5px); display: flex; align-items: center; justify-content: center; z-index: 99999; padding: 16px;';
        modal.innerHTML = `
            <div class="modal-card" style="background: #ffffff; border-radius: 14px; width: 100%; max-width: 740px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.25); overflow: hidden; border: 1px solid #e2e8f0;">
                <div style="padding: 16px 22px; border-bottom: 1px solid #e2e8f0; display: flex; justify-content: space-between; align-items: center; background: #f8fafc;">
                    <div style="display: flex; align-items: center; gap: 12px;">
                        <div style="width: 40px; height: 40px; border-radius: 10px; background: #e0f2fe; color: #0284c7; display: flex; align-items: center; justify-content: center; font-size: 18px;">
                            <i class="fa-solid fa-chart-line"></i>
                        </div>
                        <div>
                            <h4 id="banner-stats-modal-title" style="margin: 0; font-size: 16px; font-weight: 800; color: #0f172a;">Banner Click Stats</h4>
                            <span id="banner-stats-modal-subtitle" style="font-size: 12px; color: #64748b;">Daily & date-wise click breakdown</span>
                        </div>
                    </div>
                    <button type="button" onclick="closeScreenBannerStatsModal()" style="background: none; border: none; font-size: 24px; color: #64748b; cursor: pointer; padding: 0 6px; border-radius: 6px; line-height: 1;">&times;</button>
                </div>

                <!-- Calendar & Date Filter Bar -->
                <div style="background: #f1f5f9; padding: 12px 22px; border-bottom: 1px solid #e2e8f0; display: flex; flex-wrap: wrap; gap: 10px; align-items: center; justify-content: space-between;">
                    <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                        <span style="font-size: 12px; font-weight: 700; color: #475569; display: flex; align-items: center; gap: 5px;">
                            <i class="fa-regular fa-calendar" style="color: #0284c7;"></i> Date Filter:
                        </span>
                        <div style="display: flex; align-items: center; gap: 6px; background: white; padding: 3px 8px; border-radius: 8px; border: 1px solid #cbd5e1;">
                            <label style="font-size: 11px; font-weight: 600; color: #64748b;">From</label>
                            <input type="date" id="banner-stats-start-date" style="border: none; outline: none; font-size: 12px; color: #1e293b; background: transparent; cursor: pointer;">
                        </div>
                        <div style="display: flex; align-items: center; gap: 6px; background: white; padding: 3px 8px; border-radius: 8px; border: 1px solid #cbd5e1;">
                            <label style="font-size: 11px; font-weight: 600; color: #64748b;">To</label>
                            <input type="date" id="banner-stats-end-date" style="border: none; outline: none; font-size: 12px; color: #1e293b; background: transparent; cursor: pointer;">
                        </div>
                        <button type="button" id="banner-stats-apply-filter-btn" style="background: #0284c7; color: white; border: none; padding: 6px 14px; border-radius: 6px; font-weight: 700; font-size: 12px; cursor: pointer; display: flex; align-items: center; gap: 4px; box-shadow: 0 1px 2px rgba(0,0,0,0.05);">
                            <i class="fa-solid fa-filter"></i> Apply
                        </button>
                        <button type="button" id="banner-stats-reset-filter-btn" style="background: white; color: #64748b; border: 1px solid #cbd5e1; padding: 6px 10px; border-radius: 6px; font-weight: 600; font-size: 12px; cursor: pointer;">
                            Reset
                        </button>
                    </div>

                    <!-- Quick Preset Pills -->
                    <div style="display: flex; gap: 5px; flex-wrap: wrap;" id="banner-stats-preset-container">
                        <button type="button" class="banner-stats-preset-btn" data-preset="today" style="background: white; border: 1px solid #cbd5e1; padding: 4px 9px; border-radius: 6px; font-size: 11px; font-weight: 600; color: #475569; cursor: pointer;">Today</button>
                        <button type="button" class="banner-stats-preset-btn" data-preset="yesterday" style="background: white; border: 1px solid #cbd5e1; padding: 4px 9px; border-radius: 6px; font-size: 11px; font-weight: 600; color: #475569; cursor: pointer;">Yesterday</button>
                        <button type="button" class="banner-stats-preset-btn" data-preset="7days" style="background: white; border: 1px solid #cbd5e1; padding: 4px 9px; border-radius: 6px; font-size: 11px; font-weight: 600; color: #475569; cursor: pointer;">Last 7D</button>
                        <button type="button" class="banner-stats-preset-btn" data-preset="30days" style="background: white; border: 1px solid #cbd5e1; padding: 4px 9px; border-radius: 6px; font-size: 11px; font-weight: 600; color: #475569; cursor: pointer;">Last 30D</button>
                        <button type="button" class="banner-stats-preset-btn" data-preset="thismonth" style="background: white; border: 1px solid #cbd5e1; padding: 4px 9px; border-radius: 6px; font-size: 11px; font-weight: 600; color: #475569; cursor: pointer;">This Month</button>
                    </div>
                </div>

                <div id="banner-stats-modal-body" style="padding: 20px 22px; overflow-y: auto; flex: 1;">
                    <div style="text-align: center; padding: 40px; color: #64748b;">
                        <i class="fa-solid fa-circle-notch fa-spin" style="font-size: 28px; color: #0284c7; margin-bottom: 12px;"></i>
                        <p style="margin: 0; font-size: 14px; font-weight: 500;">Loading banner statistics...</p>
                    </div>
                </div>

                <div style="padding: 12px 22px; border-top: 1px solid #e2e8f0; display: flex; justify-content: space-between; align-items: center; background: #f8fafc;">
                    <button type="button" id="banner-stats-refresh-btn" style="background: #f1f5f9; color: #334155; border: 1px solid #cbd5e1; padding: 6px 14px; border-radius: 6px; font-weight: 600; font-size: 13px; cursor: pointer; display: flex; align-items: center; gap: 6px;">
                        <i class="fa-solid fa-rotate-right"></i> Refresh
                    </button>
                    <button type="button" onclick="closeScreenBannerStatsModal()" style="background: #0f172a; color: #ffffff; border: none; padding: 6px 18px; border-radius: 6px; font-weight: 600; font-size: 13px; cursor: pointer;">
                        Close
                    </button>
                </div>
            </div>
        `;
        document.body.appendChild(modal);
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeScreenBannerStatsModal();
        });
    }

    // Reset date filter inputs on open
    document.getElementById('banner-stats-start-date').value = '';
    document.getElementById('banner-stats-end-date').value = '';

    modal.style.display = 'flex';
    document.getElementById('banner-stats-modal-title').textContent = `${screenName} - Click Stats`;
    document.getElementById('banner-stats-modal-subtitle').textContent = `Screen: ${screenKey}`;
    
    // Wire apply filter button
    document.getElementById('banner-stats-apply-filter-btn').onclick = () => {
        const s = document.getElementById('banner-stats-start-date').value;
        const e = document.getElementById('banner-stats-end-date').value;
        loadScreenBannerStatsData(screenKey, s, e);
    };

    // Wire reset button
    document.getElementById('banner-stats-reset-filter-btn').onclick = () => {
        document.getElementById('banner-stats-start-date').value = '';
        document.getElementById('banner-stats-end-date').value = '';
        loadScreenBannerStatsData(screenKey, '', '');
    };

    // Wire presets
    document.querySelectorAll('.banner-stats-preset-btn').forEach(btn => {
        btn.onclick = () => {
            const preset = btn.dataset.preset;
            const now = new Date();
            const istOffset = 5.5 * 60 * 60 * 1000;
            const istNow = new Date(now.getTime() + istOffset);
            const todayStr = istNow.toISOString().slice(0, 10);

            let sDate = '';
            let eDate = todayStr;

            if (preset === 'today') {
                sDate = todayStr;
                eDate = todayStr;
            } else if (preset === 'yesterday') {
                const yDate = new Date(now.getTime() + istOffset - (24 * 60 * 60 * 1000));
                sDate = yDate.toISOString().slice(0, 10);
                eDate = sDate;
            } else if (preset === '7days') {
                const d7 = new Date(now.getTime() + istOffset - (6 * 24 * 60 * 60 * 1000));
                sDate = d7.toISOString().slice(0, 10);
            } else if (preset === '30days') {
                const d30 = new Date(now.getTime() + istOffset - (29 * 24 * 60 * 60 * 1000));
                sDate = d30.toISOString().slice(0, 10);
            } else if (preset === 'thismonth') {
                sDate = todayStr.slice(0, 8) + '01';
            }

            document.getElementById('banner-stats-start-date').value = sDate;
            document.getElementById('banner-stats-end-date').value = eDate;
            loadScreenBannerStatsData(screenKey, sDate, eDate);
        };
    });

    document.getElementById('banner-stats-refresh-btn').onclick = () => {
        const s = document.getElementById('banner-stats-start-date').value;
        const e = document.getElementById('banner-stats-end-date').value;
        loadScreenBannerStatsData(screenKey, s, e);
    };

    await loadScreenBannerStatsData(screenKey, '', '');
}

function closeScreenBannerStatsModal() {
    const modal = document.getElementById('screen-banner-stats-modal');
    if (modal) modal.style.display = 'none';
}

async function loadScreenBannerStatsData(screenKey, startDate = '', endDate = '') {
    const bodyEl = document.getElementById('banner-stats-modal-body');
    if (!bodyEl) return;

    bodyEl.innerHTML = `
        <div style="text-align: center; padding: 40px; color: #64748b;">
            <i class="fa-solid fa-circle-notch fa-spin" style="font-size: 28px; color: #0284c7; margin-bottom: 12px;"></i>
            <p style="margin: 0; font-size: 14px; font-weight: 500;">Loading banner statistics...</p>
        </div>
    `;

    try {
        let url = `/admin/banner-stats?screenKey=${encodeURIComponent(screenKey)}`;
        if (startDate) url += `&startDate=${encodeURIComponent(startDate)}`;
        if (endDate) url += `&endDate=${encodeURIComponent(endDate)}`;

        const res = await fetch(url);
        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.message || 'Failed to fetch statistics');

        const stats = json.stats || {};
        const todayClicks = Number(stats.todayClicks) || 0;
        const yesterdayClicks = Number(stats.yesterdayClicks) || 0;
        const totalClicks = Number(stats.totalClicks) || 0;
        const uniqueUsers = Number(stats.uniqueUsers) || 0;
        const filteredClicks = Number(stats.filteredClicks !== undefined ? stats.filteredClicks : totalClicks) || 0;
        const filteredUniqueUsers = Number(stats.filteredUniqueUsers !== undefined ? stats.filteredUniqueUsers : uniqueUsers) || 0;
        const dateWise = Array.isArray(stats.dateWise) ? stats.dateWise : [];
        const isFilterActive = Boolean(startDate || endDate);

        // Update total clicks badge on the screen banner card
        const cardBadgeVal = document.getElementById(`banner-total-clicks-val-${screenKey}`);
        if (cardBadgeVal) cardBadgeVal.textContent = formatNumber(totalClicks);

        bodyEl.innerHTML = `
            <!-- Top Summary Cards -->
            <div style="display: grid; grid-template-columns: repeat(${isFilterActive ? 4 : 3}, 1fr); gap: 12px; margin-bottom: 18px;">
                <div style="background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 10px; padding: 14px; text-align: center;">
                    <span style="font-size: 11px; font-weight: 700; color: #15803d; text-transform: uppercase; letter-spacing: 0.5px;">Today</span>
                    <div style="font-size: 24px; font-weight: 800; color: #166534; margin-top: 4px;">${formatNumber(todayClicks)}</div>
                </div>
                <div style="background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 10px; padding: 14px; text-align: center;">
                    <span style="font-size: 11px; font-weight: 700; color: #1d4ed8; text-transform: uppercase; letter-spacing: 0.5px;">Yesterday</span>
                    <div style="font-size: 24px; font-weight: 800; color: #1e40af; margin-top: 4px;">${formatNumber(yesterdayClicks)}</div>
                </div>
                ${isFilterActive ? `
                    <div style="background: #fffbeb; border: 1px solid #fde68a; border-radius: 10px; padding: 14px; text-align: center;">
                        <span style="font-size: 11px; font-weight: 700; color: #b45309; text-transform: uppercase; letter-spacing: 0.5px;">Filtered Range</span>
                        <div style="font-size: 24px; font-weight: 800; color: #92400e; margin-top: 4px;">${formatNumber(filteredClicks)}</div>
                        <span style="font-size: 10.5px; color: #d97706; font-weight: 600;">${formatNumber(filteredUniqueUsers)} Users</span>
                    </div>
                ` : ''}
                <div style="background: #faf5ff; border: 1px solid #e9d5ff; border-radius: 10px; padding: 14px; text-align: center;">
                    <span style="font-size: 11px; font-weight: 700; color: #7e22ce; text-transform: uppercase; letter-spacing: 0.5px;">All-Time Total</span>
                    <div style="font-size: 24px; font-weight: 800; color: #6b21a8; margin-top: 4px;">${formatNumber(totalClicks)}</div>
                    <span style="font-size: 10.5px; color: #9333ea; font-weight: 600;">${formatNumber(uniqueUsers)} Users</span>
                </div>
            </div>

            <!-- Date-wise Breakdown Header with Active Range Badge -->
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                <h5 style="margin: 0; font-size: 14px; font-weight: 700; color: #1e293b; display: flex; align-items: center; gap: 6px;">
                    <i class="fa-regular fa-calendar-days" style="color: #64748b;"></i>
                    ${isFilterActive ? `Clicks for: <span style="color: #0284c7; font-weight: 800;">${startDate || '...'} to ${endDate || '...'}</span>` : 'Date-Wise Clicks Breakdown'}
                </h5>
                <span style="font-size: 12px; color: #64748b;">${dateWise.length} day(s) recorded</span>
            </div>

            <!-- Date-wise Table -->
            ${dateWise.length === 0 ? `
                <div style="text-align: center; padding: 32px; background: #f8fafc; border: 1px dashed #cbd5e1; border-radius: 8px; color: #64748b;">
                    <i class="fa-solid fa-chart-simple" style="font-size: 28px; color: #94a3b8; margin-bottom: 8px;"></i>
                    <p style="margin: 0; font-size: 13px;">No banner clicks found for the selected date range.</p>
                </div>
            ` : `
                <div style="border: 1px solid #e2e8f0; border-radius: 8px; overflow: hidden; background: white; max-height: 350px; overflow-y: auto;">
                    <table style="width: 100%; border-collapse: collapse; text-align: left; font-size: 13px;">
                        <thead style="position: sticky; top: 0; z-index: 2;">
                            <tr style="background: #f8fafc; border-bottom: 1px solid #e2e8f0; color: #475569; font-weight: 600;">
                                <th style="padding: 10px 14px;">Date</th>
                                <th style="padding: 10px 14px; text-align: center;">Total Clicks</th>
                                <th style="padding: 10px 14px; text-align: center;">Unique Users</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${dateWise.map((row, idx) => {
                                const isToday = row.date === json.todayDate;
                                return `
                                    <tr style="border-bottom: 1px solid #f1f5f9; ${isToday ? 'background: #f0fdf4;' : (idx % 2 === 1 ? 'background: #fcfcfc;' : '')}">
                                        <td style="padding: 10px 14px; font-weight: 600; color: #1e293b;">
                                            ${row.date} ${isToday ? '<span style="background: #22c55e; color: white; font-size: 10px; font-weight: 700; padding: 2px 6px; border-radius: 4px; margin-left: 6px;">TODAY</span>' : ''}
                                        </td>
                                        <td style="padding: 10px 14px; text-align: center; font-weight: 700; color: #0284c7;">
                                            ${formatNumber(row.clicks)}
                                        </td>
                                        <td style="padding: 10px 14px; text-align: center; font-weight: 600; color: #64748b;">
                                            ${formatNumber(row.uniqueUsers)}
                                        </td>
                                    </tr>
                                `;
                            }).join('')}
                        </tbody>
                    </table>
                </div>
            `}
        `;
    } catch (err) {
        bodyEl.innerHTML = `
            <div style="text-align: center; padding: 30px; color: #ef4444;">
                <i class="fa-solid fa-triangle-exclamation" style="font-size: 28px; margin-bottom: 8px;"></i>
                <p style="margin: 0; font-size: 14px; font-weight: 600;">${escapeWalletHtml(err.message || 'Failed to load statistics')}</p>
            </div>
        `;
    }
}

function addScreenBannerCard() {
    const selectEl = document.getElementById('screen-banner-add-select');
    const screenKey = String(selectEl?.value || '').trim();
    if (!screenKey) {
        alert('Please select a screen from the dropdown to add a banner.');
        selectEl?.focus();
        return;
    }

    const container = document.getElementById('screen-banners-container');
    if (!container) return;

    // Check if already added
    const existing = container.querySelector(`.screen-banner-card[data-screen="${screenKey}"]`);
    if (existing) {
        alert(`A banner for "${SCREEN_BANNER_DEFINITIONS[screenKey]?.name || screenKey}" is already added. You can edit its details below.`);
        existing.scrollIntoView({ behavior: 'smooth', block: 'center' });
        existing.querySelector('.screen-banner-imageUrl')?.focus();
        return;
    }

    // Hide empty placeholder if present
    const emptyPlaceholder = document.getElementById('screen-banners-empty-placeholder');
    if (emptyPlaceholder) emptyPlaceholder.style.display = 'none';

    // Create wrapper div
    const temp = document.createElement('div');
    temp.innerHTML = getScreenBannerCardHtml(screenKey, { enabled: true });
    const newCard = temp.firstElementChild;
    container.appendChild(newCard);

    // Fetch click count for this card
    fetchSingleBannerClickCount(screenKey);

    // Scroll to card and focus image input
    newCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
    newCard.querySelector('.screen-banner-imageUrl')?.focus();

    // Reset select
    if (selectEl) selectEl.value = '';
}

function removeScreenBannerCard(screenKey) {
    const card = document.querySelector(`.screen-banner-card[data-screen="${screenKey}"]`);
    if (!card) return;

    const screenName = SCREEN_BANNER_DEFINITIONS[screenKey]?.name || screenKey;
    if (!confirm(`Are you sure you want to remove the banner for "${screenName}"? Click "Save Screen Banners" afterwards to apply changes.`)) {
        return;
    }

    card.remove();

    const container = document.getElementById('screen-banners-container');
    if (container && container.querySelectorAll('.screen-banner-card').length === 0) {
        const emptyPlaceholder = document.getElementById('screen-banners-empty-placeholder');
        if (emptyPlaceholder) {
            emptyPlaceholder.style.display = 'block';
        } else {
            container.innerHTML = `
                <div id="screen-banners-empty-placeholder" style="text-align: center; padding: 45px 20px; background: #f8fafc; border: 2px dashed #cbd5e1; border-radius: 12px;">
                    <i class="fa-regular fa-images" style="font-size: 40px; color: #94a3b8; margin-bottom: 12px; display: block;"></i>
                    <h5 style="margin: 0 0 6px 0; color: #334155; font-size: 16px; font-weight: 700;">No Screen Banners Configured</h5>
                    <p style="margin: 0; color: #64748b; font-size: 13px;">Select a screen from the dropdown above and click <strong>"+ Add Banner"</strong> to add a banner card.</p>
                </div>
            `;
        }
    }
}

async function fetchSingleBannerClickCount(key) {
    try {
        const res = await fetch(`/admin/banner-stats?screenKey=${encodeURIComponent(key)}`);
        const json = await res.json();
        if (json.success && json.stats) {
            const el = document.getElementById(`banner-total-clicks-val-${key}`);
            if (el) el.textContent = formatNumber(json.stats.totalClicks || 0);
        }
    } catch (e) {}
}

async function fetchBannerClickCounts() {
    const cards = document.querySelectorAll('.screen-banner-card');
    for (const card of cards) {
        const key = card.getAttribute('data-screen');
        if (!key) continue;
        await fetchSingleBannerClickCount(key);
    }
}

function formatNumber(value, maximumFractionDigits = 0) {
    return new Intl.NumberFormat('en-IN', {
        maximumFractionDigits,
        minimumFractionDigits: 0,
    }).format(Number(value) || 0);
}

function formatCurrency(value) {
    return `₹${formatNumber(value, 2)}`;
}

function statsRangeLabel(range, startDate, endDate) {
    if (range === 'today') return 'Today';
    if (range === 'yesterday') return 'Yesterday';
    if (range === 'last7') return 'Last 7 days';
    if (range === 'custom') {
        if (startDate && endDate) return `${startDate} to ${endDate}`;
        return 'Custom range';
    }
    return 'Selected range';
}

function onAppStatsRangeChange() {
    const range = String(document.getElementById('app-stats-range')?.value || 'today').trim();
    const startInput = document.getElementById('app-stats-start-date');
    const endInput = document.getElementById('app-stats-end-date');
    const isCustom = range === 'custom';

    if (startInput) startInput.disabled = !isCustom;
    if (endInput) endInput.disabled = !isCustom;

    if (!isCustom) {
        if (startInput) startInput.value = '';
        if (endInput) endInput.value = '';
    }
}

function collectAppStatsFilters() {
    const range = String(document.getElementById('app-stats-range')?.value || 'today').trim();
    const startDate = String(document.getElementById('app-stats-start-date')?.value || '').trim();
    const endDate = String(document.getElementById('app-stats-end-date')?.value || '').trim();

    if (range === 'custom') {
        if (!startDate || !endDate) {
            throw new Error('Custom range ke liye start/end date required hai');
        }
        if (startDate > endDate) {
            throw new Error('Start date end date se bada nahi ho sakta');
        }
    }

    return { range, startDate, endDate };
}

function chartBarRows(items, {
    labelField,
    valueField,
    valueFormatter,
    fillClass = 'blue',
}) {
    const rows = Array.isArray(items) ? items.filter(Boolean) : [];
    if (!rows.length) return '<div class="app-stats-empty">No data found</div>';

    const maxVal = Math.max(...rows.map((item) => Number(item[valueField]) || 0), 1);

    return rows.map((item) => {
        const label = escapeWalletHtml(item[labelField] ?? 'Unknown');
        const value = Number(item[valueField]) || 0;
        const widthPct = Math.max(2, Math.round((value / maxVal) * 100));
        const displayValue = valueFormatter(value, item);

        return `
            <div class="app-stats-bar-row">
                <div class="app-stats-bar-meta">
                    <span class="app-stats-bar-label">${label}</span>
                    <span class="app-stats-bar-value">${displayValue}</span>
                </div>
                <div class="app-stats-bar-track">
                    <div class="app-stats-bar-fill ${fillClass}" style="width:${widthPct}%"></div>
                </div>
            </div>
        `;
    }).join('');
}

function donutStyle(percent, primaryColor = '#2563eb', bgColor = '#e2e8f0') {
    const pct = Math.max(0, Math.min(100, Number(percent) || 0));
    return `background: conic-gradient(${primaryColor} 0 ${pct}%, ${bgColor} ${pct}% 100%);`;
}

async function openAppStatsModal() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    if (!selectedApp) {
        showAlert('❌ Please select app first');
        return;
    }

    openModal('app-stats-modal');

    const rangeInput = document.getElementById('app-stats-range');
    const startInput = document.getElementById('app-stats-start-date');
    const endInput = document.getElementById('app-stats-end-date');

    if (rangeInput) rangeInput.value = appStatsState.range || 'today';
    if (startInput) startInput.value = appStatsState.startDate || '';
    if (endInput) endInput.value = appStatsState.endDate || '';
    onAppStatsRangeChange();

    await loadAppStats();
}

function closeAppStatsModal() {
    closeModal('app-stats-modal');
}

async function loadAppStats() {
    const modalBody = document.getElementById('app-stats-modal-body');
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();

    if (!selectedApp) {
        modalBody.innerHTML = '<div class="app-stats-placeholder error">Please select app first.</div>';
        return;
    }

    let filters;
    try {
        filters = collectAppStatsFilters();
    } catch (err) {
        modalBody.innerHTML = `<div class="app-stats-placeholder error">${escapeWalletHtml(err.message || 'Invalid filters')}</div>`;
        return;
    }

    appStatsState = filters;
    modalBody.innerHTML = '<div class="app-stats-placeholder loading">Fetching app stats...</div>';

    try {
        const payload = {
            app: selectedApp,
            range: filters.range,
        };

        if (filters.range === 'custom') {
            payload.startDate = filters.startDate;
            payload.endDate = filters.endDate;
        }

        const res = await fetch('/check-app-stats', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        const json = await res.json();

        if (!res.ok || !json.success) {
            throw new Error(json.message || 'Failed to fetch app stats');
        }

        renderAppStatsDashboard(json.data || {}, selectedApp, filters);
    } catch (err) {
        modalBody.innerHTML = `<div class="app-stats-placeholder error">${escapeWalletHtml(err.message || 'Failed to fetch app stats')}</div>`;
    }
}

function renderAppStatsDashboard(data, selectedApp, filters) {
    const modalBody = document.getElementById('app-stats-modal-body');

    const usersTotal = Number(data.usersTotal) || 0;
    const activeUsers = Number(data.activeUsers) || 0;
    const inactiveUsers = Math.max(0, usersTotal - activeUsers);

    const rewardsTotalCoins = Number(data.rewardsTotalCoins) || 0;
    const referralTotalCoins = Number(data.referralTotalCoins) || 0;
    const rewardsTotalRevenue = Number(data.rewardsTotalRevenue) || 0;
    const rewardsTotalRecords = Number(data.rewardsTotalRecords) || 0;
    const payoutsTotal = Number(data.payoutsTotal) || 0;
    const conversionRate = Number(data.conversionRate) || 100;

    const rewardsRs = rewardsTotalCoins / conversionRate;
    const referralRs = referralTotalCoins / conversionRate;
    const activePct = usersTotal > 0 ? (activeUsers / usersTotal) * 100 : 0;
    const payoutVsRewardPct = rewardsRs > 0 ? (payoutsTotal / rewardsRs) * 100 : 0;

    const usersData = (Array.isArray(data.users) ? data.users : [])
        .map((item) => ({
            countryLabel: String(item.countryLabel || 'Unknown'),
            count: Number(item.count) || 0,
        }))
        .sort((a, b) => b.count - a.count);

    const rewardsData = (Array.isArray(data.rewards) ? data.rewards : [])
        .map((item) => ({
            provider: String(item.provider || 'Unknown'),
            coinsInRs: Number(item.coinsInRs) || 0,
            records: Number(item.records) || 0,
            coins: Number(item.coins) || 0,
        }))
        .sort((a, b) => b.coinsInRs - a.coinsInRs)
        .slice(0, 10);

    const payoutsData = (Array.isArray(data.payouts) ? data.payouts : [])
        .map((item) => ({
            methodName: String(item.methodName || 'Unknown'),
            amount: Number(item.amount) || 0,
            count: Number(item.count) || 0,
        }))
        .sort((a, b) => b.amount - a.amount)
        .slice(0, 10);

    const usersBars = chartBarRows(usersData, {
        labelField: 'countryLabel',
        valueField: 'count',
        fillClass: 'blue',
        valueFormatter: (value) => `${formatNumber(value)} users`,
    });

    const rewardsBars = chartBarRows(rewardsData, {
        labelField: 'provider',
        valueField: 'coinsInRs',
        fillClass: 'green',
        valueFormatter: (value, item) => `${formatCurrency(value)} • ${formatNumber(item.records)} records`,
    });

    const payoutsBars = chartBarRows(payoutsData, {
        labelField: 'methodName',
        valueField: 'amount',
        fillClass: 'orange',
        valueFormatter: (value, item) => `${formatCurrency(value)} • ${formatNumber(item.count)} payouts`,
    });

    modalBody.innerHTML = `
        <div class="app-stats-app-badge">
            App: ${escapeWalletHtml(selectedApp)} • ${escapeWalletHtml(statsRangeLabel(filters.range, filters.startDate, filters.endDate))}
        </div>

        <div class="app-stats-summary-grid">
            <div class="app-stats-kpi-card">
                <div class="app-stats-kpi-label">Total Users</div>
                <div class="app-stats-kpi-value">${formatNumber(usersTotal)}</div>
            </div>
            <div class="app-stats-kpi-card">
                <div class="app-stats-kpi-label">Active Users</div>
                <div class="app-stats-kpi-value">${formatNumber(activeUsers)}</div>
            </div>
            <div class="app-stats-kpi-card">
                <div class="app-stats-kpi-label">Rewards (Coins)</div>
                <div class="app-stats-kpi-value">${formatNumber(rewardsTotalCoins)}</div>
            </div>
            <div class="app-stats-kpi-card">
                <div class="app-stats-kpi-label">Rewards (₹)</div>
                <div class="app-stats-kpi-value">${formatCurrency(rewardsRs)}</div>
            </div>
            <div class="app-stats-kpi-card">
                <div class="app-stats-kpi-label">Referral Coins (₹)</div>
                <div class="app-stats-kpi-value">${formatCurrency(referralRs)}</div>
            </div>
            <div class="app-stats-kpi-card">
                <div class="app-stats-kpi-label">Payout Total (₹)</div>
                <div class="app-stats-kpi-value">${formatCurrency(payoutsTotal)}</div>
            </div>
            <div class="app-stats-kpi-card">
                <div class="app-stats-kpi-label">Rewards Revenue</div>
                <div class="app-stats-kpi-value">${formatCurrency(rewardsTotalRevenue)}</div>
            </div>
            <div class="app-stats-kpi-card">
                <div class="app-stats-kpi-label">Reward Records</div>
                <div class="app-stats-kpi-value">${formatNumber(rewardsTotalRecords)}</div>
            </div>
        </div>

        <div class="app-stats-chart-grid">
            <div class="app-stats-chart-card">
                <div class="app-stats-chart-title">Users by Country</div>
                <div class="app-stats-bar-list">${usersBars}</div>
            </div>

            <div class="app-stats-chart-card">
                <div class="app-stats-chart-title">Rewards by Provider (₹)</div>
                <div class="app-stats-bar-list">${rewardsBars}</div>
            </div>

            <div class="app-stats-chart-card">
                <div class="app-stats-chart-title">Payout by Method (₹)</div>
                <div class="app-stats-bar-list">${payoutsBars}</div>
            </div>

            <div class="app-stats-chart-card">
                <div class="app-stats-chart-title">Health Indicators</div>
                <div class="app-stats-donut-grid">
                    <div class="app-stats-donut-wrap">
                        <div class="app-stats-donut" style="${donutStyle(activePct, '#2563eb', '#e2e8f0')}">
                            <span>${formatNumber(activePct, 1)}%</span>
                        </div>
                        <div class="app-stats-donut-label">Active Ratio</div>
                        <div class="app-stats-donut-sub">Active ${formatNumber(activeUsers)} / Inactive ${formatNumber(inactiveUsers)}</div>
                    </div>
                    <div class="app-stats-donut-wrap">
                        <div class="app-stats-donut" style="${donutStyle(payoutVsRewardPct, '#ea580c', '#e2e8f0')}">
                            <span>${formatNumber(payoutVsRewardPct, 1)}%</span>
                        </div>
                        <div class="app-stats-donut-label">Payout vs Reward</div>
                        <div class="app-stats-donut-sub">Payout ${formatCurrency(payoutsTotal)} / Reward ${formatCurrency(rewardsRs)}</div>
                    </div>
                </div>
            </div>
        </div>
    `;
}

document.getElementById('appSelect')?.addEventListener('change', () => {
    const walletModal = document.getElementById('wallet-modal');
    if (walletModal?.classList.contains('is-open')) {
        refreshWalletManager();
    }

    const appDataModal = document.getElementById('app-data-modal');
    if (appDataModal?.classList.contains('is-open')) {
        refreshAppDataManager();
    }

    const appStatsModal = document.getElementById('app-stats-modal');
    if (appStatsModal?.classList.contains('is-open')) {
        loadAppStats();
    }
});

let homeGrowthChart = null;
let homeStatsState = {
    range: 'today',
    startDate: '',
    endDate: '',
};

let userDirectoryState = {
    limit: 10,
    search: '',
    cursorStack: [''],
    nextCursor: '',
    hasMore: false,
    sortBy: 'firstLogin',
    sortOrder: 'desc',
};

function toggleSidebar(forceState) {
    const body = document.querySelector('.dashboard-body');
    const backdrop = document.getElementById('sidebar-backdrop');
    if (!body) return;

    const next = typeof forceState === 'boolean' ? forceState : !body.classList.contains('sidebar-open');

    if (next) {
        body.classList.add('sidebar-open');
        if (backdrop) backdrop.style.display = 'block';
        document.body.style.overflow = 'hidden';
    } else {
        body.classList.remove('sidebar-open');
        if (backdrop) backdrop.style.display = 'none';
        document.body.style.overflow = '';
    }
}

function toggleSidebarCollapse() {
    const shell = document.querySelector('.dashboard-shell') || document.body;
    if (!shell) return;
    const isCollapsed = shell.classList.toggle('sidebar-collapsed');
    try {
        localStorage.setItem('sidebar_collapsed', isCollapsed ? 'true' : 'false');
    } catch (e) { }
}

document.addEventListener('DOMContentLoaded', () => {
    try {
        if (localStorage.getItem('sidebar_collapsed') === 'true') {
            const shell = document.querySelector('.dashboard-shell') || document.body;
            if (shell) shell.classList.add('sidebar-collapsed');
        }
    } catch (e) { }
});

function scrollToSection(event, sectionId) {
    if (event) event.preventDefault();
    const target = document.getElementById(sectionId);
    if (!target) return;
    target.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function escapeDirectoryHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function onHomeRangeChange() {
    const range = String(document.getElementById('home-range')?.value || 'today').trim();
    const startInput = document.getElementById('home-start-date');
    const endInput = document.getElementById('home-end-date');
    const isCustom = range === 'custom';

    if (startInput) startInput.disabled = !isCustom;
    if (endInput) endInput.disabled = !isCustom;

    if (!isCustom) {
        if (startInput) startInput.value = '';
        if (endInput) endInput.value = '';
    }
}

function collectHomeFilters() {
    const range = String(document.getElementById('home-range')?.value || 'today').trim();
    const startDate = String(document.getElementById('home-start-date')?.value || '').trim();
    const endDate = String(document.getElementById('home-end-date')?.value || '').trim();

    if (range === 'custom') {
        if (!startDate || !endDate) {
            throw new Error('Custom range ke liye start/end date required hai');
        }
        if (startDate > endDate) {
            throw new Error('Start date end date se bada nahi ho sakta');
        }
    }

    return { range, startDate, endDate };
}

function formatMetaTime(value) {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '';
    return date.toLocaleString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
    });
}

function renderHomeKpis(data) {
    const grid = document.getElementById('home-kpi-grid');
    if (!grid) return;

    const totalUsers = Number(data.totalUsers) || 0;
    const activeUsers = Number(data.activeUsers) || 0;
    const todayRegisteredUsers = Number(data.todayRegisteredUsers) || 0;
    const todayPayout = Number(data.todayPayout) || 0;
    const totalCoinsUsers = Number(data.totalCoinsUsers) || 0;
    const blockedUsers = Number(data.blockedUsers) || 0;
    const coinPrefix = data.coinsEstimated ? '~' : '';

    let rangeLabel = 'Range';
    let rangeDesc = 'selected range';
    const range = String(data.range || 'today').trim().toLowerCase();
    if (range === 'today') {
        rangeLabel = 'Today';
        rangeDesc = 'today';
    } else if (range === 'yesterday') {
        rangeLabel = 'Yesterday';
        rangeDesc = 'yesterday';
    } else if (range === 'last7') {
        rangeLabel = 'Last 7 Days';
        rangeDesc = 'last 7 days';
    }

    // Update new modern dashboard elements
    const statTotal = document.getElementById('stat-total-users');
    const statActive = document.getElementById('stat-active-users');
    const statBlocked = document.getElementById('stat-blocked-users');
    const statPayout = document.getElementById('stat-payout-val');
    const heroBalance = document.getElementById('hero-main-balance');
    const pastelReg = document.getElementById('pastel-reg-val');
    const pastelCoins = document.getElementById('pastel-coins-val');
    const pastelCoinsSub = document.getElementById('pastel-coins-sub');
    const pastelBlocked = document.getElementById('pastel-blocked-val');
    const statPayoutLabel = document.getElementById('stat-payout-label');
    const pastelRegTitle = document.getElementById('pastel-reg-title');

    if (statTotal) statTotal.textContent = formatNumber(totalUsers);
    if (statActive) statActive.textContent = formatNumber(activeUsers);
    if (statBlocked) statBlocked.textContent = formatNumber(blockedUsers);
    if (statPayout) statPayout.textContent = formatCurrency(todayPayout);
    if (heroBalance) heroBalance.textContent = formatCurrency(todayPayout);
    if (pastelReg) pastelReg.textContent = formatNumber(todayRegisteredUsers);
    if (pastelCoins) pastelCoins.textContent = coinPrefix + formatNumber(totalCoinsUsers);
    const liveConversionRate = Number(data.conversionRate) || 150;
    const coinsInRsEst = totalCoinsUsers > 0 ? (totalCoinsUsers / liveConversionRate) : 0;
    if (pastelCoinsSub) pastelCoinsSub.textContent = data.coinsEstimated ? 'Estimated (read-capped)' : `Live: ₹${coinsInRsEst.toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
    if (pastelBlocked) pastelBlocked.textContent = formatNumber(blockedUsers);
    if (statPayoutLabel) statPayoutLabel.textContent = `${rangeLabel.toUpperCase()} PAYOUT (INR)`;
    if (pastelRegTitle) pastelRegTitle.textContent = `${rangeLabel.toUpperCase()} REGISTRATIONS`;

    if (!grid) return;

    grid.innerHTML = `
        <article class="home-kpi">
            <div class="kpi-label">Total Users</div>
            <div class="kpi-value">${formatNumber(totalUsers)}</div>
            <div class="kpi-sub">All-time audience</div>
        </article>
        <article class="home-kpi">
            <div class="kpi-label">Active Users</div>
            <div class="kpi-value">${formatNumber(activeUsers)}</div>
            <div class="kpi-sub">Selected range active</div>
        </article>
        <article class="home-kpi">
            <div class="kpi-label">${rangeLabel} Registrations</div>
            <div class="kpi-value">${formatNumber(todayRegisteredUsers)}</div>
            <div class="kpi-sub">New users in ${rangeDesc}</div>
        </article>
        <article class="home-kpi">
            <div class="kpi-label">${rangeLabel} Payout</div>
            <div class="kpi-value">${formatCurrency(todayPayout)}</div>
            <div class="kpi-sub">Successful payouts in ${rangeDesc}</div>
        </article>
        <article class="home-kpi">
            <div class="kpi-label">Total User Coins</div>
            <div class="kpi-value">${coinPrefix}${formatNumber(totalCoinsUsers)}</div>
            <div class="kpi-sub">${data.coinsEstimated ? 'Estimated (read-capped)' : 'Live aggregate'}</div>
        </article>
        <article class="home-kpi">
            <div class="kpi-label">Blocked Users</div>
            <div class="kpi-value">${formatNumber(blockedUsers)}</div>
            <div class="kpi-sub">Currently blocked accounts</div>
        </article>
    `;
}

function renderHomeGrowthChart(data) {
    const canvas = document.getElementById('home-growth-chart');
    if (!canvas || typeof Chart === 'undefined') return;

    const graph = Array.isArray(data.graph) ? data.graph : [];
    const labels = graph.map((row) => String(row.label || ''));
    const registrations = graph.map((row) => Number(row.registrations) || 0);
    const active = graph.map((row) => Number(row.active) || 0);

    if (homeGrowthChart && typeof homeGrowthChart.destroy === 'function') {
        homeGrowthChart.destroy();
    }

    homeGrowthChart = new Chart(canvas.getContext('2d'), {
        type: 'line',
        data: {
            labels,
            datasets: [
                {
                    label: 'New Registrations',
                    data: registrations,
                    borderColor: '#22c55e',
                    backgroundColor: 'rgba(34, 197, 94, 0.18)',
                    fill: true,
                    tension: 0.35,
                    pointRadius: 3,
                    borderWidth: 3,
                },
                {
                    label: 'Active Users',
                    data: active,
                    borderColor: '#3b82f6',
                    backgroundColor: 'rgba(59, 130, 246, 0.16)',
                    fill: true,
                    tension: 0.35,
                    pointRadius: 3,
                    borderWidth: 3,
                },
            ],
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                mode: 'index',
                intersect: false,
            },
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: {
                        boxWidth: 18,
                        color: '#334155',
                        font: { size: 12, weight: '600' },
                    },
                },
            },
            scales: {
                x: {
                    grid: { color: 'rgba(148, 163, 184, 0.12)' },
                    ticks: { color: '#64748b' },
                },
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(148, 163, 184, 0.18)' },
                    ticks: { color: '#64748b', precision: 0 },
                },
            },
        },
    });
}

async function loadHomeStats() {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const metaEl = document.getElementById('home-stats-meta');
    const grid = document.getElementById('home-kpi-grid');

    if (!selectedApp || !metaEl || !grid) return;

    let filters;
    try {
        filters = collectHomeFilters();
    } catch (err) {
        metaEl.textContent = err.message || 'Invalid filters';
        return;
    }

    homeStatsState = filters;
    metaEl.textContent = 'Fetching latest app stats...';

    try {
        const payload = {
            app: selectedApp,
            range: filters.range,
        };

        if (filters.range === 'custom') {
            payload.startDate = filters.startDate;
            payload.endDate = filters.endDate;
        }

        const res = await fetch('/dashboard-home-stats', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });

        const json = await res.json();
        if (!res.ok || !json.success) {
            throw new Error(json.message || 'Failed to fetch home stats');
        }

        const data = json.data || {};
        renderHomeKpis(data);
        renderHomeGrowthChart(data);
        metaEl.textContent = `Data as of ${formatMetaTime(data.lastUpdatedAt || new Date().toISOString())}`;
    } catch (err) {
        metaEl.textContent = err.message || 'Failed to load home stats';
        grid.innerHTML = `<div class="directory-empty">${escapeDirectoryHtml(err.message || 'Failed to load')}</div>`;
    }
}

function mapDirectoryStatus(blocked) {
    return blocked ? { cls: 'blocked', text: 'Blocked' } : { cls: 'live', text: 'Live' };
}

function renderUserDirectoryRows(rows) {
    const body = document.getElementById('directory-body');
    if (!body) return;

    // Reset select all checkbox and bulk button state
    const selectAllCheckbox = document.getElementById('selectAllUsers');
    if (selectAllCheckbox) selectAllCheckbox.checked = false;
    const bulkBtn = document.getElementById('bulkDeleteBtn');
    if (bulkBtn) bulkBtn.style.display = 'none';

    const list = Array.isArray(rows) ? rows : [];
    if (!list.length) {
        body.innerHTML = '<tr><td colspan="8" class="directory-empty">No users found</td></tr>';
        return;
    }

    const offset = (Math.max(1, userDirectoryState.cursorStack.length) - 1) * userDirectoryState.limit;

    body.innerHTML = list.map((row, idx) => {
        const isGuest = Boolean(row.isGuest || !row.email || row.email === 'N/A');
        const name = escapeDirectoryHtml(row.name || (isGuest ? 'Guest User' : 'App User'));
        const email = (row.email && row.email !== 'N/A' && row.email.includes('@'))
            ? escapeDirectoryHtml(row.email)
            : (isGuest ? '<span style="color:#a855f7; font-weight:600;">Guest User</span>' : '<span style="color:#94a3b8;">No email</span>');
        const joined = formatMetaTime(row.joinedAt || row.createdAt || row.firstLogin) || 'N/A';
        const userId = escapeDirectoryHtml(row.userId || row.id || '');
        const coins = formatNumber(row.coins || 0);
        const status = mapDirectoryStatus(Boolean(row.blocked));
        const rawUserId = encodeURIComponent(String(row.userId || row.id || ''));
        const rawEmail = encodeURIComponent(String(row.email || ''));
        const rawName = encodeURIComponent(String(row.name || (isGuest ? 'Guest User' : 'App User')));
        const rawCoins = Number(row.coins || 0);
        const rawJoined = encodeURIComponent(String(joined));

        return `
            <tr>
                <td style="text-align: center; vertical-align: middle;">
                    <input type="checkbox" class="user-select-checkbox" data-user-id="${userId}" onchange="onUserCheckboxChange()" style="cursor: pointer; transform: scale(1.2);">
                </td>
                <td style="font-weight: 700; color: #64748b;">${offset + idx + 1}</td>
                <td>
                    <div class="directory-user-name" style="font-weight: 800; color: #0f172a;">${name}</div>
                    <div class="directory-user-email" style="font-size: 12px; color: #64748b;">${email}</div>
                </td>
                <td>
                    <code style="font-family: monospace; font-size: 11.5px; background: #f1f5f9; padding: 2px 6px; border-radius: 4px; color: #334155;">${userId}</code>
                </td>
                <td class="directory-coins" style="font-weight: 800; color: #2563eb;">${coins}</td>
                <td style="font-size: 12.5px; color: #64748b;">${escapeDirectoryHtml(joined)}</td>
                <td><span class="directory-status ${status.cls}">${status.text}</span></td>
                <td>
                    <div class="directory-actions" style="display: flex; gap: 6px; justify-content: flex-end; align-items: center;">
                        <button class="directory-action-btn" data-user-id="${rawUserId}" data-email="${rawEmail}" onclick="openDirectoryUserFromRow(this)" title="View User Details">View</button>
                        <button class="directory-action-btn btn-danger-delete-user" data-user-id="${rawUserId}" data-email="${rawEmail}" data-name="${rawName}" data-coins="${rawCoins}" data-joined="${rawJoined}" onclick="openDeleteUserConfirmModal(this)" title="Delete User Account" style="background: #fee2e2; color: #dc2626; border: 1px solid #fecaca; padding: 5px 8px; border-radius: 6px; cursor: pointer; display: inline-flex; align-items: center; justify-content: center;">
                            <svg width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>
                        </button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

function updateDirectoryPager() {
    const pageInfo = document.getElementById('directory-page-info');
    const prevBtn = document.getElementById('directory-prev');
    const nextBtn = document.getElementById('directory-next');

    const page = Math.max(1, userDirectoryState.cursorStack.length);
    const isSearchMode = !!userDirectoryState.search;

    if (pageInfo) {
        pageInfo.textContent = isSearchMode ? `Search (Page ${page})` : `Page ${page}`;
    }
    if (prevBtn) prevBtn.disabled = userDirectoryState.cursorStack.length <= 1;
    if (nextBtn) nextBtn.disabled = !userDirectoryState.hasMore;
}

async function fetchUserDirectory(reset = false) {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    const body = document.getElementById('directory-body');

    if (!selectedApp || !body) return;

    if (reset) {
        userDirectoryState.cursorStack = [''];
        userDirectoryState.nextCursor = '';
        userDirectoryState.hasMore = false;
    }

    body.innerHTML = '<tr><td colspan="8" class="directory-empty">Loading users...</td></tr>';

    try {
        const params = new URLSearchParams({
            app: selectedApp,
            limit: String(userDirectoryState.limit),
            sortBy: userDirectoryState.sortBy,
            sortOrder: userDirectoryState.sortOrder,
        });

        if (userDirectoryState.search) {
            params.set('search', userDirectoryState.search);
        }
        const currentCursor = userDirectoryState.cursorStack[userDirectoryState.cursorStack.length - 1] || '';
        if (currentCursor) params.set('cursor', currentCursor);

        const res = await fetch(`/dashboard-user-directory?${params.toString()}`);
        const json = await res.json();

        if (!res.ok || !json.success) {
            throw new Error(json.message || 'Failed to fetch user directory');
        }

        userDirectoryState.nextCursor = String(json.nextCursor || '');
        userDirectoryState.hasMore = !!json.hasMore && !!userDirectoryState.nextCursor;

        renderUserDirectoryRows(json.rows || []);
        updateDirectoryPager();
    } catch (err) {
        body.innerHTML = `<tr><td colspan="8" class="directory-empty">${escapeDirectoryHtml(err.message || 'Failed to load users')}</td></tr>`;
        updateDirectoryPager();
    }
}

function sortUserDirectory(field) {
    if (userDirectoryState.sortBy === field) {
        userDirectoryState.sortOrder = userDirectoryState.sortOrder === 'desc' ? 'asc' : 'desc';
    } else {
        userDirectoryState.sortBy = field;
        userDirectoryState.sortOrder = 'desc';
    }
    fetchUserDirectory(true);
}

function openDirectoryUserFromRow(button) {
    const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
    if (!selectedApp || !button) return;

    const email = decodeURIComponent(String(button.dataset.email || '')).trim();
    const userId = decodeURIComponent(String(button.dataset.userId || button.dataset.userid || '')).trim();

    if (userId) {
        openUserProfile(userId, selectedApp, 'userId');
    } else if (email && email.includes('@') && !email.toLowerCase().includes('no email') && !email.toLowerCase().includes('n/a')) {
        openUserProfile(email, selectedApp, 'email');
    } else {
        showAlert('❌ User identifier not found');
    }
}

function refreshUserDirectory() {
    fetchUserDirectory(true);
}

function searchUserDirectory() {
    const value = String(document.getElementById('directory-search')?.value || '').trim();
    userDirectoryState.search = value;
    fetchUserDirectory(true);
}

function clearUserDirectorySearch() {
    const input = document.getElementById('directory-search');
    if (input) input.value = '';
    userDirectoryState.search = '';
    fetchUserDirectory(true);
}

function loadNextUserPage() {
    if (!userDirectoryState.hasMore || !userDirectoryState.nextCursor) return;
    userDirectoryState.cursorStack.push(userDirectoryState.nextCursor);
    fetchUserDirectory(false).catch(() => {
        userDirectoryState.cursorStack.pop();
        updateDirectoryPager();
    });
}

function loadPrevUserPage() {
    if (userDirectoryState.cursorStack.length <= 1) return;
    userDirectoryState.cursorStack.pop();
    fetchUserDirectory(false);
}

function openQuickLookupPrompt() {
    const selectedApp = String(document.getElementById('appSelect')?.value || localStorage.getItem('selectedApp') || 'Crazyreward').trim();

    openActionFormModal({
        title: 'User Search',
        subtitle: 'Search by Email / User ID / Refer Code',
        submitText: 'Find User',
        fields: [
            { key: 'query', label: 'User Identifier', placeholder: 'example@mail.com or userId', required: true },
        ],
        onSubmit: async ({ query }) => {
            if (!query) {
                showAlert('❌ Please enter a user identifier');
                return;
            }
            closeModal('action-form-modal');
            openUserProfile(query, selectedApp, 'auto');
        },
    });
}

async function openNotificationComposer() {
    const selectedApp = String(document.getElementById('appSelect')?.value || localStorage.getItem('selectedApp') || 'Crazyreward').trim();

    openActionFormModal({
        title: 'Send Notification',
        subtitle: 'Push notification will be sent to app audience',
        submitText: 'Send Notification',
        fields: [
            {
                key: 'provider',
                label: 'Send Via',
                type: 'select',
                value: 'both',
                options: [
                    { value: 'both', label: '🚀 Both (OneSignal + Firebase FCM)' },
                    { value: 'onesignal', label: '📡 OneSignal Only' },
                    { value: 'firebase', label: '🔥 Firebase FCM Only' },
                ],
                required: true,
            },
            {
                key: 'userId',
                label: 'Target User ID (Leave blank to broadcast to ALL users)',
                placeholder: 'Paste User ID (e.g. 64b8f... / UID) to send individually',
                required: false,
            },
            {
                key: 'type',
                label: 'Notification Audience & Category',
                type: 'select',
                value: 'broadcast',
                options: [
                    { value: 'broadcast', label: '📢 General Broadcast (All Users - Push only, not saved in notification screen)' },
                    { value: 'personal', label: '✉️ Personal Message (For Target User ID)' },
                    { value: 'payment', label: '💳 Payment Update (For Target User ID)' },
                    { value: 'support', label: '🎧 Contact Support Reply (For Target User ID)' },
                    { value: 'service', label: '💼 Service Request Update (For Target User ID)' },
                ],
                required: false,
            },
            { key: 'title', label: 'Title', placeholder: 'Notification Title', required: true },
            { key: 'body', label: 'Message', type: 'textarea', placeholder: 'Notification message body', required: true },
            { key: 'image', label: 'Image URL (Optional)', placeholder: 'https://... (Banner / Image link)', required: false },
        ],
        onSubmit: async ({ provider, userId, type, title, body, image }) => {
            if (!title || !body) {
                showAlert('❌ Please enter both title and message');
                return;
            }

            const cleanUserId = userId ? String(userId).trim() : '';
            const selectedType = String(type || 'broadcast').trim().toLowerCase();

            if (['personal', 'payment', 'support', 'service'].includes(selectedType) && !cleanUserId) {
                showAlert('❌ Please enter Target User ID to send category notification, or select "General Broadcast" to send to all users.');
                return;
            }

            const finalType = cleanUserId ? (selectedType === 'broadcast' ? 'personal' : selectedType) : 'broadcast';

            try {
                showLoading();
                const res = await fetch('/send-notification', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        provider: provider || 'both',
                        userId: cleanUserId || undefined,
                        type: finalType,
                        title,
                        body,
                        image: image ? String(image).trim() : '',
                        selectedApp,
                    }),
                });

                const contentType = String(res.headers.get('content-type') || '').toLowerCase();
                let successMessage = 'Notification sent successfully';

                if (contentType.includes('application/json')) {
                    const json = await res.json();
                    if (!res.ok || json?.success === false) {
                        throw new Error(json?.message || 'Failed to send notification');
                    }
                    successMessage = json?.message || successMessage;
                } else {
                    const text = await res.text();
                    if (!res.ok) throw new Error(text || 'Failed to send notification');
                    successMessage = text || successMessage;
                }

                closeModal('action-form-modal');
                showAlert(`✅ ${escapeDirectoryHtml(successMessage)}`);
            } catch (err) {
                showAlert(`❌ ${escapeDirectoryHtml(err.message || 'Failed to send notification')}`);
            } finally {
                hideLoading();
                closeModal('action-form-modal');
            }
        },
    });
}

function initDashboardHome() {
    const homeGrid = document.getElementById('home-kpi-grid');
    if (!homeGrid) return;

    const rangeInput = document.getElementById('home-range');
    const startInput = document.getElementById('home-start-date');
    const endInput = document.getElementById('home-end-date');

    if (rangeInput) rangeInput.value = homeStatsState.range;
    if (startInput) startInput.value = homeStatsState.startDate;
    if (endInput) endInput.value = homeStatsState.endDate;
    onHomeRangeChange();

    document.getElementById('directory-search')?.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
            event.preventDefault();
            searchUserDirectory();
        }
    });

    loadHomeStats();
    fetchUserDirectory(true);
}

document.getElementById('appSelect')?.addEventListener('change', () => {
    if (!document.getElementById('home-kpi-grid')) return;
    loadHomeStats();
    fetchUserDirectory(true);
});

document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('action-form-modal')?.addEventListener('click', (event) => {
        if (event.target?.id === 'action-form-modal') {
            closeModal('action-form-modal');
        }
    });

    document.querySelectorAll('.side-link').forEach((link) => {
        link.addEventListener('click', () => {
            if (link.classList.contains('side-group-btn')) {
                return;
            }
            if (window.innerWidth <= 980) {
                toggleSidebar(false);
            }
        });
    });

    window.addEventListener('resize', () => {
        if (window.innerWidth > 980) {
            toggleSidebar(false);
        }
    });

    initDashboardHome();
});

function toggleSelectAllUsers(masterCheckbox) {
    const checkboxes = document.querySelectorAll('.user-select-checkbox');
    checkboxes.forEach(cb => {
        cb.checked = masterCheckbox.checked;
    });
    onUserCheckboxChange();
}

function onUserCheckboxChange() {
    const checkboxes = document.querySelectorAll('.user-select-checkbox');
    const checkedBoxes = Array.from(checkboxes).filter(cb => cb.checked);
    const bulkBtn = document.getElementById('bulkDeleteBtn');
    const selectedCountSpan = document.getElementById('selectedCount');

    if (bulkBtn && selectedCountSpan) {
        if (checkedBoxes.length > 0) {
            bulkBtn.style.display = 'block';
            selectedCountSpan.textContent = checkedBoxes.length;
        } else {
            bulkBtn.style.display = 'none';
        }
    }
}

async function performBulkDeleteUsers() {
    const checkboxes = document.querySelectorAll('.user-select-checkbox');
    const selectedUserIds = Array.from(checkboxes)
        .filter(cb => cb.checked)
        .map(cb => cb.getAttribute('data-user-id'));

    if (selectedUserIds.length === 0) {
        showAlert('No users selected', 'error');
        return;
    }

    const confirmMsg = `Are you sure you want to permanently delete all ${selectedUserIds.length} selected user accounts from MongoDB? This action is IRREVERSIBLE!`;
    if (!confirm(confirmMsg)) return;

    try {
        showAlert(`Deleting ${selectedUserIds.length} users...`, 'loading');
        const res = await fetch('/bulk-delete-users', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ userIds: selectedUserIds })
        });
        const json = await res.json();

        if (res.ok && json.success) {
            showAlert(json.message || 'Users deleted successfully', 'success');
            // Refresh list
            fetchUserDirectory(true);
        } else {
            throw new Error(json.message || 'Bulk delete failed');
        }
    } catch (err) {
        console.error('Bulk delete error:', err);
        showAlert(err.message || 'Failed to bulk delete users', 'error');
    }
}

// -------- SINGLE USER DELETE CONFIRMATION MODAL LOGIC --------
let pendingDeleteUser = null;

function openDeleteUserConfirmModal(btn) {
    const userId = decodeURIComponent(btn.getAttribute('data-user-id') || '');
    const email = decodeURIComponent(btn.getAttribute('data-email') || '');
    const name = decodeURIComponent(btn.getAttribute('data-name') || '');
    const coins = btn.getAttribute('data-coins') || '0';
    const joined = decodeURIComponent(btn.getAttribute('data-joined') || '');

    pendingDeleteUser = { userId, email, name };

    const modal = document.getElementById('delete-user-modal');
    if (!modal) {
        if (confirm(`Are you sure you want to permanently delete user "${name}" (${userId || email})?`)) {
            executeDirectUserDelete(userId, email);
        }
        return;
    }

    const nameEl = document.getElementById('del_modal_name');
    const emailEl = document.getElementById('del_modal_email');
    const useridEl = document.getElementById('del_modal_userid');
    const coinsEl = document.getElementById('del_modal_coins');
    const joinedEl = document.getElementById('del_modal_joined');

    if (nameEl) nameEl.textContent = name || 'User';
    if (emailEl) emailEl.textContent = email || 'No Email';
    if (useridEl) useridEl.textContent = userId || '-';
    if (coinsEl) coinsEl.textContent = `${formatNumber(Number(coins) || 0)} Coins`;
    if (joinedEl) joinedEl.textContent = joined || 'N/A';

    modal.style.display = 'flex';
}

function closeDeleteUserModal() {
    const modal = document.getElementById('delete-user-modal');
    if (modal) modal.style.display = 'none';
    pendingDeleteUser = null;
}

async function confirmDeleteUser() {
    if (!pendingDeleteUser || (!pendingDeleteUser.userId && !pendingDeleteUser.email)) {
        closeDeleteUserModal();
        return;
    }

    const btn = document.getElementById('del_modal_confirm_btn');
    if (btn) {
        btn.disabled = true;
        btn.innerHTML = '<span>Deleting...</span>';
    }

    try {
        const selectedApp = String(document.getElementById('appSelect')?.value || '').trim();
        const res = await fetch('/wipe-user-data', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                userId: pendingDeleteUser.userId,
                email: pendingDeleteUser.email,
                appName: selectedApp
            })
        });
        const json = await res.json();

        if (res.ok && json.success) {
            showAlert(json.message || 'User permanently deleted', 'success');
            closeDeleteUserModal();
            fetchUserDirectory(true);
        } else {
            throw new Error(json.message || 'Failed to delete user');
        }
    } catch (err) {
        console.error('Delete user error:', err);
        showAlert(err.message || 'Failed to delete user account', 'error');
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = `<svg width="15" height="15" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg><span>Delete User Account</span>`;
        }
    }
}

