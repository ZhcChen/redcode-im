import type { SessionAccount } from "@/store/session";

interface SwitchAccountPlan {
  previousAccountId: string | null;
  nextAccount: SessionAccount;
}

interface LogoutFallbackPlan {
  removedAccountId: string;
  nextAccount: SessionAccount;
}

const canReconnectAccount = (account: SessionAccount | null | undefined): account is SessionAccount =>
  Boolean(account?.id && account.user?.id && account.accessToken);

export const buildSwitchAccountPlan = (
  accounts: SessionAccount[],
  currentAccountId: string | null,
  targetAccountId: string,
): SwitchAccountPlan | null => {
  if (!targetAccountId || targetAccountId === currentAccountId) {
    return null;
  }

  const nextAccount = accounts.find((account) => account.id === targetAccountId);
  if (!canReconnectAccount(nextAccount)) {
    return null;
  }

  return {
    previousAccountId: currentAccountId,
    nextAccount,
  };
};

export const buildLogoutFallbackPlan = (
  accounts: SessionAccount[],
  currentAccountId: string | null,
): LogoutFallbackPlan | null => {
  if (!currentAccountId) {
    return null;
  }

  const nextAccount = accounts.find((account) => account.id !== currentAccountId);
  if (!canReconnectAccount(nextAccount)) {
    return null;
  }

  return {
    removedAccountId: currentAccountId,
    nextAccount,
  };
};
