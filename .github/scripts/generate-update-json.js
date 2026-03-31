#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

function fail(message) {
  console.error(message);
  process.exit(1);
}

function parseArgs(argv) {
  const [command, ...rest] = argv;
  const options = {};

  for (let index = 0; index < rest.length; index += 1) {
    const token = rest[index];
    if (!token.startsWith('--')) {
      fail(`未知参数：${token}`);
    }

    const key = token.slice(2);
    const value = rest[index + 1];
    if (value == null || value.startsWith('--')) {
      fail(`参数 ${token} 缺少值`);
    }

    options[key] = value;
    index += 1;
  }

  return { command, options };
}

function parseVersion(version) {
  const match = /^(\d+)\.(\d+)\.(\d+)$/.exec(version);
  if (!match) {
    fail(`版本号格式非法：${version}。必须使用严格三段数字，例如 0.0.2`);
  }

  return match.slice(1).map((part) => Number(part));
}

function compareVersions(left, right) {
  const leftParts = parseVersion(left);
  const rightParts = parseVersion(right);

  for (let index = 0; index < leftParts.length; index += 1) {
    if (leftParts[index] > rightParts[index]) {
      return 1;
    }
    if (leftParts[index] < rightParts[index]) {
      return -1;
    }
  }

  return 0;
}

function readCurrentVersion(filePath) {
  if (!fs.existsSync(filePath)) {
    return null;
  }

  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  if (typeof data.version !== 'string') {
    fail(`当前 latest.json 缺少 version 字段：${filePath}`);
  }

  return data.version;
}

function generateJSON(options) {
  const requiredKeys = [
    'output',
    'version',
    'published-at',
    'minimum-system-version',
    'page-url',
    'download-url',
    'notes-markdown',
  ];

  for (const key of requiredKeys) {
    if (!options[key]) {
      fail(`generate 缺少参数：--${key}`);
    }
  }

  parseVersion(options['version']);

  const payload = {
    version: options['version'],
    publishedAt: options['published-at'],
    minimumSystemVersion: options['minimum-system-version'],
    pageURL: options['page-url'],
    downloadURL: options['download-url'],
    notesMarkdown: options['notes-markdown'],
  };

  const outputPath = path.resolve(options.output);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(`${outputPath}`, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
}

function compareCandidate(options) {
  const candidate = options.candidate;
  const currentFile = options['current-file'];

  if (!candidate || !currentFile) {
    fail('compare 需要 --candidate 和 --current-file');
  }

  const current = readCurrentVersion(path.resolve(currentFile));
  if (current == null) {
    return;
  }

  const comparison = compareVersions(candidate, current);
  if (comparison <= 0) {
    fail(`候选版本 ${candidate} 不高于当前 latest.json 中的 ${current}，拒绝覆盖。`);
  }
}

function main() {
  const { command, options } = parseArgs(process.argv.slice(2));

  switch (command) {
    case 'generate':
      generateJSON(options);
      break;
    case 'compare':
      compareCandidate(options);
      break;
    default:
      fail(`未知命令：${command}`);
  }
}

main();
