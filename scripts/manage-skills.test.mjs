import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import test from 'node:test';

const managerPath = fileURLToPath(new URL('./manage-skills.mjs', import.meta.url));
const legacyInstallerPath = fileURLToPath(new URL('./install-skills.mjs', import.meta.url));
const repoRoot = path.resolve(path.dirname(managerPath), '..');
const skillName = 'yooooo-git-post-merge-cleanup';
const skillPath = path.join(repoRoot, skillName);

function runManager(args) {
  return spawnSync(process.execPath, [managerPath, ...args], {
    cwd: repoRoot,
    encoding: 'utf8',
    env: {...process.env, YOOOOO_SKILLS_REPO: repoRoot},
  });
}

function temporaryRoot() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'yooooo-skills-manager-'));
}

test('CLI installs, previews uninstall, and uninstalls a managed skill symlink', () => {
  const root = temporaryRoot();
  const target = path.join(root, 'skills');
  const destination = path.join(target, skillName);

  try {
    const install = runManager(['--skill', skillName, '--target', target, '--yes']);
    assert.equal(install.status, 0, install.stderr);
    assert.equal(fs.lstatSync(destination).isSymbolicLink(), true);
    assert.equal(path.resolve(target, fs.readlinkSync(destination)), skillPath);

    const preview = runManager(['--uninstall', '--skill', skillName, '--target', target, '--dry-run', '--yes']);
    assert.equal(preview.status, 0, preview.stderr);
    assert.match(preview.stdout, /\[dry-run] unlink /);
    assert.equal(fs.lstatSync(destination).isSymbolicLink(), true);

    const uninstall = runManager(['--uninstall', '--skill', skillName, '--target', target, '--yes']);
    assert.equal(uninstall.status, 0, uninstall.stderr);
    assert.match(uninstall.stdout, /unlinked=1/);
    assert.equal(fs.existsSync(destination), false);

    const legacyDestination = path.join(target, 'LegacySkillName');
    fs.symlinkSync(skillPath, legacyDestination, process.platform === 'win32' ? 'junction' : 'dir');
    const uninstallLegacyName = runManager(['--uninstall', '--skill', skillName, '--target', target, '--yes']);
    assert.equal(uninstallLegacyName.status, 0, uninstallLegacyName.stderr);
    assert.match(uninstallLegacyName.stdout, /unlinked=1/);
    assert.equal(fs.existsSync(legacyDestination), false);
  } finally {
    fs.rmSync(root, {recursive: true, force: true});
  }
});

test('legacy installer entry delegates to the skill manager', () => {
  const result = spawnSync(process.execPath, [legacyInstallerPath, '--help'], {
    cwd: repoRoot,
    encoding: 'utf8',
    env: {...process.env, YOOOOO_SKILLS_REPO: repoRoot},
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Manage Agent Skills/);
  assert.match(result.stdout, /--uninstall/);
});

test('CLI uninstall preserves links and directories not managed by this repository', () => {
  const root = temporaryRoot();
  const target = path.join(root, 'skills');
  const destination = path.join(target, skillName);
  const foreignSource = path.join(root, 'foreign-skill');

  try {
    fs.mkdirSync(target, {recursive: true});
    fs.mkdirSync(foreignSource);
    fs.symlinkSync(foreignSource, destination, process.platform === 'win32' ? 'junction' : 'dir');

    const foreignLink = runManager(['--uninstall', '--skill', skillName, '--target', target, '--yes']);
    assert.equal(foreignLink.status, 1);
    assert.equal(fs.lstatSync(destination).isSymbolicLink(), true);
    assert.equal(path.resolve(target, fs.readlinkSync(destination)), foreignSource);

    fs.unlinkSync(destination);
    fs.mkdirSync(destination);

    const realDirectory = runManager(['--uninstall', '--skill', skillName, '--target', target, '--yes']);
    assert.equal(realDirectory.status, 1);
    assert.equal(fs.statSync(destination).isDirectory(), true);
  } finally {
    fs.rmSync(root, {recursive: true, force: true});
  }
});
