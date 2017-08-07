import 'dart:async';
import 'dart:math';

import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:analyzer/dart/ast/token.dart';
//import 'package:unittest/unittest.dart';
import 'package:test/test.dart';
//import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'abstract_angular.dart';

//main() {
//  defineReflectiveSuite(() {
//    defineReflectiveTests(FuzzTest);
//  });
//}

void main() {
  new FuzzTest().test_fuzz_continually();
}

//@reflectiveTest
class FuzzTest extends AbstractAngularTest {
  // collected with
  // `find ../deps -name '*.dart' -exec cat {} \; | shuf -n 500 | sort`
  // and cleaned up by hand
  static const String dartSnippets = r'''
}
]),
});
{
\'\'\');
  '090cedb3f2833a3f260b0937baae56267a6cd935',
   -4.5035996273704955E15, -4.294967296000001E9, -4.294967296E9, -4.2949672959999995E9, -6031769.5,
      [[549755813990, -1],
    "57,646,075,230,342%"
      6,
,[6026.423842661978,5821.897768214317]
        addCodeUnitEscaped(buffer, $LS); // 0x2028.
    ..add(doKeyword)
        afterLineBreak = true;
args3(a, b, c) {}
                     _argumentsAsJson(_arguments));
    assert(context != null);
      assertHasResult(SearchResultKind.WRITE, 'test = 1;');
    _assertInvalid(a, LIBRARY_ERRORS_READY);
    assertNotSuggested('F1');
  assertNull(res[650].firstMatch("** Failers"), 1648);
    assertOpType(returnValue: true, typeNames: true);
    _assertTrue("{ while (true) { x: do { continue x; } while (true); } }");
    _assertUnlinkedConst(variable.initializer.bodyExpr,
    _assertUnlinkedConst(variable.initializer.bodyExpr, operators: [
      AstFactory.mapLiteralEntry("b", AstFactory.identifier3("b")),
      ast.NodeList arguments, CallStructure callStructure, _) {
  AstNode node = request.target.containingNode;
    await computeSuggestions();
  await r1Ref.reload();
  _Base64DecoderSink(this._sink);
      baseSegments = [];
    B.mb();
  bool remove(Object o) => _validKey(o) ? super.remove(o) : false;
        break;
        'C');
    } catch (e) {
    checkFile(build(
class A {
class ChM{}
    ClassElement classB = ElementFactory.classElement("B", classA.type);
    ClassElementImpl classB = ElementFactory.classElement2("B", ["F"]);
class Getter_NodeReplacerTest_test_classTypeAlias
class Malbounded1 implements Super<String> {}  /// static type warning
  c = m.shuffle(Float32x4.WZYY);
    CompilationUnit unit = resolveCompilationUnit(source, library);
  compilePolyfillAndValidate(input, generatedPolyfill);
  Compiler compiler = result.compiler;
        }, (completer) => completer.completeError('oh no'));
  const CommentType(this.name);
      const ErrorProperty<List<FieldElement>>('NOT_INITIALIZED_FIELDS', 0);
  const _MockSdkFile(this.path, this.content);
  const Pair(Namespaces.html, "font"),
  const Symbol('zm'),
          const Visit(VisitKind.VISIT_REDIRECTING_FACTORY_CONSTRUCTOR_DECL,
        context.resolveCompilationUnit2(librarySource, librarySource);
      : counters = const {Metric.functions: 1},
        csKind: CompletionSuggestionKind.IMPORT);
  DartObjectImpl integerDivide(BinaryExpression node,
        'd': 'd', // DAY
  debug('');
    defineReflectiveTests(AnalysisDriverSchedulerTest);
    document.body.append(outerElement);
  @DomName('WebGLRenderingContext.MIRRORED_REPEAT')
    Element.keyDownEvent.forTarget(_target, useCapture: true).listen(
        element.name == '[]=';
    } else {
    } else if (offset >= JS('int', '#.length', keys)) {
      _emit("print", {
  Encoding encoding;
        env.liveInstructions.forEach((HInstruction instruction, int id) {
          equals('http://dartlang.org/thing.dart 5:10'));
        "error after the listened stream completes", () {
  execRE(re, "y", ["y"]);
    expect(
    expect(() {
    expect(entry.getState(result), CacheState.INVALID);
  Expect.equals(0, IntFromN(NFromInt(0)));
  Expect.equals(1, C.getterInvocation);
    expectEqualSets(incNames.instantiatedNames, fullNames.instantiatedNames);
  Expect.equals(length, l.length);
  Expect.isFalse(map is LinkedHashMap<dynamic, int>);
      Expect.isTrue(count > 0);
  Expect.isTrue(null != 2147483647.hashCode);
  expect(iter.current, _isRune("b"));
    expect(label.name, labelName);
      Expect.listEquals(["map 1",
  expectMatchingErrors(() => classMirror.invoke(#foo, []),
      expect(new Int64(10) >= new Int64(9), true);
    expectNoValidationError((entrypoint) => new PubspecValidator(entrypoint));
  Expect.throws(() => myIterable.elementAt(0), (e) => e is RangeError);
    expect(typeSystem.isSubtypeOf(type1, type2), false);
    expect(view(elements.classes),
        fieldsToBold.add(field.name);
    File file = package.folder.getChildAssumingFile(fileName);
    FINAL,
  final num x;
      FIRSTWEEKCUTOFFDAY: 3),
  Folder folder;
  foo();
foo3() async { await fut(); }
          format._multiplier = _PERCENT_SCALE;
  f_string();
    _futureOrPrefetch = new AsyncError(error, stackTrace);
      group('excluded', () {
  _hasTimer(_FakeTimer timer) => _timers.contains(timer);
        height: 300px;
  "hellip;",
      _hi ^= high;
        'Hms': 'HH:mm:ss', // HOUR24_MINUTE_SECOND
          "HtmlEntry.PARSE_ERRORS", AnalysisError.NO_ERRORS);
    if (count++ > 0) {
  if (dartProxy == null || !_isLocalObject(o)) {
    if (_documentationComment != null) {
    if (entry.isEmpty) {
    if (event.kind == ServiceEvent.kPauseBreakpoint) {
      if (!fs._ensureUnknownFields().mergeFieldFromBuffer(tag, input)) {
      if (function.isPublic) {
    if (json == null) {
        if (mainScript == null) {
    if (message == null) return "is not true.";
  IFrameElement x = e.querySelector('iframe');
  if (s == "CSSFontFaceRule") return BlinkCSSFontFaceRule.instance;
    if (_subscription != null) _subscription.cancel();
      if (superName != null) {
    if (targetUnit == _lastOutputUnit) return _lastLibrariesMap;
      if (trimmedLine.startsWith('Observatory listening on ')) {
    if (type == null) return false;
  if (value is num) return value;
    if (value is String) {
  if (x == 0) {
        (i) => i < _dimPrefixLength ? oldDimToInt[i] : new Map<dynamic, int>());
    img.src = url;
import 'a.dart';
import 'dart:async';
import '../../descriptor.dart' as d;
        ImportElement,
import 'sub folder/lib.dart';
    int count = 0;
    InterfaceType typeA = classA.type;
  int getWidth(int viewLength);
    js.Expression initializeLoadedHunkFunction = js.js(
          Keyword keyword, TypeName type, String parameterName) =>
    l[0] = lSmall;
  'language/first_class_types_literals_test_08_multi',
library engine.source;
    listener.setLineInfo(new TestSource(), scanner.lineStarts);
          List<MirrorUsage> usages = mirrorsUsedOnLibraryTag(library, import);
    List output_words = configurations.length > 1
        localsHandler,
  log.add('a');
    m(A a) {}
main() {
main(p) {
      (map) => map.remove('a'))));
  measureText_Callback_0_(mthis) => Blink_JsNative_DomException.callMethod(mthis /* CanvasRenderingContext2D */, "measureText", []);
    _metadata = metadata;
        methods.add(sb.toString());
native "*Window" /// 28: compile-time error
  new C().test('dynamic', true);
      [new TransformerGroup([
                node, new VariableConstantExpression(element),
  onclick_Setter_(mthis, __arg_0) => Blink_JsNative_DomException.setProperty(mthis /* GlobalEventHandlers */, "onclick", __arg_0);
    } on TestException catch (e) {}
  @override
  parser.addOption("dart2js-args",
      'pkgB': [provider.getResource('/pkgB/lib/')]
  print(await Isolate.resolvePackageUri(
      properties['propagated type'] = node.propagatedType;
    provider.sourcesWithResults.add(source2);
    reportErrorForOffset(errorCode, token.offset, token.length, arguments);
  Request _createGetErrorsRequest(String file) {
        _resolver.nameScope.shouldIgnoreUndefined(superclassName)) {
        return;
  Return _clone() => new Return(value);
    return copy;
    // returned out of the TestTypeProvider don't have a mock 'dart.core'
      return expect42(f());
    return hash;
        return null;
    return receiver.isStable &&
    return segments.toString();
      Set<String> todoFiles =
  shouldBeEqualToString(test3.style.overflowX, "overlay");
  shouldBe(imported.text, 'hello world');
  shouldBe(regex11.firstMatch("baaabac"), ["aba", "a"]);
  shouldBe(style.backgroundPosition, '50% 50%, left 0% bottom 20px');
  _SourcePattern _getSourcePattern(SourceRange range) {
    Source source = addSource(r\'\'\'
        's': 's', // SECOND
          STANDALONEWEEKDAYS: const [
        start = i + 1;
              .startsWith("package:rasta/")) {
                .statement('# = #(#, $arity)', [name, closureConverter, name]));
  static const EventStreamProvider<Event> pauseEvent = const EventStreamProvider<Event>('pause');
  static const int RESERVED_3 = 3;
  static const int YXXX = 0x1;
  static const String COMPLETE = "complete";
  static int does_something() {
  static toto() => 666;
        [StaticTypeWarningCode.UNDEFINED_METHOD]);
  static void testMain() {
    storage.map.remove(_findBundleForSource(bundles, aSource).id);
  String get logicalHeight =>
    String parameterSource =
    String prefix = utils.getNodePrefix(statement);
  String toString() => "OpenSpan($start, \$$cost)";
switchTest(value) {
  test((){
    test1("child2", "-webkit-column-count", "auto");
    test('builds the correct URL with state', () {
    test("dot directories are ignored", () {
  testDynamic();
    test("initializerArrowExpression", () {
  test_perform() {
  test_PrefixedIdentifier_trailingStmt_field() async {
    .then((_) => FutureExpect.isFalse(FileSystemEntity.isLink(target)))
  try {
typedef A();
    unsorted.sort(compare);
      usedElement = prefixed.staticElement;
        validateMethodName("2newName"), RefactoringProblemSeverity.FATAL,
  'validateModifiersForField_1': new MethodTrampoline(
    var bundle1 = createPackageBundle(
    var foo2 = lib2.find("foo2");
  var obj = new Uint32List(0);
  var p2 = document.getElementById('p2');
  var zGood = 9223372036854775807;
    verify([source]);
      visitor.visitExpressionFunctionBody(this);
  void allDone() {}
  void b() {
  void fire(var event) {
  void f(x) {}
  void mergeDiamondFlow(FieldInitializationScope<T> thenScope,
  void test_binary_equal_string() {
  void test_getReturnType() {
  void test_nonAbstractClassInheritsAbstractMemberOne_getter_fromInterface() {
  void uniform2fv(UniformLocation location, v) native;
  Windows1252Decoder(List<int> bytes, [int offset = 0, int length,
  x_Getter_(mthis) => Blink_JsNative_DomException.getProperty(mthis /* SVGPathSegLinetoHorizontalAbs */, "x");
  yield 42;
      YieldStatement stmt = body.block.statements[0];
        'yMMM': 'MMM y', // YEAR_ABBR_MONTH
''';

