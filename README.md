# Angular2 Dart Analysis Plugins

## Integration with Dart Analysis Server

  To provide information for DAS clients the `server_plugin` plugin contributes several extensions.

* Angular analysis errors are automatically merged into normal `errors` notifications for Dart and HTML files.
* Navigation extension contributes navigation regions:
    * In external HTML templates.
    * In inline templates in Dart files.
    * In Dart annotations:
        * navigation from `templateUrl` to the corresponding HTML files.
        * navigation from input declarations to setters, e.g. to `text` in `inputs: const ['text: my-text']`.
* Occurrences extension reports regions where every Dart element or an input is used in a Dart or HTML file. So, clients of DAS can highlight all of the whe user select one.

![Preview gif](https://raw.githubusercontent.com/dart-lang/angular_analyzer_plugin/master/assets/angular-dart-intellij-plugin-demo.gif "Preview gif")

## Installing

**Build is currently broken as we are changing the analyzer plugin API to something more formal, reliable, and convenient.** Only works with older versions of the SDK right now (1.22.0.dev.4), which is a royal pain to install with dependencies.

Download chrome depot tools, and clone this repository.

Then run 
```
./tools/get_deps.sh
cd server_plugin/bin
./make_snapshot
```

Back up `sdk_path/snapshots/analysis_server.dart.snapshot` and replace it with `server.snapshot`. Restart the dart analysis server by clicking the skull.

**Check the pubspec.yaml in your project for transformers. They are not supported. You must manually add CORE_DIRECTIVES to your components right now for this plugin to work.**

## Chart of Current Features

All regular dart errros (that is to say, errors defined purely by the dart language spec) are not shown in this list.

Bootstrapping | Validation | Auto-Complete | Navigation | Refactoring
--------------|------------|---------------|------------|-------------
`bootstrap(AppComponent, [MyService, provide(...)]);` | :no_pedestrians: | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:

Template syntax | Validation | Auto-Complete | Navigation | Refactoring
----------------|------------|---------------|------------|-------------
`<input [value]="firstName">` | :white_check_mark: soundness of expression, type of expression, existence of `value` on element or directive | :last_quarter_moon: in some editors | :x: | :x:
`<input bind-value="firstName">` | :white_check_mark: | :last_quarter_moon: in some editors; complete inside binding but binding not suggested | :x: | :x:
`<div [attr.role]="myAriaRole">` | :last_quarter_moon: soundness of expression, but no other validation | :last_quarter_moon: in some editors; complete inside binding but binding not suggested | :x: | :x:
`<div [class.extra-sparkle]="isDelightful">` | :white_check_mark: validity of clasname, soundness of expression, type of expression must be bool | :last_quarter_moon: in some editors; complete inside binding but binding not suggested | :x: | :x:
`<div [style.width.px]="mySize">` | :waning_gibbous_moon: soundness of expression, css properties are generally checked but not against a dictionary, same for units, expression must type to `int` if units are present | :last_quarter_moon: in some editors; complete inside binding but binding not suggested | :x: | :x:
`<button (click)="readRainbow($event)">` | :white_check_mark: in some editors; soundness of expression, type of `$event`, existence of output on component/element and DOM events which propagate can be tracked anywhere | :last_quarter_moon: in some editors | :x: | :x:
`<button on-click="readRainbow($event)">` | :white_check_mark | :last_quarter_moon: in some editors; complete inside binding but binding not suggested | :x: | :x:
`<div title="Hello {{ponyName}}">` | :white_check_mark: in some editors; soundness of expression, matching mustache delimiters |:last_quarter_moon: in some editors | :x: | :x:
`<p>Hello {{ponyName}}</p>` | :white_check_mark: in some editors; soundness of expression, matching mustache delimiters |:last_quarter_moon: in some editors | :x: | :x:
`<my-cmp></my-cmp>` | :white_check_mark: in some editors; Existence of directive |:last_quarter_moon: in some editors | :x: | :x:
`<my-cmp [(title)]="name">` | :white_check_mark: soundness of expression, existence of `title` input and `titleChange` output on directive or component with proper type | :last_quarter_moon: in some editors; complete inside binding but binding not suggested | :x: | :x:
`<video #movieplayer ...></video><button (click)="movieplayer.play()">` | :white_check_mark: in some editors; Type of new variable tracked and checked in other expressions |:last_quarter_moon: in some editors | :x: | :x:
`<video ref-movieplayer ...></video><button (click)="movieplayer.play()">` | :white_check_mark: in some editors |:last_quarter_moon: in some editors | :x: | :x:
`<p *myUnless="myExpression">...</p>` | :white_check_mark: desugared to `<template [myUnless]="myExpression"><p>...` and checked from there | :last_quarter_moon: in some editors; complete inside binding but binding not suggested  | :x: | :x:
`<p>Card No.: {{cardNumber | myCardNumberFormatter}}</p>` | :x: Pipes are not typechecked yet | :x: | :x: | :x:

Built-in directives | Validation | Auto-Complete | Navigation | Refactoring
--------------------|------------|---------------|------------|-------------
`<section *ngIf="showSection">` | :white_check_mark: type checking, check for the star | :last_quarter_moon: in some editors; complete inside binding but binding not suggested  | :x: | :x:
`<li *ngFor="let item of list">` | :white_check_mark: type checking and new var, check for the star, catch accidental usage of `#item` | :last_quarter_moon: in some editors; complete after of only  | :x: | :x:
`<div [ngClass]="{active: isActive, disabled: isDisabled}">` | :warning: Requires quotes around key value strings to work | :last_quarter_moon: in some editors;  | :x: | :x:

Forms | Validation | Auto-Complete | Navigation | Refactoring
------|------------|---------------|------------|-------------
`<input [(ngModel)]="userName">` | :white_check_mark: | :last_quarter_moon: in some editors; completion inside binding but binding not suggested  | :x: | :x:
`<form #myform="ngForm">` | :white_check_mark: if `ngForm` is not an exported directive | :last_quarter_moon: in some editors; completion of variable but ngForm not suggested  | :x: | :x:

Class decorators | Validation | Auto-Complete | Navigation | Refactoring
-----------------|------------|---------------|------------|-------------
`@Component(...) class MyComponent {}` | :white_check_mark: Validates directives list is all directives, that the template file exists, that a template is specified via string or URL but not both, requires a valid selector | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
`@View(...) class MyComponent {}` | :warning: Supported, requires `@Directive` or `@Component`, but doesn't catch ambigous cases such as templates defined in the `@View` as well as `@Component` | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
`@Directive(...) class MyDirective {}` | :white_check_mark: Validates directives list is all directives, that the template file exists, that a template is specified via string or URL but not both, requires a valid selector | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
`@Pipe(...) class MyPipe {}` | :x: | :no_pedestrians: | :no_pedestrians: | :x:
`@Injectable() class MyService {}` | :x: | :no_pedestrians: | :no_pedestrians: | :x:

Directive configuration | Validation | Auto-Complete | Navigation | Refactoring
------------------------|------------|---------------|------------|-------------
`@Directive(property1: value1, ...)` | :warning: deprecated, but supported | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
`selector: '.cool-button:not(a)'` | :white_check_mark: | :no_pedestrians: | :x: | :x:
`providers: [MyService, provide(...)]` | :x: | :x: | :x: | :x:
`inputs: ['myprop', 'myprop2: byname']` | :white_check_mark: | :x: | :x: | :x:
`outputs: ['myprop', 'myprop2: byname']` | :white_check_mark: | :x: | :x: | :x:

@Component extends @Directive, so the @Directive configuration applies to components as well

Component Configuration | Validation | Auto-Complete | Navigation | Refactoring
------------------------|------------|---------------|------------|-------------
`viewProviders: [MyService, provide(...)]` | :x: | :x: | :x: | :x:
`template: 'Hello {{name}}'` | :white_check_mark: | :last_quarter_moon: in some editors | :x: | :x:
`templateUrl: 'my-component.html'` | :white_check_mark: | :x: | :x: | :x:
`styles: ['.primary {color: red}']` | :x: | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
`styleUrls: ['my-component.css']` | :x: | :x: | :x: | :x:
`directives: [MyDirective, MyComponent]` | :white_check_mark: must be directives or lists of directives, configuration affects view errors | :x: | :x: | :x:
`pipes: [MyPipe, OtherPipe]` | :x: | :x: | :x: | :x:

Class field decorators for directives and components | Validation | Auto-Complete | Navigation | Refactoring
-----------------------------------------------------|------------|---------------|------------|-------------
`@Input() myProperty;` | :white_check_mark: | :no_pedestrians: | :x: | :x:
`@Input("name") myProperty;` | :white_check_mark: | :no_pedestrians: | :x: | :x:
`@Output() myEvent = new EventEmitter();` | :white_check_mark: Subtype of `Stream<T>` required, streamed type determines `$event` type | :no_pedestrians: | :x: | :x:
`@Output("name") myEvent = new EventEmitter();` | :white_check_mark: | :no_pedestrians: | :x: | :x:
`@Attribute("name") String ctorArg` | :white_check_mark: | :x: | :x: | :x:
`@HostBinding('[class.valid]') isValid;` | :x: | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
`@HostListener('click', ['$event']) onClick(e) {...}` | :x: | :x: | :x: | :x:
`@ContentChild(myPredicate) myChildComponent;` | :x: | :no_pedestrians: | :x: | :x:
`@ContentChildren(myPredicate) myChildComponents;` | :x: | :no_pedestrians: | :x: | :x:
`@ViewChild(myPredicate) myChildComponent;` | :x: | :no_pedestrians: | :x: | :x:
`@ViewChildren(myPredicate) myChildComponents;` | :x: | :no_pedestrians: | :x: | :x:

Transclusions| Validation | Auto-Complete | Navigation | Refactoring
-----------------------------------------------------|------------|---------------|------------|-------------
`<ng-content></ng-content>` | :white_check_mark: | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
`<my-comp>text content</my-comp>` | :white_check_mark: | :x: | :x: | :x:
`<ng-content select="foo"></ng-content>` | :white_check_mark: | :last_quarter_moon: in some editors | :x: | :x:
`<my-comp><foo></foo></my-comp>` | :white_check_mark: | :last_quarter_moon: in some editors | :x: | :x:
`<ng-content select=".foo[bar]"></ng-content>` | :white_check_mark: | :last_quarter_moon: in some editors | :x: | :x:
`<my-comp><div class="foo" bar></div></my-comp>` | :white_check_mark: | :last_quarter_moon: in some editors | :x: | :x:

Directive and component change detection and lifecycle hooks (implemented as class methods) | Validation | Auto-Complete | Navigation | Refactoring
--------------------------------------------------------------------------------------------|------------|---------------|------------|-------------
`MyAppComponent(MyService myService, ...) { ... }` | :x: | :no_pedestrians: | :no_pedestrians: | :x:
`ngOnChanges(changeRecord) { ... }` | :x: | :no_pedestrians: | :no_pedestrians: | :x:
`ngOnInit() { ... }` | :x: | :no_pedestrians: | :no_pedestrians: | :x:
`ngDoCheck() { ... }` | :x: | :no_pedestrians: | :no_pedestrians: | :x:
`ngAfterContentInit() { ... }` | :x: | :no_pedestrians: | :no_pedestrians: | :x:
`ngAfterContentChecked() { ... }` | :x: | :no_pedestrians: | :no_pedestrians: | :x:
`ngAfterViewInit() { ... }` | :x: | :no_pedestrians: | :no_pedestrians: | :x:
`ngAfterViewChecked() { ... }` | :no_pedestrians: | :no_pedestrians: | :x: | :x:
`ngOnDestroy() { ... }` | :x: | :no_pedestrians: | :no_pedestrians: | :x:

Dependency injection configuration | Validation | Auto-Complete | Navigation | Refactoring
-----------------------------------|------------|---------------|------------|-------------
`provide(MyService, useClass: MyMockService)` | :x: | :no_pedestrians: | :no_pedestrians: | :x:
`provide(MyService, useFactory: myFactory)` | :x: | :no_pedestrians: | :no_pedestrians: | :x:
`provide(MyValue, useValue: 41)` | :x: | :no_pedestrians: | :no_pedestrians: | :x:

Routing and navigation | Validation | Auto-Complete | Navigation | Refactoring
-----------------------|------------|---------------|------------|-------------
`@RouteConfig(const [ const Route(...) ])` | :x: | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
`<router-outlet></router-outlet>` | :no_pedestrians: | :x: | :no_pedestrians: | :no_pedestrians:
`<a [routerLink]="[ '/MyCmp', {myParam: 'value' } ]">` | :question: | :x: | :no_pedestrians: | :no_pedestrians:
`@CanActivate(() => ...)class MyComponent() {}` | :x: | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
`routerOnActivate(nextInstruction, prevInstruction) { ... }` | :x: | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
`routerCanReuse(nextInstruction, prevInstruction) { ... }` | :x: | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
`routerOnReuse(nextInstruction, prevInstruction) { ... }` | :x: | :x: | :no_pedestrians: | :no_pedestrians:
`routerCanDeactivate(nextInstruction, prevInstruction) { ... }` | :x: | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
`routerOnDeactivate(nextInstruction, prevInstruction) { ... }` | :x: | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
