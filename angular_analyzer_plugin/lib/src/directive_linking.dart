import 'dart:async';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/ast/ast.dart'
    show SimpleIdentifier, PrefixedIdentifier, Identifier;
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart' show SourceRange, Source;
import 'package:angular_analyzer_plugin/errors.dart';
import 'package:angular_analyzer_plugin/src/directive_extraction.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/src/standard_components.dart';
import 'package:analyzer/src/dart/resolver/scope.dart';
import 'package:analyzer/dart/ast/standard_ast_factory.dart';
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'summary/idl.dart';

abstract class FileDirectiveProvider {
  Future<List<AngularAnnotatedClass>> getUnlinkedClasses(String path);
  Future<List<NgContent>> getHtmlNgContent(String path);
}

abstract class FilePipeProvider {
  Future<List<Pipe>> getUnlinkedPipes(String path);
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

  Future<List<AngularAnnotatedClass>> resynthesizeDirectives(
      UnlinkedDartSummary unlinked, String path) async {
    if (unlinked == null) {
      return [];
    }

    final unit = await _directiveLinkerEnablement.getUnit(path);

    final source = unit.source;

    final annotatedClasses = <AngularAnnotatedClass>[];

    for (final dirSum in unlinked.directiveSummaries) {
      final classElem = unit.getType(dirSum.classAnnotations.className);
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
      final inputs = deserializeInputs(
          dirSum.classAnnotations, classElem, source, bindingSynthesizer);
      final outputs = deserializeOutputs(
          dirSum.classAnnotations, classElem, source, bindingSynthesizer);
      final contentChildFields = deserializeContentChildFields(
          dirSum.classAnnotations.contentChildFields);
      final contentChildrenFields = deserializeContentChildFields(
          dirSum.classAnnotations.contentChildrenFields);
      if (dirSum.isComponent) {
        final ngContents = deserializeNgContents(dirSum.ngContents, source);
        final exports = deserializeExports(dirSum.exports);
        final pipeRefs = deserializePipes(dirSum.pipesUse);
        final component = new Component(classElem,
            exportAs: exportAs,
            selector: selector,
            inputs: inputs,
            outputs: outputs,
            isHtml: false,
            ngContents: ngContents,
            elementTags: elementTags,
            contentChildFields: contentChildFields,
            contentChildrenFields: contentChildrenFields);
        annotatedClasses.add(component);
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
        component.view = new View(classElem, component, [], [],
            templateText: dirSum.templateText,
            templateOffset: dirSum.templateOffset,
            templateUriSource: templateUriSource,
            templateUrlRange: templateUrlRange,
            directiveReferences: subDirectives,
            exports: exports,
            pipeReferences: pipeRefs);
      } else {
        annotatedClasses.add(new Directive(classElem,
            exportAs: exportAs,
            selector: selector,
            inputs: inputs,
            outputs: outputs,
            elementTags: elementTags,
            contentChildFields: contentChildFields,
            contentChildrenFields: contentChildrenFields));
      }
    }

    for (final annotations in unlinked.annotatedClasses) {
      final classElem = unit.getType(annotations.className);
      final bindingSynthesizer = new BindingTypeSynthesizer(
          classElem,
          unit.context.typeProvider,
          unit.context,
          new ErrorReporter(new IgnoringErrorListener(), unit.source));
      final inputs =
          deserializeInputs(annotations, classElem, source, bindingSynthesizer);
      final outputs = deserializeOutputs(
          annotations, classElem, source, bindingSynthesizer);
      final contentChildFields =
          deserializeContentChildFields(annotations.contentChildFields);
      final contentChildrenFields =
          deserializeContentChildFields(annotations.contentChildrenFields);
      annotatedClasses.add(new AngularAnnotatedClass(classElem, inputs, outputs,
          contentChildFields, contentChildrenFields));
    }

    return annotatedClasses;
  }

