require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });
const sheetsService = require('../services/sheetsService');

async function run() {
  console.log('[Init Sheets] Initializing Google Sheets worksheets & header schemas...');
  if (!process.env.GOOGLE_SHEETS_SPREADSHEET_ID) {
    console.error('ERROR: GOOGLE_SHEETS_SPREADSHEET_ID is not configured in .env');
    console.log('Please create a Google Spreadsheet, share Editor access with your Service Account email,');
    console.log('and put the Spreadsheet ID into backend/.env.');
    process.exit(1);
  }

  await sheetsService.init();
  if (!sheetsService.isConfigured) {
    console.error('ERROR: Could not authenticate with Google Sheets API.');
    console.log('Check your GOOGLE_SERVICE_ACCOUNT_KEY_FILE or GOOGLE_SERVICE_ACCOUNT_EMAIL credentials.');
    process.exit(1);
  }

  await sheetsService.ensureWorksheetsExist();
  console.log('[Init Sheets] All worksheets verified and initialized successfully!');
}

if (require.main === module) {
  run();
}