  // collected with
  // `find ~/ng-comps -name '*.html' -exec cat {} \; | shuf -n 150 | sort`
  // and cleaned up by hand
  static const String htmlSnippets = r'''
<!--
-->
       aria-hidden="true"
       attr.aria-hidden="{{!invalid}}"
             [attr.aria-label]="closePanelMsg">
           [attr.aria-label]="scrollScorecardBarBack">
    attr.aria-valuemin="{{min}}"
             (blur)="inputBlurAction($event, inputEl.validity.valid, inputEl.validationMessage)"
          <br *ngFor="let value of heightForTextbox">
                  (change)="inputChange(textareaEl.value, textareaEl.validity.valid, textareaEl.validationMessage);$event.stopPropagation()"
              [class.active]="activeTabIndex == idx"
         [class.animated]="underlineAnimated"></div>
          [class.bottom-scroll-stroke]="shouldShowBottomScrollStroke">
                 class="btn btn-yes"
                   [class.checked]="checked"
          [class.disable-header-expansion]="disableHeaderExpansion"
           [class.expand-more]="shouldFlipExpandIcon"
                   [class.hide]="atScorecardBarEnd"
         [class.invisible]="disabled" [class.invalid]="invalid"></div>
         [class.invisible]="!focused" [class.invalid]="invalid"
              [class.invisible]="!labelVisible"
           [class.right-align]="rightAlign">
                  class="textarea"
                  [disabled]="disabled"
                 [disabled]="yesDisabled || disabled"
      </div>
      <div>
<div attr.aria-pressed="{{checked}}"
  <div class="active-progress"
    <div class="disabled-underline" [class.invisible]="!disabled">
      <div class="label" aria-hidden="true">
<div class="spinner">
  <div class="tgl-lbl" *ngIf="hasLabel">{{label}}</div>
<div (focus)="focusFirst()" tabindex="0"></div>
  <div *ngIf="maxCount != null && focused"
  <!-- Expanded section -->
              focusItem>
              </footer>
  </glyph>
      <glyph class="glyph leading"
<h3>{{label}}<ng-content select="name"></ng-content></h3>
              </header>
              <header>
  <header buttonDecorator
    {{hintText}}
<i [class.material-icons]="useMaterialIconsExtended"
           icon="chevron_right"
             icon="{{leadingGlyph}}"
                  (input)="inputKeypress(textareaEl.value, textareaEl.validity.valid, textareaEl.validationMessage)"></textarea>
          {{label}}
  </main>
  </material-button>
  <material-button class="scroll-button scroll-left-button"
<material-button #noButton
  </material-ripple>
<material-ripple (mousedown)="onMouseDown($event)"
  <material-ripple *ngIf="!disabled"
<material-ripple *ngIf="selectable"></material-ripple>
  <material-ripple [style.color]="rippleColor"
</material-tab-strip>
     (mouseenter)="isHovered=true"
      <ng-content select="[header]"></ng-content>
    <ng-content select="[trailing]"></ng-content>
      <ng-content select="[value]"></ng-content>
                   *ngIf="isScrollable">
                 *ngIf="!pending && noDisplayed"
           *ngIf="shouldShowExpandIcon"
       *ngSwitchWhen="emptyState"
      <p class="primary-text">{{name}}</p>
        [pending]="activeSaveCancelAction"
                 [raised]="yesRaised || raised"
       role="alert"
    </span>
<span *ngIf="suggestionBefore != null" class="suggestion before">{{suggestionBefore}}</span>
       [style.transform]="secondaryTransform"></div>
  </tab-button>
                    (tabChange)="onTabChange($event)"
       tabindex="-1"
           (trigger)="handleExpandIconClick()">
                 (trigger)="yes.add($event)">
        (yes)="doSave()"
        [yesText]="saveText"
''';

