const path = require('path');
const fs = require('fs');
const dotenv = require('dotenv');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

// Load environment variables
const envPath = fs.existsSync(path.join(__dirname, '../.env'))
    ? path.join(__dirname, '../.env')
    : path.join(__dirname, '.env');
dotenv.config({ path: envPath });

// Import Models
const FirebaseService = require('./admin/models/firebaseService');
const Admin = require('./admin/models/admin');

async function seed() {
    const mongoUri = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/crazyreward';
    console.log(`🔌 Connecting to MongoDB at: ${mongoUri}...`);

    try {
        await mongoose.connect(mongoUri);
        console.log('✅ Connected to MongoDB successfully.');

        // =====================================================================
        // 1. SEED FIREBASE SERVICE
        // =====================================================================
        console.log('\n📦 Seeding FirebaseService...');
        
        let serviceAccountKeyPath = path.join(__dirname, 'serviceAccountKey.json');
        if (!fs.existsSync(serviceAccountKeyPath)) {
            serviceAccountKeyPath = path.join(__dirname, '../serviceAccountKey.json');
        }

        if (!fs.existsSync(serviceAccountKeyPath)) {
            console.error(`❌ serviceAccountKey.json not found at ${serviceAccountKeyPath}`);
        } else {
            const rawKey = fs.readFileSync(serviceAccountKeyPath, 'utf8');
            const serviceAccount = JSON.parse(rawKey);

            const appName = 'crazyreward';
            const displayName = 'Crazyreward';

            const firebaseService = await FirebaseService.findOneAndUpdate(
                { appName },
                {
                    serviceAccount,
                    appName,
                    displayName,
                },
                { upsert: true, new: true }
            );

            console.log(`✅ FirebaseService seeded successfully:`);
            console.log(`   - App Name: ${firebaseService.appName}`);
            console.log(`   - Display Name: ${firebaseService.displayName}`);
            console.log(`   - Project ID: ${serviceAccount.project_id}`);
        }

        // =====================================================================
        // 2. SEED ADMIN USER
        // =====================================================================
        console.log('\n👤 Seeding Admin User...');
        const adminEmail = 'admingames@zodroidmedia.com';
        const adminPasswordRaw = 'admin@zodroidgames';
        const hashedPassword = await bcrypt.hash(adminPasswordRaw, 10);

        const allPermissions = {
            dashboard: true,
            users: true,
            payouts: true,
            dailyTasks: true,
            games: true,
            readEarn: true,
            giveaways: true,
            promoCodes: true,
            userActivity: true,
            unusualActivity: true,
            wallet: true,
            appConfig: true,
            notifications: true,
        };

        const adminUser = await Admin.findOneAndUpdate(
            { email: adminEmail },
            {
                email: adminEmail,
                password: hashedPassword,
                name: 'Super Admin',
                role: 'superadmin',
                permissions: allPermissions,
                lastLogin: new Date(),
            },
            { upsert: true, new: true }
        );

        console.log(`✅ Admin User seeded successfully:`);
        console.log(`   - Email: ${adminUser.email}`);
        console.log(`   - Role: ${adminUser.role}`);
        console.log(`   - Password: ${adminPasswordRaw} (Hashed with bcrypt)`);
        console.log(`   - Permissions: Full Access (All True)`);

        console.log('\n🎉 ALL SEEDING COMPLETED SUCCESSFULLY!\n');
    } catch (error) {
        console.error('❌ Seeding failed with error:', error);
    } finally {
        await mongoose.disconnect();
        console.log('🔌 Disconnected from MongoDB.');
        process.exit(0);
    }
}

seed();
