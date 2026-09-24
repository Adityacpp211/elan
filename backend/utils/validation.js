function isFiniteNumber(value) {
    return typeof value === 'number' && Number.isFinite(value);
}

function isValidLatitude(lat) {
    return isFiniteNumber(lat) && lat >= -90 && lat <= 90;
}

function isValidLongitude(lng) {
    return isFiniteNumber(lng) && lng >= -180 && lng <= 180;
}

function isValidCoordinates(lat, lng) {
    return isValidLatitude(lat) && isValidLongitude(lng);
}

module.exports = {
    isFiniteNumber,
    isValidLatitude,
    isValidLongitude,
    isValidCoordinates
};