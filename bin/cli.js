#!/usr/bin/env node
// cc-discipline CLI entry point (cross-platform)
// Detects platform and spawns bash with correct paths

const { execSync, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const PKG_DIR = path.resolve(__dirname, '..');
const args = process.argv.slice(2);

// Find bash executable
function findBash() {
    // Unix: bash is always available
    if (process.platform !== 'win32') return 'bash';

    // Windows: try common Git Bash locations
    const candidates = [
        'C:\\Program Files\\Git\\bin\\bash.exe',
        'C:\\Program Files (x86)\\Git\\bin\\bash.exe',
        process.env.PROGRAMFILES + '\\Git\\bin\\bash.exe',
    ];

    for (const candidate of candidates) {
        if (fs.existsSync(candidate)) return candidate;
    }

    // Try PATH
    try {
        execSync('bash --version', { stdio: 'ignore' });
        return 'bash';
    } catch (e) {
        console.error('Error: bash not found. Please install Git for Windows (https://git-scm.com/download/win)');
        console.error('Git Bash is required to run cc-discipline on Windows.');
        process.exit(1);
    }
}

const bash = findBash();

// Convert Windows path to Unix-style for bash
function toUnixPath(p) {
    if (process.platform !== 'win32') return p;
    // C:\Users\foo → /c/Users/foo
    return p.replace(/\\/g, '/').replace(/^([A-Za-z]):/, (_, drive) => '/' + drive.toLowerCase());
}

// Route subcommands
const command = args[0] || 'init';
const restArgs = args.slice(1);

let script;
let scriptArgs;

switch (command) {
    case 'init':
        script = path.join(PKG_DIR, 'init.sh');
        scriptArgs = restArgs;
        break;
    case 'upgrade':
        script = path.join(PKG_DIR, 'init.sh');
        scriptArgs = ['--auto', ...restArgs];
        break;
    case 'status':
        script = path.join(PKG_DIR, 'lib', 'status.sh');
        scriptArgs = [];
        break;
    case 'doctor':
        script = path.join(PKG_DIR, 'lib', 'doctor.sh');
        scriptArgs = [];
        break;
    case 'add-stack':
        if (restArgs.length === 0) {
            console.log('Usage: cc-discipline add-stack <numbers>');
            console.log('  e.g.: cc-discipline add-stack 3 4');
            process.exit(1);
        }
        script = path.join(PKG_DIR, 'init.sh');
        scriptArgs = ['--stack', restArgs.join(' '), '--no-global'];
        break;
    case 'remove-stack':
        script = path.join(PKG_DIR, 'lib', 'stack-remove.sh');
        scriptArgs = restArgs;
        break;
    case '-v':
    case '--version':
    case 'version':
        const pkg = require(path.join(PKG_DIR, 'package.json'));
        console.log(`cc-discipline v${pkg.version}`);
        process.exit(0);
    case '-h':
    case '--help':
    case 'help':
        const ver = require(path.join(PKG_DIR, 'package.json')).version;
        console.log(`cc-discipline v${ver} — Discipline framework for Claude Code

Usage: cc-discipline <command> [options]

Commands:
  init [options]        Install discipline into current project (default)
  upgrade               Upgrade rules/hooks (shortcut for init --auto)
  add-stack <numbers>   Add stack rules (e.g., add-stack 3 4)
  remove-stack <numbers> Remove stack rules
  status                Show installed version, stacks, and hooks
  doctor                Check installation integrity
  version               Show version

Init options:
  --auto                Non-interactive with defaults
  --stack <choices>     Stack selection: 1-7, space-separated
  --name <name>         Project name (default: directory name)
  --global              Install global rules to ~/.claude/CLAUDE.md
  --no-global           Skip global rules install

Stacks:
  1=RTL  2=Embedded  3=Python  4=JS/TS  5=Mobile  6=Fullstack  7=General

Examples:
  npx cc-discipline                           # Interactive setup
  npx cc-discipline init --auto               # Non-interactive defaults
  npx cc-discipline init --auto --stack "3 4"  # Python + JS/TS
  npx cc-discipline upgrade                   # Upgrade to latest
  npx cc-discipline status                    # Check what's installed
  npx cc-discipline doctor                    # Diagnose issues`);
        process.exit(0);
    default:
        console.error(`Unknown command: ${command}`);
        console.error("Run 'cc-discipline --help' for usage");
        process.exit(1);
}

// Run the bash script
const unixScript = toUnixPath(script);
const pkgVersion = require(path.join(PKG_DIR, 'package.json')).version;
const env = {
    ...process.env,
    CC_DISCIPLINE_PKG_DIR: process.platform === 'win32' ? toUnixPath(PKG_DIR) : PKG_DIR,
    CC_DISCIPLINE_VERSION: pkgVersion,
};

const result = spawnSync(bash, [unixScript, ...scriptArgs], {
    stdio: 'inherit',
    env,
    cwd: process.cwd(),
});

process.exit(result.status || 0);
