// Flutter imports:
import "package:flutter/widgets.dart";

// Package imports:
import "package:markdown_widget/markdown_widget.dart";

// Project imports:
import "package:frontend/styles/base.dart";

SpanNodeGeneratorWithTag strongGenerator = SpanNodeGeneratorWithTag(
  tag: "strong",
  generator: (e, config, visitor) => StrongNode(text: e.textContent),
);

class StrongNode extends SpanNode {
  final String text;

  StrongNode({required this.text});

  @override
  InlineSpan build() => TextSpan(
    style: (parentStyle ?? TextStyle()).copyWith(
      fontSize: AppTextStyles.defaultSize,
      fontVariations: [AppTextStyles.boldVariation],
    ),
    text: text,
  );
}
