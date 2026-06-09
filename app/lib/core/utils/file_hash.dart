import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;

/// 文件哈希结果
class FileHashResult {
  const FileHashResult({
    required this.hashValue,
    required this.hashAlg,
  });

  /// 十六进制哈希值（失败时为 null）
  final String? hashValue;

  /// 哈希算法编号：2 = sha256；失败或不支持时为 null
  final int? hashAlg;
}

/// 计算文件/二进制数据的 SHA-256 哈希（前端 Flutter 侧）  
/// 若运行环境不支持 crypto（如 web 未开启），调用方可选择忽略结果。
Future<FileHashResult> computeFileHash(Uint8List bytes) async {
  try {
    final digest = crypto.sha256.convert(bytes);
    final hashHex = digest.toString();
    return FileHashResult(hashValue: hashHex, hashAlg: 2);
  } catch (_) {
    // 兜底：无法计算时返回空结果
    return const FileHashResult(hashValue: null, hashAlg: null);
  }
}
