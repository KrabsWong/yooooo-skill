#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import readline from 'node:readline/promises';
import {fileURLToPath} from 'node:url';
import React, {useMemo, useState} from 'react';
import {Box, Text, render, useApp, useInput} from 'ink';

const startDir = process.cwd();
const homeDir = os.homedir();
const scriptPath = typeof __filename === 'string' ? __filename : fileURLToPath(import.meta.url);
const repoRoot = resolveRepoRoot();
const h = React.createElement;

const knownGlobalTargets = [
  {
    key: 'shared',
    name: 'Shared global',
    dir: path.join(homeDir, '.agents', 'skills'),
  },
  {
    key: 'codex',
    name: 'Codex global',
    dir: path.join(process.env.CODEX_HOME || path.join(homeDir, '.codex'), 'skills'),
  },
  {
    key: 'claude',
    name: 'Claude Code global',
    dir: path.join(homeDir, '.claude', 'skills'),
  },
  {
    key: 'opencode',
    name: 'OpenCode global',
    dir: path.join(homeDir, '.config', 'opencode', 'skills'),
  },
  {
    key: 'pi',
    name: 'Pi global',
    dir: path.join(homeDir, '.pi', 'agent', 'skills'),
  },
];

function usage() {
  return `Install Agent Skills from this repository by creating symlinks.

Usage:
  npm run install-skills
  node scripts/install-skills.mjs
  node scripts/install-skills.mjs --list
  node scripts/install-skills.mjs --installed
  node scripts/install-skills.mjs --all --global codex --yes
  node scripts/install-skills.mjs --first-party --global all --yes
  node scripts/install-skills.mjs --skill write --project /path/to/project --yes
  node scripts/install-skills.mjs --all --target /path/to/skills --dry-run

Options:
  --all                  Install every discovered skill.
  --first-party          Install root-level first-party skills.
  --external             Install skills discovered under external/.
  --skill NAME           Install one skill by directory name. Repeatable.
  --global AGENT         shared, codex, claude, opencode, pi, or all.
  --project PATH         Install to PATH/.agents/skills.
  --target PATH          Install to an explicit skills directory.
  --dry-run              Print actions without creating links.
  --yes, -y              Skip confirmation.
  --list                 Print discovered skills and exit.
  --installed            Show installed skills. Defaults to known global targets.
                         Combine with --global, --project, or --target.
  --help, -h             Show this help.

Running without options opens the Node TUI installer. Existing symlinks are
updated. Real files or directories are skipped.`;
}

function die(message) {
  console.error(`Error: ${message}`);
  process.exit(1);
}

function expandHomePath(value) {
  if (value === '~') {
    return homeDir;
  }

  if (value.startsWith('~/')) {
    return path.join(homeDir, value.slice(2));
  }

  return value;
}

function expandPath(value) {
  return path.resolve(expandHomePath(value));
}

function looksLikeRepositoryRoot(dir) {
  try {
    const entries = fs.readdirSync(dir, {withFileTypes: true});
    return (
      entries.some((entry) => entry.isDirectory() && fs.existsSync(path.join(dir, entry.name, 'SKILL.md'))) ||
      fs.existsSync(path.join(dir, 'external'))
    );
  } catch {
    return false;
  }
}

function resolveRepoRoot() {
  if (process.env.YOOOOO_SKILLS_REPO) {
    return path.resolve(expandHomePath(process.env.YOOOOO_SKILLS_REPO));
  }

  const binaryDir = path.dirname(process.execPath);
  const candidates = [
    path.resolve(path.dirname(scriptPath), '..'),
    binaryDir,
    path.resolve(binaryDir, '..'),
    startDir,
  ];

  return candidates.find((candidate) => looksLikeRepositoryRoot(candidate)) || candidates[0];
}

function relPath(value) {
  const relative = path.relative(repoRoot, value);
  if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) {
    return value;
  }
  return relative;
}

function compactLogPath(value) {
  return value.split(repoRoot).join('.').split(homeDir).join('~');
}

function compactPath(value) {
  return value.split(homeDir).join('~');
}

function shortText(value, maxLength = 110) {
  if (!value) {
    return '';
  }
  return value.length > maxLength ? `${value.slice(0, maxLength - 3)}...` : value;
}

function terminalRows() {
  return Math.max(16, process.stdout.rows || 24);
}

function terminalColumns() {
  return Math.max(60, process.stdout.columns || 100);
}

function detailLineCount(detail) {
  if (!detail) {
    return 0;
  }

  const width = Math.max(20, terminalColumns() - 4);
  return detail
    .split('\n')
    .reduce((count, line) => count + Math.max(1, Math.ceil([...line].length / width)), 1);
}

function visibleListCount({detail, hasError}) {
  const reservedRows = 13 + detailLineCount(detail) + (hasError ? 1 : 0);
  return Math.max(4, terminalRows() - reservedRows);
}

function visibleRange(cursor, total, count) {
  const safeCount = Math.min(total, count);
  const half = Math.floor(safeCount / 2);
  const start = Math.min(Math.max(0, cursor - half), Math.max(0, total - safeCount));
  return {
    start,
    end: Math.min(total, start + safeCount),
  };
}

