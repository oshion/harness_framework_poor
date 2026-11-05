#!/usr/bin/env node
// tdd-guard.mjs
// 로직 레이어 구현 파일을 수정할 때 대응하는 테스트 파일(tests/unit/ 미러 경로)이 없으면 차단한다.
//
//   src/core/{path}/{name}.ts    → tests/unit/core/{path}/{name}.test.ts
//   src/server/{path}/{name}.ts  → tests/unit/server/{path}/{name}.test.ts
//
// 대상 레이어는 아래 RULES에서 프로젝트에 맞게 바꾼다. UI·렌더링 레이어는 E2E·스크린샷으로 검증하므로 보통 넣지 않는다.
// 차단은 exit 2 (Claude Code 훅 규약: exit 2만 도구 호출을 막고 stderr를 Claude에게 전달한다).
// python3 가 없는 Windows 환경에서도 동작하도록 Node로 작성한다.

import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

// 프로젝트에 맞게 수정: TDD를 강제할 소스 경로 → 테스트 미러 디렉토리
const RULES = [
  { pattern: /^src\/core\/(.+)\.ts$/, dir: 'tests/unit/core' },
  { pattern: /^src\/server\/(.+)\.ts$/, dir: 'tests/unit/server' },
];

let payload = {};
try {
  payload = JSON.parse(readFileSync(0, 'utf8'));
} catch {
  process.exit(0);
}

const filePath = payload?.tool_input?.file_path;
if (!filePath) process.exit(0);

const root = path.resolve(process.env.CLAUDE_PROJECT_DIR || payload.cwd || process.cwd());
const rel = path.relative(root, path.resolve(root, filePath)).split(path.sep).join('/');

// 이미 테스트 파일이거나 타입 선언·배럴 파일이면 통과
if (/\.(test|spec)\.[cm]?[jt]sx?$/.test(rel)) process.exit(0);
if (/\.d\.ts$/.test(rel) || /(^|\/)index\.ts$/.test(rel)) process.exit(0);

const rule = RULES.find((r) => r.pattern.test(rel));
if (!rule) process.exit(0);

const stem = rel.match(rule.pattern)[1];
const candidates = [`${rule.dir}/${stem}.test.ts`, `${rule.dir}/${stem}.spec.ts`];
if (candidates.some((c) => existsSync(path.join(root, c)))) process.exit(0);

process.stderr.write(
  [
    '',
    '🚫 TDD GUARD: 테스트 파일이 없습니다.',
    `   구현 파일: ${rel}`,
    '   먼저 아래 테스트를 작성하세요 (AGENTS.md TDD 규칙):',
    `   → ${candidates[0]}`,
    '',
  ].join('\n'),
);
process.exit(2);
