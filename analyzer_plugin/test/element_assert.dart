library angular2.src.analysis.analyzer_plugin.src.element_assert;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:unittest/unittest.dart';

class AngularElementAssert extends _AbstractElementAssert {
  final AngularElement element;

  AngularElementAssert(this.element, Source source) : super(source);

  AngularElementAssert get inCoreHtml {
    _inCoreHtml(element.source);
    return this;
  }

  AngularElementAssert at(String search) {
    _at(element.nameOffset, search);
    return this;
  }

  AngularElementAssert inFileName(String expectedName) {
    expect(element.source.fullName, endsWith(expectedName));
    _source = element.source;
    _code = null;
    return this;
  }

  AngularElementAssert name(String expectedName) {
    expect(element.name, expectedName);
    return this;
  }
}

class DartElementAssert extends _AbstractElementAssert {
  final Element element;

  DartElementAssert(this.element, Source source, String code)
      : super(source, code);

  DartElementAssert get getter {
    expect(element.kind, ElementKind.GETTER);
    return this;
  }

  DartElementAssert get inCoreHtml {
    _inCoreHtml(element.source);
    return this;
  }

  DartElementAssert get method {
    expect(element.kind, ElementKind.METHOD);
    return this;
  }

  DartElementAssert at(String search) {
    _at(element.nameOffset, search);
    return this;
  }
}

class ElementAssert {
  final String _dartCode;
  final Source _dartSource;
  final String _htmlCode;
  final Source _htmlSource;
  final AngularElement element;
  final int _referenceOffset;

  ElementAssert(this._dartCode, this._dartSource, this._htmlCode,
      this._htmlSource, this.element, this._referenceOffset);

  AngularElementAssert get angular {
    expect(element, new isInstanceOf<AngularElement>());
    return new AngularElementAssert(element, _dartSource);
  }

  DartElementAssert get dart {
    expect(element, new isInstanceOf<DartElement>());
    DartElement dartElement = element;
    return new DartElementAssert(dartElement.element, _dartSource, _dartCode);
  }

  AngularElementAssert get input {
    expect(element, new isInstanceOf<InputElement>());
    return new AngularElementAssert(element, _dartSource);
  }

  AngularElementAssert get output {
    expect(element, new isInstanceOf<OutputElement>());
    return new AngularElementAssert(element, _dartSource);
  }

  LocalVariableAssert get local {
    expect(element, new isInstanceOf<LocalVariable>());
    return new LocalVariableAssert(
        element, _referenceOffset, _htmlSource, _htmlCode);
  }

  AngularElementAssert get selector {
    expect(element, new isInstanceOf<SelectorName>());
    return new AngularElementAssert(element, _dartSource);
  }
}

class LocalVariableAssert extends _AbstractElementAssert {
  final LocalVariable variable;
  final int _referenceOffset;

  LocalVariableAssert(
      this.variable, this._referenceOffset, Source htmlSource, String htmlCode)
      : super(htmlSource, htmlCode);

  LocalVariableAssert get declaration {
    expect(variable.nameOffset, _referenceOffset);
    return this;
  }

  LocalVariableAssert at(String search) {
    _at(variable.nameOffset, search);
    return this;
  }

  LocalVariableAssert type(String expectedTypeName) {
    expect(variable.dartVariable.type.displayName, expectedTypeName);
    return this;
  }
}

class _AbstractElementAssert {
  Source _source;
  String _code;

  _AbstractElementAssert([this._source, this._code]);

  void _at(int actualOffset, String search) {
    if (_code == null) {
      _code = _source.contents.data;
    }
    int offset = _code.indexOf(search);
    expect(offset, isNonNegative, reason: "|$search| in |$_code|");
    expect(actualOffset, offset);
  }

  void _inCoreHtml(Source actualSource) {
    expect(actualSource.fullName, '/sdk/lib/html/dartium/html_dartium.dart');
    _source = actualSource;
    _code = null;
  }
}
