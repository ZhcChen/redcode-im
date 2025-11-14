class HotPatchManifest {
  HotPatchManifest({
    required this.schema,
    required this.baseVersion,
    required this.patchVersion,
    this.channel,
    this.description,
    this.assetsRoot,
  });

  factory HotPatchManifest.fromJson(Map<String, dynamic> json) {
    return HotPatchManifest(
      schema: json['schema'] as int? ?? 1,
      baseVersion: json['base_version'] as String? ?? '',
      patchVersion: json['patch_version'] as String? ?? '',
      channel: json['channel'] as String?,
      description: json['description'] as String?,
      assetsRoot: () {
        final payloads = json['payloads'];
        if (payloads is Map<String, dynamic>) {
          final assets = payloads['assets'];
          if (assets is Map<String, dynamic>) {
            final root = assets['root'];
            if (root is String && root.isNotEmpty) {
              return root;
            }
          }
        }
        return null;
      }(),
    );
  }

  final int schema;
  final String baseVersion;
  final String patchVersion;
  final String? channel;
  final String? description;
  final String? assetsRoot;
}
