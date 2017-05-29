import 'dart:async';

import 'package:analysis_server/src/provisional/completion/completion_core.dart';
import 'package:analysis_server/src/provisional/completion/dart/completion_dart.dart';
import 'package:angular_analyzer_server_plugin/src/completion.dart';
import 'package:unittest/unittest.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'completion_contributor_test_util.dart';

void main() {
  // TODO: get these working again on the latest SDK
  //defineReflectiveTests(DartCompletionContributorTest);
  defineReflectiveTests(HtmlCompletionContributorTest);
}

@reflectiveTest
class DartCompletionContributorTest extends AbstractCompletionContributorTest {
  @override
  void setUp() {
    testFile = '/completionTest.dart';
    super.setUp();
  }

  @override
  CompletionContributor createContributor() =>
      new AngularCompletionContributor(angularDriver);

  // ignore: non_constant_identifier_names
  Future test_completeMemberInMustache() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
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

  // ignore: non_constant_identifier_names
  Future test_completeMemberInInputBinding() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
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

  // ignore: non_constant_identifier_names
  Future test_completeMemberInClassBinding() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
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

  // ignore: non_constant_identifier_names
  Future test_completeMemberInInputOutput_at_incompleteTag_with_newTag() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<child-tag ^<div></div>', selector: 'my-tag',
directives: const [MyChildComponent])
class MyComponent {}
@Component(template: '', selector: 'child-tag')
class MyChildComponent {
  @Input() String stringInput;
  @Output() EventEmitter<String> myEvent;
}
    ''');
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[stringInput]");
    assertSuggestGetter("(myEvent)", "String");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputStarted_at_incompleteTag_with_newTag() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<child-tag [^<div></div>', selector: 'my-tag',
directives: const [MyChildComponent])
class MyComponent {}
@Component(template: '', selector: 'child-tag')
class MyChildComponent {
  @Input() String stringInput;
  @Output() EventEmitter<String> myEvent;
}
    ''');
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestSetter("[stringInput]");
    assertNotSuggested("(myEvent)");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputNotStarted_at_incompleteTag_with_newTag() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<child-tag ^<div></div>', selector: 'my-tag',
directives: const [MyChildComponent])
class MyComponent {}
@Component(template: '', selector: 'child-tag')
class MyChildComponent {
  @Input() String stringInput;
  @Output() EventEmitter<String> myEvent; 
}
    ''');
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter('[stringInput]');
  }

  // ignore: non_constant_identifier_names
  Future test_completeInput_as_plainAttribute() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<child-tag ^<div></div>', selector: 'my-tag',
directives: const [MyChildComponent])
class MyComponent {}
@Component(template: '', selector: 'child-tag', 
    inputs: const ['myDynamicInput'])
class MyChildComponent {
  @Input() String stringInput;
  @Input() String intInput;
  @Output() EventEmitter<String> myEvent;
  
  bool _myDynamicInput = false;
  bool get myDynamicInput => _myDynamicInput;
  void set myDynamicInput(value) {}
}
    ''');
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter('stringInput');
    assertNotSuggested('intInput');
    assertSuggestSetter('myDynamicInput',
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  // ignore: non_constant_identifier_names
  Future test_completeStandardInput_as_plainAttribute() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<child-tag ^<div></div>', selector: 'my-tag',
directives: const [MyChildComponent])
class MyComponent {}
@Component(template: '', selector: 'child-tag')
class MyChildComponent {
}
  }
  ''');
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter('[id]', relevance: DART_RELEVANCE_DEFAULT - 2);
    assertSuggestSetter('id', relevance: DART_RELEVANCE_DEFAULT - 2);
  }

  // ignore: non_constant_identifier_names
  Future test_completeOutputStarted_at_incompleteTag_with_newTag() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<child-tag (^<div></div>', selector: 'my-tag',
directives: const [MyChildComponent])
class MyComponent {}
@Component(template: '', selector: 'child-tag')
class MyChildComponent {
  @Input() String stringInput;
  @Output() EventEmitter<String> myEvent;
}
    ''');
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertNotSuggested("[stringInput]");
    assertSuggestGetter("(myEvent)", "String");
  }

  // ignore: non_constant_identifier_names
  Future test_completeMemberInInputOutput_at_incompleteTag_with_EOF() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<child-tag ^', selector: 'my-tag',
