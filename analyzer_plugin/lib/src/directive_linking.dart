import 'dart:async';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:angular_analyzer_plugin/src/directive_extraction.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/src/standard_components.dart';
import 'package:analyzer/src/dart/resolver/scope.dart';
import 'package:analyzer/dart/ast/standard_ast_factory.dart';
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/dart/constant/value.dart';
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
  @override
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
      final elementTags = <ElementNameSelector>[];
      selector.recordElementNameSelectors(elementTags);
      final inputs = <InputElement>[];
      for (final inputSum in dirSum.inputs) {
        // is this correct lookup?
        final setter =
            classElem.lookUpSetter(inputSum.propName, classElem.library);
        if (setter == null) {
          continue;
        }
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
      final outputs = <OutputElement>[];
      for (final outputSum in dirSum.outputs) {
        // is this correct lookup?
        final getter =
            classElem.lookUpGetter(outputSum.propName, classElem.library);
        if (getter == null) {
          continue;
        }
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
      final contentChildFields =
          deserializeContentChildFields(dirSum.contentChildFields);
      final contentChildrenFields =
          deserializeContentChildFields(dirSum.contentChildrenFields);
      if (dirSum.isComponent) {
        final ngContents = deserializeNgContents(dirSum.ngContents, source);
        final component = new Component(classElem,
            exportAs: exportAs,
            selector: selector,
            inputs: inputs,
            outputs: outputs,
            ngContents: ngContents,
            elementTags: elementTags,
            contentChildFields: contentChildFields,
            contentChildrenFields: contentChildrenFields);
        directives.add(component);
        final subDirectives = <DirectiveReference>[];
        for (final useSum in dirSum.subdirectives) {
          subDirectives.add(new DirectiveReference(useSum.name, useSum.prefix,
              new SourceRange(useSum.offset, useSum.length)));
        }
        Source templateUriSource;
        SourceRange templateUrlRange;
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
            elementTags: elementTags,
            contentChildFields: contentChildFields,
            contentChildrenFields: contentChildrenFields);
        directives.add(directive);
      }
    }

    return directives;
  }

  List<NgContent> deserializeNgContents(
          List<SummarizedNgContent> ngContentSums, Source source) =>
      ngContentSums.map((ngContentSum) {
        final selector = ngContentSum.selectorStr == ""
            ? null
            : new SelectorParser(source, ngContentSum.selectorOffset,
                    ngContentSum.selectorStr)
                .parse();
        return new NgContent.withSelector(
            ngContentSum.offset,
            ngContentSum.length,
            selector,
            selector?.offset,
            ngContentSum.selectorStr.length);
      }).toList();

  List<ContentChildField> deserializeContentChildFields(
          List<SummarizedContentChildField> fieldSums) =>
      fieldSums
          .map((fieldSum) => new ContentChildField(fieldSum.fieldName,
              nameRange:
                  new SourceRange(fieldSum.nameOffset, fieldSum.nameLength),
              typeRange:
                  new SourceRange(fieldSum.typeOffset, fieldSum.typeLength)))
          .toList();
}

class ChildDirectiveLinker implements DirectiveMatcher {
  final FileDirectiveProvider _fileDirectiveProvider;
  final ErrorReporter _errorReporter;
  final StandardAngular _standardAngular;

