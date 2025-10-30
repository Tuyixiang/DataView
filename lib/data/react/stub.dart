// Project imports:
import "package:frontend/common/config.dart";

import "package:frontend/data/react/react_sandbox.dart"; // remove this import if not applicable

Future<String> compileReact(String code) => TEST_FEATURES
    ? sandboxCompileReact(code)
    : Future.sync(
        () => """<html>
  <h2>React is not supported</h2>
</html>""",
      );
