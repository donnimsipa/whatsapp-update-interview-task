#!/usr/bin/env node
const { spawnSync } = require('child_process');
const path = require('path');
const generator = path.join(__dirname, 'generate-whatsapp-dataset.js');
const args = [generator, '--mode', 'invalid', '--records', '100'];
process.exit(spawnSync(process.execPath, args.concat(process.argv.slice(2)), { stdio: 'inherit' }).status ?? 0);
