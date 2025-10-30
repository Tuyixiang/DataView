// Project imports:
import "package:frontend/common/config.dart";

const readmeFile = "readme";
const readmeInitialPath = "English";
const readmeTitle = "Example";
final readmeData = {
  "English": {
    "About": r"""
This is a convenient data visualizer supporting multiple formats.
        
You ~~may want to~~ **should** click on buttons to see what they do.

Below are example content that can be visualized by **DataView**.
""",
    "Structured data": {
      "Hint": "Click the blue \"open\" button at top-right of this card",
      "Description": r"""
**DataView is designed to handle structured data like JSON or Excel tables.**  
In fact, you can toggle different views at the top-right of this window to see how this example content is visualized.
""",
      "Supported types": [
        "Literals (numbers, boolean, null)",
        "Strings (with special handling logic explained below)",
        "Lists/Objects/Dicts/Maps (feel free to nest them)",
      ],
      "String handling logic": r"""
**DataView tries to visualize as much data as possible.**  
For example, if a string contains a valid JSON serialization, DataView will automatically expand it into a JSON object.

Therefore, the caveat is that DataView may visualize data in a way that's not 100% authentic. It may strip trailing whitespaces, automatically convert types, etc. 
""",
    },
    "Markdown": r"""
## DataView supports markdown

> To see the markdown source text, select `plain` in the top-right switches.  
> To read this entire markdown text, click on the `open` button at the top-right.

DataView also supports rendering of $\LaTeX~\mathbb{M}\alpha\hat{t}h$ surrounded by one of these marks:
- `$...$`
- `$$...$$`
- `\[...\]`
- `\(...\)`
""",
    "Image": r"""
![sample image from picsum](https://picsum.photos/600/150)

As shown above, DataView can render images in the following formats:
- Markdown image: `![image](https://your.image.url)`
- HTML image: `<img src="https://your.image.url" />`
- Link only: `https://your.image.url/filename.jpg`
  > *Link must be single-line string with no additional content. It must also end with an image extension to be recognized.*
- *Base64 not supported yet*
""",
    "HTML":
        """
<html>
  <body>
    <h2>DataView also renders HTML${TEST_FEATURES ? " or React" : ""} code</h2>
    <hr />
    <p>HTML code should be wrapped with <code>&lt;html&gt;</code> tags.</p>
    ${TEST_FEATURES ? "<p>React code must be a single component with an <code>export default</code> statement.</p>" : ""}
    <p>To help DataView recognize the language, it's recommended to wrap code in a markdown code block starting with <code>```html</code>${TEST_FEATURES ? " or <code>```jsx</code>" : ""}.</p>
    <p>DataView supports most HTML elements including media and javascript interactions.</p>
    <p><em>DataView even reports resource load failure and javascript errors at the bottom. (Not yet supported on web version.)</em></p>
    <img src="https://picsum.photos/600/300" />
    <img src="https://nonexist.image.source" alt="https://nonexist.image.source" />
  </body>
</html>
""",
  },
  "中文": {
    "关于": r"""
这是一个方便的数据可视化工具，支持多种格式。

你~~可能想~~**应该**点击按钮看看它们的效果。

下面是一些可以通过 **DataView** 可视化的示例内容。
""",
    "结构化数据": {
      "提示": "点击此卡片右上角的蓝色“进入”按钮",
      "描述": r"""
**DataView 被设计用于处理结构化数据，例如 JSON 或 Excel 表格。**  
实际上，你可以通过切换此窗口右上角的不同视图来查看示例内容的可视化效果。
""",
      "支持类型": [
        "字面量（数字、布尔值、null）",
        "字符串（有特殊的处理逻辑，见下文说明）",
        "列表/对象/字典/映射（可以随意嵌套）",
      ],
      "字符串解析逻辑": r"""
**DataView 会尽可能对数据进行可视化。**  
例如，如果一个字符串包含有效的 JSON 序列化内容，DataView 会自动将其展开为 JSON 对象。

因此，需要注意的是 DataView 的可视化方式可能并不完全真实。它可能会去掉字符串尾部的空格，自动转换类型等。
""",
    },
    "Markdown": r"""
## DataView 支持 Markdown

> 若要查看 Markdown 源文本，请在右上角的切换中选择 `plain`。  
> 若要阅读完整的 Markdown 内容，请点击右上角的“进入”按钮。

DataView 还支持渲染 $\LaTeX~\mathbb{M}\alpha\hat{t}h$，只需使用以下符号包裹：
- `$...$`
- `$$...$$`
- `\[...\]`
- `\(...\)`
""",
    "图片": r"""
![来自 picsum 的示例图片](https://picsum.photos/600/150)

如上所示，DataView 可以渲染以下格式的图片：
- Markdown 图片: `![image](https://your.image.url)`
- HTML 图片: `<img src="https://your.image.url" />`
- 仅链接: `https://your.image.url/filename.jpg`
  > *链接必须是单行字符串且没有额外内容。它还必须以图片扩展名结尾才能被识别。*
- *暂不支持 Base64*
""",
    "HTML":
        """
<html>
  <head>
    <meta charset="UTF-8">
  </head>
  <body>
    <h2>DataView 也可以渲染 HTML${TEST_FEATURES ? " 或 React" : ""} 代码</h2>
    <hr />
    <p>HTML 代码应当包裹在 <code>&lt;html&gt;</code> 标签中。</p>
    ${TEST_FEATURES ? "<p>React 代码必须是一个包含 <code>export default</code> 语句的单个组件。</p>" : ""}
    <p>为了帮助 DataView 识别语言，推荐将代码包裹在以 <code>```html</code>${TEST_FEATURES ? " 或 <code>```jsx</code>" : ""} 开头的 Markdown 代码块中。</p>
    <p>DataView 支持大多数 HTML 元素，包括媒体和 JavaScript 交互。</p>
    <p><em>DataView 甚至会在底部报告资源加载失败和 JavaScript 错误。（网页版暂不可用）</em></p>
    <img src="https://picsum.photos/600/300" />
    <img src="https://nonexist.image.source" alt="https://nonexist.image.source" />
  </body>
</html>
""",
  },
};