  List<InputElement> deserializeInputs(
      SummarizedClassAnnotations annotations,
      ClassElement classElem,
      Source source,
      BindingTypeSynthesizer bindingSynthesizer) {
    final inputs = <InputElement>[];
    for (final inputSum in annotations.inputs) {
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

    return inputs;
  }

  List<OutputElement> deserializeOutputs(
      SummarizedClassAnnotations annotations,
      ClassElement classElem,
      Source source,
      BindingTypeSynthesizer bindingSynthesizer) {
    final outputs = <OutputElement>[];
    for (final outputSum in annotations.outputs) {
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
          new SourceRange(outputSum.propNameOffset, outputSum.propName.length),
          bindingSynthesizer.getEventType(getter, getter.name)));
    }

    return outputs;
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

  List<PipeReference> deserializePipes(List<SummarizedPipesUse> pipesUse) =>
      pipesUse
          .map((pipeUse) => new PipeReference(
              pipeUse.name, new SourceRange(pipeUse.offset, pipeUse.length),
              prefix: pipeUse.prefix))
          .toList();

  List<ExportedIdentifier> deserializeExports(
          List<SummarizedExportedIdentifier> exports) =>
      exports
          .map((export) => new ExportedIdentifier(
              export.name, new SourceRange(export.offset, export.length),
              prefix: export.prefix))
          .toList();

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

class ExportLinker {
  final LibraryScope _scope;
  final ErrorReporter _errorReporter;

  ExportLinker(this._scope, this._errorReporter);

  void linkExportsFor(AbstractDirective directive) {
    if (directive is! Component) {
      return;
    }

    final Component component = directive;

    if (component?.view?.exports == null) {
      return;
    }

    for (final export in component.view.exports) {
      if (hasWrongTypeOfPrefix(export)) {
        _errorReporter.reportErrorForOffset(
            AngularWarningCode.EXPORTS_MUST_BE_PLAIN_IDENTIFIERS,
            export.span.offset,
            export.span.length);
        continue;
      }

      final element = _scope.lookup(getIdentifier(export), null);
      if (element == component.classElement) {
        _errorReporter.reportErrorForOffset(
            AngularWarningCode.COMPONENTS_CANT_EXPORT_THEMSELVES,
            export.span.offset,
            export.span.length);
        continue;
      }

      export.element = element;
    }
  }

  /// Only report false for known non-import-prefix prefixes, the rest get
  /// flagged by the dart analyzer already.
  bool hasWrongTypeOfPrefix(ExportedIdentifier export) {
    if (export.prefix == '') {
      return false;
    }

    final prefixElement =
        _scope.lookup(getPrefixAsSimpleIdentifier(export), null);

    return prefixElement != null && prefixElement is! PrefixElement;
  }

  Identifier getIdentifier(ExportedIdentifier export) => export.prefix == ''
      ? getSimpleIdentifier(export)
      : getPrefixedIdentifier(export);

  PrefixedIdentifier getPrefixedIdentifier(ExportedIdentifier export) =>
      astFactory.prefixedIdentifier(
          getPrefixAsSimpleIdentifier(export),
          new SimpleToken(
              TokenType.PERIOD, export.span.offset + export.prefix.length),
          getSimpleIdentifier(export, offset: export.prefix.length + 1));

  SimpleIdentifier getPrefixAsSimpleIdentifier(ExportedIdentifier export) =>
      astFactory.simpleIdentifier(new StringToken(
          TokenType.IDENTIFIER, export.prefix, export.span.offset));

  SimpleIdentifier getSimpleIdentifier(ExportedIdentifier export,
          {int offset: 0}) =>
      astFactory.simpleIdentifier(new StringToken(TokenType.IDENTIFIER,
          export.identifier, export.span.offset + offset));
}

class InheritedMetadataLinker {
  AbstractDirective directive;
  FileDirectiveProvider _fileDirectiveProvider;
  BindingTypeSynthesizer bindingSynthesizer;

  InheritedMetadataLinker(this.directive, this._fileDirectiveProvider)
      : bindingSynthesizer = new BindingTypeSynthesizer(
            directive.classElement,
            directive.classElement.library.definingCompilationUnit.context
                .typeProvider,
            directive.classElement.library.definingCompilationUnit.context,
            new ErrorReporter(new IgnoringErrorListener(), directive.source));

