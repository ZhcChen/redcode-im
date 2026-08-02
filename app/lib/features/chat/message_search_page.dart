import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/services/app_config_service.dart';
import '../../core/services/message_service.dart';
import '../../core/storage/message_search_storage.dart';
import '../../core/storage/message_storage.dart';
import 'models/chat_model.dart';

class MessageSearchPage extends StatefulWidget {
  const MessageSearchPage({
    super.key,
    this.initialRoomId,
    this.searchStorage,
    this.messageStorage,
    this.messageService,
    this.appConfigService,
    this.httpClient,
  });

  final String? initialRoomId;
  final MessageSearchStorage? searchStorage;
  final MessageStorage? messageStorage;
  final MessageService? messageService;
  final AppConfigService? appConfigService;
  final http.Client? httpClient;

  @override
  State<MessageSearchPage> createState() => _MessageSearchPageState();
}

class _MessageSearchPageState extends State<MessageSearchPage> {
  final _queryController = TextEditingController();
  final _queryFocusNode = FocusNode();

  late final MessageSearchStorage _searchStorage;
  late final MessageStorage _messageStorage;
  late final MessageService _messageService;
  late final AppConfigService _appConfigService;
  late final http.Client _httpClient;

  Timer? _debounceTimer;

  bool _isIndexing = false;
  int _indexTotal = 0;
  int _indexDone = 0;

  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _serverSearchEnabled = true;

  int _searchSequence = 0;
  int _localOffset = 0;
  int _serverOffset = 0;
  bool _hasMoreLocal = false;
  bool _hasMoreServer = false;

  List<Chat> _availableChats = const [];
  String _roomFilter = '';
  String _typeFilter = '';

  List<MessageSearchResult> _results = const [];
  MessageSearchStats? _stats;

