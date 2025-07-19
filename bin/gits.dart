import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('Git server running at http://localhost:8080/');

  await for (final HttpRequest request in server) {
    final path = request.uri.path;
    final method = request.method;

    if (method == 'GET' && path.contains('/info/refs')) {
      await handleInfoRefs(request);
    } else if (method == 'POST' &&
        RegExp(r'^/([^/]+)\.git/(git-(upload|receive)-pack)$').hasMatch(path)) {
      final match = RegExp(r'^/([^/]+)\.git/(git-(upload|receive)-pack)$')
          .firstMatch(path)!;
      final repoName = match.group(1)!;
      final service = match.group(2)!;
      await handleGitService(request, repoName, service);
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('404 Not Found')
        ..close();
    }
  }
}

Future<void> handleInfoRefs(HttpRequest request) async {
  final uri = request.uri;
  final path = uri.path;

  final match = RegExp(r'^/([^/]+)\.git/info/refs$').firstMatch(path);
  if (match == null) {
    request.response
      ..statusCode = 400
      ..write('Invalid info/refs path')
      ..close();
    return;
  }

  final repoName = match.group(1)!;
  final service = uri.queryParameters['service'] ?? '';

  if (service != 'git-upload-pack' && service != 'git-receive-pack') {
    request.response
      ..statusCode = 400
      ..write('Unsupported service')
      ..close();
    return;
  }

  final repoPath = 'repo/$repoName.git';
  final dir = Directory(repoPath);
  if (!await dir.exists()) {
    print('Auto-creating repo: $repoPath');
    final result = await Process.run('git', ['init', '--bare', repoPath]);
    if (result.exitCode != 0) {
      request.response
        ..statusCode = 500
        ..write('Failed to create repo: ${result.stderr}')
        ..close();
      return;
    }
  }

  final command = service == 'git-upload-pack' ? 'upload-pack' : 'receive-pack';

  final gitProcess = await Process.start(
    'git',
    [command, '--stateless-rpc', '--advertise-refs', repoPath],
    runInShell: true,
  );

  final serviceHeader = '# service=$service\n';
  final pktLine = '${(serviceHeader.length + 4).toRadixString(16).padLeft(4, '0')}$serviceHeader' '0000';


  final response = request.response;
  response
    ..statusCode = 200
    ..headers.contentType =
        ContentType('application', 'x-$service-advertisement')
    ..add(utf8.encode(pktLine));

  await gitProcess.stdout.pipe(response);
  await gitProcess.stderr.drain();
  await response.close();

  final exitCode = await gitProcess.exitCode;
  if (exitCode != 0) {
    print('git process exited with code $exitCode');
  }
}

Future<void> handleGitService(
    HttpRequest request, String repoName, String service) async {
  final repoPath = 'repo/$repoName.git';
  final dir = Directory(repoPath);
  if (!await dir.exists()) {
    print('Auto-creating repo: $repoPath');
    final result = await Process.run('git', ['init', '--bare', repoPath]);
    if (result.exitCode != 0) {
      request.response
        ..statusCode = 500
        ..write('Failed to create repo: ${result.stderr}')
        ..close();
      return;
    }
  }

  final command = service == 'git-upload-pack' ? 'upload-pack' : 'receive-pack';

  final gitProcess = await Process.start(
    'git',
    [command, '--stateless-rpc', repoPath],
    runInShell: true,
  );

  final response = request.response;
  response.headers.contentType =
      ContentType('application', 'x-$service-result');

  await request.listen(gitProcess.stdin.add).asFuture();
  await gitProcess.stdin.close();

  await gitProcess.stdout.pipe(response);
  await gitProcess.stderr.drain();

  await response.close();

  final exitCode = await gitProcess.exitCode;
  if (exitCode != 0) {
    print('git process exited with code $exitCode');
  }
}
