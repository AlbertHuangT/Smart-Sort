const NON_DIGIT_REGEX = /\D/g;

// Normalize user input into a stable E.164-ish phone string.
// Defaults to US (+1) when a 10-digit local number is provided.
export const normalizePhoneNumber = (input) => {
  if (!input) return '';

  const trimmed = String(input).trim();
  const hasPlus = trimmed.startsWith('+');
  const digits = trimmed.replace(NON_DIGIT_REGEX, '');

  if (!digits) return '';

  if (hasPlus) {
    return `+${digits}`;
  }

  if (digits.length === 10) {
    return `+1${digits}`;
  }

  if (digits.length === 11 && digits.startsWith('1')) {
    return `+${digits}`;
  }

  return `+${digits}`;
};

export const compactPhoneDigits = (input) => {
  if (!input) return '';
  return String(input).replace(NON_DIGIT_REGEX, '');
};