function hasSkillFile(dir) {
  try {
    return fs.statSync(path.join(dir, 'SKILL.md')).isFile();
  } catch {
    return false;
  }
}

function parseFrontmatterValue(value) {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1).replaceAll('\\"', '"').replaceAll("\\'", "'");
  }
  return trimmed;
}

function parseFrontmatterBlock(lines, startIndex, marker) {
  const values = [];
  let blockIndent = null;
  let index = startIndex + 1;

  for (; index < lines.length; index += 1) {
    const line = lines[index];
    if (/^[A-Za-z0-9_-]+:\s*/.test(line)) {
      break;
    }

    if (!line.trim()) {
      values.push('');
      continue;
    }

    const indent = line.match(/^(\s+)/)?.[1].length;
    if (!indent) {
      break;
    }

    blockIndent ??= indent;
    values.push(line.slice(Math.min(blockIndent, line.length)));
  }

  const text = marker.startsWith('|')
    ? values.join('\n').trim()
    : values.map((line) => line.trim()).filter(Boolean).join(' ');

  return {text, nextIndex: index - 1};
}

function readSkillMetadata(skillPath) {
  const skillMd = path.join(skillPath, 'SKILL.md');
  let content = '';
  try {
    content = fs.readFileSync(skillMd, 'utf8');
  } catch {
    return {};
  }

  if (!content.startsWith('---\n')) {
    return {};
  }

  const end = content.indexOf('\n---', 4);
  if (end === -1) {
    return {};
  }

  const metadata = {};
  const frontmatter = content.slice(4, end).split('\n');
  for (let index = 0; index < frontmatter.length; index += 1) {
    const line = frontmatter[index];
    const match = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!match) {
      continue;
    }
    const marker = match[2].trim();
    if (/^[>|][+-]?$/.test(marker)) {
      const block = parseFrontmatterBlock(frontmatter, index, marker);
      metadata[match[1]] = block.text;
      index = block.nextIndex;
    } else {
      metadata[match[1]] = parseFrontmatterValue(match[2]);
    }
  }

  return metadata;
}

function skillSource(skillPath, origin) {
  if (origin !== 'external') {
    return 'local';
  }

  const relative = path.relative(path.join(repoRoot, 'external'), skillPath);
  const parts = relative.split(path.sep).filter(Boolean);
  if (parts.length >= 2) {
    return `${parts[0]}/${parts[1]}`;
  }

  return 'external';
}

function buildSkill(skillPath, origin) {
  const metadata = readSkillMetadata(skillPath);
  return {
    name: path.basename(skillPath),
    path: skillPath,
    origin,
    source: skillSource(skillPath, origin),
    description: metadata.description || '',
  };
}

function discoverFirstPartySkills() {
  return fs
    .readdirSync(repoRoot, {withFileTypes: true})
    .filter((entry) => entry.isDirectory())
    .filter((entry) => !entry.name.startsWith('.') && entry.name !== 'external' && entry.name !== 'scripts')
    .map((entry) => path.join(repoRoot, entry.name))
    .filter(hasSkillFile)
    .sort()
    .map((skillPath) => buildSkill(skillPath, 'first-party'));
}

function walkSkillDirs(dir, maxDepth, depth = 0, found = []) {
  if (depth > maxDepth) {
    return found;
  }

  if (hasSkillFile(dir)) {
    found.push(dir);
  }

  let entries = [];
  try {
    entries = fs.readdirSync(dir, {withFileTypes: true});
  } catch {
    return found;
  }

  for (const entry of entries) {
    if (!entry.isDirectory() || entry.name.startsWith('.')) {
      continue;
    }
    walkSkillDirs(path.join(dir, entry.name), maxDepth, depth + 1, found);
  }

  return found;
}

function discoverExternalSkills() {
  const externalRoot = path.join(repoRoot, 'external');
  if (!fs.existsSync(externalRoot)) {
    return [];
  }

  return walkSkillDirs(externalRoot, 6)
    .sort()
    .map((skillPath) => buildSkill(skillPath, 'external'));
}

function discoverSkills() {
  return [...discoverFirstPartySkills(), ...discoverExternalSkills()];
}

function formatSkillList(skills) {
  return skills
    .map((skill, index) => {
      const number = String(index + 1).padStart(2, ' ');
      const summary = `${number}) ${skill.name.padEnd(34, ' ')} ${skill.origin.padEnd(12, ' ')} ${skill.source.padEnd(22, ' ')} ${relPath(skill.path)}`;
      return skill.description ? `${summary}\n    ${skill.description}` : summary;
    })
    .join('\n');
}

function targetDirForGlobal(key) {
  const target = knownGlobalTargets.find((item) => item.key === key);
  if (!target) {
    throw new Error(`unknown global target: ${key}`);
  }
  return target.dir;
}

function addUniqueTarget(targets, target) {
  const expanded = expandPath(target);
  if (!targets.includes(expanded)) {
    targets.push(expanded);
  }
}