directives: const [MyChildComponent])
class MyComponent {}
@Component(template: '', selector: 'child-tag')
class MyChildComponent {
  @Input() String stringInput;
  @Output() EventEmitter<String> myEvent;
}
    ''');
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[stringInput]");
    assertSuggestGetter("(myEvent)", "String");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputStarted_at_incompleteTag_with_EOF() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<child-tag [^', selector: 'my-tag',
directives: const [MyChildComponent])
class MyComponent {}
@Component(template: '', selector: 'child-tag')
class MyChildComponent {
  @Input() String stringInput;
  @Output() EventEmitter<String> myEvent;
}
    ''');
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestSetter("[stringInput]");
    assertNotSuggested("(myEvent)");
  }

  // ignore: non_constant_identifier_names
  Future test_completeOutputStarted_at_incompleteTag_with_EOF() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<child-tag (^', selector: 'my-tag',
directives: const [MyChildComponent])
class MyComponent {}
@Component(template: '', selector: 'child-tag')
class MyChildComponent {
  @Input() String stringInput;
  @Output() EventEmitter<String> myEvent;
}
    ''');
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertNotSuggested("[stringInput]");
    assertSuggestGetter("(myEvent)", "String");
  }

  // ignore: non_constant_identifier_names
  Future test_completeMemberInStyleBinding() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
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

  // ignore: non_constant_identifier_names
  Future test_completeMemberInAttrBinding() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
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

  // ignore: non_constant_identifier_names
  Future test_completeMemberMustacheAttrBinding() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
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

  // ignore: non_constant_identifier_names
  Future test_completeMultipleMembers() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '{{d^}}', selector: 'a')
class MyComp {
  String text;
  String description;
}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestGetter('text', 'String');
    assertSuggestGetter('description', 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeInlineHtmlSelectorTag_at_beginning() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<^<div></div>', selector: 'my-parent', directives: const[MyChildComponent1, MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInlineHtmlSelectorTag_at_beginning_with_partial() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<my^<div></div>', selector: 'my-parent', directives: const[MyChildComponent1, MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - '<my'.length);
    expect(replacementLength, '<my'.length);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInlineHtmlSelectorTag_at_middle() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<div><div><^</div></div>', selector: 'my-parent', directives: const[MyChildComponent1,MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInlineHtmlSelectorTag_at_middle_of_text() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<div><div> some text<^</div></div>', selector: 'my-parent', directives: const[MyChildComponent1,MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInlineHtmlSelectorTag_at_middle_with_partial() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<div><div><my^</div></div>', selector: 'my-parent', directives: const[MyChildComponent1, MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - '<my'.length);
    expect(replacementLength, '<my'.length);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInlineHtmlSelectorTag_at_end() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<div><div></div></div><^', selector: 'my-parent', directives: const[MyChildComponent1,MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInlineHtmlSelectorTag_at_end_with_partial() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<div><div></div></div><m^', selector: 'my-parent', directives: const[MyChildComponent1,MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - '<m'.length);
    expect(replacementLength, '<m'.length);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInlineHtmlSelectorTag_on_empty_document() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
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

  // ignore: non_constant_identifier_names
  Future test_completeInlineHtmlSelectorTag_at_end_after_close() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
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

  // ignore: non_constant_identifier_names
  Future test_completeInlineHtmlSelectorTag_in_middle_of_unclosed_tag() async {
    addTestSource('''
import 'package:angular2/angular2.dart';
@Component(template: '<div>some text<^', selector: 'my-parent', directives: const[MyChildComponent1,MyChildComponent2])
class MyParentComponent{}
@Component(template: '', selector: 'my-child1, my-child2')
class MyChildComponent1{}
@Component(template: '', selector: 'my-child3.someClass[someAttr]')
class MyChildComponent2{}
    ''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }
}

@reflectiveTest
class HtmlCompletionContributorTest extends AbstractCompletionContributorTest {
  @override
  void setUp() {
    testFile = '/completionTest.html';
    super.setUp();
    createContributor();
  }

  @override
  CompletionContributor createContributor() =>
      new AngularCompletionContributor(angularDriver);