  ChildDirectiveLinker(
      this._fileDirectiveProvider, this._standardAngular, this._errorReporter);

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
            directive.view.directives
                .add(await withNgContentAndChildren(referent));
          } else {
            await lookupFromLibrary(
                reference, scope, directive.view.directives);
          }
        }
      }

      await new ContentChildLinker(
              directive, this, _standardAngular, _errorReporter)
          .linkContentChildren();
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

    if (type != null && type.source != null) {
      final fileDirectives = await _fileDirectiveProvider
          .getUnlinkedDirectives(type.source.fullName);

      if (type is ClassElement) {
        final directive = await matchDirective(type);

        if (directive != null) {
          directives.add(await withNgContentAndChildren(directive));
        } else {
          _errorReporter.reportErrorForOffset(
              AngularWarningCode.TYPE_IS_NOT_A_DIRECTIVE,
              reference.range.offset,
              reference.range.length,
              [type.name]);
        }
        return;
      } else if (type is PropertyAccessorElement) {
        type.variable.computeConstantValue();
        final values = type.variable.constantValue?.toListValue();
        if (values != null) {
          await _addDirectivesAndElementTagsForDartObject(
              directives, fileDirectives, values, reference);
          return;
        }

        _errorReporter.reportErrorForOffset(
            AngularWarningCode.TYPE_IS_NOT_A_DIRECTIVE,
            reference.range.offset,
            reference.range.length,
            [type.variable.constantValue.toString()]);

        return;
      }
    }

    _errorReporter.reportErrorForOffset(
        AngularWarningCode.TYPE_LITERAL_EXPECTED,
        reference.range.offset,
        reference.range.length);
  }

  @override
  Future<AbstractDirective> matchDirective(ClassElement clazz) async {
    final fileDirectives = await _fileDirectiveProvider
        .getUnlinkedDirectives(clazz.source.fullName);
    final options =
        fileDirectives.where((d) => d.classElement.name == clazz.name);

    if (options.length == 1) {
      return options.first;
    }

    return null;
  }

  /// Walk the given [value] and add directives into [directives].
  /// Return `true` if success, or `false` the [value] has items that don't
  /// correspond to a directive.
  Future _addDirectivesAndElementTagsForDartObject(
      List<AbstractDirective> directives,
      List<AbstractDirective> fileDirectives,
      List<DartObject> values,
      DirectiveReference reference) async {
    for (final listItem in values) {
      final typeValue = listItem.toTypeValue();
      if (typeValue is InterfaceType && typeValue.element is ClassElement) {
        final directive = await matchDirective(typeValue.element);
        if (directive != null) {
          directives.add(await withNgContentAndChildren(directive));
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

  Future<AbstractDirective> withNgContentAndChildren(
      AbstractDirective directive) async {
    if (directive is Component && directive?.view?.templateUriSource != null) {
      final source = directive.view.templateUriSource;
      directive.ngContents.addAll(
          await _fileDirectiveProvider.getHtmlNgContent(source.fullName));
    }

    // NOTE: Require the Exact type TemplateRef because that's what the
    // injector does.
    directive.looksLikeTemplate = directive.classElement.constructors.any(
        (constructor) => constructor.parameters
            .any((param) => param.type == _standardAngular.templateRef.type));

    // ignore errors from linking subcomponents content childs
    final errorIgnorer = new ErrorReporter(
        new IgnoringErrorListener(), directive.classElement.source);
    await new ContentChildLinker(
            directive, this, _standardAngular, errorIgnorer)
        .linkContentChildren();
    return directive;
  }
}

abstract class DirectiveMatcher {
  Future<AbstractDirective> matchDirective(ClassElement clazz);
}

class ContentChildLinker {
  final AnalysisContext _context;
  final ErrorReporter _errorReporter;
  final AbstractDirective _directive;
  final DirectiveMatcher _directiveMatcher;
  final StandardAngular _standardAngular;

  ContentChildLinker(AbstractDirective directive, this._directiveMatcher,
      this._standardAngular, this._errorReporter)
      : _context =
            directive.classElement.enclosingElement.enclosingElement.context,
        _directive = directive;

  Future linkContentChildren() async {
    final unit = _directive.classElement.enclosingElement.enclosingElement;
    final bindingSynthesizer = new BindingTypeSynthesizer(
        _directive.classElement,
        unit.context.typeProvider,
        unit.context,
        _errorReporter);

    for (final childField in _directive.contentChildFields) {
      await recordContentChildOrChildren(childField, unit.library,
          bindingSynthesizer, transformSetterTypeSingular,
          annotationName: "ContentChild",
          destinationArray: _directive.contentChilds);
    }
    for (final childrenField in _directive.contentChildrenFields) {
      await recordContentChildOrChildren(childrenField, unit.library,
          bindingSynthesizer, transformSetterTypeMultiple,
          annotationName: "ContentChildren",
          destinationArray: _directive.contentChildren);
    }
  }

  /// ConstantValue.getField() doesn't look up the inheritance tree. Rather than
  /// hardcoding the inheritance tree in our code, look up the inheritance tree
  /// until either it ends, or we find a "selector" field.
  DartObject getSelectorWithInheritance(DartObject value) {
    final selector = value.getField("selector");
    if (selector != null) {
      return selector;
    }

    final _super = value.getField("(super)");
    if (_super != null) {
      return getSelectorWithInheritance(_super);
    }

    return null;
  }

  Future recordContentChildOrChildren(
      ContentChildField field,
      LibraryElement library,
      BindingTypeSynthesizer bindingSynthesizer,
      TransformSetterTypeFn transformSetterTypeFn,
      {List<ContentChild> destinationArray,
      String annotationName}) async {
    final member =
        _directive.classElement.lookUpSetter(field.fieldName, library);
    if (member == null) {
      return;
    }

    final metadata = new List<ElementAnnotation>.from(member.metadata)
      ..addAll(member.variable.metadata);
    final annotations = metadata.where((annotation) =>
        annotation.element?.enclosingElement?.name == annotationName);

    // This can happen for invalid dart
    if (annotations.length != 1) {
      return;
    }

    final annotation = annotations.first;

    // constantValue.getField() doesn't do inheritance. Do that ourself.
    final value = getSelectorWithInheritance(annotation.computeConstantValue());
    if (value?.toStringValue() != null) {
      final setterType = transformSetterTypeFn(
          bindingSynthesizer.getSetterType(member), field, annotationName);
      destinationArray.add(new ContentChild(field,
          new LetBoundQueriedChildType(value.toStringValue(), setterType)));
    } else if (value?.toTypeValue() != null) {
      final type = value.toTypeValue();
      final referencedDirective =
          await _directiveMatcher.matchDirective(type.element);
      if (referencedDirective != null) {
        destinationArray.add(new ContentChild(
            field, new DirectiveQueriedChildType(referencedDirective)));
      } else if (type.element.name == "ElementRef") {
        destinationArray
            .add(new ContentChild(field, new ElementRefQueriedChildType()));
      } else if (type.element.name == "TemplateRef") {
        destinationArray
            .add(new ContentChild(field, new TemplateRefQueriedChildType()));
      } else {
        _errorReporter.reportErrorForOffset(
            AngularWarningCode.UNKNOWN_CHILD_QUERY_TYPE,
            field.nameRange.offset,
            field.nameRange.length,
            [field.fieldName, annotationName]);
        return;
      }

      final setterType = transformSetterTypeFn(
          bindingSynthesizer.getSetterType(member), field, annotationName);
      checkQueriedTypeAssignableTo(setterType, type, field, annotationName);
    } else {
      _errorReporter.reportErrorForOffset(
          AngularWarningCode.UNKNOWN_CHILD_QUERY_TYPE,
          field.nameRange.offset,
          field.nameRange.length,
          [field.fieldName, annotationName]);
    }
  }

  void checkQueriedTypeAssignableTo(DartType setterType, DartType annotatedType,
      ContentChildField field, String annotationName) {
    if (setterType != null && !setterType.isSupertypeOf(annotatedType)) {
      _errorReporter.reportErrorForOffset(
          AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
          field.typeRange.offset,
          field.typeRange.length,
          [field.fieldName, annotationName, annotatedType, setterType]);
    }
  }

  DartType transformSetterTypeSingular(DartType setterType,
          ContentChildField field, String annotationName) =>
      setterType;

  DartType transformSetterTypeMultiple(
      DartType setterType, ContentChildField field, String annotationName) {
    // construct QueryList<Bottom>, which is a supertype of all QueryList<T>
    // NOTE: In most languages, you'd need QueryList<Object>, but not dart.
    final queryListBottom = _standardAngular.queryList.type
        .instantiate([_context.typeProvider.bottomType]);

    final isQueryList = setterType.isSupertypeOf(queryListBottom);

    if (!isQueryList) {
      _errorReporter.reportErrorForOffset(
          AngularWarningCode.CONTENT_OR_VIEW_CHILDREN_REQUIRES_QUERY_LIST,
          field.typeRange.offset,
          field.typeRange.length,
          [field.fieldName, annotationName, setterType]);

      return _context.typeProvider.dynamicType;
    }

    final iterableType = _context.typeProvider.iterableType;

    // get T for setterTypes that extend Iterable<T>
    return _context.typeSystem
        .mostSpecificTypeArgument(setterType, iterableType);
  }
}

typedef DartType TransformSetterTypeFn(
    DartType setterType, ContentChildField field, String annotationName);
