/**
 * Google Sheets Database Service
 * 
 * Features:
 * - Enterprise serialized write queue to prevent Google Sheets 429 quota exhaustion & write race conditions.
 * - UUID-based record identification (never row index).
 * - Bi-temporal timestamps: UTC ISO 8601 for canonical storage, Asia/Kuala_Lumpur for human review.
 * - Local snapshot caching to allow instant startup, offline dev, and graceful degradation during Google Cloud outages.
 */

const fs = require('fs');
const path = require('path');
const { google } = require('googleapis');
const { v4: uuidv4 } = require('uuid');

// Worksheet names matching specification
const SHEET_NAMES = {
  EMPLOYEES: 'Employees',
  OFFICES: 'Offices',
  ATTENDANCE: 'Attendance',
  AUDIT_LOG: 'AuditLog',
};

// Column Headers Definition
const HEADERS = {
  [SHEET_NAMES.EMPLOYEES]: [
    'EmployeeID',
    'Name',
    'Email',
    'Department',
    'AssignedOfficeID',
    'Role', // 'employee' | 'admin'
    'Active', // 'TRUE' | 'FALSE'
    'PasswordHash',
    'FaceEnrolled', // 'TRUE' | 'FALSE'
    'FaceEnrolledAt',
    'CreatedAt',
  ],
  [SHEET_NAMES.OFFICES]: [
    'OfficeID',
    'Name',
    'Latitude',
    'Longitude',
    'RadiusMeters',
    'MaxAccuracyMeters',
    'MaxAgeSeconds',
    'Address',
    'Active',
  ],
  [SHEET_NAMES.ATTENDANCE]: [
    'SessionID',
    'EmployeeID',
    'EmployeeName',
    'Department',
    'OfficeID',
    'WorkDate', // YYYY-MM-DD in Asia/Kuala_Lumpur
    'ClockInTimeUTC',
    'ClockInTimeKL',
    'ClockOutTimeUTC',
    'ClockOutTimeKL',
    'ClockInLat',
    'ClockInLng',
    'ClockInAccuracy',
    'ClockInDistanceMeters',
    'ClockOutLat',
    'ClockOutLng',
    'ClockOutAccuracy',
    'ClockOutDistanceMeters',
    'FaceVerified', // 'YES' | 'NO' | 'EXEMPT'
    'FaceVerificationConfidence',
    'WorkedMinutes',
    'WorkedHours',
    'AttendanceStatus', // 'IN_PROGRESS' | 'COMPLETED' | 'EXCEPTION_OUTSIDE_RADIUS' | 'EXCEPTION_MISSING_CLOCK_OUT' | 'CORRECTED'
    'ExceptionNotes',
    'LastModifiedBy',
    'LastModifiedAt',
  ],
  [SHEET_NAMES.AUDIT_LOG]: [
    'LogID',
    'ActorID',
    'ActorName',
    'Action',
    'AffectedRecordType',
    'AffectedRecordID',
    'TimestampUTC',
    'TimestampKL',
    'Reason',
    'BeforeValues',
    'AfterValues',
  ],
};

class SheetsService {
  constructor() {
    this.sheetsClient = null;
    this.spreadsheetId = process.env.GOOGLE_SHEETS_SPREADSHEET_ID || null;
    this.isConfigured = false;
    this.cacheFilePath = path.join(__dirname, '../../data/sheets_cache.json');
    this.queue = Promise.resolve(); // FIFO queue for serialized write operations
    this.cache = {
      [SHEET_NAMES.EMPLOYEES]: [],
      [SHEET_NAMES.OFFICES]: [],
      [SHEET_NAMES.ATTENDANCE]: [],
      [SHEET_NAMES.AUDIT_LOG]: [],
    };

    this.init();
  }