  // ignore: non_constant_identifier_names
  Future test_completeMemberInMustache() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  String text;
}
    ''');

    addTestSource('html file {{^}} with mustache');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
    assertSuggestMethod('toString', 'Object', 'String');
    assertSuggestGetter('hashCode', 'int');
  }

  // ignore: non_constant_identifier_names
  Future test_completeDotMemberInMustache() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  String text;
}
    ''');

    addTestSource('html file {{text.^}} with mustache');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('length', 'int');
  }

  // ignore: non_constant_identifier_names
  Future test_completeDotMemberAlreadyStartedInMustache() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  String text;
}
    ''');

    addTestSource('html file {{text.le^}} with mustache');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 'le'.length);
    expect(replacementLength, 'le'.length);
    assertSuggestGetter('length', 'int');
  }

  // ignore: non_constant_identifier_names
  Future test_completeDotMemberInNgFor() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  String text;
}
    ''');

    addTestSource('<div *ngFor="let item of text.^"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('length', 'int');
  }

  // ignore: non_constant_identifier_names
  Future test_completeMemberInNgFor() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  String text;
}
    ''');

    addTestSource('<div *ngFor="let item of ^"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
    assertSuggestMethod('toString', 'Object', 'String');
    assertSuggestGetter('hashCode', 'int');
  }

  // ignore: non_constant_identifier_names
  Future test_noCompleteMemberInNgForRightAfterLet() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  String text;
}
    ''');

    addTestSource('<div *ngFor="let^ item of [text]"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 'let'.length);
    expect(replacementLength, 'let item'.length);
    assertNotSuggested('text');
  }

  // ignore: non_constant_identifier_names
  Future test_noCompleteMemberInNgForInLet() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  String text;
}
    ''');

    addTestSource('<div *ngFor="l^et item of [text]"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 'let item'.length);
    assertNotSuggested('text');
  }

  // ignore: non_constant_identifier_names
  Future test_noCompleteMemberInNgForAfterLettedName() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  String text;
}
    ''');

    addTestSource('<div *ngFor="let item^ of [text]"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 'let item'.length);
    expect(replacementLength, 'let item'.length);
    assertNotSuggested('text');
  }

  // ignore: non_constant_identifier_names
  Future test_noCompleteMemberInNgForInLettedName() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  String text;
}
    ''');

    addTestSource('<div *ngFor="let i^tem of [text]"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 'let i'.length);
    expect(replacementLength, 'let item'.length);
    assertNotSuggested('text');
  }

  // ignore: non_constant_identifier_names
  Future test_noCompleteMemberInNgFor_forLettedName() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  String text;
}
    ''');

    addTestSource('<div *ngFor="let ^"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('text');
  }

  // ignore: non_constant_identifier_names
  Future test_completeNgForItem() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  List<String> items;
}
    ''');

    addTestSource('<div *ngFor="let item of items">{{^}}</div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestLocalVar('item', 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeHashVar() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
}
    ''');

    addTestSource('<button #buttonEl>button</button> {{^}}');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestLocalVar('buttonEl', 'ButtonElement');
  }

  // ignore: non_constant_identifier_names
  Future test_completeNgVars_notAfterDot() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  List<String> items;
}
    ''');

    addTestSource(
        '<button #buttonEl>button</button><div *ngFor="item of items">{{hashCode.^}}</div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('buttonEl');
    assertNotSuggested('item');
  }

  // ignore: non_constant_identifier_names
  Future test_findCompletionTarget_afterUnclosedDom() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  String text;
}
    ''');

    addTestSource('<input /> {{^}}');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeStatements() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  String text;
}
    ''');

    addTestSource('<button (click)="^"></button>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestLocalVar(r'$event', 'MouseEvent');
    assertSuggestField('text', 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeUnclosedMustache() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  String text;
}
    ''');

    addTestSource('some text and {{^   <div>some html</div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestGetter('text', 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeEmptyExpressionDoesntIncludeVoid() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  void dontCompleteMe() {}
}
    ''');

    addTestSource('{{^}}');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("dontCompleteMe");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInMiddleOfExpressionDoesntIncludeVoid() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
  bool takesArg(dynamic arg) {};
  void dontCompleteMe() {}
}
    ''');

    addTestSource('{{takesArg(^)}}');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("dontCompleteMe");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputOutputBanana() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
  
  @Input() String twoWay;
  @Output() EventEmitter<String> twoWayChange;
}
    ''');

    addTestSource('<my-tag ^></my-tag>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter('[name]');
    assertSuggestSetter('[hidden]', relevance: DART_RELEVANCE_DEFAULT - 2);
    assertSuggestGetter('(nameEvent)', 'String');
    assertSuggestGetter('(click)', 'MouseEvent',
        relevance: DART_RELEVANCE_DEFAULT - 1);
    assertSuggestSetter('[twoWay]');
    assertSuggestGetter('(twoWayChange)', 'String');
    assertSuggestSetter('[(twoWay)]', returnType: 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputOutputBanana_at_incompleteTag_with_newTag() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
  
  @Input() String twoWay;
  @Output() EventEmitter<String> twoWayChange;
}
    ''');

    addTestSource('<my-tag ^<div></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter('[name]');
    assertSuggestSetter('[hidden]', relevance: DART_RELEVANCE_DEFAULT - 2);
    assertSuggestGetter('(nameEvent)', 'String');
    assertSuggestGetter('(click)', 'MouseEvent',
        relevance: DART_RELEVANCE_DEFAULT - 1);
    assertSuggestSetter('[twoWay]');
    assertSuggestGetter('(twoWayChange)', 'String');
    assertSuggestSetter('[(twoWay)]', returnType: 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputStarted_at_incompleteTag_with_newTag() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    addTestSource('<my-tag [^<div></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
    assertNotSuggested("(nameEvent)");
    assertNotSuggested("(click)");
  }

  // ignore: non_constant_identifier_names
  Future test_completeOutputStarted_at_incompleteTag_with_newTag() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    addTestSource('<my-tag (^<div></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertNotSuggested("[name]");
    assertNotSuggested("[hidden]");
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  // ignore: non_constant_identifier_names
  Future test_completeBananaStarted_at_incompleteTag_bracketStart() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameChange;
}
    ''');

    addTestSource('<my-tag [^<div></div>');
    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);

    assertNotSuggested('(nameChange)');
    assertSuggestSetter('[name]');
    assertSuggestSetter('[(name)]', returnType: 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeBananaStarted_at_incompleteTag_bananaStart() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameChange;
}
    ''');

    addTestSource('<my-tag [(^<div></div>');
    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 2);
    expect(replacementLength, 2);

    assertNotSuggested('(nameChange)');
    assertNotSuggested('[name]');
    assertSuggestSetter('[(name)]', returnType: 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputOutputBanana_at_incompleteTag_with_EOF() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameEvent;
  
  @Input() String twoWay;
  @Output() EventEmitter<String> twoWayChange;
}
    ''');

    addTestSource('<my-tag ^');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter('[name]');
    assertSuggestSetter('[hidden]', relevance: DART_RELEVANCE_DEFAULT - 2);
    assertSuggestGetter('(nameEvent)', 'String');
    assertSuggestGetter('(click)', 'MouseEvent',
        relevance: DART_RELEVANCE_DEFAULT - 1);
    assertSuggestSetter('[twoWay]');
    assertSuggestGetter('(twoWayChange)', 'String');
    assertSuggestSetter('[(twoWay)]', returnType: 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputStarted_at_incompleteTag_with_EOF() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    addTestSource('<my-tag [^');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
    assertNotSuggested("(nameEvent)");
    assertNotSuggested("(click)");
  }

  // ignore: non_constant_identifier_names
  Future test_completeOutputStarted_at_incompleteTag_with_EOF() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    addTestSource('<my-tag (^');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertNotSuggested("[name]");
    assertNotSuggested("[hidden]");
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  // ignore: non_constant_identifier_names
  Future test_completeBananaStarted1_at_incompleteTag_with_EOF() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameChange;
}
    ''');

    addTestSource('<my-tag [^');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertNotSuggested('(nameChange)');
    assertSuggestSetter('[name]');
    assertSuggestSetter('[(name)]', returnType: 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeBananaStarted2_at_incompleteTag_with_EOF() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameChange;
}
    ''');

    addTestSource('<my-tag [(^');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 2);
    expect(replacementLength, 2);
    assertNotSuggested('(nameChange)');
    assertNotSuggested('[name]');
    assertSuggestSetter('[(name)]', returnType: 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputNotSuggestedTwice() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[name]");
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  // ignore: non_constant_identifier_names
  Future test_completeStandardInputNotSuggestedTwice() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[hidden]");
    assertSuggestSetter("[name]");
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputSuggestsItself() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '[name'.length);
    expect(replacementLength, '[name'.length);
    assertSuggestSetter("[name]");
  }

  // ignore: non_constant_identifier_names
  Future test_completeStandardInputSuggestsItself() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '[hidden'.length);
    expect(replacementLength, '[hidden'.length);
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
  }

  // ignore: non_constant_identifier_names
  Future test_completeOutputNotSuggestedTwice() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
    assertNotSuggested("(nameEvent)");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  // ignore: non_constant_identifier_names
  Future test_completeOutputSuggestsItself() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '(nameEvent'.length);
    expect(replacementLength, '(nameEvent'.length);
    assertSuggestGetter("(nameEvent)", "String");
  }

  // ignore: non_constant_identifier_names
  Future test_completeStdOutputNotSuggestedTwice() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
    assertSuggestGetter("(nameEvent)", "String");
    assertNotSuggested("(click)");
  }

  // ignore: non_constant_identifier_names
  Future test_completeStdOutputSuggestsItself() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '(click'.length);
    expect(replacementLength, '(click'.length);
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputOutputNotSuggestedAfterTwoWay() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[name]");
    assertNotSuggested("(nameEvent)");
  }

  // ignore: non_constant_identifier_names
  Future test_completeBananaNotSuggestedTwice() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameChange;
}
    ''');

    addTestSource('<my-tag [(name)]="\'bob\'" ^></my-tag>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('[name]');
    assertNotSuggested('(nameChange)');
    assertNotSuggested('[(name)]');
  }

  // ignore: non_constant_identifier_names
  Future test_completeBananaNotSuggested_after_inputUsed() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameChange;
}
    ''');

    addTestSource('<my-tag [name]="\'bob\'" ^></my-tag>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('[name]');
    assertSuggestGetter('(nameChange)', 'String');
    assertNotSuggested('[(name)]');
  }

  // ignore: non_constant_identifier_names
  Future test_completeBananaNotSuggested_after_outputUsed() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameChange;
}
    ''');

    addTestSource('<my-tag (nameChange)="" ^></my-tag>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter('[name]');
    assertNotSuggested('(nameChange)');
    assertNotSuggested('[(name)]');
  }

  // ignore: non_constant_identifier_names
  Future test_completeBananaSuggestsItself() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameChange;
}
    ''');

    addTestSource('<my-tag [(name^></my-tag>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 6);
    expect(replacementLength, 6);
    assertNotSuggested('[name]');
    assertNotSuggested('(nameChange)');
    assertSuggestSetter('[(name)]', returnType: 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputStarted() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
    assertNotSuggested("(nameEvent)");
    assertNotSuggested("(click)");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputStarted_standardHtmlInput() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
}
    ''');

    addTestSource('<div [^></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestSetter('[class]', relevance: DART_RELEVANCE_DEFAULT - 2);
    assertNotSuggested('[className]');
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputNotStarted() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter('[name]');
    assertSuggestSetter('[hidden]', relevance: DART_RELEVANCE_DEFAULT - 2);
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputNotStarted_standardHtmlInput() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
}
    ''');

    addTestSource('<div ^></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter('[class]', relevance: DART_RELEVANCE_DEFAULT - 2);
    assertNotSuggested('[className]');
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputAsPlainAttribute() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag', inputs: const ['myDynamicInput'])
class OtherComp {
  @Input() String name;
  @Input() int intInput;
  
  bool _myDynamicInput = false;
  bool get myDynamicInput => _myDynamicInput;
  void set myDynamicInput(value) {}
}
    ''');
    addTestSource('<my-tag ^></my-tag>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter('name');
    assertNotSuggested('intInput');
    assertSuggestSetter('id', relevance: DART_RELEVANCE_DEFAULT - 2);
    assertSuggestSetter('[myDynamicInput]');
    assertSuggestSetter('myDynamicInput',
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputNotStarted_plain_standardHtmlInput() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
}
    ''');

    addTestSource('<div ^></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter('class', relevance: DART_RELEVANCE_DEFAULT - 2);
    assertNotSuggested('className');
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputAsPlainAttributeStarted() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag', inputs: const ['myDynamicInput'])
class OtherComp {
  @Input() String name;
  @Input() int intInput;
  
  bool _myDynamicInput = false;
  bool get myDynamicInput => _myDynamicInput;
  void set myDynamicInput(value) {}
}
    ''');
    addTestSource('<my-tag myDyna^></my-tag>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 6);
    expect(replacementLength, 6);
    assertSuggestSetter('name');
    assertNotSuggested('intInput');
    assertSuggestSetter('id', relevance: DART_RELEVANCE_DEFAULT - 2);
    assertSuggestSetter('[myDynamicInput]');
    assertSuggestSetter('myDynamicInput',
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputStarted_plain_standardHtmlInput() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a')
class MyComp {
}
    ''');

    addTestSource('<div cla^></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 3);
    expect(replacementLength, 3);
    assertSuggestSetter('class', relevance: DART_RELEVANCE_DEFAULT - 2);
    assertNotSuggested('className');
  }

  // ignore: non_constant_identifier_names
  Future test_completeOutputStarted() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
    assertNotSuggested("[name]");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputReplacing() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, '[input]'.length);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
    assertNotSuggested("(nameEvent)");
    assertNotSuggested("(click)");
  }

  // ignore: non_constant_identifier_names
  Future test_completeOutputReplacing() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, '(output)'.length);
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
    assertNotSuggested("[name]");
  }

  // ignore: non_constant_identifier_names
  Future test_completeBananaNotStarted() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameChange;
}
    ''');

    addTestSource('<my-tag ^></my-tag>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter('[name]');
    assertSuggestSetter('[(name)]', returnType: 'String');
    assertSuggestGetter('(nameChange)', 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_completeBananaStarted1() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameChange;
}
    ''');

    addTestSource('<my-tag [^></my-tag>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestSetter('[name]');
    assertSuggestSetter('[(name)]', returnType: 'String');
    assertNotSuggested('(nameChange)');
  }

  // ignore: non_constant_identifier_names
  Future test_completeBananaStarted2() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameChange;
}
    ''');

    addTestSource('<my-tag [(^></my-tag>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 2);
    expect(replacementLength, 2);
    assertNotSuggested('[name]');
    assertSuggestSetter('[(name)]', returnType: 'String');
    assertNotSuggested('(nameChange)');
  }

  // ignore: non_constant_identifier_names
  Future test_completeBananaReplacing() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter<String> nameChange;
  
  @Input() String codename;
  @Output() EventEmitter<String> codenameChange;
}
    ''');

    addTestSource('<my-tag [(^name)]></my-tag>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 2);
    expect(replacementLength, '[(name)]'.length);
    assertNotSuggested('[name]');
    assertNotSuggested('(nameChange)');
    assertNotSuggested('[codename]');
    assertNotSuggested('(codenameChange)');
    assertSuggestSetter('[(name)]', returnType: 'String');
    assertSuggestSetter('[(codename)]', returnType: 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_noCompleteInOutputInCloseTag() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter event;
  
  @Input() String twoWay;
  @Output() EventEmitter<String> twoWayChange;
}
    ''');

    addTestSource('<my-tag></my-tag ^>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('[name]');
    assertNotSuggested('[hidden]');
    assertNotSuggested('(event)');
    assertNotSuggested('(click)');
    assertNotSuggested('[twoWay]');
    assertNotSuggested('(twoWayChange)');
    assertNotSuggested('[(twoWay)]');
  }

  // ignore: non_constant_identifier_names
  Future test_noCompleteEmptyTagContents() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[name]");
    assertNotSuggested("[hidden]");
    assertNotSuggested("(event)");
    assertNotSuggested("(click)");
  }

  // ignore: non_constant_identifier_names
  Future test_noCompleteInOutputsOnTagNameCompletion() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [OtherComp])
