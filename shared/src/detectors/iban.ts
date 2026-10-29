// Number of characters in an IBAN, by country. More countries can be added later.
const IBAN_LENGTHS: Record<string, number> = {
  AT: 20,
  BA: 20,
  DE: 22,
  FR: 27,
  GB: 22,
  HR: 21,
  HU: 28,
  IT: 27,
  ME: 22,
  RS: 22,
  SI: 19,
};

export function isValidIban(value: string): boolean {
  if (!/^[A-Z]{2}\d{2}[A-Z0-9]+$/.test(value)) return false;

  const expected = IBAN_LENGTHS[value.slice(0, 2)];
  if (expected === undefined || value.length !== expected) return false;

  const rearranged = value.slice(4) + value.slice(0, 4);
  let remainder = 0;
  for (const ch of rearranged) {
    const code = ch.charCodeAt(0);
    if (code >= 48 && code <= 57) {
      remainder = (remainder * 10 + (code - 48)) % 97;
    } else {
      remainder = (remainder * 100 + (code - 55)) % 97;
    }
  }

  return remainder === 1;
}