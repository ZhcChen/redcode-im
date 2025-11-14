import 'dart:convert';

enum HotUpdateStage {
  idle,
  checking,
  noUpdate,
  available,
  downloading,
  verifying,
  downloaded,
  applying,
  applied,
  failed,
}

class HotPatchInfo {
  HotPatchInfo({
    required this.id,
    required this.platform,
    required this.appVersionId,
    required this.patchVersion,
    required this.channel,
    required this.downloadKey,
    this.downloadUrl,
    this.fileSize,
    this.checksum,
    this.signature,
    required this.rolloutPercentage,
    required this.mandatory,
    this.description,
    required this.isActive,
    this.releasedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HotPatchInfo.fromJson(Map<String, dynamic> json) {
    return HotPatchInfo(
      id: json['id'] as String,
      platform: json['platform'] as String? ?? '',
      appVersionId: json['app_version_id'] as String? ?? '',
      patchVersion: json['patch_version'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      downloadKey: json['download_key'] as String? ?? '',
      downloadUrl: json['download_url'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      checksum: json['checksum'] as String?,
      signature: json['signature'] as String?,
      rolloutPercentage: (json['rollout_percentage'] as num?)?.toInt() ?? 100,
      mandatory: json['mandatory'] as bool? ?? false,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      releasedAt: json['released_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'platform': platform,
      'app_version_id': appVersionId,
      'patch_version': patchVersion,
      'channel': channel,
      'download_key': downloadKey,
      'download_url': downloadUrl,
      'file_size': fileSize,
      'checksum': checksum,
      'signature': signature,
      'rollout_percentage': rolloutPercentage,
      'mandatory': mandatory,
      'description': description,
      'is_active': isActive,
      'released_at': releasedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  final String id;
  final String platform;
  final String appVersionId;
  final String patchVersion;
  final String channel;
  final String downloadKey;
  final String? downloadUrl;
  final int? fileSize;
  final String? checksum;
  final String? signature;
  final int rolloutPercentage;
  final bool mandatory;
  final String? description;
  final bool isActive;
  final String? releasedAt;
  final String createdAt;
  final String updatedAt;
}

class HotUpdateCheckResult {
  const HotUpdateCheckResult({
    required this.hasUpdate,
    required this.currentPatchVersion,
    this.patch,
  });

  final bool hasUpdate;
  final String? currentPatchVersion;
  final HotPatchInfo? patch;
}

class HotUpdateDownloadRecord {
  HotUpdateDownloadRecord({
    required this.patchId,
    required this.patchVersion,
    required this.baseVersion,
    required this.filePath,
    this.fileSize,
    this.checksum,
    this.downloadedAt,
  });

  factory HotUpdateDownloadRecord.fromJson(Map<String, dynamic> json) {
    return HotUpdateDownloadRecord(
      patchId: json['patch_id'] as String,
      patchVersion: json['patch_version'] as String,
      baseVersion: json['base_version'] as String,
      filePath: json['file_path'] as String,
      fileSize: json['file_size'] as int?,
      checksum: json['checksum'] as String?,
      downloadedAt: json['downloaded_at'] == null
          ? null
          : DateTime.tryParse(json['downloaded_at'] as String),
    );
  }

  final String patchId;
  final String patchVersion;
  final String baseVersion;
  final String filePath;
  final int? fileSize;
  final String? checksum;
  final DateTime? downloadedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'patch_id': patchId,
      'patch_version': patchVersion,
      'base_version': baseVersion,
      'file_path': filePath,
      'file_size': fileSize,
      'checksum': checksum,
      'downloaded_at': downloadedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}

class HotUpdateState {
  const HotUpdateState({
    this.stage = HotUpdateStage.idle,
    this.patch,
    this.downloaded,
    this.progress = 0,
    this.errorMessage,
  });

  final HotUpdateStage stage;
  final HotPatchInfo? patch;
  final HotUpdateDownloadRecord? downloaded;
  final double progress;
  final String? errorMessage;

  HotUpdateState copyWith({
    HotUpdateStage? stage,
    HotPatchInfo? patch,
    HotUpdateDownloadRecord? downloaded,
    double? progress,
    String? errorMessage,
  }) {
    return HotUpdateState(
      stage: stage ?? this.stage,
      patch: patch ?? this.patch,
      downloaded: downloaded ?? this.downloaded,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
    );
  }

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}

class InstalledHotPatchInfo {
  InstalledHotPatchInfo({
    required this.patchVersion,
    required this.baseVersion,
    this.appliedAt,
  });

  factory InstalledHotPatchInfo.fromJson(Map<String, dynamic> json) {
    return InstalledHotPatchInfo(
      patchVersion: json['patch_version'] as String,
      baseVersion: json['base_version'] as String,
      appliedAt: json['applied_at'] == null
          ? null
          : DateTime.tryParse(json['applied_at'] as String),
    );
  }

  final String patchVersion;
  final String baseVersion;
  final DateTime? appliedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'patch_version': patchVersion,
      'base_version': baseVersion,
      'applied_at': appliedAt?.toIso8601String(),
    };
  }
}
