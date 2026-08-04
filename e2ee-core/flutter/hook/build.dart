import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const _assetName = 'redcode_e2ee_core';

Future<void> main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final config = input.config.code;
    final target = _rustTarget(config);
    final crateRoot = input.packageRoot.resolve('../');
    output.dependencies.addAll(_crateDependencies(crateRoot));
    final targetDirectory = input.outputDirectoryShared.resolve(
      'cargo-target/',
    );
    final environment = Map<String, String>.from(Platform.environment)
      ..['CARGO_TARGET_DIR'] = targetDirectory.toFilePath();

    final compiler = config.cCompiler;
    final linker = switch ((config.targetOS, compiler)) {
      (OS.android, final compiler?) => _androidClang(config, compiler),
      (_, final compiler?) => compiler.linker.toFilePath(),
      _ => null,
    };
    if (linker != null) {
      environment['CARGO_TARGET_${target.toUpperCase().replaceAll('-', '_')}_LINKER'] =
          linker;
    }

    final result = await Process.run('cargo', [
      'build',
      '--manifest-path',
      crateRoot.resolve('Cargo.toml').toFilePath(),
      '--release',
      '--target',
      target,
    ], environment: environment);
    if (result.exitCode != 0) {
      throw StateError(
        'E2EE core build failed for $target:\n${result.stdout}\n${result.stderr}',
      );
    }

    final library = targetDirectory.resolve(
      '$target/release/${_libraryName(config.targetOS)}',
    );
    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _assetName,
        linkMode: DynamicLoadingBundled(),
        file: library,
      ),
    );
  });
}

Iterable<Uri> _crateDependencies(Uri crateRoot) sync* {
  yield crateRoot.resolve('Cargo.toml');
  yield crateRoot.resolve('Cargo.lock');
  final sourceDirectory = Directory.fromUri(crateRoot.resolve('src/'));
  for (final entry in sourceDirectory.listSync(recursive: true)) {
    if (entry is File) yield entry.uri;
  }
}

String _androidClang(CodeConfig config, CCompilerConfig compiler) {
  final prefix = switch (config.targetArchitecture) {
    Architecture.arm => 'armv7a-linux-androideabi',
    Architecture.arm64 => 'aarch64-linux-android',
    Architecture.ia32 => 'i686-linux-android',
    Architecture.x64 => 'x86_64-linux-android',
    _ => throw UnsupportedError(
      'Unsupported Android architecture ${config.targetArchitecture}',
    ),
  };
  final compilerFile = File.fromUri(compiler.compiler);
  return '${compilerFile.parent.path}/$prefix${config.android.targetNdkApi}-clang';
}

String _rustTarget(CodeConfig config) {
  final architecture = config.targetArchitecture;
  if (config.targetOS == OS.iOS) {
    if (config.iOS.targetSdk == IOSSdk.iPhoneSimulator) {
      return architecture == Architecture.arm64
          ? 'aarch64-apple-ios-sim'
          : 'x86_64-apple-ios';
    }
    if (architecture == Architecture.arm64) return 'aarch64-apple-ios';
  }
  if (config.targetOS == OS.android) {
    if (architecture == Architecture.arm64) return 'aarch64-linux-android';
    if (architecture == Architecture.x64) return 'x86_64-linux-android';
    if (architecture == Architecture.arm) return 'armv7-linux-androideabi';
  }
  if (config.targetOS == OS.macOS) {
    return architecture == Architecture.arm64
        ? 'aarch64-apple-darwin'
        : 'x86_64-apple-darwin';
  }
  throw UnsupportedError(
    'E2EE core does not support ${config.targetOS}/${config.targetArchitecture}',
  );
}

String _libraryName(OS os) {
  if (os == OS.android || os == OS.linux) return 'libredcode_e2ee_core.so';
  if (os == OS.iOS || os == OS.macOS) return 'libredcode_e2ee_core.dylib';
  if (os == OS.windows) return 'redcode_e2ee_core.dll';
  throw UnsupportedError('E2EE core does not support $os');
}
