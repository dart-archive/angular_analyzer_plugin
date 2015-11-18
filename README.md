# Angular2 Dart Analysis Plugins


## Annotation analysis in Dart files

* Build models for `@Directive` and `@Component` annotations:
    * Parse selector.
    * Build inputs.
    * Report problems for invalid selectors, unresolved input setters, etc.
* Build models for `@View` annotations:
    * Resolve `templateUrl` argument.
    * Validate that specified `directives` are valid directive class literals.
* Resolve inline `@View` templates in Dart files.
* Resolve external `@View` templates referenced from Dart files in context of specified directives and view class members.


## Templates resolution

  Templates resolution is implemented only partially.
  Currently the following feature are done.

* Resolve element tags to `@Component` selectors.
* Resolve of attribute names in forms `name`, `[name]`, `bind-name`, `(event)`, `on-event` to corresponding inputs and events.
* Resolve expressions in interpolations like `<div>{{user.name}}</div>`.
* Resolve expressions in bound inputs like `<text-panel [text]='user.name'>`.
* Support for the `template` attribute `<div template='ng-if items.isNotEmpty'>Has items</div>`.


## Integration with Dart Analysis Server

  To provide information for DAS clients the `server_plugin` plugin contributes several extensions.

* Angular analysis errors are automatically merged into normal `errors` notifications for Dart and HTML files.
* Navigation extension contributes navigation regions:
    * In external HTML templates.
    * In inline templates in Dart files.
    * In Dart annotations:
        * navigation from `templateUrl` to the corresponding HTML files.
        * navigation from input declarations to setters, e.g. to `text` in `inputs: const ['text: my-text']`.
* Occurrences extension reports regions where every Dart element or an input is used in a Dart or HTML file. So, clients of DAS can highlight all of the whe user select one.