class MyComp {
}
@Component(template: '', selector: 'my-tag')
class OtherComp {
  @Input() String name;
  @Output() EventEmitter event;
  
  @Input() String twoWay;
  @Output() EventEmitter<String> twoWayChange;
}
    ''');

    addTestSource('<my-tag^></my-tag>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, 0);
    expect(replacementLength, '<my-tag'.length);
    assertNotSuggested('[name]');
    assertNotSuggested('[hidden]');
    assertNotSuggested('(event)');
    assertNotSuggested('(click)');
    assertNotSuggested('[twoWay]');
    assertNotSuggested('(twoWayChange)');
    assertNotSuggested('[(twoWay)]');
  }

  // ignore: non_constant_identifier_names
  Future test_completeHtmlSelectorTag_at_beginning() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
      import 'package:angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2
      ''');
    addTestSource('<^<div></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeHtmlSelectorTag_at_beginning_with_partial() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
      import 'package:angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('<my^<div></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '<my'.length);
    expect(replacementLength, '<my'.length);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeHtmlSelectorTag_at_middle() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
      import 'package:angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('''<div><div><^</div></div>''');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeHtmlSelectorTag_at_middle_of_text() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
      import 'package:angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('''<div><div> some text<^</div></div>''');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeHtmlSelectorTag_at_middle_with_partial() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
      import 'package:angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('''<div><div><my^</div></div>''');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '<my'.length);
    expect(replacementLength, '<my'.length);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeHtmlSelectorTag_at_end() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
      import 'package:angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('''<div><div></div></div><^''');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeHtmlSelectorTag_at_end_with_partial() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
      import 'package:angular2/angular2.dart';
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '<my'.length);
    expect(replacementLength, '<my'.length);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeHtmlSelectorTag_on_empty_document() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
      import 'package:angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('^');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeHtmlSelectorTag_at_end_after_close() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
      import 'package:angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('<div><div></div></div>^');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeHtmlSelectorTag__in_middle_of_unclosed_tag() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
      import 'package:angular2/angular2.dart';
      @Component(templateUrl: 'completionTest.html', selector: 'a',
        directives: const [MyChildComponent1, MyChildComponent2])
        class MyComp{}
      @Component(template: '', selector: 'my-child1, my-child2')
      class MyChildComponent1{}
      @Component(template: '', selector: 'my-child3.someClass[someAttr]')
      class MyChildComponent2{}
      ''');
    addTestSource('<div>some text<^');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  // ignore: non_constant_identifier_names
  Future test_completeTransclusionSuggestion() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [ContainerComponent])
