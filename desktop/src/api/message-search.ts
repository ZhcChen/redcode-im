import { get } from './http';
import type { MessageSearchResult, SearchParams, SearchStats } from './search';

type ServerSearchResultItem = {
  id: string;
  room_id: string;
  room_name: string;
  sender_id: string;
  sender_name: string;
  content: string;
  message_type: string;
  timestamp: string;
  matched_text?: string | null;
  relevance_score: number;
};

type ServerSearchStats = {
  total_results: number;
  search_time_ms: number;
  query: string;
};

type ServerSearchResponse = {
  results: ServerSearchResultItem[];
  stats: ServerSearchStats;
  has_more: boolean;
};

const toServerTimestampSeconds = (value?: number) => {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return undefined;
  }
  // Desktop 本地索引使用毫秒时间戳；后端使用秒级时间戳
  return value > 1_000_000_000_000 ? Math.floor(value / 1000) : Math.floor(value);
};

const mapServerResult = (item: ServerSearchResultItem): MessageSearchResult => {
  const timestampMs = Date.parse(item.timestamp);
  return {
    id: item.id,
    roomId: item.room_id,
    roomName: item.room_name,
    senderId: item.sender_id,
    senderName: item.sender_name,
    content: item.content,
    messageType: item.message_type,
    timestamp: Number.isFinite(timestampMs) ? timestampMs : Date.now(),
    matchedText: item.matched_text ?? undefined,
    relevanceScore: item.relevance_score,
  };
};

const mapServerStats = (stats: ServerSearchStats): SearchStats => ({
  totalResults: stats.total_results,
  searchTimeMs: stats.search_time_ms,
  query: stats.query,
});

export async function searchMessagesFromServer(params: SearchParams): Promise<{
  results: MessageSearchResult[];
  stats: SearchStats;
  hasMore: boolean;
}> {
  const serverParams: Record<string, any> = {
    query: params.query,
    limit: params.limit,
    offset: params.offset,
  };

  if (params.roomId) serverParams.room_id = params.roomId;
  if (params.senderId) serverParams.sender_id = params.senderId;
  if (params.messageType) serverParams.message_type = params.messageType;

  const dateFrom = toServerTimestampSeconds(params.dateFrom);
  if (typeof dateFrom === 'number') serverParams.date_from = dateFrom;
  const dateTo = toServerTimestampSeconds(params.dateTo);
  if (typeof dateTo === 'number') serverParams.date_to = dateTo;

  const response = await get<ServerSearchResponse>('/messages/search', serverParams);
  if (!response.success || !response.data) {
    throw new Error(response.message || '服务端搜索失败');
  }

  return {
    results: (response.data.results || []).map(mapServerResult),
    stats: mapServerStats(response.data.stats),
    hasMore: Boolean(response.data.has_more),
  };
}

