import 'package:analysis_server/src/provisional/completion/completion_core.dart';
import 'package:analysis_server/src/provisional/completion/dart/completion_dart.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/task/dart.dart';
import 'package:angular_analyzer_server_plugin/src/completion.dart';
import 'package:angular_analyzer_plugin/src/tasks.dart';
import 'package:unittest/unittest.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'completion_contributor_test_util.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(DartCompletionContributorTest);
  defineReflectiveTests(HtmlCompletionContributorTest);
}

@reflectiveTest
class DartCompletionContributorTest
    extends AbstractDartCompletionContributorTest {
  @override
  setUp() {
    testFile = '/completionTest.dart';
    super.setUp();
  }

  @override
  DartCompletionContributor createContributor() {
    return new AngularDartCompletionContributor();
  }

  test_completeMemberInMustache() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '{{^}}', selector: 'a')
class MyComp {
  String text;
}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
  }

  test_completeMemberInInputBinding() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<h1 [hidden]="^"></h1>', selector: 'a')
class MyComp {
  String text;
}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
  }

  test_completeMemberInClassBinding() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<h1 [class.my-class]="^"></h1>', selector: 'a')
class MyComp {
  String text;
}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
  }

  test_completeMemberInStyleBinding() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<h1 [style.background-color]="^"></h1>', selector: 'a')
class MyComp {
  String text;
}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
  }

  test_completeMemberInAttrBinding() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<h1 [attr.on-click]="^"></h1>', selector: 'a')
class MyComp {
  String text;
}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
  }

  test_completeMemberMustacheAttrBinding() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<h1 title="{{^}}"></h1>', selector: 'a')
class MyComp {
  String text;
}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
  }

  test_completeMultipleMembers() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '{{d^}}', selector: 'a')