  @override
  void initState() {
    super.initState();

    _searchStorage = widget.searchStorage ?? const MessageSearchStorage();
    _messageStorage = widget.messageStorage ?? const MessageStorage();
    _messageService = widget.messageService ?? MessageService.instance;
    _appConfigService = widget.appConfigService ?? AppConfigService.instance;
    _httpClient = widget.httpClient ?? http.Client();
    _serverSearchEnabled = !_appConfigService.currentMessageRuntime.isRelayOnly;
    _appConfigService.addListener(_handleRuntimeChanged);
    _availableChats = _messageService.chats;
    _roomFilter = widget.initialRoomId?.trim() ?? '';

    unawaited(_rebuildIndexFromCache());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _queryFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _appConfigService.removeListener(_handleRuntimeChanged);
    _debounceTimer?.cancel();
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  void _handleRuntimeChanged() {
    final nextEnabled = !_appConfigService.currentMessageRuntime.isRelayOnly;
    if (_serverSearchEnabled == nextEnabled) {
      return;
    }

    if (!mounted) {
      _serverSearchEnabled = nextEnabled;
      return;
    }

    setState(() {
      _serverSearchEnabled = nextEnabled;
      _hasMoreServer = false;
      _serverOffset = 0;
    });

    final query = _queryController.text.trim();
    if (query.isNotEmpty) {
      unawaited(_runSearch(reset: true));
    }
  }

  Future<void> _rebuildIndexFromCache() async {
    if (_isIndexing) return;
    setState(() {
      _isIndexing = true;
      _indexDone = 0;
      _indexTotal = 0;
    });

    try {
      final roomIds = await _messageStorage.listRoomIds();
      if (!mounted) return;

      final roomNameById = <String, String>{};
      for (final chat in _availableChats) {
        roomNameById[chat.roomId] = chat.name;
      }

      setState(() {
        _indexTotal = roomIds.length;
      });

      for (final roomId in roomIds) {
        final messages = await _messageStorage.loadMessages(roomId);
        final roomName = roomNameById[roomId] ?? roomId;
        await _searchStorage.replaceRoomIndex(
          roomId: roomId,
          roomName: roomName,
          messages: messages,
        );

        if (!mounted) return;
        setState(() {
          _indexDone += 1;
        });
      }
    } catch (_) {
      // 索引构建失败时不阻塞：仍可继续使用服务端搜索
    } finally {
      if (mounted) {
        setState(() {
          _isIndexing = false;
        });
      }
    }
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final query = _queryController.text.trim();
      if (query.isEmpty) {
        setState(() {
          _results = const [];
          _stats = null;
          _localOffset = 0;
          _serverOffset = 0;
          _hasMoreLocal = false;
          _hasMoreServer = false;
          _isSearching = false;
        });
        return;
      }
      unawaited(_runSearch(reset: true));
    });
  }

  Future<void> _runSearch({required bool reset}) async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    if (reset) {
      _searchSequence += 1;
      setState(() {
        _isSearching = true;
        _results = const [];
        _stats = null;
        _localOffset = 0;
        _serverOffset = 0;
        _hasMoreLocal = false;
        _hasMoreServer = false;
      });
    } else {
      setState(() {
        _isSearching = true;
      });
    }

    final seq = _searchSequence;

    try {
      final local = await _searchStorage.searchMessages(
        query: query,
        roomId: _roomFilter.isEmpty ? null : _roomFilter,
        messageType: _typeFilter.isEmpty ? null : _typeFilter,
        limit: 50,
        offset: 0,
      );

      if (!mounted || seq != _searchSequence) return;

      setState(() {
        _results = _deduplicateResults(local.results);
        _stats = local.stats;
        _localOffset = local.results.length;
        _hasMoreLocal = local.hasMore;
        _hasMoreServer = false;
        _serverOffset = 0;
      });

      if (_serverSearchEnabled) {
        unawaited(_syncServerResults(offset: 0, seq: seq));
      }
    } catch (_) {
      if (!mounted || seq != _searchSequence) return;
      setState(() {
        _results = const [];
        _stats = null;
        _localOffset = 0;
        _hasMoreLocal = false;
        _hasMoreServer = false;
        _serverOffset = 0;
      });
      if (_serverSearchEnabled) {
        unawaited(_syncServerResults(offset: 0, seq: seq));
      }
    } finally {
      if (mounted && seq == _searchSequence) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    if (!_hasMoreLocal && !_hasMoreServer) return;

    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    final seq = _searchSequence;

    try {
      if (_hasMoreLocal) {
        final local = await _searchStorage.searchMessages(
          query: query,
          roomId: _roomFilter.isEmpty ? null : _roomFilter,
          messageType: _typeFilter.isEmpty ? null : _typeFilter,
          limit: 50,
          offset: _localOffset,
        );

        if (!mounted || seq != _searchSequence) return;

        _mergeResults(local.results);
        setState(() {
          _localOffset += local.results.length;
          _hasMoreLocal = local.hasMore;
        });
        return;
      }

      if (_hasMoreServer) {
        await _syncServerResults(offset: _serverOffset, seq: seq);
      }
    } finally {
      if (mounted && seq == _searchSequence) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _mergeResults(List<MessageSearchResult> incoming) {
    if (incoming.isEmpty) return;
    final exists = _results.map((r) => r.id).toSet();
    final merged = List<MessageSearchResult>.from(_results);
    for (final item in incoming) {
      if (exists.add(item.id)) {
        merged.add(item);
      }
    }
    setState(() {
      _results = merged;
    });
  }

  List<MessageSearchResult> _deduplicateResults(
    List<MessageSearchResult> results,
  ) {
    final seen = <String>{};
    return results
        .where((result) => seen.add(result.id))
        .toList(growable: false);
  }

  Future<void> _syncServerResults({
    required int offset,
    required int seq,
  }) async {
    try {
      final response = await _searchFromServer(
        query: _queryController.text.trim(),
        roomId: _roomFilter.isEmpty ? null : _roomFilter,
        messageType: _typeFilter.isEmpty ? null : _typeFilter,
        limit: 50,
        offset: offset,
      );

      if (!mounted || seq != _searchSequence) return;

      _mergeResults(response.results);

      setState(() {
        if (_stats == null) {
          _stats = response.stats;
        } else {
          _stats = MessageSearchStats(
            totalResults: _stats!.totalResults < response.stats.totalResults
                ? response.stats.totalResults
                : _stats!.totalResults,
            searchTimeMs: _stats!.searchTimeMs,
            query: _stats!.query,
          );
        }

        _hasMoreServer = response.hasMore;
        _serverOffset = offset + response.results.length;
      });
    } catch (_) {
      // 静默失败：本地索引结果仍可用
    }
  }

  int? _toServerTimestampSeconds(int? valueMs) {
    if (valueMs == null) return null;
    if (valueMs > 1_000_000_000_000) {
      return valueMs ~/ 1000;
    }
    return valueMs;
  }

  Future<_ServerSearchResponse> _searchFromServer({
    required String query,
    String? roomId,
    String? messageType,
    int? dateFromMs,
    int? dateToMs,
    required int limit,
    required int offset,
  }) async {
    final session = await _messageService.tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final params = <String, String>{
      'query': query,
      'limit': limit.clamp(1, 100).toString(),
      'offset': offset < 0 ? '0' : offset.toString(),
    };

    if (roomId != null && roomId.trim().isNotEmpty) {
      params['room_id'] = roomId.trim();
    }
    if (messageType != null && messageType.trim().isNotEmpty) {
      params['message_type'] = messageType.trim();
    }
    final dateFrom = _toServerTimestampSeconds(dateFromMs);
    if (dateFrom != null) params['date_from'] = dateFrom.toString();
    final dateTo = _toServerTimestampSeconds(dateToMs);
    if (dateTo != null) params['date_to'] = dateTo.toString();

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/messages/search',
    ).replace(queryParameters: params);
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer ${session.token}'},
    );

    if (response.statusCode != 200) {
      throw Exception('服务端搜索失败: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Invalid server search response');
    }

    final resultsRaw = decoded['results'];
    final statsRaw = decoded['stats'];
    final hasMoreRaw = decoded['has_more'];

    final results = <MessageSearchResult>[];
    if (resultsRaw is List) {
      for (final item in resultsRaw) {
        if (item is! Map) continue;
        final id = item['id']?.toString() ?? '';
        final roomIdVal = item['room_id']?.toString() ?? '';
        final roomName = item['room_name']?.toString() ?? '';
        final senderId = item['sender_id']?.toString() ?? '';
        final senderName = item['sender_name']?.toString() ?? '';
        final content = item['content']?.toString() ?? '';
        final messageTypeVal = item['message_type']?.toString() ?? 'text';
        final relevanceScore =
            (item['relevance_score'] as num?)?.toDouble() ?? 0;

        final timestampRaw = item['timestamp']?.toString() ?? '';
        final timestampMs = DateTime.tryParse(
          timestampRaw,
        )?.millisecondsSinceEpoch;

        results.add(
          MessageSearchResult(
            id: id,
            roomId: roomIdVal,
            roomName: roomName,
            senderId: senderId,
            senderName: senderName,
            content: content,
            messageType: messageTypeVal,
            timestampMs: timestampMs ?? DateTime.now().millisecondsSinceEpoch,
            relevanceScore: relevanceScore,
            matchedText: null,
          ),
        );
      }
    }

    MessageSearchStats stats;
    if (statsRaw is Map) {
      stats = MessageSearchStats(
        totalResults: (statsRaw['total_results'] as int?) ?? results.length,
        searchTimeMs: (statsRaw['search_time_ms'] as int?) ?? 0,
        query: statsRaw['query']?.toString() ?? query,
      );
    } else {
      stats = MessageSearchStats(
        totalResults: results.length,
        searchTimeMs: 0,
        query: query,
      );
    }

    return _ServerSearchResponse(
      results: results,
      stats: stats,
      hasMore: hasMoreRaw == true,
    );
  }

  void _clearQuery() {
    _debounceTimer?.cancel();
    _queryController.clear();
    setState(() {
      _results = const [];
      _stats = null;
      _localOffset = 0;
      _serverOffset = 0;
      _hasMoreLocal = false;
      _hasMoreServer = false;
      _isSearching = false;
    });
    _queryFocusNode.requestFocus();
  }

  String _formatTimestamp(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now().toLocal();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  String _messageTypeLabel(String type) {
    switch (type) {
      case 'text':
        return '文本';
      case 'image':
        return '图片';
      case 'video':
        return '视频';
      case 'audio':
        return '语音';
      case 'file':
        return '文件';
      case 'system':
        return '系统';
      case 'mixed':
        return '多媒体';
      default:
        return type;
    }
  }

  List<TextSpan> _buildMarkedTextSpans(
    String text, {
    required TextStyle normalStyle,
    required TextStyle highlightStyle,
  }) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'<mark>(.*?)</mark>', dotAll: true);
    var current = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > current) {
        spans.add(
          TextSpan(
            text: text.substring(current, match.start),
            style: normalStyle,
          ),
        );
      }
      spans.add(TextSpan(text: match.group(1) ?? '', style: highlightStyle));
      current = match.end;
    }
    if (current < text.length) {
      spans.add(TextSpan(text: text.substring(current), style: normalStyle));
    }
    return spans;
  }

  List<TextSpan> _buildKeywordTextSpans(
    String text,
    List<String> keywords, {
    required TextStyle normalStyle,
    required TextStyle highlightStyle,
  }) {
    final filtered = keywords
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    if (filtered.isEmpty) {
      return [TextSpan(text: text, style: normalStyle)];
    }

    final pattern = filtered.map(RegExp.escape).join('|');
    final regex = RegExp('($pattern)', caseSensitive: false);
    final spans = <TextSpan>[];

    var current = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > current) {
        spans.add(
          TextSpan(
            text: text.substring(current, match.start),
            style: normalStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: highlightStyle,
        ),
      );
      current = match.end;
    }
    if (current < text.length) {
      spans.add(TextSpan(text: text.substring(current), style: normalStyle));
    }
    return spans;
  }

  List<String> _extractKeywords(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final removedQuotes = normalized.replaceAll('"', ' ');
    final tokens = removedQuotes
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty);
    final keywords = <String>[];
    for (final token in tokens) {
      final upper = token.toUpperCase();
      if (upper == 'AND' || upper == 'OR' || upper == 'NOT') continue;
      keywords.add(token);
    }
    return keywords;
  }

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final initialRoom = _roomFilter;
        final initialType = _typeFilter;
        var selectedRoom = initialRoom;
        var selectedType = initialType;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '筛选',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '会话',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRoom.isEmpty ? '' : selectedRoom,
                      items: [
                        const DropdownMenuItem(value: '', child: Text('所有会话')),
                        ..._availableChats.map(
                          (chat) => DropdownMenuItem(
                            value: chat.roomId,
                            child: Text(chat.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          selectedRoom = (value ?? '').trim();
                        });
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '类型',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType.isEmpty ? '' : selectedType,
                      items: const [
                        DropdownMenuItem(value: '', child: Text('所有类型')),
                        DropdownMenuItem(value: 'text', child: Text('文本')),
                        DropdownMenuItem(value: 'image', child: Text('图片')),
                        DropdownMenuItem(value: 'video', child: Text('视频')),
                        DropdownMenuItem(value: 'audio', child: Text('语音')),
                        DropdownMenuItem(value: 'file', child: Text('文件')),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          selectedType = (value ?? '').trim();
                        });
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                            },
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              setState(() {
                                _roomFilter = selectedRoom;
                                _typeFilter = selectedType;
                              });
                              final query = _queryController.text.trim();
                              if (query.isNotEmpty) {
                                unawaited(_runSearch(reset: true));
                              }
                            },
                            child: const Text('应用'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _activeFilterLabel() {
    final labels = <String>[];
    if (_roomFilter.isNotEmpty) {
      final chat = _availableChats
          .where((c) => c.roomId == _roomFilter)
          .toList();
      labels.add(chat.isNotEmpty ? chat.first.name : '指定会话');
    }
    if (_typeFilter.isNotEmpty) {
      labels.add(_messageTypeLabel(_typeFilter));
    }
    return labels.isEmpty ? '' : labels.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final filterLabel = _activeFilterLabel();
    final totalLabel = _stats == null ? '' : '共 ${_stats!.totalResults} 条';
    final hasMore = _hasMoreLocal || _hasMoreServer;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('搜索消息'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '筛选',
            onPressed: _showFilters,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isIndexing)
              LinearProgressIndicator(
                value: _indexTotal == 0 ? null : (_indexDone / _indexTotal),
                minHeight: 2,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        focusNode: _queryFocusNode,
                        onChanged: _onQueryChanged,
                        onSubmitted: (_) => unawaited(_runSearch(reset: true)),
                        textInputAction: TextInputAction.search,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: const InputDecoration(
                          hintText: '搜索消息内容',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                    if (_queryController.text.isNotEmpty)
                      GestureDetector(
                        onTap: _clearQuery,
                        child: const Icon(
                          Icons.clear,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (filterLabel.isNotEmpty || totalLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    if (filterLabel.isNotEmpty)
                      Expanded(
                        child: Text(
                          filterLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (totalLabel.isNotEmpty)
                      Text(
                        totalLabel,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            if (!_serverSearchEnabled)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '当前仅搜索本地缓存消息',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _queryController.text.trim().isNotEmpty && _results.isEmpty
                  ? const Center(
                      child: Text(
                        '未找到相关消息',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: _results.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _results.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: OutlinedButton(
                              onPressed: _isLoadingMore ? null : _loadMore,
                              child: Text(_isLoadingMore ? '加载中...' : '加载更多'),
                            ),
                          );
                        }

                        final result = _results[index];
                        final isNonText = result.messageType != 'text';
                        final title = result.roomName.isNotEmpty
                            ? result.roomName
                            : result.roomId;
                        final subtitle = result.senderName.isNotEmpty
                            ? result.senderName
                            : result.senderId;
                        final timeText = _formatTimestamp(result.timestamp);

                        final contentStyle = const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.35,
                        );
                        final highlightStyle = contentStyle.copyWith(
                          backgroundColor: const Color(0x33FFCC00),
                          fontWeight: FontWeight.w600,
                        );

                        final matched = result.matchedText;
                        final keywords = _extractKeywords(
                          _queryController.text,
                        );
                        final spans = matched != null && matched.isNotEmpty
                            ? _buildMarkedTextSpans(
                                matched,
                                normalStyle: contentStyle,
                                highlightStyle: highlightStyle,
                              )
                            : _buildKeywordTextSpans(
                                result.content,
                                keywords,
                                normalStyle: contentStyle,
                                highlightStyle: highlightStyle,
                              );

                        return InkWell(
                          onTap: () => Navigator.of(context).pop(result),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0x11000000)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      timeText,
                                      style: const TextStyle(
                                        color: AppColors.textTertiary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (isNonText) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceMuted,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          _messageTypeLabel(result.messageType),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                RichText(
                                  text: TextSpan(children: spans),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerSearchResponse {
  const _ServerSearchResponse({
    required this.results,
    required this.stats,
    required this.hasMore,
  });

  final List<MessageSearchResult> results;
  final MessageSearchStats stats;
  final bool hasMore;
}
