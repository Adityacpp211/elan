const crypto = require('crypto');
const { get, run } = require('./database');
const { v4: uuidv4 } = require('uuid');

const CODE_TTL_MS = 15 * 60 * 1000;
const MAX_ATTEMPTS = 5;

function hashCode(code) {
    return crypto.createHash('sha256').update(String(code)).digest('hex');
}

/// One-time 6-digit codes for resetting a forgotten password. Only a hash is
/// stored; a code expires after 15 minutes or 5 wrong guesses, and issuing a
/// new code cancels any earlier one for the same account.
class PasswordReset {
    static issue(userId) {
        const now = new Date();
        run('UPDATE password_resets SET used_at = ? WHERE user_id = ? AND used_at IS NULL',
            [now.toISOString(), userId]);

        const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
        run(
            `INSERT INTO password_resets (id, user_id, code_hash, expires_at, created_at)
       VALUES (?, ?, ?, ?, ?)`,
            [uuidv4(), userId, hashCode(code), new Date(now.getTime() + CODE_TTL_MS).toISOString(), now.toISOString()]
        );
        return code;
    }

    /// Check [code] for [userId]. Returns true once (the code is then spent);
    /// a wrong code uses up one of the attempts.
    static consume(userId, code) {
        const reset = get(
            `SELECT * FROM password_resets WHERE user_id = ? AND used_at IS NULL
       ORDER BY created_at DESC LIMIT 1`,
            [userId]
        );
        if (!reset) return false;
        if (new Date(reset.expires_at).getTime() < Date.now() || reset.attempts >= MAX_ATTEMPTS) {
            return false;
        }

        const expected = Buffer.from(reset.code_hash, 'hex');
        const received = Buffer.from(hashCode(code), 'hex');
        const ok = expected.length === received.length && crypto.timingSafeEqual(expected, received);

        if (!ok) {
            run('UPDATE password_resets SET attempts = attempts + 1 WHERE id = ?', [reset.id]);
            return false;
        }
        run('UPDATE password_resets SET used_at = ? WHERE id = ?', [new Date().toISOString(), reset.id]);
        return true;
    }
}

PasswordReset.CODE_TTL_MS = CODE_TTL_MS;
PasswordReset.MAX_ATTEMPTS = MAX_ATTEMPTS;

module.exports = PasswordReset;
