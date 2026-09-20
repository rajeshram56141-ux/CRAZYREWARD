const admin = require('firebase-admin');

const firebaseInstances = {};

function getOrInitFirebase(appName, serviceAccount) {
    if (firebaseInstances[appName]) {
        return firebaseInstances[appName];
    }

    const firebaseApp = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    }, appName);

    firebaseInstances[appName] = firebaseApp;
    return firebaseApp;
}

module.exports = {
    getOrInitFirebase
};