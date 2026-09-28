/**
 * Idempotency Middleware for Attendance Requests
 * 
 * Prevents duplicate clock-ins and clock-outs caused by mobile network retries or timeouts.
 */

const idempotencyStore = new Map();
const IDEMPOTENCY_TTL_MS = 15 * 60 * 1000; // 15 minutes

// Clean up expired keys every 5 minutes
const cleanupTimer = setInterval(() => {
  const now = Date.now();
  for (const [key, val] of idempotencyStore.entries()) {
    if (now > val.expiresAt) {
      idempotencyStore.delete(key);
    }
  }
}, 5 * 60 * 1000);
if (cleanupTimer.unref) cleanupTimer.unref();

function idempotencyMiddleware(req, res, next) {
  // Only inspect state-mutating requests (POST, PUT, PATCH)
  if (req.method !== 'POST' && req.method !== 'PUT' && req.method !== 'PATCH') {
    return next();
  }

  const idempotencyKey =
    req.headers['x-idempotency-key'] ||
    req.body?.idempotencyKey ||
    null;

  if (!idempotencyKey) {
    // If client did not provide an explicit idempotency key, proceed normally
    return next();
  }

  const employeePrefix = req.user?.employeeId ? `${req.user.employeeId}:` : '';
  const fullKey = `${employeePrefix}${idempotencyKey}`;

  const cached = idempotencyStore.get(fullKey);

  if (cached) {
    if (cached.status === 'PROCESSING') {
      return res.status(409).json({
        success: false,
        errorCode: 'CONCURRENT_REQUEST_IN_PROGRESS',
        message: 'A request with this idempotency key is currently being processed. Please wait.',
      });
    }

    // Return the cached successful/failed response
    res.setHeader('X-Cache-Lookup', 'HIT');
    return res.status(cached.statusCode).json(cached.body);
  }

  // Mark as processing
  idempotencyStore.set(fullKey, {
    status: 'PROCESSING',
    createdAt: Date.now(),
    expiresAt: Date.now() + IDEMPOTENCY_TTL_MS,
  });

  // Intercept json() response to cache outcome
  const originalJson = res.json.bind(res);
  res.json = (body) => {
    // Store finished response
    idempotencyStore.set(fullKey, {
      status: 'COMPLETED',
      statusCode: res.statusCode,
      body,
      createdAt: Date.now(),
      expiresAt: Date.now() + IDEMPOTENCY_TTL_MS,
    });
    return originalJson(body);
  };

  next();
}

module.exports = idempotencyMiddleware;
