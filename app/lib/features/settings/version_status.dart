import '../../core/services/version_service.dart';
import '../../core/update/hot_update_models.dart';

enum VersionStatusKind {
  checking,
  latest,
  optional,
  forced,
  error,
  hotAvailable,
  hotApplied,
}

class VersionStatus {
  const VersionStatus(this.kind, this.label);

  final VersionStatusKind kind;
  final String label;
}

VersionStatus resolveVersionStatus({
  required bool checking,
  VersionCheckResult? result,
  Object? error,
  HotUpdateStage? hotStage,
}) {
  if (hotStage == HotUpdateStage.applied) {
    return const VersionStatus(VersionStatusKind.hotApplied, '热更新已应用');
  }
  if (hotStage == HotUpdateStage.available ||
      hotStage == HotUpdateStage.downloaded) {
    return const VersionStatus(VersionStatusKind.hotAvailable, '有可用热更新');
  }
  if (checking) {
    return const VersionStatus(VersionStatusKind.checking, '正在检查更新');
  }
  if (error != null) {
    return const VersionStatus(VersionStatusKind.error, '检查失败，可重试');
  }
  final latest = result?.latest;
  if (result?.hasUpdate == true && latest != null) {
    return latest.mandatory
        ? const VersionStatus(VersionStatusKind.forced, '发现强制更新')
        : const VersionStatus(VersionStatusKind.optional, '发现可选更新');
  }
  return const VersionStatus(VersionStatusKind.latest, '当前已是最新版本');
}