  Future link() async {
    for (final supertype in directive.classElement.allSupertypes) {
      final result = await _fileDirectiveProvider
          .getUnlinkedClasses(supertype.element.source.fullName);
      final match = result.firstWhere(
          (c) => c.classElement == supertype.element,
          orElse: () => null);

      if (match == null) {
        continue;
      }

      directive.inputs.addAll(match.inputs.map(reresolveInput));
      directive.outputs.addAll(match.outputs.map(reresolveOutput));
      directive.contentChildFields.addAll(match.contentChildFields);
      directive.contentChildrenFields.addAll(match.contentChildrenFields);
    }
  }

  InputElement reresolveInput(InputElement input) {
    final setter = directive.classElement.lookUpSetter(
        input.setter.name.replaceAll('=', ''), directive.classElement.library);
    if (setter == null) {
      // Happens when an interface with an input isn't implemented correctly.
      // This will be accompanied by a dart error, so we can just return the
      // original without transformation to prevent cascading errors.
      return input;
    }
    return new InputElement(
        input.name,
        input.nameOffset,
        input.nameLength,
        input.source,
        setter,
        new SourceRange(setter.nameOffset, setter.nameLength),
        bindingSynthesizer.getSetterType(setter));
  }

  OutputElement reresolveOutput(OutputElement output) {
    final getter = directive.classElement
        .lookUpGetter(output.getter.name, directive.classElement.library);
    if (getter == null) {
      // Happens when an interface with an output isn't implemented correctly.
      // This will be accompanied by a dart error, so we can just return the
      // original without transformation to prevent cascading errors.
      return output;
    }
    return new OutputElement(
        output.name,
        output.nameOffset,
        output.nameLength,
        output.source,
        getter,
        new SourceRange(getter.nameOffset, getter.nameLength),
        bindingSynthesizer.getEventType(getter, output.name));
  }
}

class ChildDirectiveLinker implements DirectiveMatcher {
  final FileDirectiveProvider _fileDirectiveProvider;
  final FilePipeProvider _filePipeProvider;
  final ErrorReporter _errorReporter;
  final StandardAngular _standardAngular;

  ChildDirectiveLinker(this._fileDirectiveProvider, this._filePipeProvider,
      this._standardAngular, this._errorReporter);

  Future linkDirectivesAndPipes(
    List<AbstractDirective> directivesToLink,
    List<Pipe> pipesToLink,
    LibraryElement library,
  ) async {
    final scope = new LibraryScope(library);
    final exportLinker = new ExportLinker(scope, _errorReporter);
    for (final directive in directivesToLink) {
      if (directive is Component && directive.view != null) {
        // Link directive references to actual directive definition.
        for (final reference in directive.view.directiveReferences) {
          final referent = lookupDirectiveByName(reference, directivesToLink);
          if (referent != null) {
            directive.view.directives.add(await linkedAsChild(referent));
          } else {
            await lookupDirectiveFromLibrary(
                reference, scope, directive.view.directives);
          }
        }
        // Link pipe references to actual pipe definition.
        for (final reference in directive.view.pipeReferences) {
          final referent = lookupPipeByName(reference, pipesToLink);
          if (referent != null) {
            directive.view.pipes.add(referent);
          } else {
            await lookupPipeFromLibrary(reference, scope, directive.view.pipes);
          }
        }
      }

      exportLinker.linkExportsFor(directive);
      await new InheritedMetadataLinker(directive, _fileDirectiveProvider)
          .link();

      await new ContentChildLinker(
              directive, this, _standardAngular, _errorReporter)
          .linkContentChildren();
    }
  }