function addGlobalTarget(targets, key) {
  if (key === 'all') {
    for (const target of knownGlobalTargets) {
      addUniqueTarget(targets, target.dir);
    }
    return;
  }

  addUniqueTarget(targets, targetDirForGlobal(key));
}

function defaultInstalledTargets() {
  return knownGlobalTargets.map((target) => target.dir);
}

function resolveTargetKeys(keys, projectRootValue, customTargetValue) {
  const resolved = [];
  for (const key of keys) {
    if (key === 'project') {
      addUniqueTarget(resolved, path.join(expandPath(projectRootValue || startDir), '.agents', 'skills'));
    } else if (key === 'custom') {
      if (customTargetValue) {
        addUniqueTarget(resolved, customTargetValue);
      }
    } else {
      addGlobalTarget(resolved, key);
    }
  }
  return resolved;
}

function inspectInstalledTarget(target) {
  let entries = [];
  try {
    entries = fs.readdirSync(target, {withFileTypes: true});
  } catch (error) {
    if (error.code === 'ENOENT') {
      return {target, exists: false, entries: []};
    }
    throw error;
  }

  const installed = [];
  for (const entry of entries) {
    const entryPath = path.join(target, entry.name);
    let stat = null;
    try {
      stat = fs.lstatSync(entryPath);
    } catch {
      continue;
    }

    if (stat.isSymbolicLink()) {
      const linkTarget = fs.readlinkSync(entryPath);
      const source = path.resolve(path.dirname(entryPath), linkTarget);
      const sourceExists = fs.existsSync(source);
      const metadata = sourceExists && hasSkillFile(source) ? readSkillMetadata(source) : {};
      installed.push({
        name: entry.name,
        kind: sourceExists ? 'symlink' : 'broken symlink',
        source,
        description: metadata.description || '',
      });
      continue;
    }

    if (stat.isDirectory() && hasSkillFile(entryPath)) {
      const metadata = readSkillMetadata(entryPath);
      installed.push({
        name: entry.name,
        kind: 'directory',
        source: entryPath,
        description: metadata.description || '',
      });
    }
  }

  installed.sort((left, right) => left.name.localeCompare(right.name));
  return {target, exists: true, entries: installed};
}

function inspectInstalledTargets(targets) {
  return targets.map((target) => inspectInstalledTarget(target));
}

function formatInstalledReport(reports) {
  return reports
    .map((report) => {
      const lines = [`${compactPath(report.target)}`];
      if (!report.exists) {
        lines.push('  not found');
        return lines.join('\n');
      }

      if (report.entries.length === 0) {
        lines.push('  no installed skills found');
        return lines.join('\n');
      }

      for (const entry of report.entries) {
        lines.push(`  - ${entry.name.padEnd(34, ' ')} ${entry.kind.padEnd(14, ' ')} ${compactPath(entry.source)}`);
        if (entry.description) {
          lines.push(`    ${shortText(entry.description, 160)}`);
        }
      }
      return lines.join('\n');
    })
    .join('\n\n');
}

function selectSkillByName(skills, selectedIndexes, name) {
  const matches = skills
    .map((skill, index) => ({skill, index}))
    .filter((entry) => entry.skill.name === name);

  if (matches.length === 0) {
    throw new Error(`skill not found: ${name}`);
  }

  if (matches.length > 1) {
    throw new Error(`multiple skills named '${name}'; use the TUI to choose a specific source`);
  }

  selectedIndexes.add(matches[0].index);
}

function resolveCliSelection(skills, options) {
  const selectedIndexes = new Set();

  if (options.all) {
    skills.forEach((_, index) => selectedIndexes.add(index));
  }

  if (options.firstParty) {
    skills.forEach((skill, index) => {
      if (skill.origin === 'first-party') {
        selectedIndexes.add(index);
      }
    });
  }

  if (options.external) {
    skills.forEach((skill, index) => {
      if (skill.origin === 'external') {
        selectedIndexes.add(index);
      }
    });
  }

  for (const skillName of options.skills) {
    selectSkillByName(skills, selectedIndexes, skillName);
  }

  const selected = [...selectedIndexes].sort((left, right) => left - right);
  if (selected.length === 0) {
    throw new Error('no skills selected');
  }

  return selected;
}

