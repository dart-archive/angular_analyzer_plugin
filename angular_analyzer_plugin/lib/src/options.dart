import 'package:yaml/yaml.dart';

class AngularOptions {
  AngularOptions({this.customTagNames});
  factory AngularOptions.from(String contents) =>
      new _OptionsBuilder(contents).build();
  factory AngularOptions.defaults() => new _OptionsBuilder.empty().build();

  final List<String> customTagNames;
}

class _OptionsBuilder {
  dynamic analysisOptions;
  dynamic angularOptions;
  dynamic angularPluginOptions;

  List<String> customTagNames = const [];

  _OptionsBuilder.empty();
  _OptionsBuilder(String contents) : analysisOptions = loadYaml(contents) {
    load();
  }

  void resolve() {
    customTagNames = getOption('custom_tag_names', isListOfStrings) ?? [];
  }

  AngularOptions build() => new AngularOptions(customTagNames: customTagNames);

  void load() {
    if (analysisOptions['analyzer'] == null ||
        analysisOptions['analyzer']['plugins'] == null) {
      return;
    }

    // default path
    angularOptions = optionsIfEnabled('angular');
    // specific-version path (see project root Readme.md)
    angularPluginOptions = optionsIfEnabled('angular_analyzer_plugin');

    if ((angularOptions ?? angularPluginOptions) != null) {
      resolve();
    }
  }

  dynamic optionsIfEnabled(String key) {
    final section = analysisOptions['analyzer']['plugins'][key];
    if (section != null && section['enabled'] != true) {
      return null;
    }
    return section;
  }

  dynamic getOption(String key, bool validator(input)) {
    if (angularOptions != null && validator(angularOptions[key])) {
      return angularOptions[key];
    } else if (angularPluginOptions != null &&
        validator(angularPluginOptions[key])) {
      return angularPluginOptions[key];
    }
    return null;
  }

  bool isListOfStrings(values) =>
      values is List && values.every((value) => value is String);
}
