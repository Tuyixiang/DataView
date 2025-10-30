// Flutter imports:
import "package:flutter/material.dart";

// Project imports:
import "package:frontend/common/common.dart";
import "package:frontend/data/clipboard/desktop.dart";
import "package:frontend/data_view.dart";
import "package:frontend/styles/base.dart";

import "package:frontend/data/url/stub.dart"
    if (dart.library.html) "package:frontend/data/url/web.dart";

class LabelCard extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final int? maxLength;
  final bool inverse;
  final bool disabled;
  final TextStyle? style;
  final AlignmentGeometry? alignment;

  const LabelCard({
    this.text,
    this.icon,
    super.key,
    this.maxLength,
    this.inverse = false,
    this.disabled = false,
    this.style,
    this.alignment,
  });

  List<FontVariation>? get textVariation {
    if (icon == null) {
      return inverse ? [AppTextStyles.boldVariation] : null;
    } else {
      return inverse
          ? [FontVariation.weight(450)]
          : [FontVariation.weight(400)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final contentColor = (inverse ? colors.onPrimary : colors.onSurface)
        .withAlpha(disabled ? 128 : 255);
    final backgroundColor = inverse ? colors.primary : colors.surfaceDim;
    return Container(
      height: AppLayout.labelHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: alignment,
      color: backgroundColor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (text != null)
            Text(
              ellipsis(text!, maxLength: maxLength),
              style: AppTextStyles.label
                  .copyWith(color: contentColor, fontVariations: textVariation)
                  .merge(style),
            ),
          if (text != null && icon != null) SizedBox(width: 4),
          if (icon != null)
            Icon(
              icon!,
              size: AppTextStyles.label.fontSize,
              color: style?.color ?? contentColor,
            ),
        ],
      ),
    );
  }
}

extension InvisibleWidget on Widget {
  Widget invisible() => Visibility.maintain(visible: false, child: this);
}

extension ClickableWidget on Widget {
  Widget onTap(void Function() callback) =>
      InkWell(onTap: callback, child: this);

  Widget onHover(void Function(bool) callback) =>
      InkWell(onHover: callback, onTap: nullCallback, child: this);
}

class InspectableContainer extends Container with PositionInspect {
  InspectableContainer({required Widget child})
    : super(key: GlobalKey(), child: child);
}

mixin PositionInspect on Widget {
  GlobalKey? get globalKey => key as GlobalKey?;

  RenderBox? get renderBox =>
      globalKey?.currentContext?.findRenderObject() as RenderBox?;

  Size? get renderSize => renderBox?.size;

  Offset? get renderPosition => renderBox?.localToGlobal(Offset.zero);
}

void showSnackBar(BuildContext context, String message, {int seconds = 1}) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: seconds),
      ),
    );
  }
}

void copyToClipboard({
  required BuildContext context,
  required String text,
}) async {
  final origin = getCurrentUrl()?.origin ?? "http://this-website:port";
  final result = await writeToClipboard(text)
      .then((_) => "Copied to clipboard")
      .catchError((e) {
        if (context.mounted) {
          showDataDialog(
            context,
            data: {
              "English":
                  """
**Failed to write to clipboard: $e**

If you're on a web platform, this is probably due to browsers blocking clipboard interaction on HTTP. Consider use Chrome and add this flag:

```shell
--unsafely-treat-insecure-origin-as-secure=$origin
```

Or, head to `chrome://flags`, find `Insecure origin treated as secure` field, and add:

```url
$origin
```

*Ask GPT for more info regarding clipboard being blocked on non-HTTPS websites.*
""",
              "中文":
                  """
**无法写入剪贴板：$e**

如果你正在网页上使用 **DataView**，这可能是因为浏览器在 HTTP 环境下阻止了剪贴板交互。建议使用 Chrome，并添加以下启动参数：

```shell
--unsafely-treat-insecure-origin-as-secure=$origin
```

或者，打开 chrome://flags，找到名为 Insecure origin treated as secure 的选项，并添加：

```url
$origin
```

*向 GPT 询问更多关于非 HTTPS 网站被阻止访问剪贴板的原因。*
""",
            },
          );
        }
        return "Failed to copy to clipboard";
      });
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result), duration: Duration(seconds: 1)),
    );
  }
}
