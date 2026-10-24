import { spawn } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { existsSync, mkdirSync, openSync, closeSync, readFileSync, writeFileSync } from 'node:fs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const output = join(root, 'Verification', 'mvp');
mkdirSync(output, { recursive: true });
const env = { ...process.env, PATH: dirname(process.execPath) + ':' + process.env.PATH,
  npm_config_cache: process.env.npm_config_cache || join(tmpdir(), 'sudokuly-npm-cache'), npm_config_loglevel: 'error' };
function shellQuote(value) { return "'" + value.replaceAll("'", "'\\''") + "'"; }
async function command(executable, args, log, inherited = false) {
  const fd = inherited ? null : openSync(log, 'w');
  return await new Promise((resolveExit, reject) => {
    const child = spawn(executable, args, { cwd: root, env, stdio: inherited ? 'inherit' : ['ignore', fd, fd] });
    child.on('error', error => { if (fd !== null) closeSync(fd); reject(error); });
    child.on('close', code => { if (fd !== null) closeSync(fd); resolveExit(code ?? 1); });
  });
}
async function capture(executable, args) {
  return await new Promise((resolveOutput, reject) => {
    const child = spawn(executable, args, { cwd: root, env, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = '';
    child.stdout.on('data', data => { stdout += data; }); child.stderr.on('data', data => { stderr += data; });
    child.on('error', reject);
    child.on('close', code => code === 0 ? resolveOutput(stdout) : reject(new Error(stderr || `${executable} failed`)));
  });
}

if (!process.argv.includes('--inside-emulators')) {
  if (Number(process.versions.node.split('.')[0]) < 22) throw new Error('Use Node.js 22 or later.');
  if (!existsSync(join(root, 'Tests/Firebase/node_modules/@firebase/rules-unit-testing/package.json'))) {
    const installed = await command('npm', ['ci', '--prefix', 'Tests/Firebase', '--ignore-scripts', '--no-audit', '--no-fund'],
      join(output, 'dependencies.log'));
    if (installed !== 0) throw new Error('Test dependency installation failed; see dependencies.log.');
  }
  // CLI owns the emulator lifecycle and stops it on success, failure or interruption.
  const inside = [process.execPath, fileURLToPath(import.meta.url), '--inside-emulators'].map(shellQuote).join(' ');
  process.exitCode = await command('npx', ['-y', 'firebase-tools@latest', 'emulators:exec', '--only', 'auth,firestore',
    '--project', 'demo-sudokuly', '--config', 'firebase.emulators.json', inside], null, true);
} else {
  const resultRoot = join(tmpdir(), 'sudokuly-mvp-' + Date.now());
  mkdirSync(resultRoot, { recursive: true });
  const derived = env.SUDOKULY_TEST_DERIVED_DATA || join(tmpdir(), 'sudokuly-auth-derived');
  const available = JSON.parse(await capture('xcrun', ['simctl', 'list', 'devices', 'available', '--json']));
  const phones = Object.entries(available.devices).filter(([runtime]) => runtime.includes('iOS')).flatMap(([, devices]) => devices);
  const simulator = env.SUDOKULY_TEST_SIMULATOR_UDID || phones.find(d => d.name === 'Sudokuly QA')?.udid
    || phones.find(d => d.name.includes('iPhone 17e'))?.udid || phones.find(d => d.name.includes('iPhone'))?.udid;
  if (!simulator) throw new Error('No available iPhone simulator.');
  const results = [];
  async function run(name, executable, args, file) {
    process.stdout.write(`Running ${name}…\n`);
    const exitCode = await command(executable, args, join(output, file));
    results.push({ name, exitCode, log: file });
    process.stdout.write(`${name}: ${exitCode === 0 ? 'PASS' : 'FAIL'}\n`);
  }
  await run('Core generator and state-machine tests', 'swift', ['test', '--scratch-path', join(resultRoot, 'core')], 'core-tests.log');
  // Rules tests clear the demo data; finish them before any iOS SDK session begins.
  await run('Firestore rules', 'npm', ['--prefix', 'Tests/Firebase', 'test'], 'rules-tests.log');
  const bundle = join(resultRoot, 'ios.xcresult');
  await run('Full iOS unit, SDK and UI suite', 'xcodebuild', ['-project', 'sudokuly.xcodeproj', '-scheme', 'Sudokuly Firebase Tests',
    '-destination', `platform=iOS Simulator,id=${simulator}`, '-derivedDataPath', derived, '-resultBundlePath', bundle,
    '-parallel-testing-enabled', 'NO', '-collect-test-diagnostics', 'never', 'CODE_SIGNING_ALLOWED=YES',
    'CODE_SIGN_IDENTITY=-', 'CODE_SIGNING_REQUIRED=YES', 'test'], 'ios-tests.log');
  let xcodeSummary = null;
  if (existsSync(bundle)) {
    try { xcodeSummary = JSON.parse(await capture('xcrun', ['xcresulttool', 'get', 'test-results', 'summary', '--path', bundle, '--compact'])); }
    catch (error) { xcodeSummary = { error: error.message }; }
  }
  await run('Release build', 'xcodebuild', ['-project', 'sudokuly.xcodeproj', '-scheme', 'Sudokuly', '-configuration', 'Release',
    '-destination', 'generic/platform=iOS', '-derivedDataPath', env.SUDOKULY_RELEASE_DERIVED_DATA || join(tmpdir(), 'sudokuly-auth-release'),
    'CODE_SIGNING_ALLOWED=NO', 'build'], 'release-build.log');
  const summary = { completedAt: new Date().toISOString(), project: 'demo-sudokuly', simulator, resultBundle: bundle,
    results, xcodeSummary, scenarioCoverage: { generatedPuzzlesInStressTest: 128, stateMachineActions: 6400,
      engineToFirestoreGames: 140, levels: 4, terminalVariantsPerLevel: 7, maxDeletionBatchFixture: 405 } };
  writeFileSync(join(output, 'summary.json'), JSON.stringify(summary, null, 2) + '\n');
  process.stdout.write(`Report: ${join(output, 'summary.json')}\n`);
  const skipped = xcodeSummary?.skippedTests ?? xcodeSummary?.testsSkipped ?? 0;
  process.exitCode = results.some(r => r.exitCode !== 0) || !xcodeSummary || xcodeSummary.error || skipped > 0 ? 1 : 0;
}