class MyComp{}

@Component(template:
    '<ng-content select="tag1,tag2[withattr],tag3.withclass"></ng-content>',
    selector: 'container')
class ContainerComponent{}
      ''');
    addTestSource('<container>^</container>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestTransclusion("<tag1");
    assertSuggestTransclusion("<tag2 withattr");
    assertSuggestTransclusion("<tag3 class=\"withclass\"");
  }

  // ignore: non_constant_identifier_names
  Future test_completeTransclusionSuggestionInWhitespace() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [ContainerComponent])
class MyComp{}

@Component(template:
    '<ng-content select="tag1,tag2[withattr],tag3.withclass"></ng-content>',
    selector: 'container')
class ContainerComponent{}
      ''');
    addTestSource('''
<container>
  ^
</container>''');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestTransclusion("<tag1");
    assertSuggestTransclusion("<tag2 withattr");
    assertSuggestTransclusion("<tag3 class=\"withclass\"");
  }

  // ignore: non_constant_identifier_names
  Future test_completeTransclusionSuggestionStarted() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [ContainerComponent])
class MyComp{}

@Component(template:
    '<ng-content select="tag1,tag2[withattr],tag3.withclass"></ng-content>',
    selector: 'container')
class ContainerComponent{}
      ''');
    addTestSource('''
