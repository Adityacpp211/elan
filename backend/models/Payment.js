const { all, get, run } = require('./database');
const { randomUUID: uuidv4 } = require('crypto');

class Payment {
    static create(data) {
        const id = uuidv4();
        const now = new Date().toISOString();
        run(
            `INSERT INTO payments (id, alert_id, razorpay_order_id, amount_paise, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
            [id, data.alertId, data.razorpayOrderId, data.amountPaise, 'pending', now]
        );
        return this.findById(id);
    }

    static findById(id) {
        return get('SELECT * FROM payments WHERE id = ?', [id]);
    }

    static findByOrderId(razorpayOrderId) {
        return get('SELECT * FROM payments WHERE razorpay_order_id = ?', [razorpayOrderId]);
    }

    static findByAlertId(alertId) {
        return get('SELECT * FROM payments WHERE alert_id = ?', [alertId]);
    }

    static updateStatus(id, status, razorpayPaymentId = null) {
        if (razorpayPaymentId) {
            run(
                `UPDATE payments SET status = ?, razorpay_payment_id = ? WHERE id = ?`,
                [status, razorpayPaymentId, id]
            );
        } else {
            run('UPDATE payments SET status = ? WHERE id = ?', [status, id]);
        }
        return this.findById(id);
    }
}

module.exports = Payment;
