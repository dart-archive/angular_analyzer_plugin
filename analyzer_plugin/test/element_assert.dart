library angular2.src.analysis.analyzer_plugin.src.element_assert;

import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart' show AnalysisContext;
import 'package:analyzer/src/generated/source.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/resolver.dart';
import 'package:angular2_analyzer_plugin/src/selector.dart';
import 'package:unittest/unittest.dart';

class AngularElementAssert extends _AbstractElementAssert {
  final AngularElement element;

  AngularElementAssert(AnalysisContext context, this.element, Source source)
      : super(context, source);

  AngularElementAssert get inCoreHtml {
    _inCoreHtml(element.source);
    return this;
  }

  AngularElementAssert at(String search) {
    _at(element.nameOffset, search);
    return this;
  }
}

class DartElementAssert extends _AbstractElementAssert {
  final Element element;

  DartElementAssert(AnalysisContext context, this.element, Source source)
      : super(context, source);

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
  final AnalysisContext context;
  final String dartCode;
  final Source dartSource;
  final String htmlCode;
  final Source htmlSource;
  final AngularElement element;

  ElementAssert(this.context, this.dartCode, this.dartSource, this.htmlCode,
      this.htmlSource, this.element);

  AngularElementAssert get angular {
    expect(element, new isInstanceOf<AngularElement>());
    return new AngularElementAssert(context, element, dartSource);
  }

  DartElementAssert get dart {
    expect(element, new isInstanceOf<DartElement>());
    DartElement dartElement = element;
    return new DartElementAssert(context, dartElement.element, dartSource);
  }

  LocalVariableAssert get local {
    expect(element, new isInstanceOf<LocalVariable>());
    return new LocalVariableAssert(context, element, htmlSource, htmlCode);
  }

  AngularElementAssert get selector {
    expect(element, new isInstanceOf<SelectorName>());
    return new AngularElementAssert(context, element, dartSource);
  }
}

class LocalVariableAssert extends _AbstractElementAssert {
  final LocalVariable variable;

  LocalVariableAssert(AnalysisContext context, this.variable, Source htmlSource,
      String htmlCode)
      : super(context, htmlSource, htmlCode);

  LocalVariableAssert at(String search) {
    _at(variable.nameOffset, search);
    return this;
  }
}

class _AbstractElementAssert {
  final AnalysisContext context;
  Source source;
  String code;

  _AbstractElementAssert(this.context, [this.source, this.code]);

  void _at(int actualOffset, String search) {
    if (code == null) {
      code = context.getContents(source).data;
    }
    int offset = code.indexOf(search);
    expect(offset, isNonNegative, reason: "|$search| in |$code|");
    expect(actualOffset, offset);
  }

  void _inCoreHtml(Source actualSource) {
    Source htmlLibrarySource = context.sourceFactory.forUri('dart:html');
    expect(actualSource, htmlLibrarySource);
    source = htmlLibrarySource;
    code = null;
  }
}