<container>
  <^
</container>''');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    //expect(replacementOffset, completionOffset - 1);
    //expect(replacementLength, 1);
    assertSuggestTransclusion("<tag1");
    assertSuggestTransclusion("<tag2 withattr");
    assertSuggestTransclusion("<tag3 class=\"withclass\"");
  }

  // ignore: non_constant_identifier_names
  Future test_completeTransclusionSuggestionStartedTagName() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [ContainerComponent])
class MyComp{}

@Component(template:
    '<ng-content select="tag1,tag2[withattr],tag3.withclass"></ng-content>',
    selector: 'container')
class ContainerComponent{}
      ''');
    addTestSource('''
<container>
  <tag^
</container>''');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    //expect(replacementOffset, completionOffset - 4);
    //expect(replacementLength, 4);
    assertSuggestTransclusion("<tag1");
    assertSuggestTransclusion("<tag2 withattr");
    assertSuggestTransclusion("<tag3 class=\"withclass\"");
  }

  // ignore: non_constant_identifier_names
  Future test_completeTransclusionSuggestionAfterTag() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [ContainerComponent])
class MyComp{}

@Component(template:
    '<ng-content select="tag1,tag2[withattr],tag3.withclass"></ng-content>',
    selector: 'container')
class ContainerComponent{}
      ''');
    addTestSource('''
