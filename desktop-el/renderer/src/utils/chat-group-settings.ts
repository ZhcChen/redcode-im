export interface GroupMaxMembersUpdateResult {
  nextValue: number | null;
  errorMessage: string | null;
}

export const resolveGroupMaxMembersUpdate = (
  input: string,
  currentValue: number,
): GroupMaxMembersUpdateResult => {
  const trimmed = input.trim();
  if (!trimmed || !/^\d+$/.test(trimmed)) {
    return {
      nextValue: null,
      errorMessage: "群最大人数必须是正整数。",
    };
  }

  const nextValue = Number.parseInt(trimmed, 10);
  if (!Number.isSafeInteger(nextValue) || nextValue <= 0) {
    return {
      nextValue: null,
      errorMessage: "群最大人数必须是正整数。",
    };
  }

  if (nextValue === currentValue) {
    return {
      nextValue: null,
      errorMessage: "群最大人数未发生变化。",
    };
  }

  return {
    nextValue,
    errorMessage: null,
  };
};
