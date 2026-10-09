const Razorpay = require('razorpay');
const crypto = require('crypto');
const config = require('../config/config');

let razorpayInstance = null;

// Initialize Razorpay
function initializeRazorpay() {
    if (razorpayInstance) return razorpayInstance;

    if (!config.razorpay.keyId || !config.razorpay.keySecret) {
        console.warn('⚠️ Razorpay credentials not configured. Payment processing disabled.');
        return null;
    }

    razorpayInstance = new Razorpay({
        key_id: config.razorpay.keyId,
        key_secret: config.razorpay.keySecret
    });

    console.log('✅ Razorpay initialized');
    return razorpayInstance;
}

// Get price for tier
function getPriceForTier(tier) {
    switch (tier) {
        case 1: return config.alertPricing.tier1;
        case 2: return config.alertPricing.tier2;
        case 3: return config.alertPricing.tier3;
        default: return config.alertPricing.tier1;
    }
}

// Get hospital count for tier
function getHospitalCountForTier(tier) {
    switch (tier) {
        case 1: return config.hospitalCountPerTier.tier1;
        case 2: return config.hospitalCountPerTier.tier2;
        case 3: return config.hospitalCountPerTier.tier3;
        default: return config.hospitalCountPerTier.tier1;
    }
}

// Create a new order
async function createOrder(amountPaise, alertId, notes = {}) {
    const razorpay = initializeRazorpay();

    if (!razorpay) {
        // Return mock order for testing
        console.log('📦 [Mock Razorpay] Creating order:', { amountPaise, alertId });
        return {
            id: `order_mock_${Date.now()}`,
            amount: amountPaise,
            currency: 'INR',
            receipt: alertId,
            status: 'created',
            mock: true
        };
    }

    try {
        const options = {
            amount: amountPaise,
            currency: 'INR',
            receipt: alertId,
            notes: {
                alertId,
                ...notes
            }
        };

        const order = await razorpay.orders.create(options);
        console.log('✅ Razorpay order created:', order.id);
        return order;
    } catch (error) {
        console.error('❌ Razorpay order creation error:', error.message);
        throw error;
    }
}

// Verify payment signature
function verifyPayment(orderId, paymentId, signature) {
    if (!config.razorpay.keySecret) {
        // Mock mode only exists for local development; config refuses to boot
        // production without keys, and this guards against it regardless.
        if (config.isProduction) return false;
        console.log('📦 [Mock Razorpay] Verifying payment:', { orderId, paymentId });
        return true; // Auto-verify in mock mode
    }

    if (typeof signature !== 'string') return false;

    const body = orderId + '|' + paymentId;
    const expected = Buffer.from(
        crypto.createHmac('sha256', config.razorpay.keySecret).update(body).digest('hex')
    );
    const received = Buffer.from(signature);

    return expected.length === received.length && crypto.timingSafeEqual(expected, received);
}

function isMockMode() {
    return !config.razorpay.keyId || !config.razorpay.keySecret;
}

// Capture payment (for manual capture mode)
async function capturePayment(paymentId, amount) {
    const razorpay = initializeRazorpay();

    if (!razorpay) {
        console.log('📦 [Mock Razorpay] Capturing payment:', { paymentId, amount });
        return { id: paymentId, status: 'captured', mock: true };
    }

    try {
        const payment = await razorpay.payments.capture(paymentId, amount);
        console.log('✅ Payment captured:', payment.id);
        return payment;
    } catch (error) {
        console.error('❌ Payment capture error:', error.message);
        throw error;
    }
}

module.exports = {
    initializeRazorpay,
    getPriceForTier,
    getHospitalCountForTier,
    createOrder,
    verifyPayment,
    isMockMode,
    capturePayment,
    config: config.razorpay
};