<container>
  <blah></blah>
  ^
</container>''');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestTransclusion("<tag1");
    assertSuggestTransclusion("<tag2 withattr");
    assertSuggestTransclusion("<tag3 class=\"withclass\"");
  }

  // ignore: non_constant_identifier_names
  Future test_completeTransclusionSuggestionBeforeTag() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [ContainerComponent])
class MyComp{}

@Component(template:
    '<ng-content select="tag1,tag2[withattr],tag3.withclass"></ng-content>',
    selector: 'container')
class ContainerComponent{}
      ''');
    addTestSource('''
<container>
  ^
  <blah></blah>
</container>''');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestTransclusion("<tag1");
    assertSuggestTransclusion("<tag2 withattr");
    assertSuggestTransclusion("<tag3 class=\"withclass\"");
  }

  void assertSuggestTransclusion(String name) {
    assertSuggestClassTypeAlias(name,
        relevance: TemplateCompleter.RELEVANCE_TRANSCLUSION);
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputInStarReplacing() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  List<String> items;
}
    ''');

    addTestSource('<div *ngFor="let x of items; trackBy^: foo"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 'trackBy'.length);
    expect(replacementLength, 'trackBy'.length);
    assertSuggestTemplateInput("trackBy:", elementName: '[ngForTrackBy]');
    assertNotSuggested("of");
    assertNotSuggested("of:");
    assertNotSuggested("trackBy"); // without the colon
    assertNotSuggested("items");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputInStarReplacingBeforeValue() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  List<String> items;
}
    ''');

    addTestSource('<div *ngFor="let x of items; trackBy^"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 'trackBy'.length);
    expect(replacementLength, 'trackBy'.length);
    assertSuggestTemplateInput("trackBy:", elementName: '[ngForTrackBy]');
    assertNotSuggested("of");
    assertNotSuggested("of:");
    assertNotSuggested("trackBy"); // without the colon
    assertNotSuggested("items");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputInStar() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  List<String> items;
}
    ''');

    addTestSource('<div *ngFor="let x of items; ^"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestTemplateInput("trackBy:", elementName: '[ngForTrackBy]');
    assertNotSuggested("of");
    assertNotSuggested("of:");
    assertNotSuggested("trackBy"); // without the colon
    assertNotSuggested("items");
  }

  // ignore: non_constant_identifier_names
  Future test_completeInputInStarValueAlready() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  List<String> items;
}
    ''');

    addTestSource('<div *ngFor="let x of items; ^ : foo"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestTemplateInput("trackBy:", elementName: '[ngForTrackBy]');
    assertNotSuggested("of");
    assertNotSuggested("of:");
    assertNotSuggested("trackBy"); // without the colon
    assertNotSuggested("items");
  }

  // ignore: non_constant_identifier_names
  Future test_completeNgForStarted() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  List<String> items;
}
    ''');

    addTestSource('<div *ngFor^');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '*ngFor'.length);
    expect(replacementLength, '*ngFor'.length);
    assertSuggestStar("*ngFor");
    assertNotSuggested("*ngForOf");
    assertNotSuggested("[id]");
    assertNotSuggested("id");
  }

  // ignore: non_constant_identifier_names
  Future test_completeNgForStartedWithValue() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  List<String> items;
}
    ''');

    addTestSource('<div *ngFor^="let x of items"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '*ngFor'.length);
    expect(replacementLength, '*ngFor'.length);
    assertSuggestStar("*ngFor");
    assertNotSuggested("*ngForOf");
    assertNotSuggested("[id]");
    assertNotSuggested("id");
  }

  // ignore: non_constant_identifier_names
  Future test_completeStarAttrsNotStarted() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [NgFor, NgIf, CustomTemplateDirective, NotTemplateDirective])
