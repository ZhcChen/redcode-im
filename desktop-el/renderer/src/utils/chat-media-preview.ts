export const IMAGE_PREVIEW_MIN_SCALE = 1;
export const IMAGE_PREVIEW_MAX_SCALE = 4;
export const IMAGE_PREVIEW_SCALE_STEP = 0.2;
export const IMAGE_PREVIEW_ROTATION_STEP = 90;
export const VIDEO_PREVIEW_SEEK_STEP_SECONDS = 5;

export interface ImagePreviewGalleryPart {
  partType: string;
  position: number;
}

export interface ImagePreviewGalleryMessage {
  id: string;
  parts: ImagePreviewGalleryPart[];
}

export interface ImagePreviewGalleryEntry {
  id: string;
  messageId: string;
  partPosition: number;
}

export interface MediaPreviewKeyboardActionInput {
  previewType: "image" | "video" | null;
  key: string;
}

export interface MediaPreviewSource {
  messageId: string;
  partPosition: number;
}

const roundImagePreviewScale = (value: number) =>
  Math.round(value * 100) / 100;

const roundMediaPreviewProgress = (value: number) =>
  Math.round(value * 100) / 100;

export const clampImagePreviewScale = (value: number) =>
  roundImagePreviewScale(
    Math.min(
      IMAGE_PREVIEW_MAX_SCALE,
      Math.max(IMAGE_PREVIEW_MIN_SCALE, Number.isFinite(value) ? value : IMAGE_PREVIEW_MIN_SCALE),
    ),
  );

export const getNextImagePreviewScaleFromWheel = (
  currentScale: number,
  deltaY: number,
) => {
  const nextScale =
    deltaY > 0
      ? currentScale - IMAGE_PREVIEW_SCALE_STEP
      : currentScale + IMAGE_PREVIEW_SCALE_STEP;
  return clampImagePreviewScale(nextScale);
};

export const normalizeImagePreviewRotation = (value: number) => {
  const normalized = ((Math.round(value) % 360) + 360) % 360;
  return normalized;
};

export const getNextImagePreviewRotation = (
  currentRotation: number,
  direction: "clockwise" | "counterclockwise",
) => {
  const nextRotation =
    direction === "clockwise"
      ? currentRotation + IMAGE_PREVIEW_ROTATION_STEP
      : currentRotation - IMAGE_PREVIEW_ROTATION_STEP;
  return normalizeImagePreviewRotation(nextRotation);
};

export const buildImagePreviewGalleryEntries = (
  messages: ImagePreviewGalleryMessage[],
): ImagePreviewGalleryEntry[] =>
  messages.flatMap((message) =>
    message.parts
      .filter((part) => part.partType === "image")
      .map((part) => ({
        id: `${message.id}:${part.position}`,
        messageId: message.id,
        partPosition: part.position,
      })),
  );

export const getImagePreviewGalleryNeighbor = (
  entries: ImagePreviewGalleryEntry[],
  currentEntryID: string,
  direction: "previous" | "next",
) => {
  const currentIndex = entries.findIndex((entry) => entry.id === currentEntryID);
  if (currentIndex < 0) {
    return null;
  }

  const nextIndex = direction === "previous" ? currentIndex - 1 : currentIndex + 1;
  return entries[nextIndex] ?? null;
};

export const formatMediaPreviewPlaybackTime = (
  value: number | null | undefined,
) => {
  const totalSeconds =
    typeof value === "number" && Number.isFinite(value) && value > 0
      ? Math.floor(value)
      : 0;
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
  }

  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
};

export const getMediaPreviewPlaybackProgress = (
  currentTime: number,
  duration: number,
) => {
  if (!Number.isFinite(duration) || duration <= 0) {
    return 0;
  }

  const safeCurrentTime = Number.isFinite(currentTime) ? currentTime : 0;
  const clampedCurrentTime = Math.min(duration, Math.max(0, safeCurrentTime));
  return roundMediaPreviewProgress((clampedCurrentTime / duration) * 100);
};

export const getNextVideoPreviewCurrentTime = (
  currentTime: number,
  duration: number,
  direction: "backward" | "forward",
  stepSeconds = VIDEO_PREVIEW_SEEK_STEP_SECONDS,
) => {
  const safeDuration =
    Number.isFinite(duration) && duration > 0 ? duration : 0;
  const safeCurrentTime = Number.isFinite(currentTime) ? currentTime : 0;
  const clampedCurrentTime = Math.min(
    safeDuration,
    Math.max(0, safeCurrentTime),
  );
  const safeStepSeconds =
    Number.isFinite(stepSeconds) && stepSeconds > 0
      ? stepSeconds
      : VIDEO_PREVIEW_SEEK_STEP_SECONDS;
  const delta = direction === "forward" ? safeStepSeconds : -safeStepSeconds;

  return Math.min(safeDuration, Math.max(0, clampedCurrentTime + delta));
};

export const getMediaPreviewKeyboardAction = (
  input: MediaPreviewKeyboardActionInput,
):
  | "close"
  | "previous"
  | "next"
  | "toggle-play"
  | "seek-backward"
  | "seek-forward"
  | null => {
  if (!input.previewType) {
    return null;
  }
  if (input.key === "Escape") {
    return "close";
  }
  if (input.previewType === "image") {
    if (input.key === "ArrowLeft") {
      return "previous";
    }
    if (input.key === "ArrowRight") {
      return "next";
    }
    return null;
  }
  if (input.key === " " || input.key === "Spacebar") {
    return "toggle-play";
  }
  if (input.key === "ArrowLeft") {
    return "seek-backward";
  }
  if (input.key === "ArrowRight") {
    return "seek-forward";
  }
  return null;
};

export const findMediaPreviewSource = <
  TPart extends { position: number },
  TMessage extends { id: string; parts: TPart[] },
>(
  messages: TMessage[],
  source: MediaPreviewSource | null,
): { message: TMessage; part: TPart } | null => {
  if (!source) {
    return null;
  }

  const message = messages.find((item) => item.id === source.messageId);
  if (!message) {
    return null;
  }

  const part = message.parts.find((item) => item.position === source.partPosition);
  if (!part) {
    return null;
  }

  return {
    message,
    part,
  };
};
