// Flutter imports:
import "package:flutter/material.dart";

// Package imports:
import "package:http/http.dart" as http;
import "package:url_launcher/url_launcher.dart";

// Project imports:
import "package:frontend/common/config.dart";
import "package:frontend/component/common.dart";
import "package:frontend/styles/base.dart";

import "package:frontend/window/stub.dart"
    if (dart.library.html) "package:frontend/window/web.dart"
    if (dart.library.io) "package:frontend/window/desktop.dart";

class VersionNote extends StatefulWidget {
  const VersionNote({super.key});

  @override
  State<VersionNote> createState() => _VersionNoteState();
}

class _VersionNoteState extends State<VersionNote> {
  static String? latest;

  @override
  void initState() {
    super.initState();
    checkUpdate();
  }

  void checkUpdate() async {
    if (VERSION_LINK.isEmpty || latest != null) return;
    try {
      final resp = await http.get(Uri.parse(VERSION_LINK));
      if (resp.statusCode != 200) {
        throw Exception("Received HTTP ${resp.statusCode} response");
      }
      latest = resp.body.trim();
      setState(() {});
    } catch (e) {
      WindowData.alert(e.toString(), title: "Failed to check for updates");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 16,
      children: [
        if (HELP_LINK.isNotEmpty)
          Text(
            "Help",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ).onTap(() => launchUrl(Uri.parse(HELP_LINK))),
        if (NEWS_LINK.isNotEmpty)
          InkWell(
            onTap: () => launchUrl(Uri.parse(NEWS_LINK)),
            child: latest != null && latest!.compareTo(BUILD_DATE) > 0
                ? Text(
                    "UPDATE AVAILABLE",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontVariations: [AppTextStyles.boldVariation],
                    ),
                  )
                : Text(
                    "What's New",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
          ),
        Spacer(),
        Text(
          VERSION_NAME,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor),
        ),
      ],
    );
  }
}
