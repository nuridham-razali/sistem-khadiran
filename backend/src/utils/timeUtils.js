/**
 * Time and Timezone utilities (Asia/Kuala_Lumpur & UTC)
 */

const TIMEZONE = process.env.DEFAULT_TIMEZONE || 'Asia/Kuala_Lumpur';

/**
 * Returns current UTC ISO string
 */
function getNowUTC() {
  return new Date().toISOString();
}

/**
 * Converts a Date object or ISO string to Asia/Kuala_Lumpur formatted strings.
 * @param {Date|string} dateInput
 * @returns {Object} { dateKL: 'YYYY-MM-DD', timeKL: 'HH:mm:ss', displayKL: 'DD/MM/YYYY hh:mm A', isoKL }
 */
function formatKualaLumpurTime(dateInput = new Date()) {
  const date = typeof dateInput === 'string' ? new Date(dateInput) : dateInput;

  if (isNaN(date.getTime())) {
    return { dateKL: '', timeKL: '', displayKL: '', isoKL: '' };
  }

  // Use Intl.DateTimeFormat for strict timezone representation
  const dateParts = new Intl.DateTimeFormat('en-MY', {
    timeZone: TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).formatToParts(date);

  const map = {};
  dateParts.forEach((p) => {
    map[p.type] = p.value;
  });

  const dateKL = `${map.year}-${map.month}-${map.day}`;
  const timeKL = `${map.hour}:${map.minute}:${map.second}`;

  // Formatted 12-hour display: DD/MM/YYYY hh:mm A
  const hour12 = new Intl.DateTimeFormat('en-MY', {
    timeZone: TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
  }).format(date);

  return {
    dateKL,
    timeKL,
    displayKL: hour12,
    isoKL: `${dateKL}T${timeKL}+08:00`,
  };
}

/**
 * Calculates elapsed working minutes and hours between clock-in and clock-out.
 * @param {string} clockInIso UTC ISO string
 * @param {string} clockOutIso UTC ISO string
 * @returns {Object} { workedMinutes: number, workedHours: number }
 */
function calculateWorkedDuration(clockInIso, clockOutIso) {
  const inMs = new Date(clockInIso).getTime();
  const outMs = new Date(clockOutIso).getTime();

  if (isNaN(inMs) || isNaN(outMs) || outMs < inMs) {
    return { workedMinutes: 0, workedHours: 0 };
  }

  const diffMs = outMs - inMs;
  const workedMinutes = Math.floor(diffMs / (1000 * 60));
  const workedHours = Math.round((workedMinutes / 60) * 100) / 100;

  return { workedMinutes, workedHours };
}

module.exports = {
  getNowUTC,
  formatKualaLumpurTime,
  calculateWorkedDuration,
  TIMEZONE,
};
