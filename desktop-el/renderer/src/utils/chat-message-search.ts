import type { ChatMessage } from "@/api/chat";

export interface LocalChatMessageSearchResult {
  messageId: string;
  senderName: string;
  createdAt: Date | null;
  messageType: ChatMessage["messageType"];
  summaryText: string;
  highlightedHtml: string;
}

const escapeHtml = (value: string) =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

const escapeRegExp = (value: string) =>
  value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const compactWhitespace = (value: string) => value.replace(/\s+/g, " ").trim();

const extractQuotedSearchText = (message: ChatMessage) => {
  if (!message.quotedMessage || message.quotedMessage.isDeleted) {
    return "";
  }

  const quotedTexts = message.quotedMessage.parts
    .map((part) => part.text?.trim() ?? part.attachment?.name?.trim() ?? "")
    .filter(Boolean);

  return compactWhitespace(
    [
      message.quotedMessage.senderName,
      message.quotedMessage.content ?? "",
      ...quotedTexts,
    ]
      .filter(Boolean)
      .join(" "),
  );
};

export const buildLocalMessageSearchText = (message: ChatMessage) => {
  const segments = new Set<string>();

  const pushSegment = (value: string | null | undefined) => {
    const normalized = compactWhitespace(value ?? "");
    if (normalized) {
      segments.add(normalized);
    }
  };

  pushSegment(message.content);
  pushSegment(message.preview);
  message.parts.forEach((part) => {
    pushSegment(part.text);
    pushSegment(part.attachment?.name);
  });
  pushSegment(extractQuotedSearchText(message));

  return Array.from(segments).join(" ");
};

const buildSummaryText = (sourceText: string, query: string, radius = 26) => {
  const normalizedSource = sourceText.trim();
  if (!normalizedSource) {
    return "";
  }

  const normalizedQuery = query.trim().toLowerCase();
  const matchIndex = normalizedSource.toLowerCase().indexOf(normalizedQuery);
  if (matchIndex < 0) {
    return normalizedSource;
  }

  const start = Math.max(0, matchIndex - radius);
  const end = Math.min(
    normalizedSource.length,
    matchIndex + normalizedQuery.length + radius,
  );
  const prefix = start > 0 ? "..." : "";
  const suffix = end < normalizedSource.length ? "..." : "";
  return `${prefix}${normalizedSource.slice(start, end)}${suffix}`;
};

export const highlightLocalMessageSearchSnippet = (
  sourceText: string,
  query: string,
) => {
  const summaryText = buildSummaryText(sourceText, query);
  const escapedSummary = escapeHtml(summaryText);
  const normalizedQuery = query.trim();
  if (!normalizedQuery) {
    return escapedSummary;
  }

  return escapedSummary.replace(
    new RegExp(escapeRegExp(escapeHtml(normalizedQuery)), "gi"),
    (matched) => `<mark>${matched}</mark>`,
  );
};

export const searchLocalChatMessages = (
  messages: ChatMessage[],
  query: string,
  options: { limit?: number } = {},
): LocalChatMessageSearchResult[] => {
  const normalizedQuery = compactWhitespace(query).toLowerCase();
  if (!normalizedQuery) {
    return [];
  }

  const limit = options.limit ?? 50;

  return messages
    .filter(
      (message) => !message.isDeleted && message.messageType !== "system",
    )
    .map((message) => {
      const searchableText = buildLocalMessageSearchText(message);
      return {
        message,
        searchableText,
      };
    })
    .filter(({ searchableText }) =>
      searchableText.toLowerCase().includes(normalizedQuery),
    )
    .sort((left, right) => {
      const leftTime = left.message.createdAt?.getTime() ?? 0;
      const rightTime = right.message.createdAt?.getTime() ?? 0;
      return rightTime - leftTime;
    })
    .slice(0, limit)
    .map(({ message, searchableText }) => {
      const summaryText = buildSummaryText(searchableText, query);
      return {
        messageId: message.id,
        senderName: message.senderName,
        createdAt: message.createdAt,
        messageType: message.messageType,
        summaryText,
        highlightedHtml: highlightLocalMessageSearchSnippet(searchableText, query),
      };
    });
};