  static const String baseDart = r'''
import 'package:angular2/angular2.dart';

@Component(
  selector: 'my-aaa',
  templateUrl: 'test.html',
  directives: const [CounterComponent, NgIf, NgFor, NgForm, NgModel])
class ComponentA {
  List<String> items;
  String header;
}

@Component(
  selector: 'my-counter',
  inputs: const ['count'],
  outputs: const ['resetEvent: reset'],
  template: '{{count}} <button (click)="increment()" [value]="\'add\'"></button>')
class CounterComponent {
  int count;
  @Input() int maxCount;
  EventEmitter<String> resetEvent;
  @Output() EventEmitter<int> incremented;

  @ContentChild(CounterComponent)
  CounterComponent recursedComponent;

  void reset() {}
  void increment() {}
}
''';

  static const String baseHtml = r'''
<!-- @ngIgnoreErrors: -->
<h1 #h1>Showing {{items.length}} items:</h1>
<li *ngFor='let item of items; let x=index' [hidden]='item != null'>
  {{x}} : {{item.trim()}}
</li>

<div *ngIf="items.length > 0">
  <form #ngForm="ngForm"></form>
  {{ngForm.dirty}}
  
  <input [(ngModel)]="header" />
      
  <my-counter
    #counter
    [count]="items.length"
    [maxCount]='4'
    (reset)=''
    (click)='h1.hidden = !h1.hidden; counter.reset()'
    (incremented)='items.add($event.toString())'>
    <my-counter></my-counter>
  </my-counter>
</div>
''';

