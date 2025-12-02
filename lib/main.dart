// Dart imports:
import "dart:convert";

// Flutter imports:
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

// Package imports:
import "package:desktop_drop/desktop_drop.dart";
import "package:provider/provider.dart";
import "package:styled_widget/styled_widget.dart";
import "package:url_launcher/url_launcher.dart";
import "package:window_manager/window_manager.dart";

// Project imports:
import "package:frontend/common/config.dart";
import "package:frontend/common/platform.dart";
import "package:frontend/component/common.dart";
import "package:frontend/data/backend/base_backend.dart";
import "package:frontend/data/loader.dart";
import "package:frontend/data/pick_file.dart";
import "package:frontend/data/sample_data.dart";
import "package:frontend/styles/base.dart";
import "package:frontend/version_note.dart";
import "data_view.dart";

import "package:frontend/window/stub.dart"
    if (dart.library.html) "package:frontend/window/web.dart"
    if (dart.library.io) "package:frontend/window/desktop.dart";


import "package:frontend/data/url/stub.dart"
    if (dart.library.html) "package:frontend/data/url/web.dart";

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialization for macOS
  if (kIsMac) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  late final DataSource source;

  if (kIsWeb) {
    // Web: parse from current url
    final urlParams = getQueryParams();
    source = await DataSource.fromUrl(
      urlParams["file"],
      initialPath: urlParams["path"],
    );
  } else if (args.firstOrNull == "multi_window") {
    // Multi window: read from args
    final Map data = jsonDecode(args[2]);
    source = DataSource(
      await Backend.fromUriString(data["file"]),
      data["path"],
    );
  } else if (args.isNotEmpty) {
    // Non-macOS desktop: read file path from args
    source = await DataSource.fromFile(args[0]);
  } else if (kIsMac) {
    // in MacOS, we need to make a call to Swift native code to check if a file has been opened with our App
    const hostApi = MethodChannel("myChannel");
    final String? filePath = await hostApi.invokeMethod("getCurrentFile");
    source = await DataSource.fromFile(filePath);
  } else {
    throw UnimplementedError();
  }

  WindowData.initialize();

  runApp(
    ChangeNotifierProvider<DataSource>.value(value: source, child: MyApp()),
  );
}

class NewWindowIntent extends Intent {
  const NewWindowIntent();
}