class MyComp {
  String text;
  String description;
}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
    assertSuggestGetter('description', 'String');
  }

  test_completeInlineHtmlSelectorTag_at_beginning() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<^<div></div>', selector: 'my-parent', directives: const[MyChildComponent1, MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeInlineHtmlSelectorTag_at_beginning_with_partial() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<my^<div></div>', selector: 'my-parent', directives: const[MyChildComponent1, MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeInlineHtmlSelectorTag_at_middle() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<div><div><^</div></div>', selector: 'my-parent', directives: const[MyChildComponent1,MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeInlineHtmlSelectorTag_at_middle_of_text() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<div><div> some text<^</div></div>', selector: 'my-parent', directives: const[MyChildComponent1,MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeInlineHtmlSelectorTag_at_middle_with_partial() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<div><div><my^</div></div>', selector: 'my-parent', directives: const[MyChildComponent1, MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeInlineHtmlSelectorTag_at_end() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<div><div></div></div><^', selector: 'my-parent', directives: const[MyChildComponent1,MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeInlineHtmlSelectorTag_at_end_with_partial() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<div><div></div></div><m^', selector: 'my-parent', directives: const[MyChildComponent1,MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeInlineHtmlSelectorTag_on_empty_document() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '^', selector: 'my-parent', directives: const[MyChildComponent1,MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeInlineHtmlSelectorTag_at_end_after_close() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<div><div></div></div>^', selector: 'my-parent', directives: const[MyChildComponent1,MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeInlineHtmlSelectorTag_in_middle_of_unclosed_tag() async {
    addTestSource('''
import '/angular2/angular2.dart';
@Component(template: '<div>some text<^', selector: 'my-parent', directives: const[MyChildComponent1,MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }
}

@reflectiveTest
class HtmlCompletionContributorTest extends AbstractCompletionContributorTest {
  @override
  setUp() {
    testFile = '/completionTest.html';
    super.setUp();
  }

  @override
  CompletionContributor createContributor() {
    return new AngularTemplateCompletionContributor();
  }

  test_completeMemberInMustache() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  String text;
}
    ''');

    addTestSource('html file {{^}} with mustache');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
    assertSuggestMethod('toString', 'Object', 'String');
    assertSuggestGetter('hashCode', 'int');
  }

  test_completeDotMemberInMustache() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  String text;
}
    ''');

    addTestSource('html file {{text.^}} with mustache');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('length', 'int');
  }

  test_completeDotMemberInNgFor() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  String text;
}
    ''');

    addTestSource('<div *ngFor="let item of text.^"></div>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('length', 'int');
  }

  test_completeMemberInNgFor() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  String text;
}
    ''');

    addTestSource('<div *ngFor="let item of ^"></div>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
    assertSuggestMethod('toString', 'Object', 'String');
    assertSuggestGetter('hashCode', 'int');
  }

  test_completeNgForItem() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  List<String> items;
}
    ''');

    addTestSource('<div *ngFor="let item of items">{{^}}</div>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestLocalVar('item', 'String');
  }

  test_completeHashVar() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
}
    ''');

    addTestSource('<button #buttonEl>button</button> {{^}}');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestLocalVar('buttonEl', 'ButtonElement');
  }

  test_completeNgVars_notAfterDot() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  List<String> items;
}
    ''');

    addTestSource(
        '<button #buttonEl>button</button><div *ngFor="item of items">{{hashCode.^}}</div>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('buttonEl');
    assertNotSuggested('item');
  }

  test_findCompletionTarget_afterUnclosedDom() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  String text;
}
    ''');

    addTestSource('<input /> {{^}}');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
  }

  test_completeStatements() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  String text;
}
    ''');

    addTestSource('<button (click)="^"></button>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestLocalVar(r'$event', 'MouseEvent');
    assertSuggestField('text', 'String');
  }

  test_completeUnclosedMustache() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  String text;
}
    ''');

    addTestSource('some text and {{^   <div>some html</div>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
  }

  test_completeEmptyExpressionDoesntIncludeVoid() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  void dontCompleteMe() {}
}
    ''');

    addTestSource('{{^}}');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("dontCompleteMe");
  }

  test_completeInMiddleOfExpressionDoesntIncludeVoid() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  bool takesArg(dynamic arg) {};
  void dontCompleteMe() {}
}
    ''');

    addTestSource('{{takesArg(^)}}');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("dontCompleteMe");
  }

  test_completeInputOutput() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
}
    ''');

    addTestSource('<my-tag ^></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 1);
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  test_completeInputNotSuggestedTwice() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
}
    ''');

    addTestSource('<my-tag [name]="\'bob\'" ^></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[name]");
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  test_completeStandardInputNotSuggestedTwice() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
}
    ''');

    addTestSource('<my-tag [hidden]="true" ^></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[hidden]");
    assertSuggestSetter("[name]");
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  test_completeInputSuggestsItself() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
}
    ''');

    addTestSource('<my-tag [name^></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[name]");
  }

  test_completeStandardInputSuggestsItself() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
}
    ''');

    addTestSource('<my-tag [hidden^></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  test_completeOutputNotSuggestedTwice() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
}
    ''');

    addTestSource('<my-tag (nameEvent)="" ^></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 1);
    assertNotSuggested("(nameEvent)");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  test_completeOutputSuggestsItself() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
}
    ''');

    addTestSource('<my-tag (nameEvent^></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter("(nameEvent)", "String");
  }

  test_completeStdOutputNotSuggestedTwice() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
}
    ''');

    addTestSource('<my-tag (click)="" ^></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 1);
    assertSuggestGetter("(nameEvent)", "String");
    assertNotSuggested("(click)");
  }

  test_completeStdOutputSuggestsItself() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
}
    ''');

    addTestSource('<my-tag (click^></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  test_completeInputOutputNotSuggestedAfterTwoWay() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
  String name;
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameChange;
}
    ''');

    addTestSource('<my-tag [(name)]="name" ^></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[name]");
    assertNotSuggested("(nameEvent)");
  }

  test_completeInputStarted() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
}
    ''');

    addTestSource('<my-tag [^></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 1);
    assertNotSuggested("(nameEvent)");
    assertNotSuggested("(click)");
  }

  test_completeOutputStarted() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
}
    ''');

    addTestSource('<my-tag (^></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
    assertNotSuggested("[name]");
  }

  test_completeInputReplacing() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
}
    ''');

    addTestSource('<my-tag [^input]="4"></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 1);
    assertNotSuggested("(nameEvent)");
    assertNotSuggested("(click)");
  }

  test_completeOutputReplacing() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
}
    ''');

    addTestSource('<my-tag (^output)="4"></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
    assertNotSuggested("[name]");
  }

  test_noCompleteInOutputInCloseTag() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter event;
}
    ''');

    addTestSource('<my-tag></my-tag ^>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[name]");
    assertNotSuggested("[hidden]");
    assertNotSuggested("(event)");
    assertNotSuggested("(click)");
  }

  test_noCompleteEmptyTagContents() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter event;
}
    ''');

    addTestSource('<my-tag>^</my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[name]");
    assertNotSuggested("[hidden]");
    assertNotSuggested("(event)");
    assertNotSuggested("(click)");
  }

  test_noCompleteInOutputsOnTagNameCompletion() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter event;
}
    ''');

    addTestSource('<my-tag^></my-tag>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[name]");
    assertNotSuggested("[hidden]");
    assertNotSuggested("(event)");
    assertNotSuggested("(click)");
  }

  test_completeHtmlSelectorTag_at_beginning() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
      import '/angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2
      ''');
    addTestSource('<^<div></div>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeHtmlSelectorTag_at_beginning_with_partial() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
      import '/angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('<my^<div></div>');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeHtmlSelectorTag_at_middle() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
      import '/angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('''<div><div><^</div></div>''');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeHtmlSelectorTag_at_middle_of_text() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
      import '/angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('''<div><div> some text<^</div></div>''');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeHtmlSelectorTag_at_middle_with_partial() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
      import '/angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('''<div><div><my^</div></div>''');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeHtmlSelectorTag_at_end() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
      import '/angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('''<div><div></div></div><^''');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeHtmlSelectorTag_at_end_with_partial() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
      import '/angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('''<div><div></div></div>
    <my^''');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }

  test_completeHtmlSelectorTag_on_empty_document() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
      import '/angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('^');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeHtmlSelectorTag_at_end_after_close() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
      import '/angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('<div><div></div></div>^');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeHtmlSelectorTag__in_middle_of_unclosed_tag() async {
    Source dartSource = newSource(
        '/completionTest.dart',
        '''
      import '/angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('<div>some text<^');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("my-child1");
    assertSuggestClassTypeAlias("my-child2");
    assertSuggestClassTypeAlias("my-child3");
  }
}