class MyComp {
  List<String> items;
}

@Directive(selector: '[customTemplateDirective]')
class CustomTemplateDirective {
  CustomTemplateDirective(TemplateRef tpl);
}

@Directive(selector: '[notTemplateDirective]')
class NotTemplateDirective {
}
    ''');

    addTestSource('<div ^></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestStar("*ngFor");
    assertSuggestStar("*ngIf");
    assertSuggestStar("*customTemplateDirective");
    assertNotSuggested("*notTemplateDirective");
    assertNotSuggested("*ngForOf");
  }

  // ignore: non_constant_identifier_names
  Future test_completeStarAttrsOnlyStar() async {
    final dartSource = newSource(
        '/completionTest.dart',
        '''
import 'package:angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a',
    directives: const [NgFor, NgIf, CustomTemplateDirective])
class MyComp {
  List<String> items;
}

@Directive(selector: '[customTemplateDirective]')
class CustomTemplateDirective {
  CustomTemplateDirective(TemplateRef tpl);
}
    ''');

    addTestSource('<div *^></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestStar("*ngFor");
    assertSuggestStar("*ngIf");
    assertSuggestStar("*customTemplateDirective");
    assertNotSuggested("*ngForOf");
    assertNotSuggested("[id]");
    assertNotSuggested("id");
  }
}
