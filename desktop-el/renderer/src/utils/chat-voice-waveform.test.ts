import { afterEach, describe, expect, test } from "bun:test";
import {
  clampVoiceWaveformBars,
  createWaveformDataFromChannelData,
  createWaveformFromBlob,
} from "./chat-voice-waveform";

describe("chat voice waveform helpers", () => {
  const originalWindow = globalThis.window;

  afterEach(() => {
    globalThis.window = originalWindow;
  });

  test("creates normalized waveform bars from channel data", () => {
    const waveform = createWaveformDataFromChannelData(
      new Float32Array([0, 0.1, -0.2, 0.05]),
      2,
    );

    expect(waveform).toEqual([0.2, 0.5]);
  });

  test("returns placeholder bars when channel data is empty", () => {
    expect(createWaveformDataFromChannelData(new Float32Array([]), 6)).toEqual([
      0.24,
      0.42,
      0.66,
      0.5,
      0.34,
      0.58,
    ]);
  });

  test("clamps waveform bars into the visible range", () => {
    expect(clampVoiceWaveformBars([-0.3, 0, 0.06, 1.4])).toEqual([
      0.2,
      0.2,
      0.2,
      1,
    ]);
  });

  test("decodes an audio blob through Web Audio before sampling waveform", async () => {
    const closeCalls: number[] = [];

    class FakeAudioContext {
      async decodeAudioData(_buffer: ArrayBuffer) {
        return {
          getChannelData() {
            return new Float32Array([0, 0.1, -0.2, 0.05]);
          },
        } as AudioBuffer;
      }

      async close() {
        closeCalls.push(Date.now());
      }
    }

    globalThis.window = {
      AudioContext: FakeAudioContext,
    } as Window & typeof globalThis;

    const waveform = await createWaveformFromBlob(
      new Blob(["voice-preview"], {
        type: "audio/webm",
      }),
      2,
    );

    expect(waveform).toEqual([0.2, 0.5]);
    expect(closeCalls).toHaveLength(1);
  });
});