  String dart = baseDart;
  String html = baseHtml;

  Random random = new Random();

  // ignore: non_constant_identifier_names
  Future test_fuzz_continually() async {
    final fuzzOptions = <FuzzModification>[
      fuzz_removeChar,
      fuzz_truncate,
      fuzz_addChar,
      fuzz_copyLine,
      fuzz_dropLine,
      fuzz_joinLine,
      fuzz_shuffleLines,
      fuzz_copyChunk,
      fuzz_addKeyword,
      fuzz_addDartChunk,
      fuzz_addHtmlChunk,
    ];

    const iters = 1000000;
    for (var i = 0; i < iters; ++i) {
      final transforms = random.nextInt(20) + 1;
      print("Fuzz $i: $transforms transforms");
      dart = baseDart;
      html = baseHtml;

      for (var x = 0; x < transforms; ++x) {
        if (random.nextBool()) {
          dart = fuzzOptions[random.nextInt(fuzzOptions.length)](dart);
        } else {
          html = fuzzOptions[random.nextInt(fuzzOptions.length)](html);
        }
      }

      try {
        super.setUp();
        await checkNoCrash(dart, html);
      } catch (e, stacktrace) {
        // catch exceptions so that the test keeps running
        print(e);
        print(stacktrace);
      }
    }
  }

