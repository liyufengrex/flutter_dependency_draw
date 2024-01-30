## flutter 项目组件依赖关系可视化 - 实现

### 实现方案

使用[gviz](https://pub.dev/packages/gviz/changelog),通过 DOT （一种描述语言来定义图形）Graphviz 实现图形可视化。

最终产物可生成 PNG、PDF、SVG 等格式。

### 前置工作

+ 以 Mac 为例，需要在电脑使用命令行工具安装 `graphviz`

```dart
// 我的电脑是 m1，命令行如下：
arch -arm64 brew install graphviz
```
+ 在需要生成**依赖关系图形**的项目根目录下，找到 `pubspec.yaml` 文件，添加如下依赖

```dart
dev_dependencies:
yaml: ^3.1.1
gviz: ^0.4.0
```

### 直接执行脚本即可生成依赖关系图

如 demo ： flutter_dependency_draw 项目内的 `script/dependency_draw.dart`

最终会生成 依赖关系.png 文件, 位于当前项目的 dotGenerateDir 目录下。

+ flutter_dependency_draw 作为主项目，
+ cart、common、common_ui、login、menu、net、 order、splash、trade、upgrade 分别是组件模块
+ 组件模块内部依赖了些许第三方库

生成的依赖关系图如下：

![flutter_dependency_draw.png](https://upload-images.jianshu.io/upload_images/25776880-2e62fa6ba1480e24.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



### DOT 语言相关参考资料：

+ https://graphviz.org/doc/info/shapes.html
+ https://blog.csdn.net/essencelite/article/details/132789403


