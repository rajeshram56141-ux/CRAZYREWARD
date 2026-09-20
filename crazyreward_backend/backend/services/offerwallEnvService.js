/**
 * Resolves Offerwall and Survey configuration fields by falling back to .env variables
 * if key fields (appId, secretKey, token, appKey, url, pubKey, etc.) are empty in DB/Admin.
 */

function getEnvVal(providerKey, fieldName) {
    if (!providerKey || !fieldName) return '';

    const cleanP = String(providerKey).toUpperCase().replace(/[\s\-_]/g, '');
    const cleanF = String(fieldName).toUpperCase().replace(/[\s\-_]/g, '');

    for (const [envKey, envVal] of Object.entries(process.env)) {
        if (!envVal || !envVal.trim() || envVal.trim().startsWith('YOUR_')) continue;

        const normalizedEnvKey = String(envKey).toUpperCase().replace(/[\s\-_]/g, '');

        if (normalizedEnvKey.includes(cleanP) || cleanP.includes(normalizedEnvKey.replace('OFFERWALL', ''))) {
            if (cleanF === 'APPID' || cleanF === 'APPKEY' || cleanF === 'TOKEN' || cleanF === 'KEY') {
                if (normalizedEnvKey.includes('KEY') || normalizedEnvKey.includes('APP') || normalizedEnvKey.includes('ID') || normalizedEnvKey.includes('TOKEN')) {
                    if (!normalizedEnvKey.includes('SECRET') || cleanF === 'SECRETKEY') {
                        return envVal.trim();
                    }
                }
            }
            if ((cleanF === 'SECRETKEY' || cleanF === 'SECRET') && (normalizedEnvKey.includes('SECRET') || normalizedEnvKey.includes('PASSWORD'))) {
                return envVal.trim();
            }
            if (cleanF === 'URL' && normalizedEnvKey.includes('URL')) {
                return envVal.trim();
            }
        }
    }

    return '';
}

function resolveOfferwallEnvFallbacks(offersConfig = {}) {
    if (!offersConfig || typeof offersConfig !== 'object') return {};
    const resolved = JSON.parse(JSON.stringify(offersConfig));

    for (const [providerKey, providerCfg] of Object.entries(resolved)) {
        if (!providerCfg || typeof providerCfg !== 'object') continue;

        const fieldsToCheck = [
            'appId', 'secretKey', 'token', 'appKey', 'url',
            'pubKey', 'apiKey', 'apiSecret', 'apiToken', 'placementId'
        ];

        for (const field of fieldsToCheck) {
            const currentVal = String(providerCfg[field] || '').trim();
            if (!currentVal) {
                const fallbackVal = getEnvVal(providerKey, field);
                if (fallbackVal) {
                    providerCfg[field] = fallbackVal;
                }
            }
        }
    }

    return resolved;
}

module.exports = {
    getEnvVal,
    resolveOfferwallEnvFallbacks
};
