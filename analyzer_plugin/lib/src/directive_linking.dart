import 'dart:async';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:angular_analyzer_plugin/src/directive_extraction.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:analyzer/src/dart/resolver/scope.dart';
import 'package:analyzer/dart/ast/standard_ast_factory.dart';
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:front_end/src/scanner/token.dart';
import 'summary/idl.dart';

abstract class FileDirectiveProvider {
  Future<List<AbstractDirective>> getUnlinkedDirectives(String path);
  Future<List<NgContent>> getHtmlNgContent(String path);
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
      final exportAs = dirSum.exportAs == ""
          ? null
          : new AngularElementImpl(dirSum.exportAs, dirSum.exportAsOffset,
              dirSum.exportAs.length, source);
      final selector =
          new SelectorParser(source, dirSum.selectorOffset, dirSum.selectorStr)
              .parse();
      List<ElementNameSelector> elementTags = <ElementNameSelector>[];
      selector.recordElementNameSelectors(elementTags);
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
            new SourceRange(inputSum.propNameOffset, inputSum.propName.length),
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
            new SourceRange(
                outputSum.propNameOffset, outputSum.propName.length),
            bindingSynthesizer.getEventType(getter, getter.name)));
      }
      if (dirSum.isComponent) {
        final ngContents = deserializeNgContents(dirSum.ngContents, source);
        final component = new Component(classElem,
            exportAs: exportAs,
            selector: selector,
            inputs: inputs,
            outputs: outputs,
            ngContents: ngContents,
            elementTags: elementTags);
        directives.add(component);
        final subDirectives = <DirectiveReference>[];
        for (final useSum in dirSum.subdirectives) {
          subDirectives.add(new DirectiveReference(useSum.name, useSum.prefix,
              new SourceRange(useSum.offset, useSum.length)));
        }
        var templateUriSource = null;
        var templateUrlRange = null;
        if (dirSum.templateUrl != '') {
          templateUriSource =
              _directiveLinkerEnablement.getSource(dirSum.templateUrl);
          templateUrlRange = new SourceRange(
              dirSum.templateUrlOffset, dirSum.templateUrlLength);
        }
        component.view = new View(classElem, component, [],
            templateText: dirSum.templateText,
            templateOffset: dirSum.templateOffset,
            templateUriSource: templateUriSource,
            templateUrlRange: templateUrlRange,
            directiveReferences: subDirectives);
      } else {
        final directive = new Directive(classElem,
            exportAs: exportAs,
            selector: selector,
            inputs: inputs,
            outputs: outputs,
            elementTags: elementTags);
        directives.add(directive);
      }
    }

    for (final dirSum in unlinked.directiveSummaries) {
      final directive = directives
          .singleWhere((d) => d.classElement.name == dirSum.decoratedClassName);
      if (directive is Component) {}
    }

    return directives;
  }

  List<ElementNameSelector> _getElementTagsFromSelector(Selector selector) {
    List<ElementNameSelector> elementTags = <ElementNameSelector>[];
    if (selector is ElementNameSelector) {
      elementTags.add(selector);
    } else if (selector is OrSelector) {
      for (Selector innerSelector in selector.selectors) {
        elementTags.addAll(_getElementTagsFromSelector(innerSelector));
      }
    } else if (selector is AndSelector) {
      for (Selector innerSelector in selector.selectors) {
        elementTags.addAll(_getElementTagsFromSelector(innerSelector));
      }
    }
    return elementTags;
  }

  List<NgContent> deserializeNgContents(
      List<SummarizedNgContent> ngContentSums, Source source) {
    return ngContentSums.map((ngContentSum) {
      final selector = ngContentSum.selectorStr == ""
          ? null
          : new SelectorParser(
                  source, ngContentSum.selectorOffset, ngContentSum.selectorStr)
              .parse();
      return new NgContent.withSelector(
          ngContentSum.offset,
          ngContentSum.length,
          selector,
          selector?.offset,
          ngContentSum.selectorStr.length);
    }).toList();
  }
}

