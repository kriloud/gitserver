const http = require('http');
const url = require('url');
const { spawn, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const PORT = 8080;

http.createServer(async (req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const method = req.method;

  if (method === 'GET' && pathname.includes('/info/refs')) {
    handleInfoRefs(req, res, parsedUrl);
  } else if (
    method === 'POST' &&
    /^\/([^/]+)\.git\/(git-(upload|receive)-pack)$/.test(pathname)
  ) {
    const match = pathname.match(/^\/([^/]+)\.git\/(git-(upload|receive)-pack)$/);
    const repoName = match[1];
    const service = match[2];
    handleGitService(req, res, repoName, service);
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('404 Not Found');
  }
}).listen(PORT, () => {
  console.log(`Git server running at http://localhost:${PORT}/`);
});

function handleInfoRefs(req, res, parsedUrl) {
  const pathname = parsedUrl.pathname;
  const match = pathname.match(/^\/([^/]+)\.git\/info\/refs$/);

  if (!match) {
    res.writeHead(400, { 'Content-Type': 'text/plain' });
    res.end('Invalid info/refs path');
    return;
  }

  const repoName = match[1];
  const service = parsedUrl.query.service;

  if (service !== 'git-upload-pack' && service !== 'git-receive-pack') {
    res.writeHead(400, { 'Content-Type': 'text/plain' });
    res.end('Unsupported service');
    return;
  }

  const repoPath = path.join('repo', `${repoName}.git`);
  if (!fs.existsSync(repoPath)) {
    console.log('Auto-creating repo:', repoPath);
    try {
      execSync(`git init --bare ${repoPath}`);
    } catch (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Failed to create repo:\n' + err.stderr);
      return;
    }
  }

  const command = service === 'git-upload-pack' ? 'upload-pack' : 'receive-pack';
  const git = spawn('git', [command, '--stateless-rpc', '--advertise-refs', repoPath]);

  const serviceHeader = `# service=${service}\n`;
  const pktLine =
    (serviceHeader.length + 4).toString(16).padStart(4, '0') + serviceHeader + '0000';

  res.writeHead(200, {
    'Content-Type': `application/x-${service}-advertisement`,
  });
  res.write(pktLine);

  git.stdout.pipe(res);
  git.stderr.on('data', () => {}); // Drain
  git.on('close', (code) => {
    if (code !== 0) {
      console.log(`git process exited with code ${code}`);
    }
  });
}

function handleGitService(req, res, repoName, service) {
  const repoPath = path.join('repo', `${repoName}.git`);
  if (!fs.existsSync(repoPath)) {
    console.log('Auto-creating repo:', repoPath);
    try {
      execSync(`git init --bare ${repoPath}`);
    } catch (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Failed to create repo:\n' + err.stderr);
      return;
    }
  }

  const command = service === 'git-upload-pack' ? 'upload-pack' : 'receive-pack';
  const git = spawn('git', [command, '--stateless-rpc', repoPath]);

  res.writeHead(200, {
    'Content-Type': `application/x-${service}-result`,
  });

  req.pipe(git.stdin);
  git.stdout.pipe(res);
  git.stderr.on('data', () => {}); // Drain

  git.on('close', (code) => {
    if (code !== 0) {
      console.log(`git process exited with code ${code}`);
    }
  });
}
