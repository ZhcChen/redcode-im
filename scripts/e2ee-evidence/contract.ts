import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

export const evidenceSchema = 'redcode-u10-e2ee-evidence/v1';
export const generator = { name: 'scripts/e2ee-evidence/sanitize.ts', version: 1 } as const;
export const sha256Pattern = /^[a-f0-9]{64}$/;
export const commitPattern = /^[a-f0-9]{40}$/;
export const timestampPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/;

export type EvidenceType = 'g1-backup-rollout' | 'g3-h5-release';

export function fail(message: string): never {
  throw new Error(`[e2ee-evidence] ${message}`);
}

export function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.entries(value as Record<string, unknown>)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, item]) => `${JSON.stringify(key)}:${canonicalJson(item)}`)
      .join(',')}}`;
  }
  return JSON.stringify(value);
}

export function sha256(value: unknown): string {
  return createHash('sha256').update(canonicalJson(value)).digest('hex');
}

export function exactKeys(
  value: unknown,
  keys: readonly string[],
  context: string,
): asserts value is Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail(`${context} 必须是 object`);
  const actual = Object.keys(value as Record<string, unknown>).sort();
  const expected = [...keys].sort();
  if (actual.length !== expected.length || actual.some((key, index) => key !== expected[index])) {
    fail(`${context} 字段不符合白名单`);
  }
}

export function integer(value: unknown, context: string): number {
  if (!Number.isSafeInteger(value) || Number(value) < 0) fail(`${context} 必须是非负整数`);
  return Number(value);
}

export function boolean(value: unknown, context: string): boolean {
  if (typeof value !== 'boolean') fail(`${context} 必须是 boolean`);
  return value;
}

export function string(value: unknown, context: string): string {
  if (typeof value !== 'string' || !value) fail(`${context} 必须是非空字符串`);
  return value;
}

export function enumValue<T extends string>(
  value: unknown,
  allowed: readonly T[],
  context: string,
): T {
  if (typeof value !== 'string' || !allowed.includes(value as T)) {
    fail(`${context} 不在允许枚举中`);
  }
  return value as T;
}

export function subjectCommitTime(root: string, commit: string): string {
  if (!commitPattern.test(commit)) fail('subject_commit 必须是完整小写 Git SHA');
  try {
    const resolved = execFileSync('git', ['rev-parse', `${commit}^{commit}`], {
      cwd: root,
      encoding: 'utf8',
    }).trim();
    if (resolved !== commit) fail('subject_commit 解析结果不一致');
    return execFileSync('git', ['show', '-s', '--format=%cI', commit], {
      cwd: root,
      encoding: 'utf8',
    }).trim();
  } catch {
    fail('subject_commit 在当前仓库不可达');
  }
}

const sensitivePatterns: Array<[string, RegExp]> = [
  ['credential key', /^(password|token|secret|private[_-]?key|authorization|database_url|redis_url)$/i],
  ['credential value', /(bearer\s+|postgres(?:ql)?:\/\/|redis:\/\/|BEGIN [A-Z ]*PRIVATE KEY)/i],
  ['plaintext marker', /(u10-restore-|h5-production-store-|h5-aad-tamper-|H5Audit-)/i],
  ['UUID', /\b[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/i],
  ['reusable URL', /\b(?:https?|wss?):\/\//i],
];

export function assertSensitiveValuesAbsent(value: unknown): void {
  const visit = (item: unknown, key = ''): void => {
    for (const [name, pattern] of sensitivePatterns) {
      if (pattern.test(key)) fail(`证据包含敏感字段：${name}`);
    }
    if (typeof item === 'string') {
      for (const [name, pattern] of sensitivePatterns) {
        if (pattern.test(item)) fail(`证据包含敏感值：${name}`);
      }
      return;
    }
    if (Array.isArray(item)) {
      item.forEach((child) => visit(child));
      return;
    }
    if (item && typeof item === 'object') {
      for (const [childKey, child] of Object.entries(item as Record<string, unknown>)) {
        visit(child, childKey);
      }
    }
  };
  visit(value);
}
