import 'dart:convert';
import 'dart:io';
import 'package:gviz/gviz.dart';
import 'package:yaml/yaml.dart' as yaml;

void main() async {
  final projectPath = await _getProjectPath();
  final file = File('$projectPath/pubspec.yaml');
  final fileContent = file.readAsStringSync();
  final yamlMap = yaml.loadYaml(fileContent) as yaml.YamlMap;
  final appName = yamlMap['name'].toString();

  print('开始 ...');
  final dependencyContent = await _getComponentDependencyTree(
    projectPath: projectPath,
  );
  // 获取所有的组件依赖
  print('... 开始遍历组件依赖节点');
  print(dependencyContent);
  final dependencyNodes = _traversalComponentDependencyTree(dependencyContent);
  print('... 完成遍历组件依赖节点');
  final graph = Gviz(
    name: appName,
    graphProperties: {
      'pad': '0.5',
      'nodesep': '1',
      'ranksep': '2',
    },
    edgeProperties: {
      'fontcolor': 'gray',
    },
  );
  print('... 开始转换 dot 节点');
  _generateDotByNodes(
    dependencyNodes,
    graph: graph,
    edgeCache: <String>[],
  );
  print('... 完成转换 dot 节点');
  final dotDirectoryPath = '$projectPath/dotGenerateDir';
  final dotDirectory = Directory(dotDirectoryPath);
  if (!dotDirectory.existsSync()) {
    await dotDirectory.create();
    print('... 创建 dotGenerate 文件夹');
  }
  final dotFileName = '$appName.dot';
  final dotPngName = '$appName.png';
  final dotFile = File('$dotDirectoryPath/$dotFileName');
  final dotPngFile = File('$dotDirectoryPath/$dotPngName');
  if (dotFile.existsSync()) {
    await dotFile.delete();
    print('... 删除原有 dot 生成文件');
  }
  if (dotPngFile.existsSync()) {
    await dotPngFile.delete();
    print('... 删除原有 dot 依赖关系图');
  }
  await dotFile.create();
  final dotResult = await dotFile.writeAsString(graph.toString());
  print('dot 文件生成成功: ${dotResult.path}');
  print('... 开始生成 dot png');
  await _runCommand(
    executable: 'dot',
    projectPath: projectPath,
    commandArgs: [
      '$dotDirectoryPath/$dotFileName',
      '-T',
      'png',
      '-o',
      '$dotDirectoryPath/$dotPngName'
    ],
  );
  print('png 文件生成成功：$dotDirectoryPath/$dotPngName');
  await Process.run(
    'open',
    [dotDirectoryPath],
  );
}

// 忽略这些组件库，不需要显示出来
const List<String> ignoreDependency = <String>[
  'flutter',
  'flutter_test',
  'flutter_lints',
  'cupertino_icons',
  'gviz',
  'yaml',
];

/// 获取组件依赖树
Future<String> _getComponentDependencyTree({
  required String projectPath,
}) {
  return _runCommand(
    projectPath: projectPath,
    commandArgs: ['pub', 'deps', '--json'],
  ).then(
    (value) {
      if (value.contains('dependencies:') &&
          value.contains('dev dependencies:')) {
        final start = value.indexOf('dependencies:');
        final end = value.indexOf('dev dependencies:');
        return value.substring(start, end);
      } else {
        return value;
      }
    },
  );
}

