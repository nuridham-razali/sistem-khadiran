/**
 * Geolocation & Haversine Distance Calculations
 */

/**
 * Calculates great-circle distance between two GPS coordinates using the Haversine formula.
 * @param {number} lat1 Latitude of point 1 in degrees
 * @param {number} lon1 Longitude of point 1 in degrees
 * @param {number} lat2 Latitude of point 2 in degrees
 * @param {number} lon2 Longitude of point 2 in degrees
 * @returns {number} Distance in metres
 */
function calculateHaversineDistanceMeters(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth radius in metres
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;

  return Math.round(distance * 10) / 10; // Round to 1 decimal place
}

function toRadians(degrees) {
  return (degrees * Math.PI) / 180;
}

/**
 * Validates device GPS reading against office geofence and quality constraints.
 * @param {Object} params
 * @param {number} params.clientLat
 * @param {number} params.clientLng
 * @param {number} params.clientAccuracy Accuracy in metres
 * @param {number|string} params.clientTimestamp Timestamp in ms or ISO string
 * @param {boolean} [params.isMockLocation] Whether device reported mock/spoofed GPS
 * @param {Object} params.office
 * @param {number} params.office.latitude
 * @param {number} params.office.longitude
 * @param {number} params.office.radiusMeters
 * @param {number} [params.office.maxAccuracyMeters=50]
 * @param {number} [params.office.maxAgeSeconds=60]
 * @returns {Object} { isValid, distanceMeters, withinRadius, errorCode, errorMessage }
 */
function validateLocation({
  clientLat,
  clientLng,
  clientAccuracy,
  clientTimestamp,
  isMockLocation = false,
  office,
}) {
  if (
    typeof clientLat !== 'number' ||
    typeof clientLng !== 'number' ||
    isNaN(clientLat) ||
    isNaN(clientLng)
  ) {
    return {
      isValid: false,
      errorCode: 'INVALID_COORDINATES',
      errorMessage: 'Invalid GPS coordinates provided.',
    };
  }

  // 1. Check for mock/spoofed location indicator from client
  if (isMockLocation && process.env.REJECT_MOCK_LOCATIONS !== 'false') {
    return {
      isValid: false,
      errorCode: 'MOCK_LOCATION_DETECTED',
      errorMessage:
        'Mock or simulated GPS location detected. Please disable location mocking in device settings.',
    };
  }

  // 2. Freshness check
  const maxAgeSeconds = office.maxAgeSeconds || parseInt(process.env.MAX_LOCATION_AGE_SECONDS || '60', 10);
  const nowMs = Date.now();
  const locationTimeMs =
    typeof clientTimestamp === 'string'
      ? new Date(clientTimestamp).getTime()
      : Number(clientTimestamp) || nowMs;

  const ageSeconds = Math.abs(nowMs - locationTimeMs) / 1000;
  if (ageSeconds > maxAgeSeconds) {
    return {
      isValid: false,
      errorCode: 'STALE_GPS_READING',
      errorMessage: `GPS reading is stale (${Math.round(ageSeconds)}s old). Maximum permitted age is ${maxAgeSeconds}s. Please refresh your location.`,
      ageSeconds,
    };
  }

  // 3. Accuracy check
  const maxAccuracy = office.maxAccuracyMeters || parseInt(process.env.MAX_ALLOWED_GPS_ACCURACY_METERS || '50', 10);
  if (typeof clientAccuracy === 'number' && clientAccuracy > maxAccuracy) {
    return {
      isValid: false,
      errorCode: 'INACCURATE_GPS',
      errorMessage: `GPS accuracy (${Math.round(clientAccuracy)}m) is too poor. Must be within ±${maxAccuracy}m. Move to an area with clear sky view.`,
      accuracy: clientAccuracy,
    };
  }

  // 4. Haversine distance from office
  const distanceMeters = calculateHaversineDistanceMeters(
    clientLat,
    clientLng,
    office.latitude,
    office.longitude
  );

  const radiusMeters = office.radiusMeters || parseInt(process.env.DEFAULT_OFFICE_RADIUS_METERS || '100', 10);
  const withinRadius = distanceMeters <= radiusMeters;

  if (!withinRadius) {
    return {
      isValid: false,
      withinRadius: false,
      distanceMeters,
      radiusMeters,
      errorCode: 'OUTSIDE_RADIUS',
      errorMessage: `You are ${Math.round(distanceMeters)}m away from ${office.name}. Maximum allowed radius is ${radiusMeters}m.`,
    };
  }

  return {
    isValid: true,
    withinRadius: true,
    distanceMeters,
    radiusMeters,
    accuracy: clientAccuracy,
    ageSeconds,
  };
}

module.exports = {
  calculateHaversineDistanceMeters,
  validateLocation,
};
