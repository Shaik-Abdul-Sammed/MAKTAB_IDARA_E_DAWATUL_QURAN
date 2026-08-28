const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

const SALT = "idara_maktab_sec_salt_2026";
const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_MS = 15 * 60 * 1000; // 15 minutes lockout

// Helper to hash PIN matching Flutter App AuthProvider._hashPin
function hashPin(pin) {
  return crypto.createHash("sha256").update(SALT + pin).digest("hex");
}

function hashPinUnsalted(pin) {
  return crypto.createHash("sha256").update(pin).digest("hex");
}

/**
  HTTPS Endpoint: verifyTeacherPin
  Payload: { maktabId: string, teacherId: string|number, pin: string }
  Returns: { success: boolean, customToken?: string, error?: string }
 */
exports.verifyTeacherPin = functions.https.onRequest(async (req, res) => {
  // CORS handling
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ success: false, error: "Method Not Allowed" });
    return;
  }

  try {
    const { maktabId, teacherId, pin } = req.body || {};

    if (!maktabId || !teacherId || !pin) {
      res.status(400).json({ success: false, error: "Missing required fields: maktabId, teacherId, pin" });
      return;
    }

    const tIdStr = String(teacherId).trim();
    const mIdStr = String(maktabId).trim();
    const pinStr = String(pin).trim();
    const lockKey = `${mIdStr}_${tIdStr}`;

    // Rate Limiting Check
    const lockRef = admin.database().ref(`auth_rate_limits/${lockKey}`);
    const lockSnap = await lockRef.once("value");
    const lockData = lockSnap.val() || {};

    const now = Date.now();
    if (lockData.attempts >= MAX_FAILED_ATTEMPTS && lockData.lockoutUntil > now) {
      const waitMins = Math.ceil((lockData.lockoutUntil - now) / 60000);
      res.status(429).json({
        success: false,
        error: `Too many failed login attempts. Locked out for ${waitMins} more minute(s).`
      });
      return;
    }

    // Fetch Teacher record from Realtime Database
    const teacherRef = admin.database().ref(`maktabs/${mIdStr}/teachers/${tIdStr}`);
    const teacherSnap = await teacherRef.once("value");

    if (!teacherSnap.exists()) {
      await recordFailedAttempt(lockRef, lockData, now);
      res.status(401).json({ success: false, error: "Invalid Teacher ID or PIN." });
      return;
    }

    const teacherData = teacherSnap.val();
    const isActive = teacherData.is_active === 1 || teacherData.is_active === true || teacherData.isActive === true;

    if (!isActive) {
      res.status(403).json({ success: false, error: "Teacher account is inactive. Contact your administrator." });
      return;
    }

    // Compute PIN hashes
    const saltedHash = hashPin(pinStr);
    const unsaltedHash = hashPinUnsalted(pinStr);
    const storedHash = teacherData.pin_hash || teacherData.pinHash;

    const isMatch = storedHash === saltedHash || storedHash === unsaltedHash;

    if (!isMatch) {
      await recordFailedAttempt(lockRef, lockData, now);
      res.status(401).json({ success: false, error: "Invalid Teacher ID or PIN." });
      return;
    }

    // Successful Verification -> Clear Rate Limits
    await lockRef.remove();

    // Mint Firebase Custom Token with strict claims
    const uid = `teacher_${mIdStr}_${tIdStr}`;
    const customClaims = {
      role: "teacher",
      maktabId: mIdStr,
      teacherId: Number(tIdStr) || tIdStr
    };

    const customToken = await admin.auth().createCustomToken(uid, customClaims);

    res.status(200).json({
      success: true,
      customToken: customToken,
      teacher: {
        id: teacherData.id,
        name: teacherData.name,
        role: "teacher",
        maktabId: mIdStr
      }
    });
  } catch (err) {
    console.error("verifyTeacherPin Error:", err);
    res.status(500).json({ success: false, error: "Internal Server Error during verification." });
  }
});

async function recordFailedAttempt(lockRef, lockData, now) {
  const newAttempts = (lockData.attempts || 0) + 1;
  const lockoutUntil = newAttempts >= MAX_FAILED_ATTEMPTS ? now + LOCKOUT_MS : 0;
  await lockRef.set({
    attempts: newAttempts,
    lastAttempt: now,
    lockoutUntil: lockoutUntil
  });
}