  AbstractDirective lookupDirectiveByName(
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

  Pipe lookupPipeByName(PipeReference reference, List<Pipe> pipesToLink) {
    if (reference.prefix != '') {
      return null;
    }
    final options =
        pipesToLink.where((p) => p.classElement.name == reference.identifier);
    if (options.length == 1) {
      return options.first;
    }
    return null;
  }

  Future lookupDirectiveFromLibrary(DirectiveReference reference,
      LibraryScope scope, List<AbstractDirective> directives) async {
    final type = scope.lookup(
        astFactory.simpleIdentifier(
            new StringToken(TokenType.IDENTIFIER, reference.name, 0)),
        null);

    if (type != null && type.source != null) {
      if (type is ClassElement) {
        final directive = await matchDirective(type);

        if (directive != null) {
          directives.add(await linkedAsChild(directive));
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
              directives, values, reference.range);
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

  Future lookupPipeFromLibrary(
      PipeReference reference, LibraryScope scope, List<Pipe> pipes) async {
    final type = scope.lookup(
        astFactory.simpleIdentifier(
            new StringToken(TokenType.IDENTIFIER, reference.identifier, 0)),
        null);
    if (type != null && type.source != null) {
      if (type is ClassElement) {
        final pipe = await matchPipe(type);

        if (pipe != null) {
          pipes.add(pipe);
        } else {
          _errorReporter.reportErrorForOffset(
              AngularWarningCode.TYPE_IS_NOT_A_PIPE,
              reference.span.offset,
              reference.span.length,
              [type.name]);
        }
        return;
      } else if (type is PropertyAccessorElement) {
        type.variable.computeConstantValue();
        final values = type.variable.constantValue?.toListValue();
        if (values != null) {
          await _addPipesForDartObject(pipes, values, reference.span);
          return;
        }

        _errorReporter.reportErrorForOffset(
            AngularWarningCode.TYPE_IS_NOT_A_PIPE,
            reference.span.offset,
            reference.span.length,
            [type.variable.constantValue.toString()]);

        return;
      }
    }

    _errorReporter.reportErrorForOffset(
        AngularWarningCode.TYPE_LITERAL_EXPECTED,
        reference.span.offset,
        reference.span.length);
  }

  @override
  Future<AbstractDirective> matchDirective(ClassElement clazz) async {
    final fileDirectives =
        await _fileDirectiveProvider.getUnlinkedClasses(clazz.source.fullName);
    final options = fileDirectives
        .where((d) => d.classElement.name == clazz.name)
        .where((d) => d is AbstractDirective);

    if (options.length == 1) {
      return options.first;
    }

    return null;
  }

  @override
  Future<Pipe> matchPipe(ClassElement clazz) async {
    final filePipes =
        await _filePipeProvider.getUnlinkedPipes(clazz.source.fullName);
    final options = filePipes.where((p) => p.classElement.name == clazz.name);
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
      List<DartObject> values,
      SourceRange errorRange) async {
    for (final listItem in values) {
      final typeValue = listItem.toTypeValue();
      if (typeValue is InterfaceType && typeValue.element is ClassElement) {
        final directive = await matchDirective(typeValue.element);
        if (directive != null) {
          directives.add(await linkedAsChild(directive));
        } else {
          _errorReporter.reportErrorForOffset(
              AngularWarningCode.TYPE_IS_NOT_A_DIRECTIVE,
              errorRange.offset,
              errorRange.length,
              [typeValue.name]);
        }
      } else {
        final listValue = listItem.toListValue();
        if (listValue != null) {
          await _addDirectivesAndElementTagsForDartObject(
              directives, listValue, errorRange);
        } else {
          _errorReporter.reportErrorForOffset(
            AngularWarningCode.TYPE_LITERAL_EXPECTED,
            errorRange.offset,
            errorRange.length,
          );
        }
      }
    }
  }

  /// Walk the given [value] and add pipes into [pipes].
  /// Return `true` if success, or `false` the [value] has items
  /// that don't correspond to a pipe.
  Future _addPipesForDartObject(
      List<Pipe> pipes, List<DartObject> values, SourceRange errorRange) async {
    for (final listItem in values) {
      final typeValue = listItem.toTypeValue();
      if (typeValue is InterfaceType && typeValue.element is ClassElement) {
        final pipe = await matchPipe(typeValue.element);
        if (pipe != null) {
          pipes.add(pipe);
        } else {
          _errorReporter.reportErrorForOffset(
              AngularWarningCode.TYPE_IS_NOT_A_PIPE,
              errorRange.offset,
              errorRange.length,
              [typeValue.name]);
        }
      } else {
        final listValue = listItem.toListValue();
        if (listValue != null) {
          await _addPipesForDartObject(pipes, listValue, errorRange);
        } else {
          _errorReporter.reportErrorForOffset(
            AngularWarningCode.TYPE_LITERAL_EXPECTED,
            errorRange.offset,
            errorRange.length,
          );
        }
      }
    }
  }

  Future<AbstractDirective> linkedAsChild(AbstractDirective directive) async {
    if (directive is Component && directive?.view?.templateUriSource != null) {
      final source = directive.view.templateUriSource;
      directive.ngContents.addAll(
          await _fileDirectiveProvider.getHtmlNgContent(source.fullName));
    }

    // Important: Link inherited metadata before content child fields, as
    // the directive may import unlinked content childs
    await new InheritedMetadataLinker(directive, _fileDirectiveProvider).link();

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
  Future<Pipe> matchPipe(ClassElement clazz);
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

  /// See [getFieldWithInheritance]
  DartObject getSelectorWithInheritance(DartObject value) =>
      getFieldWithInheritance(value, 'selector');

  /// See [getFieldWithInheritance]
  String getReadWithInheritance(DartObject value) {
    final constantVal = getFieldWithInheritance(value, 'read');
    if (constantVal.isNull) {
      return null;
    }

    // TODO: track more types of these values, once we use this.
    return constantVal.toStringValue() ??
        constantVal.toTypeValue()?.toString() ??
        constantVal.toString();
  }

  /// ConstantValue.getField() doesn't look up the inheritance tree. Rather than
  /// hardcoding the inheritance tree in our code, look up the inheritance tree
  /// until either it ends, or we find a "selector" field.
  DartObject getFieldWithInheritance(DartObject value, String field) {
    final selector = value.getField(field);
    if (selector != null) {
      return selector;
    }

    final _super = value.getField('(super)');
    if (_super != null) {
      return getFieldWithInheritance(_super, field);
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
    final annotationValue = annotation.computeConstantValue();

    // `constantValue.getField()` doesn't do inheritance. Do that ourself.
    final value = getSelectorWithInheritance(annotationValue);
    final read = getReadWithInheritance(annotationValue);

    if (value?.toStringValue() != null) {
      // Take the type -- except, we can't validate DI symbols via `read`.
      final setterType = read == null
          ? transformSetterTypeFn(
              bindingSynthesizer.getSetterType(member), field, annotationName)
          : _context.typeProvider.dynamicType;

      destinationArray.add(new ContentChild(field,
          new LetBoundQueriedChildType(value.toStringValue(), setterType),
          read: read));
    } else if (value?.toTypeValue() != null) {
      final type = value.toTypeValue();
      final referencedDirective =
          await _directiveMatcher.matchDirective(type.element);

      AbstractQueriedChildType query;
      if (referencedDirective != null) {
        query = new DirectiveQueriedChildType(referencedDirective);
      } else if (type.element.name == 'ElementRef') {
        query = new ElementRefQueriedChildType();
      } else if (type.element.name == 'TemplateRef') {
        query = new TemplateRefQueriedChildType();
      } else {
        _errorReporter.reportErrorForOffset(
            AngularWarningCode.UNKNOWN_CHILD_QUERY_TYPE,
            field.nameRange.offset,
            field.nameRange.length,
            [field.fieldName, annotationName]);
        return;
      }

      destinationArray.add(new ContentChild(field, query, read: read));

      if (read == null) {
        final setterType = transformSetterTypeFn(
            bindingSynthesizer.getSetterType(member), field, annotationName);
        checkQueriedTypeAssignableTo(setterType, type, field, annotationName);
      }
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