function parseArgs(argv) {
  const options = {
    all: false,
    firstParty: false,
    external: false,
    skills: [],
    targets: [],
    dryRun: false,
    yes: false,
    list: false,
    installed: false,
    help: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === '--all') {
      options.all = true;
    } else if (arg === '--first-party') {
      options.firstParty = true;
    } else if (arg === '--external') {
      options.external = true;
    } else if (arg === '--skill') {
      index += 1;
      if (!argv[index]) {
        throw new Error('--skill requires a value');
      }
      options.skills.push(argv[index]);
    } else if (arg.startsWith('--skill=')) {
      options.skills.push(arg.slice('--skill='.length));
    } else if (arg === '--global') {
      index += 1;
      if (!argv[index]) {
        throw new Error('--global requires a value');
      }
      addGlobalTarget(options.targets, argv[index]);
    } else if (arg.startsWith('--global=')) {
      addGlobalTarget(options.targets, arg.slice('--global='.length));
    } else if (arg === '--project') {
      index += 1;
      if (!argv[index]) {
        throw new Error('--project requires a value');
      }
      addUniqueTarget(options.targets, path.join(expandPath(argv[index]), '.agents', 'skills'));
    } else if (arg.startsWith('--project=')) {
      addUniqueTarget(options.targets, path.join(expandPath(arg.slice('--project='.length)), '.agents', 'skills'));
    } else if (arg === '--target') {
      index += 1;
      if (!argv[index]) {
        throw new Error('--target requires a value');
      }
      addUniqueTarget(options.targets, argv[index]);
    } else if (arg.startsWith('--target=')) {
      addUniqueTarget(options.targets, arg.slice('--target='.length));
    } else if (arg === '--dry-run') {
      options.dryRun = true;
    } else if (arg === '--yes' || arg === '-y') {
      options.yes = true;
    } else if (arg === '--list') {
      options.list = true;
    } else if (arg === '--installed' || arg === '--list-installed') {
      options.installed = true;
    } else if (arg === '--help' || arg === '-h') {
      options.help = true;
    } else {
      throw new Error(`unknown option: ${arg}`);
    }
  }

  return options;
}

function linkType() {
  return process.platform === 'win32' ? 'junction' : 'dir';
}

function installLinks({skills, selectedIndexes, targets, dryRun}) {
  const logs = [];
  const counts = {
    linked: 0,
    updated: 0,
    already: 0,
    conflicts: 0,
  };

  if (selectedIndexes.length === 0) {
    throw new Error('no skills selected');
  }

  if (targets.length === 0) {
    throw new Error('no targets selected');
  }

  for (const target of targets) {
    for (const index of selectedIndexes) {
      const skill = skills[index];
      const destination = path.join(target, skill.name);

      if (dryRun) {
        logs.push(`[dry-run] mkdir -p ${target}`);
        logs.push(`[dry-run] ln -s ${skill.path} ${destination}`);
        continue;
      }

      fs.mkdirSync(target, {recursive: true});

      let existing = null;
      try {
        existing = fs.lstatSync(destination);
      } catch (error) {
        if (error.code !== 'ENOENT') {
          throw error;
        }
      }

      if (existing?.isSymbolicLink()) {
        const current = fs.readlinkSync(destination);
        const resolvedCurrent = path.resolve(path.dirname(destination), current);
        if (resolvedCurrent === skill.path) {
          logs.push(`already linked: ${destination} -> ${skill.path}`);
          counts.already += 1;
          continue;
        }

        fs.unlinkSync(destination);
        fs.symlinkSync(skill.path, destination, linkType());
        logs.push(`updated link:  ${destination} -> ${skill.path}`);
        counts.updated += 1;
        continue;
      }

      if (existing) {
        logs.push(`skipped:       ${destination} already exists and is not a symlink`);
        counts.conflicts += 1;
        continue;
      }

      fs.symlinkSync(skill.path, destination, linkType());
      logs.push(`linked:        ${destination} -> ${skill.path}`);
      counts.linked += 1;
    }
  }

  return {counts, logs};
}

async function promptConfirm(message) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  const answer = await rl.question(`${message} [y/N] `);
  rl.close();
  return ['y', 'yes'].includes(answer.trim().toLowerCase());
}

function printSummary({skills, selectedIndexes, targets}) {
  console.log('\nSelected skills:');
  for (const index of selectedIndexes) {
    const skill = skills[index];
    console.log(`  - ${skill.name.padEnd(34, ' ')} ${relPath(skill.path)}`);
  }

  console.log('\nTarget directories:');
  for (const target of targets) {
    console.log(`  - ${target}`);
  }
  console.log('');
}

async function runCli(argv) {
  const skills = discoverSkills();
  const options = parseArgs(argv);

  if (options.help) {
    console.log(usage());
    return;
  }

  if (options.list) {
    console.log(formatSkillList(skills));
    return;
  }

  if (options.installed) {
    const targets = options.targets.length > 0 ? options.targets : defaultInstalledTargets();
    console.log(formatInstalledReport(inspectInstalledTargets(targets)));
    return;
  }

  const selectedIndexes = resolveCliSelection(skills, options);
  if (options.targets.length === 0) {
    throw new Error('no targets selected');
  }

  if (!options.yes) {
    printSummary({skills, selectedIndexes, targets: options.targets});
    const confirmed = await promptConfirm(options.dryRun ? 'Run dry-run now?' : 'Create/update these symlinks?');
    if (!confirmed) {
      throw new Error('cancelled');
    }
  }

  const result = installLinks({
    skills,
    selectedIndexes,
    targets: options.targets,
    dryRun: options.dryRun,
  });

  for (const log of result.logs) {
    console.log(log);
  }
  console.log('');

  if (options.dryRun) {
    console.log('Dry-run complete.');
    return;
  }

  const {linked, updated, already, conflicts} = result.counts;
  console.log(`Done. linked=${linked} updated=${updated} already=${already} conflicts=${conflicts}`);

  if (conflicts > 0) {
    process.exitCode = 1;
  }
}