  /**
   * Initializes Google Auth and loads cached data.
   */
  async init() {
    this.loadLocalCache();

    // Check for Service Account Key File or Environment Variables
    const keyFilePath = process.env.GOOGLE_SERVICE_ACCOUNT_KEY_FILE
      ? path.resolve(process.env.GOOGLE_SERVICE_ACCOUNT_KEY_FILE)
      : null;

    let auth = null;

    if (keyFilePath && fs.existsSync(keyFilePath)) {
      try {
        auth = new google.auth.GoogleAuth({
          keyFile: keyFilePath,
          scopes: ['https://www.googleapis.com/auth/spreadsheets'],
        });
        console.log(`[Google Sheets] Using service account key file: ${keyFilePath}`);
      } catch (err) {
        console.warn(`[Google Sheets] Failed loading key file: ${err.message}`);
      }
    } else if (process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL && process.env.GOOGLE_PRIVATE_KEY) {
      try {
        const privateKey = process.env.GOOGLE_PRIVATE_KEY.replace(/\\n/g, '\n');
        auth = new google.auth.JWT({
          email: process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL,
          key: privateKey,
          scopes: ['https://www.googleapis.com/auth/spreadsheets'],
        });
        console.log(`[Google Sheets] Using environment service account credentials for: ${process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL}`);
      } catch (err) {
        console.warn(`[Google Sheets] Failed configuring JWT auth: ${err.message}`);
      }
    }

    if (auth && this.spreadsheetId) {
      try {
        this.sheetsClient = google.sheets({ version: 'v4', auth });
        this.isConfigured = true;
        console.log(`[Google Sheets] Connected successfully to Spreadsheet ID: ${this.spreadsheetId}`);
        await this.syncFromGoogleSheets();
      } catch (err) {
        console.warn(`[Google Sheets] Initialization sync failed. Falling back to local cache: ${err.message}`);
      }
    } else {
      console.log(`[Google Sheets] Service account or SPREADSHEET_ID not fully provided. Running in Standalone Resilient Mode with local file cache at ${this.cacheFilePath}`);
    }
  }

  /**
   * Serializes a write task using a promise queue to prevent concurrency race conditions on Google Sheets.
   */
  enqueueWrite(task) {
    const runTask = () =>
      new Promise((resolve, reject) => {
        task()
          .then(resolve)
          .catch(reject);
      });

    this.queue = this.queue.then(runTask, runTask);
    return this.queue;
  }

  loadLocalCache() {
    try {
      if (fs.existsSync(this.cacheFilePath)) {
        const data = fs.readFileSync(this.cacheFilePath, 'utf8');
        this.cache = JSON.parse(data);
      } else {
        this.saveLocalCache();
      }
    } catch (e) {
      console.error('[Google Sheets Cache] Error loading cache:', e.message);
    }
  }

