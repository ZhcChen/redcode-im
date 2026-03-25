interface WindowTitleUserLike {
  mobile?: string | null;
  nickname?: string | null;
  username?: string | null;
}

const pickUserLabel = (user: WindowTitleUserLike | null | undefined) => {
  const mobile = user?.mobile?.trim();
  if (mobile) {
    return mobile;
  }

  const nickname = user?.nickname?.trim();
  if (nickname) {
    return nickname;
  }

  const username = user?.username?.trim();
  if (username) {
    return username;
  }

  return null;
};

export const buildDesktopWindowTitle = (
  appName: string,
  user: WindowTitleUserLike | null | undefined,
) => {
  const baseTitle = appName.trim() || "CHATLY";
  const userLabel = pickUserLabel(user);
  if (!userLabel) {
    return baseTitle;
  }

  return `${baseTitle} - ${userLabel}`;
};
