#!/usr/bin/env node
const { spawnSync } = require('child_process');
const path = require('path');
const generator = path.join(__dirname, 'generate-whatsapp-dataset.js');
const sizes = [100, 1000, 5000];

sizes.forEach((size) => {
  const args = [generator,
    '--mode', 'uniform',
    '--records', String(size),
    '--output', path.join('outputs/performance', `large-${size}.csv`),
    '--patients-json', path.join('outputs/performance', `patients-${size}.json`),
  ];
  const result = spawnSync(process.execPath, args.concat(process.argv.slice(2)), { stdio: 'inherit' });
  if ((result.status ?? 0) !== 0) {
    process.exit(result.status ?? 1);
  }
});
