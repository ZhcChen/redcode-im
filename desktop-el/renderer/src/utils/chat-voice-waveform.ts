const DEFAULT_PLACEHOLDER_WAVEFORM_PATTERN = [
  0.24,
  0.42,
  0.66,
  0.5,
  0.34,
  0.58,
  0.74,
  0.46,
] as const;

const DEFAULT_VISIBLE_WAVEFORM_MIN = 0.2;
const DEFAULT_WAVEFORM_SAMPLES = 32;

type AudioContextLike = {
  decodeAudioData: (buffer: ArrayBuffer) => Promise<AudioBuffer>;
  close: () => Promise<void>;
};

type AudioContextConstructorLike = new () => AudioContextLike;

const clamp = (value: number, minimum: number, maximum: number) =>
  Math.min(maximum, Math.max(minimum, value));

const normalizeWaveformPrecision = (value: number) =>
  Math.round(value * 1000) / 1000;

export const buildPlaceholderVoiceWaveform = (
  samples = DEFAULT_WAVEFORM_SAMPLES,
) => {
  if (samples <= 0) {
    return [];
  }

  return Array.from({ length: samples }, (_, index) => {
    const value =
      DEFAULT_PLACEHOLDER_WAVEFORM_PATTERN[
        index % DEFAULT_PLACEHOLDER_WAVEFORM_PATTERN.length
      ] ?? DEFAULT_VISIBLE_WAVEFORM_MIN;
    return normalizeWaveformPrecision(
      clamp(value, DEFAULT_VISIBLE_WAVEFORM_MIN, 1),
    );
  });
};

export const clampVoiceWaveformBars = (
  bars: readonly number[],
  minimumVisibleBar = DEFAULT_VISIBLE_WAVEFORM_MIN,
) =>
  bars.map((bar) => {
    const normalizedBar = Number.isFinite(bar) ? bar : minimumVisibleBar;
    return normalizeWaveformPrecision(
      clamp(normalizedBar, minimumVisibleBar, 1),
    );
  });

export const createWaveformDataFromChannelData = (
  channelData: ArrayLike<number>,
  samples = DEFAULT_WAVEFORM_SAMPLES,
) => {
  const normalizedSamples = Math.max(0, Math.floor(samples));
  if (normalizedSamples === 0) {
    return [];
  }

  const channelLength = Number(channelData.length) || 0;
  if (channelLength <= 0) {
    return buildPlaceholderVoiceWaveform(normalizedSamples);
  }

  const waveform = Array.from({ length: normalizedSamples }, (_, index) => {
    const blockStart = Math.floor((index * channelLength) / normalizedSamples);
    const blockEnd = Math.max(
      blockStart + 1,
      Math.floor(((index + 1) * channelLength) / normalizedSamples),
    );

    let sum = 0;
    for (let cursor = blockStart; cursor < blockEnd; cursor += 1) {
      sum += Math.abs(Number(channelData[cursor] ?? 0));
    }

    const average = sum / Math.max(1, blockEnd - blockStart);
    return clamp(average * 4, 0, 1);
  });

  return clampVoiceWaveformBars(waveform);
};

const resolveAudioContextConstructor = (): AudioContextConstructorLike | null => {
  if (typeof window === "undefined") {
    return null;
  }

  const audioWindow = window as Window &
    typeof globalThis & {
      webkitAudioContext?: AudioContextConstructorLike;
    };

  return (
    (audioWindow.AudioContext as AudioContextConstructorLike | undefined) ??
    audioWindow.webkitAudioContext ??
    null
  );
};

export const createWaveformFromBlob = async (
  blob: Blob,
  samples = DEFAULT_WAVEFORM_SAMPLES,
) => {
  const AudioContextConstructor = resolveAudioContextConstructor();
  if (!AudioContextConstructor) {
    throw new Error("Web Audio API is not supported");
  }

  const arrayBuffer = await blob.arrayBuffer();
  const audioContext = new AudioContextConstructor();

  try {
    const audioBuffer = await audioContext.decodeAudioData(arrayBuffer.slice(0));
    return createWaveformDataFromChannelData(
      audioBuffer.getChannelData(0),
      samples,
    );
  } finally {
    await audioContext.close();
  }
};
