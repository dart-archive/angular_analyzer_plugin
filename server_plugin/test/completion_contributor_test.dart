import 'package:analysis_server/src/provisional/completion/completion_core.dart';
import 'package:analysis_server/src/provisional/completion/dart/completion_dart.dart';
import 'package:angular_analyzer_server_plugin/src/completion.dart';
import 'package:unittest/unittest.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'completion_contributor_test_util.dart';

main() {
  // TODO: get these working again on the latest SDK
  //defineReflectiveTests(DartCompletionContributorTest);
  defineReflectiveTests(HtmlCompletionContributorTest);
}

@reflectiveTest
class DartCompletionContributorTest extends AbstractCompletionContributorTest {
  @override
  setUp() {
    testFile = '/completionTest.dart';
    super.setUp();
  }

  @override
  CompletionContributor createContributor() {
    return new AngularCompletionContributor(angularDriver);
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

  test_completeMemberInInputOutput_at_incompleteTag_with_newTag() async {
    addTestSource('''
import '/angular2/angular2.dart';
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

  test_completeInputStarted_at_incompleteTag_with_newTag() async {
    addTestSource('''
import '/angular2/angular2.dart';
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

  test_completeInputNotStarted_at_incompleteTag_with_newTag() async {
    addTestSource('''
import '/angular2/angular2.dart';
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

  test_completeInput_as_plainAttribute() async {
    addTestSource('''
import '/angular2/angular2.dart';
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

  test_completeStandardInput_as_plainAttribute() async {
    addTestSource('''
import '/angular2/angular2.dart';
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

  test_completeOutputStarted_at_incompleteTag_with_newTag() async {
    addTestSource('''
import '/angular2/angular2.dart';
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

  test_completeMemberInInputOutput_at_incompleteTag_with_EOF() async {
    addTestSource('''
import '/angular2/angular2.dart';
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

  test_completeInputStarted_at_incompleteTag_with_EOF() async {
    addTestSource('''
import '/angular2/angular2.dart';
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

  test_completeOutputStarted_at_incompleteTag_with_EOF() async {
    addTestSource('''
import '/angular2/angular2.dart';
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
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
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
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
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
    expect(replacementOffset, completionOffset - '<my'.length);
    expect(replacementLength, '<my'.length);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
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
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
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
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
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
    expect(replacementOffset, completionOffset - '<my'.length);
    expect(replacementLength, '<my'.length);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
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
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
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
    expect(replacementOffset, completionOffset - '<m'.length);
    expect(replacementLength, '<m'.length);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
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
  setUp() {
    testFile = '/completionTest.html';
    super.setUp();
    createContributor();
  }

  @override
  CompletionContributor createContributor() {
    return new AngularCompletionContributor(angularDriver);
  }

  test_completeMemberInMustache() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeDotMemberInMustache() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeDotMemberAlreadyStartedInMustache() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeDotMemberInNgFor() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeMemberInNgFor() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_noCompleteMemberInNgForRightAfterLet() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  String text;
}
    ''');

    addTestSource('<div *ngFor="let^ item of [text]"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('text');
  }

  test_noCompleteMemberInNgForInLet() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  String text;
}
    ''');

    addTestSource('<div *ngFor="l^et item of [text]"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('text');
  }

  test_noCompleteMemberInNgForAfterLettedName() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  String text;
}
    ''');

    addTestSource('<div *ngFor="let item^ of [text]"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('text');
  }

  test_noCompleteMemberInNgForInLettedName() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
@Component(templateUrl: 'completionTest.html', selector: 'a', directives: const [NgFor])
class MyComp {
  String text;
}
    ''');

    addTestSource('<div *ngFor="let i^tem of [text]"></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('text');
  }

  test_noCompleteMemberInNgFor_forLettedName() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeNgForItem() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeHashVar() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeNgVars_notAfterDot() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('buttonEl');
    assertNotSuggested('item');
  }

  test_findCompletionTarget_afterUnclosedDom() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeStatements() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeUnclosedMustache() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeEmptyExpressionDoesntIncludeVoid() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeInMiddleOfExpressionDoesntIncludeVoid() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("dontCompleteMe");
  }

  test_completeInputOutput() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  test_completeInputOutput_at_incompleteTag_with_newTag() async {
    var dartSource = newSource(
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

    addTestSource('<my-tag ^<div></div>');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  test_completeInputStarted_at_incompleteTag_with_newTag() async {
    var dartSource = newSource(
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

  test_completeOutputStarted_at_incompleteTag_with_newTag() async {
    var dartSource = newSource(
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

  test_completeInputOutput_at_incompleteTag_with_EOF() async {
    var dartSource = newSource(
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

    addTestSource('<my-tag ^');

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  test_completeInputStarted_at_incompleteTag_with_EOF() async {
    var dartSource = newSource(
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

  test_completeOutputStarted_at_incompleteTag_with_EOF() async {
    var dartSource = newSource(
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

  test_completeInputNotSuggestedTwice() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[name]");
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  test_completeStandardInputNotSuggestedTwice() async {
    var dartSource = newSource(
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

  test_completeInputSuggestsItself() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '[name'.length);
    expect(replacementLength, '[name'.length);
    assertSuggestSetter("[name]");
  }

  test_completeStandardInputSuggestsItself() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '[hidden'.length);
    expect(replacementLength, '[hidden'.length);
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
  }

  test_completeOutputNotSuggestedTwice() async {
    var dartSource = newSource(
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

  test_completeOutputSuggestsItself() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '(nameEvent'.length);
    expect(replacementLength, '(nameEvent'.length);
    assertSuggestGetter("(nameEvent)", "String");
  }

  test_completeStdOutputNotSuggestedTwice() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
    assertSuggestGetter("(nameEvent)", "String");
    assertNotSuggested("(click)");
  }

  test_completeStdOutputSuggestsItself() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '(click'.length);
    expect(replacementLength, '(click'.length);
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
  }

  test_completeInputOutputNotSuggestedAfterTwoWay() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[name]");
    assertNotSuggested("(nameEvent)");
  }

  test_completeInputStarted() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
    assertNotSuggested("(nameEvent)");
    assertNotSuggested("(click)");
  }

  test_completeInputNotStarted() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestSetter('[name]');
    assertSuggestSetter('[hidden]', relevance: DART_RELEVANCE_DEFAULT - 2);
  }

  test_completeInputAsPlainAttribute() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeInputAsPlainAttributeStarted() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeOutputStarted() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
    assertNotSuggested("[name]");
  }

  test_completeInputReplacing() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, '[input]'.length);
    assertSuggestSetter("[name]");
    assertSuggestSetter("[hidden]", relevance: DART_RELEVANCE_DEFAULT - 2);
    assertNotSuggested("(nameEvent)");
    assertNotSuggested("(click)");
  }

  test_completeOutputReplacing() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, '(output)'.length);
    assertSuggestGetter("(nameEvent)", "String");
    assertSuggestGetter("(click)", "MouseEvent",
        relevance: DART_RELEVANCE_DEFAULT - 1);
    assertNotSuggested("[name]");
  }

  test_noCompleteInOutputInCloseTag() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[name]");
    assertNotSuggested("[hidden]");
    assertNotSuggested("(event)");
    assertNotSuggested("(click)");
  }

  test_noCompleteEmptyTagContents() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested("[name]");
    assertNotSuggested("[hidden]");
    assertNotSuggested("(event)");
    assertNotSuggested("(click)");
  }

  test_noCompleteInOutputsOnTagNameCompletion() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, 0);
    expect(replacementLength, '<my-tag'.length);
    assertNotSuggested("[name]");
    assertNotSuggested("[hidden]");
    assertNotSuggested("(event)");
    assertNotSuggested("(click)");
  }

  test_completeHtmlSelectorTag_at_beginning() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeHtmlSelectorTag_at_beginning_with_partial() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '<my'.length);
    expect(replacementLength, '<my'.length);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeHtmlSelectorTag_at_middle() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeHtmlSelectorTag_at_middle_of_text() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeHtmlSelectorTag_at_middle_with_partial() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '<my'.length);
    expect(replacementLength, '<my'.length);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeHtmlSelectorTag_at_end() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeHtmlSelectorTag_at_end_with_partial() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - '<my'.length);
    expect(replacementLength, '<my'.length);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeHtmlSelectorTag_on_empty_document() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeHtmlSelectorTag_at_end_after_close() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeHtmlSelectorTag__in_middle_of_unclosed_tag() async {
    var dartSource = newSource(
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

    await resolveSingleTemplate(dartSource);
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClassTypeAlias("<my-child1");
    assertSuggestClassTypeAlias("<my-child2");
    assertSuggestClassTypeAlias("<my-child3");
  }

  test_completeTransclusionSuggestion() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeTransclusionSuggestionInWhitespace() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeTransclusionSuggestionStarted() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeTransclusionSuggestionStartedTagName() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeTransclusionSuggestionAfterTag() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  test_completeTransclusionSuggestionBeforeTag() async {
    var dartSource = newSource(
        '/completionTest.dart',
        '''
import '/angular2/angular2.dart';
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

  assertSuggestTransclusion(String name) {
    assertSuggestClassTypeAlias(name,
        relevance: TemplateCompleter.RELEVANCE_TRANSCLUSION);
  }
}
