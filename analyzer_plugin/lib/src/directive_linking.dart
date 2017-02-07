import 'dart:async';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/directive_extraction.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:analyzer/src/dart/resolver/scope.dart';
import 'package:analyzer/dart/ast/standard_ast_factory.dart';
import 'package:front_end/src/scanner/token.dart';
import 'summary/idl.dart';

abstract class FileDirectiveProvider {
  Future<List<AbstractDirective>> getUnlinkedDirectives(String path);
}

abstract class DirectiveLinkerEnablement {
  Future<CompilationUnitElement> getUnit(String path);
  Source getSource(String path);
}

class IgnoringErrorListener implements AnalysisErrorListener {
  void onError(Object o) {}
}

class DirectiveLinker {
  final DirectiveLinkerEnablement _directiveLinkerEnablement;

  DirectiveLinker(this._directiveLinkerEnablement);

  Future<List<AbstractDirective>> resynthesizeDirectives(
      UnlinkedDartSummary unlinked, String path) async {
    if (unlinked == null) {
      return [];
    }

    final unit = await _directiveLinkerEnablement.getUnit(path);

    final source = unit.source;

    final directives = <AbstractDirective>[];

    for (final dirSum in unlinked.directiveSummaries) {
      final classElem = unit.getType(dirSum.decoratedClassName);
      final bindingSynthesizer = new BindingTypeSynthesizer(
          classElem,
          unit.context.typeProvider,
          unit.context,
          new ErrorReporter(new IgnoringErrorListener(), unit.source));
      final exportAs = dirSum.exportAs == null
          ? null
          : new AngularElementImpl(dirSum.exportAs, dirSum.exportAsOffset,
              dirSum.exportAs.length, source);
      final selector =
          new SelectorParser(source, dirSum.selectorOffset, dirSum.selectorStr)
              .parse();
      final List<InputElement> inputs = [];
      for (final inputSum in dirSum.inputs) {
        // is this correct lookup?
        final setter =
            classElem.lookUpSetter(inputSum.propName, classElem.library);
        if (setter == null) continue;
        inputs.add(new InputElement(
            inputSum.name,
            inputSum.nameOffset,
            inputSum.name.length,
            source,
            setter,
            new SourceRange(setter.nameOffset, setter.name.length),
            bindingSynthesizer
                .getSetterType(setter))); // Don't think type is correct
      }
      final List<OutputElement> outputs = [];
      for (final outputSum in dirSum.outputs) {
        // is this correct lookup?
        final getter =
            classElem.lookUpGetter(outputSum.propName, classElem.library);
        if (getter == null) continue;
        outputs.add(new OutputElement(
            outputSum.name,
            outputSum.nameOffset,
            outputSum.name.length,
            source,
            getter,
            new SourceRange(getter.nameOffset, getter.nameLength),
            bindingSynthesizer.getEventType(getter, getter.name)));
      }
      if (dirSum.isComponent) {
        final component = new Component(classElem,
            exportAs: exportAs,
            selector: selector,
            inputs: inputs,
            outputs: outputs);
        directives.add(component);
        // TODO get subdirectives from summary
        final subDirectives = <String>[];
        for (final useSum in dirSum.subdirectives) {
          subDirectives.add(useSum.name);
        }
        component.view = new View(classElem, component, [],
            templateText: dirSum.templateText,
            templateOffset: dirSum.templateOffset,
            templateUriSource: dirSum.templateUrl == ''
                ? null
                : _directiveLinkerEnablement.getSource(dirSum.templateUrl),
            directiveNames: subDirectives);
      } else {
        final directive = new Directive(classElem,
            exportAs: exportAs,
            selector: selector,
            inputs: inputs,
            outputs: outputs);
        directives.add(directive);
      }
    }

    final scope = new LibraryScope(unit.library);
    for (final dirSum in unlinked.directiveSummaries) {
      final directive = directives
          .singleWhere((d) => d.classElement.name == dirSum.decoratedClassName);
      if (directive is Component) {}
    }

    return directives;
  }
}

class ChildDirectiveLinker {
  final FileDirectiveProvider _fileDirectiveProvider;

  ChildDirectiveLinker(this._fileDirectiveProvider);

  Future linkDirectives(
    List<AbstractDirective> directivesToLink,
    LibraryElement library,
  ) async {
    final scope = new LibraryScope(library);
    for (final directive in directivesToLink) {
      if (directive is Component) {
        for (final name in directive.view.directiveNames) {
          final options =
              directivesToLink.where((d) => d.classElement.name == name);
          if (options.length == 1) {
            directive.view.directives.add(options.first);
          } else {
            final type = scope.lookup(
                astFactory.simpleIdentifier(
                    new StringToken(TokenType.IDENTIFIER, name, 0)),
                directive.classElement.library);
            if (type == null) {
              continue;
            }

            final fileDirectives = await _fileDirectiveProvider
                .getUnlinkedDirectives(type.source.fullName);
            final fileDirectivesOptions =
                fileDirectives.where((d) => d.classElement.name == name);

            if (fileDirectivesOptions.length != 1) {
              continue;
            }

            directive.view.directives.add(fileDirectivesOptions.first);
          }
        }
      }
    }
  }
}