  int randomPos(String s) {
    if (s.isEmpty) {
      return 0;
    }
    // range is between 1 and n, but a random pos is 0 to n
    return random.nextInt(s.length);
  }

  int randomIndex(List s) {
    if (s.isEmpty) {
      return null;
    } else if (s.length == 1) {
      return 0;
    }
    // range is between 1 and n, but a random pos is 0 to n
    return random.nextInt(s.length - 1);
  }

  // ignore: non_constant_identifier_names
  String fuzz_removeChar(String input) {
    final charpos = randomIndex(input.codeUnits);
    if (charpos == null) {
      return input;
    }
    return input.replaceRange(charpos, charpos + 1, '');
  }

  // ignore: non_constant_identifier_names
  String fuzz_addChar(String input) {
    String newchar;
    if (input.isEmpty) {
      newchar = new String.fromCharCode(random.nextInt(128));
    } else {
      newchar = input[randomIndex(input.codeUnits)];
    }
    final charpos = randomPos(input);
    return input.replaceRange(charpos, charpos, newchar);
  }

  // ignore: non_constant_identifier_names
  String fuzz_truncate(String input) {
    final charpos = randomPos(input);
    if (charpos == 0) {
      return '';
    }
    return input.substring(0, charpos);
  }

  // ignore: non_constant_identifier_names
  String fuzz_shuffleLines(String input) {
    final lines = input.split('\n')..shuffle(random);
    return lines.join('\n');
  }

  // ignore: non_constant_identifier_names
  String fuzz_dropLine(String input) {
    final lines = input.split('\n');
    lines.removeAt(randomIndex(lines)); // ignore: cascade_invocations
    return lines.join('\n');
  }

