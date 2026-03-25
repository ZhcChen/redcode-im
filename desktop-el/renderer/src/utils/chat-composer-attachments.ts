export interface ComposerPendingAttachment<TFile = File> {
  id: string;
  file: TFile;
}

export const hasFileTransfer = (
  dataTransfer: Pick<DataTransfer, "types"> | null | undefined,
) => Array.from(dataTransfer?.types ?? []).includes("Files");

export const buildPendingComposerAttachments = <TFile extends {
  name: string;
  size: number;
}>(
  files: TFile[],
  now = Date.now(),
): ComposerPendingAttachment<TFile>[] =>
  files.map((file, index) => ({
    id: `${now}-${index}-${file.name}-${file.size}`,
    file,
  }));

export const buildPendingAttachmentNotice = (
  files: Array<{ name: string }>,
  mode: "pick" | "drop" = "pick",
) => {
  if (!files.length) {
    return "";
  }

  const actionLabel = mode === "drop" ? "通过拖拽添加" : "添加附件";
  if (files.length === 1) {
    return `已${actionLabel} ${files[0].name}，可直接发送，也可继续输入文本混发。`;
  }
  return `已${actionLabel} ${files.length} 个附件，可直接发送，也可继续输入文本混发。`;
};
