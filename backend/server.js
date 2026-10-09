const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const config = require('./config/config');
const { initializeDatabase } = require('./models/database');
const { apiLimiter, authLimiter, emergencyLimiter } = require('./middleware/rateLimit');

// Import routes
const authRoutes = require('./routes/auth');
const hospitalsRoutes = require('./routes/hospitals');
const paymentsRoutes = require('./routes/payments');
const alertsRoutes = require('./routes/alerts');
const recordsRoutes = require('./routes/records');
const receiverRoutes = require('./routes/receiver');

// Import models for seeding
const Hospital = require('./models/Hospital');
const User = require('./models/User');

// Seed hospitals if empty
function seedHospitals() {
    if (Hospital.count() === 0) {
        console.log('🏥 Seeding hospital data...');

        // Local hospitals near Shravanabelagola / Bahubali College
        const hospitals = [
            {
                id: 'H001',
                name: 'Bahubali Children Hospital',
                address: 'Shri Dhavala Teertham, Chalya Post, Shravanabelagola (Hirisave Road), SH-8, Karnataka',
                phone: '+91-81763-41450',
                emergencyEmail: 'emergency@bahubali-hospital.com',
                latitude: 12.8540,
                longitude: 76.4850
            },
            {
                id: 'H002',
                name: 'Shravanabelagola Government Hospital',
                address: 'Shravanabelagola Main Road, Shravanabelagola, Karnataka 573135',
                phone: '+91-81726-00000',
                emergencyEmail: 'govt-hospital@shravanabelagola.gov.in',
                latitude: 12.8585,
                longitude: 76.4880
            },
            {
                id: 'H003',
                name: 'Swayam Sevak Nagara Hospital',
                address: 'Shravanabelagola area, Karnataka',
                phone: '+91-81726-00001',
                emergencyEmail: 'swayamsevak@hospital.com',
                latitude: 12.8560,
                longitude: 76.4900
            },
            {
                id: 'H004',
                name: 'Primary Health Centre (PHC) - Chalya',
                address: 'Chalya / Nirisare Road, Shravanabelagola, Karnataka',
                phone: '+91-81726-00002',
                emergencyEmail: 'phc-chalya@karnataka.gov.in',
                latitude: 12.8450,
                longitude: 76.4750
            }
        ];

        hospitals.forEach(hospital => {
            try {
                Hospital.create(hospital);
                console.log(`  ✅ Added: ${hospital.name}`);
            } catch (error) {
                console.error(`  ❌ Failed to add ${hospital.name}:`, error.message);
            }
        });

        console.log(`🏥 Seeded ${Hospital.count()} hospitals`);
    } else {
        console.log(`🏥 Found ${Hospital.count()} existing hospitals`);
    }
}

// Seed one hospital-staff account so the receiver app has something to sign in
// with on a fresh install. Never runs in production, and never overwrites an
// account that already exists.
async function seedReceiverStaff() {
    if (process.env.NODE_ENV === 'production') return;
    if (config.seedReceiverStaff === false) return;

    const email = (config.seedReceiverEmail || 'duty@bahubali-hospital.com').toLowerCase();
    if (User.findByEmail(email)) return;

    const hospitalId = config.seedReceiverHospitalId || Hospital.findAll()[0]?.id;
    if (!hospitalId) return;

    const password = config.seedReceiverPassword || 'elan-demo-2026';
    const passwordHash = await bcrypt.hash(password, 10);

    const staff = User.create('Duty Officer', email, passwordHash, {
        role: 'hospital',
        hospitalId
    });

    console.log(`🩺 Seeded receiver account: ${staff.email} (hospital ${hospitalId})`);
    if (process.env.NODE_ENV !== 'test') {
        console.log(`   Demo password: ${password}`);
    }
}

// Create Express app
function createApp() {
    const app = express();

    // Middleware
    app.use(cors());
    app.use(express.json({ limit: '100kb' }));

    // Request logging
    app.use((req, res, next) => {
        if (process.env.NODE_ENV !== 'test') {
            console.log(`${new Date().toISOString()} | ${req.method} ${req.path}`);
        }
        next();
    });

    // Rate limiting
    app.use('/api/auth/register', authLimiter);
    app.use('/api/auth/login', authLimiter);
    app.use('/api/alerts/send', emergencyLimiter);
    app.use('/api', apiLimiter);

    // Health check
    app.get('/health', (req, res) => {
        res.json({
            status: 'ok',
            service: 'Élan Backend',
            timestamp: new Date().toISOString()
        });
    });

    // API Routes
    app.use('/api/auth', authRoutes);
    app.use('/api/hospitals', hospitalsRoutes);
    app.use('/api/payments', paymentsRoutes);
    app.use('/api/alerts', alertsRoutes);
    app.use('/api/records', recordsRoutes);
    app.use('/api/receiver', receiverRoutes);

    // 404 handler
    app.use((req, res) => {
        res.status(404).json({ error: 'Endpoint not found' });
    });

    // Error handler
    app.use((err, req, res, next) => {
        // Malformed or oversized request bodies are client errors, not crashes
        if (err.type === 'entity.parse.failed') {
            return res.status(400).json({ error: 'Request body is not valid JSON' });
        }
        if (err.type === 'entity.too.large') {
            return res.status(413).json({ error: 'Request body too large' });
        }
        console.error('Server error:', err);
        res.status(500).json({ error: 'Internal server error' });
    });

    return app;
}

// Initialize database and seed data (idempotent)
async function initialize() {
    await initializeDatabase();
    seedHospitals();
    await seedReceiverStaff();
}

// Start server (async to wait for database)
async function startServer() {
    try {
        await initialize();

        const app = createApp();

        // Start listening
        app.listen(config.port, () => {
            console.log(`
╔════════════════════════════════════════════════════╗
║          🫀 Élan Backend Server               ║
╠════════════════════════════════════════════════════╣
║  Status:    Running                                ║
║  Port:      ${config.port}                                    ║
║  Time:      ${new Date().toISOString()}     ║
╚════════════════════════════════════════════════════╝
      `);
        });
    } catch (error) {
        console.error('Failed to start server:', error);
        process.exit(1);
    }
}

const app = createApp();

module.exports = {
    app,
    createApp,
    initialize,
    seedHospitals,
    seedReceiverStaff,
    startServer
};

if (require.main === module) {
    startServer();
}