import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/generated/source.dart';

class AngularOptions {
  AngularOptions({this.customTagNames, this.customEvents, this.source});
  factory AngularOptions.from(Source source) =>
      new _OptionsBuilder(null, source).build();
  factory AngularOptions.defaults() => new _OptionsBuilder.empty().build();

  /// For tests, its easier to pass the Source's contents directly rather than
  /// creating mocks that returned mocked data that mocked contents.
  @visibleForTesting
  factory AngularOptions.fromString(String content, Source source) =>
      new _OptionsBuilder(content, source).build();

  final List<String> customTagNames;
  final Map<String, CustomEvent> customEvents;
  final Source source;

  /// A unique signature based on the events for hashing the settings into the
  /// resolution hashes.
  String get customEventsHashString =>
      _customEventsHashString ??= _computeCustomEventsHashString();
  String _customEventsHashString;

  /// When events are present, generate a string in the form of
  /// 'e:name,type,path,name,type,path'. Take care we sort before emitting. And
  /// in theory we could/should escape colon and comma, but the only one of
  /// those that should appear in a valid config is the colon in 'package:',
  /// and due to its position between the fixed placement of commas, it should
  /// not be able to make one signature look like another.
  String _computeCustomEventsHashString() {
    if (customEvents.isEmpty) {
      return '';
    }

    final buffer = new StringBuffer()..write('e:');
    for (final key in customEvents.keys.toList()..sort()) {
      final event = customEvents[key];
      buffer
        ..write(event.name ?? '')
        ..write(',')
        ..write(event.typeName ?? '')
        ..write(',')
        ..write(event.typePath ?? '')
        ..write(',');
    }
    return buffer.toString();
  }
}

class CustomEvent {
  final String name;
  final String typeName;
  final String typePath;
  final int nameOffset;

  CustomEvent(this.name, this.typeName, this.typePath, this.nameOffset);

  DartType resolvedType;
}

class _OptionsBuilder {
  dynamic analysisOptions;
  dynamic angularOptions;

  List<String> customTagNames = const [];
  Map<String, CustomEvent> customEvents = {};
  final Source source;

  _OptionsBuilder.empty() : source = null;
  _OptionsBuilder(String content, Source source)
      : source = source,
        analysisOptions = loadYaml(content ?? source.contents.data) {
    load();
  }

  void resolve() {
    customTagNames = new List<String>.from(
        getOption('custom_tag_names', isListOfStrings) ?? []);
    getOption('custom_events', isMapOfObjects)
        ?.nodes
        ?.forEach((nameNode, props) {
      final name = (nameNode as YamlScalar).value as String;
      final offset = nameNode.span.start.offset;
      customEvents[nameNode.value] = props is YamlMap
          ? new CustomEvent(name, props['type'], props['path'], offset)
          // Handle `event:` with no value, a shortcut for dynamic.
          : new CustomEvent(name, null, null, offset);
    });
  }

  AngularOptions build() => new AngularOptions(
      customTagNames: customTagNames, customEvents: customEvents);

  void load() {
    if (analysisOptions['analyzer'] == null ||
        analysisOptions['analyzer']['plugins'] == null) {
      return;
    }

    if (loadTopLevelSection() ||
        loadPluginSection('angular') ||
        loadPluginSection('angular_analyzer_plugin')) {
      resolve();
    }
  }

  /// Attempt to load the top level `angular` config section into
  /// [angularOptions]. If the section exists and is a map, return true. This is
  /// the going-forward default case.
  bool loadTopLevelSection() {
    if (analysisOptions['angular'] is Map) {
      angularOptions = analysisOptions['angular'];
      return true;
    }
    return false;
  }

  /// Look for a plugin enabled by name [key], which for historical purposes is
  /// allowed via "angular" or "angular_analyzer_plugin." Return true if that
  /// plugin is specified, and as an edge case, it may have config to load into
  /// [angularOptions]. This will soon be removed.
  bool loadPluginSection(String key) {
    final pluginsSection = analysisOptions['analyzer']['plugins'];

    // This is common. This means the plugin is turned on but has no config.
    if (pluginsSection is List) {
      return pluginsSection.contains(key);
    }

    // Protect against confusing configs
    if (pluginsSection is! Map) {
      return false;
    }

    // Outdated edge case, support a map of options under `plugins: x: ...`.
    final specified = pluginsSection.containsKey(key);
    if (specified) {
      angularOptions = pluginsSection[key];
    }
    return specified;
  }

  dynamic getOption(String key, bool validator(input)) {
    if (angularOptions != null && validator(angularOptions[key])) {
      return angularOptions[key];
    }
    return null;
  }

  bool isListOfStrings(values) =>
      values is List && values.every((value) => value is String);

  bool isMapOfObjects(values) =>
      values is YamlMap &&
      values.values.every((value) => value is YamlMap || value == null);
}
