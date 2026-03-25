export type GroupMemberRole = "owner" | "admin" | "member";

export interface GroupMemberListItem {
  userId: string;
  username: string;
  displayName: string;
  role: GroupMemberRole;
  joinedAt: Date | null;
}

const ROLE_ORDER: Record<GroupMemberRole, number> = {
  owner: 0,
  admin: 1,
  member: 2,
};

const ROLE_LABEL: Record<GroupMemberRole, string> = {
  owner: "群主",
  admin: "管理员",
  member: "成员",
};

export const sortGroupMembers = <T extends GroupMemberListItem>(members: T[]) =>
  [...members].sort((left, right) => {
    const roleDiff = ROLE_ORDER[left.role] - ROLE_ORDER[right.role];
    if (roleDiff !== 0) {
      return roleDiff;
    }

    return left.displayName
      .toLowerCase()
      .localeCompare(right.displayName.toLowerCase());
  });

export const filterGroupMembers = <T extends GroupMemberListItem>(
  members: T[],
  keyword: string,
) => {
  const normalized = keyword.trim().toLowerCase();
  if (!normalized) {
    return members;
  }

  return members.filter((member) => {
    const displayName = member.displayName.toLowerCase();
    const username = member.username.toLowerCase();
    const roleLabel = ROLE_LABEL[member.role].toLowerCase();
    return (
      displayName.includes(normalized) ||
      username.includes(normalized) ||
      roleLabel.includes(normalized)
    );
  });
};

export const summarizeGroupMembers = <T extends GroupMemberListItem>(
  members: T[],
) => ({
  total: members.length,
  ownerCount: members.filter((member) => member.role === "owner").length,
  adminCount: members.filter((member) => member.role === "admin").length,
  memberCount: members.filter((member) => member.role === "member").length,
});
