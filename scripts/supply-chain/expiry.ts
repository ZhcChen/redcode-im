const DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;
const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_EXCEPTION_VALIDITY_DAYS = 90;

function parseUtcCalendarDate(value: string): number {
  const match = DATE_PATTERN.exec(value);
  if (!match) throw new Error("has an invalid expires_at UTC calendar date");

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(0);
  date.setUTCHours(0, 0, 0, 0);
  date.setUTCFullYear(year, month - 1, day);
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    throw new Error("has an invalid expires_at UTC calendar date");
  }
  return date.getTime();
}

export function validateExceptionExpiry(
  expiresAt: string,
  today: string,
  maxValidityDays: number
): void {
  validateMaxValidityDays(maxValidityDays);

  const expiryTime = parseUtcCalendarDate(expiresAt);
  const todayTime = parseUtcCalendarDate(today);
  if (expiryTime < todayTime) {
    throw new Error("is expired or has an invalid expires_at");
  }
  if ((expiryTime - todayTime) / DAY_MS > maxValidityDays) {
    throw new Error("expires_at exceeds the policy maximum validity period");
  }
}

export function validateMaxValidityDays(value: number): void {
  if (
    !Number.isSafeInteger(value) ||
    value < 1 ||
    value > MAX_EXCEPTION_VALIDITY_DAYS
  ) {
    throw new Error(
      "policy exceptions.max_validity_days must be a safe integer between 1 and 90"
    );
  }
}