function optionLabel(label, detail) {
  return detail ? `${label.padEnd(21, ' ')} ${detail}` : label;
}

function Header({skills}) {
  return h(
    Box,
    {borderStyle: 'round', borderColor: 'cyan', paddingX: 2, paddingY: 1, marginBottom: 1, flexDirection: 'column'},
    h(Text, {bold: true, color: 'cyan'}, 'yooooo-skills installer'),
    h(Text, null, `Repository: ${repoRoot}`),
    h(Text, {dimColor: true}, `Discovered skills: ${skills.length}`),
  );
}

const footerKeyPattern = /\b(?:Ctrl\+C|Enter|Space|PageUp|PageDown|arrows|a|b|n|q|r)\b/g;

function Footer({text = 'Use arrows to move, Enter to continue, Ctrl+C to quit.'}) {
  const parts = [];
  let cursor = 0;
  let match;

  while ((match = footerKeyPattern.exec(text)) !== null) {
    if (match.index > cursor) {
      parts.push({kind: 'text', value: text.slice(cursor, match.index)});
    }
    parts.push({kind: 'key', value: match[0]});
    cursor = match.index + match[0].length;
  }

  if (cursor < text.length) {
    parts.push({kind: 'text', value: text.slice(cursor)});
  }

  return h(
    Box,
    {marginTop: 1},
    h(
      Text,
      null,
      parts.map((part, index) =>
        part.kind === 'key'
          ? h(Text, {key: `${index}-${part.value}`, color: 'cyan', bold: true}, part.value)
          : h(Text, {key: `${index}-${part.value}`, dimColor: true}, part.value),
      ),
    ),
  );
}

function Page({skills, title, children, footer}) {
  return h(
    Box,
    {flexDirection: 'column'},
    h(Header, {skills}),
    h(Text, {bold: true}, title),
    h(Box, {height: 1}),
    children,
    h(Footer, {text: footer}),
  );
}

function SingleSelect({items, defaultIndex = 0, onSubmit}) {
  const [cursor, setCursor] = useState(defaultIndex);

  useInput((input, key) => {
    if (key.upArrow) {
      setCursor((value) => Math.max(0, value - 1));
    } else if (key.downArrow) {
      setCursor((value) => Math.min(items.length - 1, value + 1));
    } else if (key.return) {
      onSubmit(items[cursor].value);
    } else if (/^[1-9]$/.test(input)) {
      const next = Number(input) - 1;
      if (next >= 0 && next < items.length) {
        setCursor(next);
      }
    }
  });

  return h(
    Box,
    {flexDirection: 'column'},
    items.map((item, index) =>
      h(
        Text,
        {key: item.value, color: index === cursor ? 'cyan' : undefined},
        `${index === cursor ? '>' : ' '} ${index + 1}. ${item.label}`,
      ),
    ),
  );
}

function MultiSelect({items, onSubmit, onBack}) {
  const [cursor, setCursor] = useState(0);
  const [selected, setSelected] = useState(() => new Set());
  const [error, setError] = useState('');
  const currentItem = items[cursor];
  const itemCount = visibleListCount({detail: currentItem?.detail, hasError: Boolean(error)});
  const range = visibleRange(cursor, items.length, itemCount);
  const visibleItems = items.slice(range.start, range.end);
  const isClipped = range.start > 0 || range.end < items.length;

  useInput((input, key) => {
    if (input === 'b' && onBack) {
      onBack();
    } else if (key.upArrow) {
      setCursor((value) => Math.max(0, value - 1));
    } else if (key.downArrow) {
      setCursor((value) => Math.min(items.length - 1, value + 1));
    } else if (key.pageUp) {
      setCursor((value) => Math.max(0, value - itemCount));
    } else if (key.pageDown) {
      setCursor((value) => Math.min(items.length - 1, value + itemCount));
    } else if (input === ' ') {
      setSelected((current) => {
        const next = new Set(current);
        const value = items[cursor].value;
        if (next.has(value)) {
          next.delete(value);
        } else {
          next.add(value);
        }
        return next;
      });
      setError('');
    } else if (input === 'a') {
      setSelected(new Set(items.map((item) => item.value)));
      setError('');
    } else if (input === 'n') {
      setSelected(new Set());
    } else if (key.return) {
      if (selected.size === 0) {
        setError('Select at least one item.');
        return;
      }
      onSubmit([...selected]);
    }
  });

  return h(
    Box,
    {flexDirection: 'column'},
    isClipped
      ? h(
          Text,
          {dimColor: true},
          `Showing ${range.start + 1}-${range.end} of ${items.length}`,
        )
      : null,
    visibleItems.map((item, visibleIndex) => {
      const index = range.start + visibleIndex;
      const checked = selected.has(item.value) ? '[x]' : '[ ]';
      return h(
        Text,
        {key: item.value, color: index === cursor ? 'cyan' : undefined},
        `${index === cursor ? '>' : ' '} ${checked} ${item.label}`,
      );
    }),
    currentItem?.detail
      ? h(
          Box,
          {marginTop: 1, flexDirection: 'column'},
          h(Text, {bold: true}, currentItem.detailTitle || 'Details'),
          ...currentItem.detail.split('\n').map((line, index) => h(Text, {key: `${currentItem.value}-${index}`, dimColor: true}, line)),
        )
      : null,
    error ? h(Box, {marginTop: 1}, h(Text, {color: 'red'}, error)) : null,
  );
}