class CloseWindowIntent extends Intent {
  const CloseWindowIntent();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "DataView",
      theme: ThemeData(
        fontFamily: "MiSans",
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      // darkTheme: ThemeData(
      //   fontFamily: "MiSans",
      //   colorScheme: ColorScheme.fromSeed(
      //     seedColor: Colors.blueAccent,
      //     brightness: Brightness.dark,
      //   ),
      // ),
      home: !kIsMac
          ? MyHomePage()
          : Shortcuts(
              shortcuts: {
                // There is a framework bug that will err if key triggers new window
                // https://github.com/flutter/flutter/issues/125975
                // LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN):
                //     const NewWindowIntent(),
                LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyW):
                    const CloseWindowIntent(),
              },
              child: Actions(
                actions: {
                  NewWindowIntent: CallbackAction<NewWindowIntent>(
                    onInvoke: (intent) {
                      WindowData.createWindow();
                      return null;
                    },
                  ),
                  CloseWindowIntent: CallbackAction<CloseWindowIntent>(
                    onInvoke: (intent) {
                      WindowData.close();
                      return null;
                    },
                  ),
                },
                child: Focus(autofocus: true, child: MyHomePage()),
              ),
            ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final inputController = TextEditingController();

  Future<void> pickOpenFile() async {
    final result = await pickFiles();
    if (result.isEmpty) return;
    final file = result.first;

    final newData = await parseData(
      file.name,
      file.stream,
      exceptionCallback: (message) {
        if (mounted) {
          showSnackBar(context, message, seconds: 2);
        }
      },
    );
    if (newData != null && mounted) {
      context.read<DataSource>().update(
        MemoryBackend.fromObject(newData, file: file.name),
      );
    }
  }

  Widget buildInitial(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      alignment: AlignmentGeometry.topLeft,
      children: [
        Column(
              spacing: 12,
              mainAxisSize: .min,
              crossAxisAlignment: .center,
              children: [
                SizedBox(width: .infinity, height: 12),
                Text.rich(
                  textAlign: .center,
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "DataView\n",
                        style: textTheme.displaySmall
                            ?.merge(AppTextStyles.boldStyle)
                            .copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      TextSpan(
                        text: "by tuyixiang@baidu.com",
                        style: textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  textAlign: .center,
                  TextSpan(
                    style: textTheme.bodyLarge?.copyWith(height: 1.6),
                    children: [
                      TextSpan(text: "Supported structures: "),
                      TextSpan(
                        text: [
                          "json",
                          "jsonl",
                          "yaml",
                          "csv",
                          "xlsx",
                        ].join(","),
                        style: AppTextStyles.monospace,
                      ),
                      TextSpan(text: "\n"),
                      TextSpan(text: "Supported formats: "),
                      TextSpan(
                        text: [
                          "txt",
                          "md",
                          "html",
                          if (TEST_FEATURES) "jsx",
                        ].join(","),
                        style: AppTextStyles.monospace,
                      ),
                      TextSpan(text: "\n"),
                      TextSpan(text: "Supported compression: "),
                      TextSpan(
                        text: ["gz/gzip", "zst/zstd"].join(","),
                        style: AppTextStyles.monospace,
                      ),
                    ],
                  ),
                ),
                Divider(),
                TextField(
                  expands: true,
                  style: AppTextStyles.monospace.copyWith(fontSize: 12),
                  controller: inputController,
                  minLines: null,
                  maxLines: null,
                  decoration: InputDecoration(
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    hintText: r"""* Paste data here and "Visualize".
* Drag a file into the window.
* Select a file with "Open File".""",
                    hintStyle: TextStyle(color: Theme.of(context).hintColor),
                    hoverColor: Theme.of(context).colorScheme.surfaceBright,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                ).expanded(),
                Row(
                  children: [
                    // Readme button
                    OutlinedButton(
                      onPressed: () {
                        context.read<DataSource>().update(
                          MemoryBackend.fromObject(readmeData),
                          readmeInitialPath,
                        );
                      },
                      child: Text(
                        "Readme",
                        style: textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).hintColor,
                          fontVariations: [AppTextStyles.boldVariation],
                        ),
                      ),
                    ),
                    Spacer(),
                    // Visualize button
                    FilledButton(
                      onPressed: () {
                        if (inputController.text.isEmpty) {
                          showSnackBar(
                            context,
                            "Paste data into text box first",
                          );
                        } else {
                          context.read<DataSource>().update(
                            MemoryBackend.fromObject(inputController.text),
                          );
                        }
                      },
                      child: Text(
                        "Visualize",
                        style: textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontVariations: [AppTextStyles.boldVariation],
                        ),
                      ),
                    ),
                    Spacer(),
                    // Open file button
                    OutlinedButton(
                      onPressed: pickOpenFile,
                      child: Text(
                        "Open File",
                        style: textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).hintColor,
                          fontVariations: [AppTextStyles.boldVariation],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: .infinity, height: 12),
              ],
            )
            .paddingDirectional(horizontal: 16)
            .constrained(
              maxHeight: AppLayout.cardMaxHeight,
              maxWidth: AppLayout.centerMaxWidth,
            )
            .center()
            .backgroundColor(Theme.of(context).colorScheme.surfaceContainer),
        // Stacked version info
        VersionNote().paddingDirectional(horizontal: 4, top: 2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = context.watch<DataSource>();
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: "App",
          menus: <PlatformMenuItem>[
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: "About DataView",
                  onSelected: () => WindowData.alert(
                    "DataView (version: $VERSION_NAME)\nDeveloped by tuyixiang@baidu.com",
                    title: "About",
                  ),
                ),
                if (HELP_LINK.isNotEmpty)
                  PlatformMenuItem(
                    label: "View Documentation",
                    onSelected: () => launchUrl(Uri.parse(HELP_LINK)),
                  ),
              ],
            ),
            if (PlatformProvidedMenuItem.hasMenu(
              PlatformProvidedMenuItemType.servicesSubmenu,
            ))
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.servicesSubmenu,
              ),
            if (PlatformProvidedMenuItem.hasMenu(
              PlatformProvidedMenuItemType.quit,
            ))
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.quit,
              ),
          ],
        ),
        PlatformMenu(
          label: "File",
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: "New Window",
                  onSelected: WindowData.createWindow,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: "Open File...",
                  onSelected: pickOpenFile,
                ),
                PlatformMenuItem(
                  label: "Close File",
                  onSelected: () => context.read<DataSource>().update(),
                ),
              ],
            ),
          ],
        ),
      ],
      child: Scaffold(
        body: Container(
          color: Theme.of(context).colorScheme.surface,
          child: DropTarget(
            onDragDone: (details) async {
              final file = details.files.first;
              final newData = await parseData(
                file.name,
                file.openRead(),
                exceptionCallback: (message) {
                  if (context.mounted) {
                    showSnackBar(context, message, seconds: 2);
                  }
                },
              );
              if (newData != null) {
                source.update(
                  MemoryBackend.fromObject(newData, file: file.name),
                );
              }
            },
            child: source.isEmpty
                ? buildInitial(context)
                : DataView(
                    key: ObjectKey(source.backend),
                    initialSource: source,
                    exitCallback: source.update,
                  ),
          ),
        ),
      ),
    );
  }
}
