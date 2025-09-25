class PhoneNormalizationError extends Error {}

function normalizePhoneNumber(raw) {
  if (!raw || typeof raw !== 'string') {
    throw new PhoneNormalizationError('empty phone number');
  }

  // Strip all formatting characters (spaces, dashes, parentheses, dots)
  let cleaned = String(raw).replace(/[\s\-\(\)\.\+]/g, '');
  
  if (!cleaned) {
    throw new PhoneNormalizationError('empty phone number');
  }

  // Extract only digits
  let digits = cleaned.replace(/\D/g, '');
  
  if (!digits) {
    throw new PhoneNormalizationError('no digits found in phone number');
  }

  let normalized;
  
  // Handle different prefix formats
  if (digits.startsWith('62')) {
    // +62 or 62 prefix - Indonesian country code
    const localPart = digits.slice(2);
    if (!localPart) {
      throw new PhoneNormalizationError('country code without subscriber number');
    }
    // Convert to local format with leading 0
    normalized = localPart.startsWith('0') ? localPart : `0${localPart}`;
  } else if (digits.startsWith('0')) {
    // Already in local format with leading 0
    normalized = digits;
  } else if (digits.startsWith('8')) {
    // Local format without leading 0 - add it
    normalized = `0${digits}`;
  } else {
    throw new PhoneNormalizationError(`unexpected prefix in number '${raw}'`);
  }

  // Validate minimum length (9 digits total including leading 0)
  if (normalized.length < 9) {
    throw new PhoneNormalizationError(`number too short after normalisation '${raw}' -> '${normalized}'`);
  }

  // Validate maximum reasonable length (15 digits is international standard)
  if (normalized.length > 15) {
    throw new PhoneNormalizationError(`number too long after normalisation '${raw}' -> '${normalized}'`);
  }

  // Validate that it starts with valid Indonesian mobile prefixes after normalization
  const validPrefixes = ['081', '082', '083', '085', '087', '088', '089'];
  const prefix = normalized.substring(0, 3);
  if (!validPrefixes.includes(prefix)) {
    //console.warn(`Warning: Phone number '${normalized}' may not be a valid Indonesian mobile number`);
  }

  return normalized;
}

module.exports = { normalizePhoneNumber, PhoneNormalizationError };
