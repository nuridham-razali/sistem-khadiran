const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const authRoutes = require('./routes/authRoutes');
const attendanceRoutes = require('./routes/attendanceRoutes');
const adminRoutes = require('./routes/adminRoutes');
const faceRoutes = require('./routes/faceRoutes');

const app = express();

// Security & Middlewares
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate Limiter
const generalLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 120, // 120 requests per minute
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    errorCode: 'RATE_LIMIT_EXCEEDED',
    message: 'Too many requests. Please try again later.',
  },
});
app.use('/api', generalLimiter);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'UP',
    name: 'GeoAttend Backend API',
    version: '1.0.0',
    timezone: process.env.DEFAULT_TIMEZONE || 'Asia/Kuala_Lumpur',
    timestampUTC: new Date().toISOString(),
  });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/biometrics', faceRoutes);

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    errorCode: 'NOT_FOUND',
    message: `Endpoint ${req.method} ${req.url} does not exist.`,
  });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('[Unhandled Server Error]:', err);
  res.status(err.status || 500).json({
    success: false,
    errorCode: 'INTERNAL_SERVER_ERROR',
    message: err.message || 'An unexpected internal error occurred.',
  });
});

module.exports = app;