class ChildDirectiveLinker {
  final FileDirectiveProvider _fileDirectiveProvider;
  final ErrorReporter _errorReporter;

  ChildDirectiveLinker(this._fileDirectiveProvider, this._errorReporter);

  Future linkDirectives(
    List<AbstractDirective> directivesToLink,
    LibraryElement library,
  ) async {
    final scope = new LibraryScope(library);
    for (final directive in directivesToLink) {
      if (directive is Component && directive.view != null) {
        for (final reference in directive.view.directiveReferences) {
          final referent = lookupByName(reference, directivesToLink);
          if (referent != null) {
            directive.view.directives.add(await withNgContent(referent));
          } else {
            await lookupFromLibrary(
                reference, scope, directive.view.directives);
          }
        }
      }
    }
  }

  AbstractDirective lookupByName(
      DirectiveReference reference, List<AbstractDirective> directivesToLink) {
    if (reference.prefix != "") {
      return null;
    }
    final options =
        directivesToLink.where((d) => d.classElement.name == reference.name);
    if (options.length == 1) {
      return options.first;
    }
    return null;
  }

  Future lookupFromLibrary(DirectiveReference reference, LibraryScope scope,
      List<AbstractDirective> directives) async {
    final type = scope.lookup(
        astFactory.simpleIdentifier(
            new StringToken(TokenType.IDENTIFIER, reference.name, 0)),
        null);

    if (type != null) {
      final fileDirectives = await _fileDirectiveProvider
          .getUnlinkedDirectives(type.source.fullName);

      if (type is ClassElement) {
        final directive = matchDirective(type, fileDirectives);

        if (directive != null) {
          directives.add(await withNgContent(directive));
        } else {
          _errorReporter.reportErrorForOffset(
              AngularWarningCode.TYPE_IS_NOT_A_DIRECTIVE,
              reference.range.offset,
              reference.range.length,
              [type.name]);
        }
        return;
      } else if (type is PropertyAccessorElement) {
        final values = type.variable.constantValue?.toListValue();
        if (values != null) {
          await _addDirectivesAndElementTagsForDartObject(
              directives, fileDirectives, values, reference);
          return;
        }
      }
    }

    _errorReporter.reportErrorForOffset(
        AngularWarningCode.TYPE_LITERAL_EXPECTED,
        reference.range.offset,
        reference.range.length);
  }

  AbstractDirective matchDirective(
      ClassElement clazz, List<AbstractDirective> fileDirectives) {
    final options =
        fileDirectives.where((d) => d.classElement.name == clazz.name);

    if (options.length == 1) {
      return options.first;
    }

    return null;
  }

  /**
   * Walk the given [value] and add directives into [directives].
   * Return `true` if success, or `false` the [value] has items that don't
   * correspond to a directive.
   */
  Future _addDirectivesAndElementTagsForDartObject(
      List<AbstractDirective> directives,
      List<AbstractDirective> fileDirectives,
      List<DartObject> values,
      DirectiveReference reference) async {
    for (DartObject listItem in values) {
      final typeValue = listItem.toTypeValue();
      if (typeValue is InterfaceType && typeValue.element is ClassElement) {
        final directive = matchDirective(typeValue.element, fileDirectives);
        if (directive != null) {
          directives.add(await withNgContent(directive));
        } else {
          _errorReporter.reportErrorForOffset(
              AngularWarningCode.TYPE_IS_NOT_A_DIRECTIVE,
              reference.range.offset,
              reference.range.length,
              [typeValue.name]);
        }
      } else {
        _errorReporter.reportErrorForOffset(
          AngularWarningCode.TYPE_LITERAL_EXPECTED,
          reference.range.offset,
          reference.range.length,
        );
      }
    }
  }

  Future<AbstractDirective> withNgContent(AbstractDirective directive) async {
    if (directive is Component && directive?.view?.templateUriSource != null) {
      final source = directive.view.templateUriSource;
      directive.ngContents.addAll(
          await _fileDirectiveProvider.getHtmlNgContent(source.fullName));
    }
    return directive;
  }
}
