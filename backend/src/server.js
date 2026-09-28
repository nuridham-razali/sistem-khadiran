require('dotenv').config();
const app = require('./app');
const sheetsService = require('./services/sheetsService');

const PORT = process.env.PORT || 4000;

async function startServer() {
  try {
    console.log('----------------------------------------------------');
    console.log('Starting GeoAttend Enterprise Attendance Backend...');
    console.log('----------------------------------------------------');

    // Initialize sheets service
    await sheetsService.init();

    const server = app.listen(PORT, '0.0.0.0', () => {
      console.log(`[GeoAttend] Server listening on port ${PORT}`);
      console.log(`[GeoAttend] Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`[GeoAttend] Timezone: ${process.env.DEFAULT_TIMEZONE || 'Asia/Kuala_Lumpur'}`);
      console.log(`[GeoAttend] Health check: http://localhost:${PORT}/health`);
      console.log('----------------------------------------------------');
    });

    // Graceful Shutdown
    process.on('SIGTERM', () => {
      console.log('[GeoAttend] SIGTERM received. Shutting down gracefully...');
      server.close(() => {
        console.log('[GeoAttend] Process terminated.');
      });
    });
  } catch (err) {
    console.error('[GeoAttend] Fatal startup error:', err);
    process.exit(1);
  }
}

if (require.main === module) {
  startServer();
}

module.exports = app;
