export const AVATAR_ALLOWED_MIME_TYPES = [
  "image/png",
  "image/jpeg",
  "image/jpg",
  "image/webp",
  "image/gif",
  "image/heic",
  "image/heif",
  "image/svg+xml"
] as const;

export const AVATAR_INPUT_ACCEPT = AVATAR_ALLOWED_MIME_TYPES.join(",");
export const AVATAR_MAX_SIZE_BYTES = 5 * 1024 * 1024;

const AVATAR_FORMAT_ERROR_MESSAGE = "仅支持 PNG、JPG、WEBP、GIF、HEIC、HEIF、SVG 格式头像";
const AVATAR_SIZE_ERROR_MESSAGE = "头像大小不能超过 5MB";

export const validateAvatarFile = (file: Pick<File, "type" | "size">) => {
  if (!AVATAR_ALLOWED_MIME_TYPES.includes(file.type as (typeof AVATAR_ALLOWED_MIME_TYPES)[number])) {
    return AVATAR_FORMAT_ERROR_MESSAGE;
  }

  if (file.size > AVATAR_MAX_SIZE_BYTES) {
    return AVATAR_SIZE_ERROR_MESSAGE;
  }

  return null;
};