  saveLocalCache() {
    try {
      const dir = path.dirname(this.cacheFilePath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      fs.writeFileSync(this.cacheFilePath, JSON.stringify(this.cache, null, 2), 'utf8');
    } catch (e) {
      console.error('[Google Sheets Cache] Error saving cache:', e.message);
    }
  }

  /**
   * Ensures Google Sheets has all necessary worksheets and column headers.
   */
  async ensureWorksheetsExist() {
    if (!this.isConfigured || !this.sheetsClient) return;

    try {
      const meta = await this.sheetsClient.spreadsheets.get({
        spreadsheetId: this.spreadsheetId,
      });

      const existingSheets = meta.data.sheets.map((s) => s.properties.title);

      for (const [sheetName, headers] of Object.entries(HEADERS)) {
        if (!existingSheets.includes(sheetName)) {
          // Add sheet
          await this.sheetsClient.spreadsheets.batchUpdate({
            spreadsheetId: this.spreadsheetId,
            requestBody: {
              requests: [
                {
                  addSheet: {
                    properties: { title: sheetName },
                  },
                },
              ],
            },
          });
          // Add headers
          await this.sheetsClient.spreadsheets.values.update({
            spreadsheetId: this.spreadsheetId,
            range: `${sheetName}!A1`,
            valueInputOption: 'USER_ENTERED',
            requestBody: {
              values: [headers],
            },
          });
          console.log(`[Google Sheets] Created worksheet '${sheetName}' with headers.`);
        }
      }
    } catch (err) {
      console.error('[Google Sheets] Error ensuring worksheets exist:', err.message);
    }
  }

  /**
   * Syncs existing Google Sheet rows into memory.
   */
  async syncFromGoogleSheets() {
    if (!this.isConfigured || !this.sheetsClient) return;

    for (const sheetName of Object.values(SHEET_NAMES)) {
      try {
        const res = await this.sheetsClient.spreadsheets.values.get({
          spreadsheetId: this.spreadsheetId,
          range: `${sheetName}!A1:Z10000`,
        });

        const rows = res.data.values || [];
        if (rows.length > 1) {
          const headers = rows[0];
          const records = rows.slice(1).map((row) => {
            const item = {};
            headers.forEach((h, idx) => {
              item[h] = row[idx] !== undefined ? row[idx] : '';
            });
            return item;
          });
          this.cache[sheetName] = records;
        }
      } catch (err) {
        console.warn(`[Google Sheets] Failed reading ${sheetName}: ${err.message}`);
      }
    }
    this.saveLocalCache();
  }

  // ==========================================
  // EMPLOYEE METHODS
  // ==========================================

  async getEmployees() {
    return [...this.cache[SHEET_NAMES.EMPLOYEES]];
  }

  async getEmployeeById(employeeId) {
    return this.cache[SHEET_NAMES.EMPLOYEES].find(
      (e) => String(e.EmployeeID).toLowerCase() === String(employeeId).toLowerCase()
    ) || null;
  }

  async getEmployeeByEmail(email) {
    return this.cache[SHEET_NAMES.EMPLOYEES].find(
      (e) => String(e.Email).toLowerCase() === String(email).toLowerCase()
    ) || null;
  }

  async saveEmployee(employee) {
    return this.enqueueWrite(async () => {
      const existing = await this.getEmployeeById(employee.EmployeeID);
      if (existing) {
        throw new Error(`Employee ID ${employee.EmployeeID} already exists.`);
      }

      this.cache[SHEET_NAMES.EMPLOYEES].push(employee);
      this.saveLocalCache();

      if (this.isConfigured && this.sheetsClient) {
        const row = HEADERS[SHEET_NAMES.EMPLOYEES].map((h) => employee[h] ?? '');
        await this.appendRowWithRetry(SHEET_NAMES.EMPLOYEES, row);
      }

      return employee;
    });
  }

  async updateEmployee(employeeId, updates) {
    return this.enqueueWrite(async () => {
      const idx = this.cache[SHEET_NAMES.EMPLOYEES].findIndex(
        (e) => String(e.EmployeeID).toLowerCase() === String(employeeId).toLowerCase()
      );
      if (idx === -1) {
        throw new Error(`Employee ID ${employeeId} not found.`);
      }

      const updated = { ...this.cache[SHEET_NAMES.EMPLOYEES][idx], ...updates };
      this.cache[SHEET_NAMES.EMPLOYEES][idx] = updated;
      this.saveLocalCache();

      if (this.isConfigured && this.sheetsClient) {
        await this.updateRowByUniqueId(SHEET_NAMES.EMPLOYEES, 'EmployeeID', employeeId, updated);
      }

      return updated;
    });
  }

  // ==========================================
  // OFFICE METHODS
  // ==========================================

  async getOffices() {
    return [...this.cache[SHEET_NAMES.OFFICES]];
  }

  async getOfficeById(officeId) {
    return this.cache[SHEET_NAMES.OFFICES].find(
      (o) => String(o.OfficeID).toLowerCase() === String(officeId).toLowerCase()
    ) || null;
  }

  async saveOffice(office) {
    return this.enqueueWrite(async () => {
      this.cache[SHEET_NAMES.OFFICES].push(office);
      this.saveLocalCache();

      if (this.isConfigured && this.sheetsClient) {
        const row = HEADERS[SHEET_NAMES.OFFICES].map((h) => office[h] ?? '');
        await this.appendRowWithRetry(SHEET_NAMES.OFFICES, row);
      }
      return office;
    });
  }

  async updateOffice(officeId, updates) {
    return this.enqueueWrite(async () => {
      const idx = this.cache[SHEET_NAMES.OFFICES].findIndex(
        (o) => String(o.OfficeID).toLowerCase() === String(officeId).toLowerCase()
      );
      if (idx === -1) {
        throw new Error(`Office ID ${officeId} not found.`);
      }

      const updated = { ...this.cache[SHEET_NAMES.OFFICES][idx], ...updates };
      this.cache[SHEET_NAMES.OFFICES][idx] = updated;
      this.saveLocalCache();

      if (this.isConfigured && this.sheetsClient) {
        await this.updateRowByUniqueId(SHEET_NAMES.OFFICES, 'OfficeID', officeId, updated);
      }

      return updated;
    });
  }

  // ==========================================
  // ATTENDANCE METHODS
  // ==========================================

  async getAttendanceRecords(filter = {}) {
    let records = [...this.cache[SHEET_NAMES.ATTENDANCE]];

    if (filter.employeeId) {
      records = records.filter(
        (r) => String(r.EmployeeID).toLowerCase() === String(filter.employeeId).toLowerCase()
      );
    }
    if (filter.officeId) {
      records = records.filter(
        (r) => String(r.OfficeID).toLowerCase() === String(filter.officeId).toLowerCase()
      );
    }
    if (filter.department) {
      records = records.filter(
        (r) => String(r.Department).toLowerCase() === String(filter.department).toLowerCase()
      );
    }
    if (filter.status) {
      records = records.filter((r) => r.AttendanceStatus === filter.status);
    }
    if (filter.startDate) {
      records = records.filter((r) => r.WorkDate >= filter.startDate);
    }
    if (filter.endDate) {
      records = records.filter((r) => r.WorkDate <= filter.endDate);
    }

    // Sort descending by ClockInTimeUTC
    return records.sort((a, b) => (b.ClockInTimeUTC || '').localeCompare(a.ClockInTimeUTC || ''));
  }

  async getAttendanceById(sessionId) {
    return this.cache[SHEET_NAMES.ATTENDANCE].find(
      (r) => String(r.SessionID) === String(sessionId)
    ) || null;
  }

  /**
   * Finds the latest open session (IN_PROGRESS) for an employee.
   * Handles overnight shifts gracefully by matching the active open session regardless of date.
   */
  async getOpenSession(employeeId) {
    return this.cache[SHEET_NAMES.ATTENDANCE].find(
      (r) =>
        String(r.EmployeeID).toLowerCase() === String(employeeId).toLowerCase() &&
        r.AttendanceStatus === 'IN_PROGRESS'
    ) || null;
  }

  async saveAttendanceSession(record) {
    return this.enqueueWrite(async () => {
      this.cache[SHEET_NAMES.ATTENDANCE].push(record);
      this.saveLocalCache();

      if (this.isConfigured && this.sheetsClient) {
        const row = HEADERS[SHEET_NAMES.ATTENDANCE].map((h) => record[h] ?? '');
        await this.appendRowWithRetry(SHEET_NAMES.ATTENDANCE, row);
      }

      return record;
    });
  }

  async updateAttendanceSession(sessionId, updates) {
    return this.enqueueWrite(async () => {
      const idx = this.cache[SHEET_NAMES.ATTENDANCE].findIndex(
        (r) => String(r.SessionID) === String(sessionId)
      );
      if (idx === -1) {
        throw new Error(`Attendance session ${sessionId} not found.`);
      }

      const updated = { ...this.cache[SHEET_NAMES.ATTENDANCE][idx], ...updates };
      this.cache[SHEET_NAMES.ATTENDANCE][idx] = updated;
      this.saveLocalCache();

      if (this.isConfigured && this.sheetsClient) {
        await this.updateRowByUniqueId(SHEET_NAMES.ATTENDANCE, 'SessionID', sessionId, updated);
      }

      return updated;
    });
  }

  // ==========================================
  // AUDIT LOG METHODS
  // ==========================================

  async recordAuditLog({
    actorId,
    actorName,
    action,
    affectedRecordType,
    affectedRecordId,
    timestampUTC,
    timestampKL,
    reason,
    beforeValues,
    afterValues,
  }) {
    return this.enqueueWrite(async () => {
      const logEntry = {
        LogID: uuidv4(),
        ActorID: actorId || 'SYSTEM',
        ActorName: actorName || 'System Automated Process',
        Action: action,
        AffectedRecordType: affectedRecordType,
        AffectedRecordID: affectedRecordId,
        TimestampUTC: timestampUTC || new Date().toISOString(),
        TimestampKL: timestampKL || '',
        Reason: reason || 'N/A',
        BeforeValues: typeof beforeValues === 'object' ? JSON.stringify(beforeValues) : String(beforeValues || ''),
        AfterValues: typeof afterValues === 'object' ? JSON.stringify(afterValues) : String(afterValues || ''),
      };

      this.cache[SHEET_NAMES.AUDIT_LOG].push(logEntry);
      this.saveLocalCache();

      if (this.isConfigured && this.sheetsClient) {
        const row = HEADERS[SHEET_NAMES.AUDIT_LOG].map((h) => logEntry[h] ?? '');
        await this.appendRowWithRetry(SHEET_NAMES.AUDIT_LOG, row);
      }

      return logEntry;
    });
  }

  async getAuditLogs(limit = 100) {
    return [...this.cache[SHEET_NAMES.AUDIT_LOG]]
      .sort((a, b) => (b.TimestampUTC || '').localeCompare(a.TimestampUTC || ''))
      .slice(0, limit);
  }

  // ==========================================
  // GOOGLE SHEETS API HELPERS (With Exponential Backoff)
  // ==========================================

  async appendRowWithRetry(sheetName, values, retries = 3) {
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        await this.sheetsClient.spreadsheets.values.append({
          spreadsheetId: this.spreadsheetId,
          range: `${sheetName}!A1`,
          valueInputOption: 'USER_ENTERED',
          insertDataOption: 'INSERT_ROWS',
          requestBody: {
            values: [values],
          },
        });
        return;
      } catch (error) {
        if (attempt === retries) throw error;
        const delay = Math.pow(2, attempt) * 500;
        await new Promise((res) => setTimeout(res, delay));
      }
    }
  }

  async updateRowByUniqueId(sheetName, idColumnName, idValue, updatedRecord, retries = 3) {
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        // Read the target sheet's ID column
        const res = await this.sheetsClient.spreadsheets.values.get({
          spreadsheetId: this.spreadsheetId,
          range: `${sheetName}!A1:Z5000`,
        });

        const rows = res.data.values || [];
        if (rows.length < 2) return;

        const headers = rows[0];
        const idColIndex = headers.indexOf(idColumnName);
        if (idColIndex === -1) return;

        // Find row index (1-based for Google Sheets)
        let targetRowIndex = -1;
        for (let i = 1; i < rows.length; i++) {
          if (String(rows[i][idColIndex]) === String(idValue)) {
            targetRowIndex = i + 1; // 1-based index
            break;
          }
        }

        if (targetRowIndex === -1) {
          console.warn(`[Google Sheets] Record with ${idColumnName}=${idValue} not found in sheet for update.`);
          return;
        }

        const newRowValues = headers.map((h) => updatedRecord[h] ?? '');

        await this.sheetsClient.spreadsheets.values.update({
          spreadsheetId: this.spreadsheetId,
          range: `${sheetName}!A${targetRowIndex}`,
          valueInputOption: 'USER_ENTERED',
          requestBody: {
            values: [newRowValues],
          },
        });
        return;
      } catch (error) {
        if (attempt === retries) {
          console.error(`[Google Sheets] Update failed after retries for ${idValue}:`, error.message);
          throw error;
        }
        const delay = Math.pow(2, attempt) * 500;
        await new Promise((res) => setTimeout(res, delay));
      }
    }
  }
}

// Export singleton instance
const sheetsService = new SheetsService();
module.exports = sheetsService;
