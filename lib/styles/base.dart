// Flutter imports:
import "package:flutter/material.dart";

extension InverseColor on TextStyle {
  TextStyle inversed({Color? background}) => copyWith(
    backgroundColor: color,
    color: background ?? backgroundColor ?? Colors.white,
  );
}

class AppLayout {
  static const double centerMaxWidth = 960;
  static const double cardMaxHeight = 600;
  static const double previewMinHeight = 120;
  static const double labelHeight = 24;
}

class AppTextStyles {
  static const double defaultSize = 16;
  static const boldVariation = FontVariation.weight(550);
  static const boldStyle = TextStyle(fontVariations: [boldVariation]);

  static const TextStyle monospace = TextStyle(
    fontFamily: "JetBrainsMono",
    fontFamilyFallback: ["MiSans"],
    fontVariations: [FontVariation.weight(350)],
    fontFeatures: [FontFeature.disable("calt")],
    fontSize: defaultSize,
  );

  static final TextStyle monospaceWithBack = monospace.copyWith(
    backgroundColor: Color(0x18000000),
  );

  static const TextStyle label = TextStyle(
    fontVariations: [FontVariation.weight(500)],
    fontFeatures: [FontFeature.disable("calt")],
    fontSize: 14,
  );

  static TextStyle hint([BuildContext? context]) => TextStyle(
    fontFamily: "JetBrainsMono",
    fontFamilyFallback: ["MiSans"],
    fontVariations: const [FontVariation.weight(450)],
    fontFeatures: [FontFeature.disable("calt")],
    fontSize: defaultSize,
    color: context != null ? Theme.of(context).hintColor : Color(0xff808080),
    fontStyle: FontStyle.italic,
  );
}