/// 遍历组件节点
List<DependencyNode> _traversalComponentDependencyTree(
  String dependencyContent,
) {
  final dependencyJson = jsonDecode(dependencyContent) as Map<String, dynamic>;
  final packages = dependencyJson['packages'] as List<dynamic>;
  final dependencyNodeList =
      packages.map((e) => DependencyNode.fromMap(e)).toList();
  final rootNode =
      dependencyNodeList.firstWhere((element) => element.isRootNode);

  DependencyNode? matchNode(String nodeName) {
    DependencyNode? target;
    try {
      target =
          dependencyNodeList.firstWhere((element) => element.name == nodeName);
    } catch (_) {
      print(_);
    }
    return target;
  }

  void mapDependencies(DependencyNode node) {
    final dependencies = node.dependencies;
    for (int index = 0; index < dependencies.length; index++) {
      final itemName = dependencies[index];
      if (!ignoreDependency.contains(itemName)) {
        final itemNode = matchNode(itemName);
        if (itemNode != null) {
          mapDependencies(itemNode);
          node.children.add(itemNode);
        }
      }
    }
  }

  mapDependencies(rootNode);

  // 获取子集中所有的依赖
  void fetchChildrenDependency(
    DependencyNode node, {
    required List<String> dependencyContainer,
    bool containSelf = false,
  }) {
    if (node.children.isEmpty) {
      return;
    } else {
      for (int index = 0; index < node.children.length; index++) {
        final itemNode = node.children[index];
        if (containSelf && !dependencyContainer.contains(itemNode.name)) {
          dependencyContainer.add(itemNode.name);
        }
        for (var element in itemNode.children) {
          fetchChildrenDependency(
            element,
            dependencyContainer: dependencyContainer,
            containSelf: true,
          );
        }
      }
    }
  }

  // 去掉重复的连线关系
  void filterRepeatDependency(DependencyNode node) {
    final childrenDependencyContainer = <String>[];
    fetchChildrenDependency(node,
        dependencyContainer: childrenDependencyContainer);
    if (childrenDependencyContainer.isNotEmpty) {
      node.children.removeWhere(
          (element) => childrenDependencyContainer.contains(element.name));
    }
    for (var childNode in node.children) {
      filterRepeatDependency(childNode);
    }
  }

  filterRepeatDependency(rootNode);
  return [rootNode];
}

/// 获取项目根路径
Future<String> _getProjectPath() async {
  final originProjectPath = await Process.run(
    'pwd',
    [],
  );
  final projectPath = (originProjectPath.stdout as String).replaceAll(
    '\n',
    '',
  );
  return projectPath;
}

/// 转换生成 dot 绘制节点
void _generateDotByNodes(
  List<DependencyNode> nodes, {
  required Gviz graph,
  required List<String> edgeCache,
}) {
  if (nodes.isEmpty) {
    return;
  }
  for (int index = 0; index < nodes.length; index++) {
    final itemNode = nodes[index];
    final from = '${itemNode.name}\n${itemNode.version}';
    if (!graph.nodeExists(from)) {
      // 绘制节点
      graph.addNode(
        from,
        properties: {
          'color': 'black',
          'shape': 'rectangle',
          'margin': '1,0.8',
          'penwidth': '7',
          'style': 'filled',
          'fillcolor': 'gray',
          'fontsize': itemNode.isLevel1Node ? '60' : '55',
        },
      );
    }
    final toArr = itemNode.children.map((e) => '${e.name}\n${e.version}').toList();
    for (var element in toArr) {
      // 绘制连线
      final edgeKey = '$from-$element';
      if (!edgeCache.contains(edgeKey)) {
        graph.addEdge(
          from,
          element,
          properties: {
            'penwidth': '2',
            'style': 'dashed',
            'arrowed': 'vee',
            // 'weight': '2',
          },
        );
        edgeCache.add(edgeKey);
      }
    }
    _generateDotByNodes(
      itemNode.children,
      graph: graph,
      edgeCache: edgeCache,
    );
  }
}

/// 执行命令行
Future<String> _runCommand({
  String executable = 'flutter',
  required String projectPath,
  required List<String> commandArgs,
}) {
  return Process.run(
    executable,
    commandArgs,
    runInShell: true,
    workingDirectory: projectPath,
  ).then((result) => result.stdout as String);
}

/// 依赖的节点
class DependencyNode {
  final String name;
  final String version;
  final String kind;
  final String source;
  final List<String> dependencies;
  final children = <DependencyNode>[];
  bool isLevel1Node = true; //是否一级节点

  factory DependencyNode.fromMap(Map<String, dynamic> map) {
    return DependencyNode(
      name: map['name'] as String,
      version: map['version'] as String,
      kind: map['kind'] as String,
      source: map['source'] as String,
      dependencies: (map['dependencies'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  bool get isRootNode => kind == 'root';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DependencyNode &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  DependencyNode({
    required this.name,
    required this.version,
    required this.kind,
    required this.source,
    required this.dependencies,
  });
}
