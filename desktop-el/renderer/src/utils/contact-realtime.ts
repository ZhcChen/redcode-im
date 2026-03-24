export type ContactRealtimeEvent =
  | {
      type: "friend_request_update";
      pendingCount: number | null;
    }
  | {
      type: "friendship_deleted";
      userId: string;
    }
  | {
      type: "friend_profile_updated";
      userId: string;
    };

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

export const mapContactRealtimeEvent = (value: unknown): ContactRealtimeEvent | null => {
  if (!isRecord(value) || typeof value.type !== "string") {
    return null;
  }

  switch (value.type) {
    case "friend_request_update":
      return {
        type: "friend_request_update",
        pendingCount: typeof value.pending_count === "number" ? value.pending_count : null
      };
    case "friendship_deleted":
      if (typeof value.user_id !== "string") {
        return null;
      }
      return {
        type: "friendship_deleted",
        userId: value.user_id
      };
    case "friend_profile_updated":
      if (typeof value.user_id !== "string") {
        return null;
      }
      return {
        type: "friend_profile_updated",
        userId: value.user_id
      };
    default:
      return null;
  }
};
