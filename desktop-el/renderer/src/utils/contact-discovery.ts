export type RelationshipState = "self" | "friend" | "pending" | "addable";

export interface DiscoveryUserIdentity {
  username: string;
  nickname: string | null;
}

export const resolveRelationshipState = (params: {
  candidateId: string;
  currentUserId: string | null;
  friendUserIds: string[];
  pendingTargetUserIds: string[];
}): RelationshipState => {
  if (params.currentUserId && params.candidateId === params.currentUserId) {
    return "self";
  }
  if (params.friendUserIds.includes(params.candidateId)) {
    return "friend";
  }
  if (params.pendingTargetUserIds.includes(params.candidateId)) {
    return "pending";
  }
  return "addable";
};

export const buildDefaultFriendRequestMessage = (user: DiscoveryUserIdentity | null): string => {
  const preferredName = user?.nickname?.trim() || user?.username?.trim() || "";
  if (!preferredName) {
    return "你好，很高兴认识你";
  }
  return `我是${preferredName}`;
};
