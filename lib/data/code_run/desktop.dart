// Dart imports:
import "dart:async";
import "dart:io";

// Project imports:
import "package:frontend/data/code_run/stdcpp.dart";

Future<void> runScript(String dir, File scriptFile, File statusFile) async {
  final appleScript =
      """
set theCmd to "clear && cd $dir && bash ${scriptFile.path}; echo \$? > ${statusFile.path}; cd ~;"

if application "iTerm" exists then
    -- Prefer iTerm2
    tell application "iTerm"
        activate
        set newWindow to (create window with default profile)
        tell newWindow's current session to write text theCmd
    end tell
else
    -- Fallback to Terminal
    tell application "Terminal"
        do script theCmd
        activate
    end tell
end if
""";

  await Process.run("osascript", ["-e", appleScript]);

  final start = DateTime.now();
  const timeout = Duration(minutes: 5);
  while (!await statusFile.exists()) {
    await Future.delayed(const Duration(seconds: 1));
    if (DateTime.now().difference(start) > timeout) {
      throw TimeoutException("Execution timed out");
    }
  }
}

Future<void> executeEnvironment({
  required Map<String, String> files,
  required String script,
}) async {
  final tempDir = await Directory.systemTemp.createTemp("dataview_execution_");

  try {
    final scriptFile = File("${tempDir.path}/script.sh");
    await scriptFile.writeAsString(script);
    final statusFile = File("${tempDir.path}/.status");
    for (final entry in files.entries) {
      final file = File("${tempDir.path}/${entry.key}");
      await file.create(recursive: true);
      await file.writeAsString(entry.value);
    }
    await runScript(tempDir.path, scriptFile, statusFile);
  } finally {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // Ignore cleanup errors
    }
  }
}

Future<void> executePython(String code) => executeEnvironment(
  files: {"test.py": code},
  script: r"""#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Running python script ===${NC}"

python3 test.py

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Program exited with status code 0${NC}"
else
    echo -e "\n${RED}✗ Program exited with exit code $?${NC}"
    exit 1
fi
""",
);

Future<void> executeCpp(String code) => executeEnvironment(
  files: {"test.cpp": code, "bits/stdc++.h": stdcppH},
  script: r"""#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Compiling test.cpp ===${NC}"

g++ -o test test.cpp -std=c++17 -O -I. 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Compilation successful${NC}\n"
    
    echo -e "${YELLOW}=== Running compiled binary ===${NC}"
    
    ./test
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}✓ Program exited with status code 0${NC}"
    else
        echo -e "\n${RED}✗ Program crashed with status code $?${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Compilation failed${NC}"
    exit 1
fi
""",
);

Future<void> launchHtml(Future<String> code) async {
  final dir = await Directory.systemTemp.createTemp("dataview_html_");
  final file = File("${dir.path}/preview.html");
  await file.writeAsString(await code);
  await Process.run("open", [file.path]);
}