  // ignore: non_constant_identifier_names
  String fuzz_joinLine(String input) {
    final lines = input.split('\n');
    if (lines.length == 1) {
      return input;
    }
    final which = randomIndex(lines);
    final toPrepend = lines[which];
    lines.removeAt(which);
    // ignore: prefer_interpolation_to_compose_strings
    lines[which] = toPrepend + lines[which];
    return lines.join('\n');
  }

  // ignore: non_constant_identifier_names
  String fuzz_copyLine(String input) {
    final lines = input.split('\n');
    if (lines.length == 1) {
      return input;
    }
    final which = randomIndex(lines);
    final toPrepend = lines[which];
    lines.removeAt(which);
    // ignore: prefer_interpolation_to_compose_strings
    lines[which] = toPrepend + lines[which];
    return lines.join('\n');
  }

  // ignore: non_constant_identifier_names
  String fuzz_copyChunk(String input) {
    if (input.isEmpty) {
      return input;
    }

    final chunk = fuzz_truncate(input.substring(randomIndex(input.codeUnits)));
    final charpos = randomPos(input);
    return input.replaceRange(charpos, charpos, chunk);
  }

  // ignore: non_constant_identifier_names
  String fuzz_addKeyword(String input) {
    final token = Keyword.values[randomIndex(Keyword.values)];
    if (input.isEmpty) {
      return input;
    }

    final charpos = randomPos(input);
    return input.replaceRange(charpos, charpos, token.lexeme);
  }

  // ignore: non_constant_identifier_names
  String fuzz_addDartChunk(String input) {
    var chunk = fuzz_truncate(dartSnippets);
    if (chunk.length > 80) {
      chunk = chunk.substring(0, random.nextInt(80));
    } else if (chunk.isEmpty) {
      return input;
    } else {
      chunk = chunk.substring(randomPos(chunk));
    }
    final charpos = randomPos(input);
    return input.replaceRange(charpos, charpos, chunk);
  }

  // ignore: non_constant_identifier_names
  String fuzz_addHtmlChunk(String input) {
    var chunk = fuzz_truncate(htmlSnippets);
    if (chunk.length > 80) {
      chunk = chunk.substring(0, random.nextInt(80));
    } else if (chunk.isEmpty) {
      return input;
    } else {
      chunk = chunk.substring(randomPos(chunk));
    }
    final charpos = randomPos(input);
    return input.replaceRange(charpos, charpos, chunk);
  }

  Future checkNoCrash(String dart, String html) async {
    newSource('/test.dart', dart);
    newSource('/test.html', html);
    final reason =
        '<<==DART CODE==>>\n$dart\n<<==HTML CODE==>>\n$html\n<<==DONE==>>';
    try {
      final result = await angularDriver.resolveDart('/test.dart');
      if (result.directives.isNotEmpty) {
        final directive = result.directives.first;
        if (directive is Component &&
            directive.view?.templateUriSource?.fullName == '/test.html') {
          try {
            await angularDriver.resolveHtml('/test.html');
          } catch (e, stacktrace) {
            print("ResolveHtml failed\n$reason\n$e\n$stacktrace");
          }
        }
      }
    } catch (e, stacktrace) {
      print("ResolveDart failed\n$reason\n$e\n$stacktrace");
    }
  }

  /// More or less expect(), but without failing the test. Returns a [Future] so
  /// that you can chain things to do when this succeeds or fails.
  Future check(Object actual, Matcher matcher, {String reason}) {
    final matchState = {};

    print('failed');
    final description = new StringDescription();
    description.add('Expected: ').addDescriptionOf(matcher).add('\n');
    description.add('  Actual: ').addDescriptionOf(actual).add('\n');

    final mismatchDescription = new StringDescription();
    matcher.describeMismatch(actual, mismatchDescription, matchState, false);

    if (mismatchDescription.length > 0) {
      description.add('   Which: $mismatchDescription\n');
    }
    if (reason != null) {
      description.add(reason).add('\n');
    }

    print(description.toString());
    return new Future.error(description);
  }
}

typedef String FuzzModification(String input);