function TextInput({placeholder, onSubmit, onBack}) {
  const [value, setValue] = useState('');

  useInput((input, key) => {
    if (input === 'b' && !value && onBack) {
      onBack();
    } else if (key.return) {
      onSubmit(value);
    } else if (key.backspace || key.delete) {
      setValue((current) => current.slice(0, -1));
    } else if (key.escape) {
      if (!value && onBack) {
        onBack();
      } else {
        setValue('');
      }
    } else if (input && !key.ctrl && !key.meta) {
      setValue((current) => `${current}${input}`);
    }
  });

  return h(
    Box,
    {flexDirection: 'column'},
    h(
      Text,
      null,
      '> ',
      h(Text, {dimColor: !value}, value || placeholder),
    ),
  );
}

function Summary({skills, selectedIndexes, targets, dryRun}) {
  return h(
    Box,
    {flexDirection: 'column'},
    h(Text, {bold: true}, 'Selected skills'),
    ...selectedIndexes.map((index) => {
      const skill = skills[index];
      return h(Text, {key: skill.path}, `  - ${skill.name.padEnd(34, ' ')} ${relPath(skill.path)}`);
    }),
    h(Box, {height: 1}),
    h(Text, {bold: true}, 'Target directories'),
    ...targets.map((target) => h(Text, {key: target}, `  - ${target}`)),
    h(Box, {height: 1}),
    h(Text, {bold: true}, `Mode: ${dryRun ? 'Dry-run only' : 'Install symlinks'}`),
  );
}

function Results({result, dryRun, onBack, onInstall}) {
  const {exit} = useApp();

  useInput((input, key) => {
    if (dryRun && input === 'b') {
      onBack();
    } else if (dryRun && input === 'r') {
      onInstall();
    } else if (key.return || input === 'q') {
      exit();
    }
  });

  return h(
    Box,
    {flexDirection: 'column'},
    h(Text, {bold: true, color: result.counts.conflicts > 0 ? 'yellow' : 'green'}, dryRun ? 'Dry-run complete.' : 'Install complete.'),
    h(Box, {height: 1}),
    ...result.logs.map((log, index) => h(Text, {key: `${index}-${log}`}, compactLogPath(log))),
    h(Box, {height: 1}),
    dryRun
      ? null
      : h(
          Text,
          null,
          `linked=${result.counts.linked} updated=${result.counts.updated} already=${result.counts.already} conflicts=${result.counts.conflicts}`,
        ),
    h(Footer, {text: dryRun ? 'Press b to return, r to install now, Enter or q to exit.' : 'Press Enter or q to exit.'}),
  );
}

function InstalledResults({reports, onBack}) {
  const {exit} = useApp();

  useInput((input, key) => {
    if (input === 'b') {
      onBack();
    } else if (key.return || input === 'q') {
      exit();
    }
  });

  return h(
    Box,
    {flexDirection: 'column'},
    h(Text, {bold: true, color: 'cyan'}, 'Installed skills'),
    h(Box, {height: 1}),
    ...reports.flatMap((report) => {
      const lines = [
        h(Text, {key: `${report.target}-header`, bold: true}, compactPath(report.target)),
      ];

      if (!report.exists) {
        lines.push(h(Text, {key: `${report.target}-missing`, dimColor: true}, '  not found'));
        lines.push(h(Box, {key: `${report.target}-gap`, height: 1}));
        return lines;
      }

      if (report.entries.length === 0) {
        lines.push(h(Text, {key: `${report.target}-empty`, dimColor: true}, '  no installed skills found'));
        lines.push(h(Box, {key: `${report.target}-gap`, height: 1}));
        return lines;
      }

      for (const entry of report.entries) {
        lines.push(
          h(
            Text,
            {key: `${report.target}-${entry.name}`},
            `  - ${entry.name.padEnd(28, ' ')} ${entry.kind.padEnd(14, ' ')} ${compactPath(entry.source)}`,
          ),
        );
        if (entry.description) {
          lines.push(h(Text, {key: `${report.target}-${entry.name}-desc`, dimColor: true}, `    ${shortText(entry.description, 120)}`));
        }
      }

      lines.push(h(Box, {key: `${report.target}-gap`, height: 1}));
      return lines;
    }),
    h(Footer, {text: 'Press b to choose another location, Enter or q to exit.'}),
  );
}

