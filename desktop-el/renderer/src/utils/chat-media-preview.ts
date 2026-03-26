export const IMAGE_PREVIEW_MIN_SCALE = 1;
export const IMAGE_PREVIEW_MAX_SCALE = 4;
export const IMAGE_PREVIEW_SCALE_STEP = 0.2;
export const IMAGE_PREVIEW_ROTATION_STEP = 90;

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

const roundImagePreviewScale = (value: number) =>
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
