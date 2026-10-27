import { spawn } from 'node:child_process';

const maxAttempts = 3;

function runComposeUp() {
  return new Promise((resolve) => {
    const child = spawn('docker', ['compose', 'up', '--build', '-d'], {
      stdio: 'inherit',
      shell: process.platform === 'win32',
    });

    child.on('error', (error) => {
      console.error(`Could not start Docker Compose: ${error.message}`);
      resolve(1);
    });
    child.on('exit', (code) => resolve(code ?? 1));
  });
}

for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
  const code = await runComposeUp();
  if (code === 0) process.exit(0);
  if (attempt === maxAttempts) process.exit(code);

  const delaySeconds = attempt * 3;
  console.warn(`Compose failed (attempt ${attempt}/${maxAttempts}); retrying in ${delaySeconds}s...`);
  await new Promise((resolve) => setTimeout(resolve, delaySeconds * 1000));
}