function InstallerApp({skills}) {
  const {exit} = useApp();
  const [step, setStep] = useState('home');
  const [selectedIndexes, setSelectedIndexes] = useState([]);
  const [targetKeys, setTargetKeys] = useState([]);
  const [projectRoot, setProjectRoot] = useState('');
  const [customTarget, setCustomTarget] = useState('');
  const [dryRun, setDryRun] = useState(true);
  const [result, setResult] = useState(null);
  const [installedReports, setInstalledReports] = useState([]);
  const [error, setError] = useState('');

  const skillItems = useMemo(
    () =>
      skills.map((skill, index) => ({
        value: String(index),
        label: `${skill.name.padEnd(34, ' ')} ${skill.origin.padEnd(12, ' ')} ${skill.source}`,
        detailTitle: skill.name,
        detail: `Path: ${relPath(skill.path)}\nDescription: ${skill.description || 'No description in SKILL.md.'}`,
      })),
    [skills],
  );

  const targetItems = useMemo(
    () => [
      ...knownGlobalTargets.map((target) => ({
        value: target.key,
        label: optionLabel(target.name, target.dir),
      })),
      {value: 'all', label: 'All global targets'},
      {value: 'project', label: 'Project-local         <project>/.agents/skills'},
      {value: 'custom', label: 'Custom target directory'},
    ],
    [],
  );

  const targets = useMemo(() => {
    return resolveTargetKeys(targetKeys, projectRoot, customTarget);
  }, [customTarget, projectRoot, targetKeys]);

  const scanInstalledTargets = (keys, nextProjectRoot = projectRoot, nextCustomTarget = customTarget) => {
    const resolved = keys.length > 0 ? resolveTargetKeys(keys, nextProjectRoot, nextCustomTarget) : defaultInstalledTargets();
    setInstalledReports(inspectInstalledTargets(resolved));
    setStep('installedResults');
  };

  if (step === 'home') {
    return h(
      Page,
      {skills, title: 'What do you want to do?'},
      h(SingleSelect, {
        key: 'home-action-select',
        items: [
          {value: 'install', label: 'Install skills'},
          {value: 'installed', label: 'View installed skills'},
        ],
        onSubmit: (value) => {
          setError('');
          setTargetKeys([]);
          setProjectRoot('');
          setCustomTarget('');
          if (value === 'install') {
            setStep('scope');
          } else {
            setStep('installedTargets');
          }
        },
      }),
    );
  }

  if (skills.length === 0 && !step.startsWith('installed')) {
    return h(Page, {skills, title: 'No skills found'}, h(Text, {color: 'red'}, 'No SKILL.md files were discovered.'), 'Press Ctrl+C to exit.');
  }

  if (step === 'scope') {
    return h(
      Page,
      {skills, title: 'Install which skills?'},
      h(SingleSelect, {
        key: 'install-scope-select',
        items: [
          {value: 'all', label: 'All discovered skills'},
          {value: 'first-party', label: 'First-party skills only'},
          {value: 'external', label: 'External skills only'},
          {value: 'specific', label: 'Choose specific skills'},
        ],
        onSubmit: (value) => {
          if (value === 'all') {
            setSelectedIndexes(skills.map((_, index) => index));
            setStep('targets');
          } else if (value === 'first-party') {
            setSelectedIndexes(skills.map((skill, index) => (skill.origin === 'first-party' ? index : -1)).filter((index) => index >= 0));
            setStep('targets');
          } else if (value === 'external') {
            setSelectedIndexes(skills.map((skill, index) => (skill.origin === 'external' ? index : -1)).filter((index) => index >= 0));
            setStep('targets');
          } else {
            setStep('skills');
          }
        },
      }),
    );
  }

  if (step === 'skills') {
    return h(
      Page,
      {skills, title: 'Choose specific skills', footer: 'Space toggles, a all, n none, PageUp/PageDown jumps, Enter continues.'},
      h(MultiSelect, {
        key: 'skill-select',
        items: skillItems,
        onSubmit: (values) => {
          setSelectedIndexes(values.map((value) => Number(value)).sort((left, right) => left - right));
          setStep('targets');
        },
      }),
    );
  }

  if (step === 'installedTargets') {
    return h(
      Page,
      {skills, title: 'View installed skills where?', footer: 'Space toggles, a all, n none, PageUp/PageDown jumps, b back, Enter continues.'},
      h(MultiSelect, {
        key: 'installed-target-select',
        items: targetItems,
        onBack: () => {
          setTargetKeys([]);
          setStep('home');
        },
        onSubmit: (values) => {
          setTargetKeys(values);
          if (values.includes('project')) {
            setStep('installedProject');
          } else if (values.includes('custom')) {
            setStep('installedCustom');
          } else {
            scanInstalledTargets(values);
          }
        },
      }),
    );
  }

  if (step === 'installedProject') {
    return h(
      Page,
      {skills, title: 'Project root', footer: 'Press b to go back, Enter to accept the current value.'},
      h(TextInput, {
        placeholder: startDir,
        onBack: () => {
          setStep('installedTargets');
        },
        onSubmit: (value) => {
          const nextProjectRoot = value || startDir;
          setProjectRoot(nextProjectRoot);
          if (targetKeys.includes('custom')) {
            setStep('installedCustom');
          } else {
            scanInstalledTargets(targetKeys, nextProjectRoot, customTarget);
          }
        },
      }),
    );
  }

  if (step === 'installedCustom') {
    return h(
      Page,
      {skills, title: 'Custom target directory', footer: 'Press b to go back, Enter to continue.'},
      h(TextInput, {
        placeholder: '/path/to/skills',
        onBack: () => {
          setError('');
          setStep(targetKeys.includes('project') ? 'installedProject' : 'installedTargets');
        },
        onSubmit: (value) => {
          if (!value.trim()) {
            setError('Custom target cannot be empty.');
            return;
          }
          const nextCustomTarget = value.trim();
          setError('');
          setCustomTarget(nextCustomTarget);
          scanInstalledTargets(targetKeys, projectRoot, nextCustomTarget);
        },
      }),
      error ? h(Box, {marginTop: 1}, h(Text, {color: 'red'}, error)) : null,
    );
  }

  if (step === 'installedResults') {
    return h(InstalledResults, {
      reports: installedReports,
      onBack: () => {
        setInstalledReports([]);
        setTargetKeys([]);
        setStep('installedTargets');
      },
    });
  }

  if (step === 'targets') {
    return h(
      Page,
      {skills, title: 'Install where?', footer: 'Space toggles, a all, n none, PageUp/PageDown jumps, b back, Enter continues.'},
      h(MultiSelect, {
        key: 'install-target-select',
        items: targetItems,
        onBack: () => {
          setTargetKeys([]);
          setStep('scope');
        },
        onSubmit: (values) => {
          setTargetKeys(values);
          if (values.includes('project')) {
            setStep('project');
          } else if (values.includes('custom')) {
            setStep('custom');
          } else {
            setStep('mode');
          }
        },
      }),
    );
  }

  if (step === 'project') {
    return h(
      Page,
      {skills, title: 'Project root', footer: 'Press b to go back, Enter to accept the current value.'},
      h(TextInput, {
        placeholder: startDir,
        onBack: () => {
          setStep('targets');
        },
        onSubmit: (value) => {
          setProjectRoot(value || startDir);
          setStep(targetKeys.includes('custom') ? 'custom' : 'mode');
        },
      }),
    );
  }

  if (step === 'custom') {
    return h(
      Page,
      {skills, title: 'Custom target directory', footer: 'Press b to go back, Enter to continue.'},
      h(TextInput, {
        placeholder: '/path/to/skills',
        onBack: () => {
          setError('');
          setStep(targetKeys.includes('project') ? 'project' : 'targets');
        },
        onSubmit: (value) => {
          if (!value.trim()) {
            setError('Custom target cannot be empty.');
            return;
          }
          setError('');
          setCustomTarget(value.trim());
          setStep('mode');
        },
      }),
      error ? h(Box, {marginTop: 1}, h(Text, {color: 'red'}, error)) : null,
    );
  }

  if (step === 'mode') {
    return h(
      Page,
      {skills, title: 'Run mode'},
      h(SingleSelect, {
        key: 'run-mode-select',
        items: [
          {value: 'dry-run', label: 'Dry-run only'},
          {value: 'install', label: 'Install symlinks'},
        ],
        onSubmit: (value) => {
          setDryRun(value === 'dry-run');
          setStep('confirm');
        },
      }),
    );
  }

  if (step === 'confirm') {
    return h(
      Page,
      {skills, title: dryRun ? 'Review dry-run' : 'Review install'},
      h(Summary, {skills, selectedIndexes, targets, dryRun}),
      targets.length === 0 ? h(Box, {marginTop: 1}, h(Text, {color: 'red'}, 'No target directories selected.')) : null,
      h(Box, {height: 1}),
      h(SingleSelect, {
        key: 'confirm-select',
        items: [
          {value: 'yes', label: dryRun ? 'Run dry-run now' : 'Create/update symlinks'},
          {value: 'no', label: 'Cancel'},
        ],
        onSubmit: (value) => {
          if (value !== 'yes') {
            exit();
            return;
          }

          try {
            const nextResult = installLinks({skills, selectedIndexes, targets, dryRun});
            setResult(nextResult);
            setStep('results');
          } catch (nextError) {
            setError(nextError.message);
            setStep('error');
          }
        },
      }),
    );
  }

  if (step === 'error') {
    return h(
      Box,
      {flexDirection: 'column'},
      h(Text, {bold: true, color: 'red'}, 'Install failed'),
      h(Text, null, error),
      h(Footer, {text: 'Press Ctrl+C to exit.'}),
    );
  }

  return h(Results, {
    result,
    dryRun,
    onBack: () => {
      setResult(null);
      setStep('confirm');
    },
    onInstall: () => {
      try {
        setDryRun(false);
        const nextResult = installLinks({skills, selectedIndexes, targets, dryRun: false});
        setResult(nextResult);
        setStep('results');
      } catch (nextError) {
        setError(nextError.message);
        setStep('error');
      }
    },
  });
}

async function main() {
  try {
    const argv = process.argv.slice(2);
    if (argv.length > 0) {
      await runCli(argv);
      return;
    }

    if (!process.stdin.isTTY || !process.stdout.isTTY) {
      console.log(usage());
      process.exit(1);
    }

    const skills = discoverSkills();
    render(h(InstallerApp, {skills}));
  } catch (error) {
    die(error.message);
  }
}

await main();
