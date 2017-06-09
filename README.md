# Angular2 Dart Analysis Plugins

## Integration with Dart Analysis Server

  To provide information for DAS clients the `server_plugin` plugin contributes several extensions.

* Angular analysis errors are automatically merged into normal `errors` notifications for Dart and HTML files.

![Preview gif](https://raw.githubusercontent.com/dart-lang/angular_analyzer_plugin/master/assets/angular-dart-intellij-plugin-demo.gif "Preview gif")

**Check the pubspec.yaml in your project for transformers. They are not supported. You must manually add CORE_DIRECTIVES to your components right now for this plugin to work.**

## Building & Installing -- Version One (recommended but soon to be deprecated)

Download chrome depot tools, and clone this repository.

Then run 
```
./tools/get_deps.sh
cd server_plugin/bin
./make_snapshot
```

Back up `sdk_path/snapshots/analysis_server.dart.snapshot` and replace it with `server.snapshot`. Restart the dart analysis server by clicking the skull.

## Building -- Version Two (not usable yet, but this will soon be the future)

Under the next system, you will not need to build to install (woo hoo!). However, these steps currently don't produce anything usable. Installation steps will come once its ready.

Download chrome depot tools, and clone this repository.

Then run 
```
./tools/get_deps.sh
cd analyze_angular/tools/plugin
cp pubspec.yaml.defaults pubspec.yaml
```

Modify `pubspec.yaml` in this folder to fix the absolute paths. They **must** be absolute for the moment! Once they can be relative this step will not be required.

Then run `pub get`.

You can now use this in projects on your local system which a correctly configured pubspec. For instance, `playground/`. Note that you must `import 'package:analyze_angular/'` in your project to get the analysis.

## Chart of Current Features

We plug into many editors with varying degrees of support. In theory anything that supports Dart analysis also supports our plugin, but in practice that's not always the case.

Bootstrapping | Validation | Auto-Complete | Navigation | Refactoring
--------------|------------|---------------|------------|-------------
IntelliJ | :white_check_mark: | :white_check_mark: | :warning: some support in EAP | :no_pedestrians:
Vim (special setup required) | :white_check_mark: | :white_check_mark: | :white_check_mark: | :no_pedestrians:
others | :question: let us know! | :question: let us know! | :question: let us know! | :question: let us know!

If you are using an editor with Dart support that's not in this list, then please let us know what does or doesn't work. We can sometimes contribute fixes, too!

Bootstrapping | Validation | Auto-Complete | Navigation | Refactoring
--------------|------------|---------------|------------|-------------
`bootstrap(AppComponent, [MyService, provide(...)]);` | :no_pedestrians: | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:

Template syntax | Validation | Auto-Complete | Navigation | Refactoring
----------------|------------|---------------|------------|-------------
`<div stringInput="string">` | :white_check_mark: typecheck is string input on component | :white_check_mark: | :x: | :x:
`<input [value]="firstName">` | :white_check_mark: soundness of expression, type of expression, existence of `value` on element or directive | :white_check_mark: | :x: | :x:
`<input bind-value="firstName">` | :white_check_mark: | :skull: | :x: | :x:
`<div [attr.role]="myAriaRole">` | :last_quarter_moon: soundness of expression, but no other validation | :last_quarter_moon: complete inside binding but binding not suggested | :x: | :x:
`<div [class.extra-sparkle]="isDelightful">` | :white_check_mark: validity of clasname, soundness of expression, type of expression must be bool | :last_quarter_moon: complete inside binding but binding not suggested | :x: | :x:
`<div [style.width.px]="mySize">` | :waning_gibbous_moon: soundness of expression, css properties are generally checked but not against a dictionary, same for units, expression must type to `int` if units are present | :last_quarter_moon: complete inside binding but binding not suggested | :x: | :x:
`<button (click)="readRainbow($event)">` | :white_check_mark: soundness of expression, type of `$event`, existence of output on component/element and DOM events which propagate can be tracked anywhere | :white_check_mark: | :x: | :x:
`<button on-click="readRainbow($event)">` | :white_check_mark: | :skull: | :x: | :x:
`<div title="Hello {{ponyName}}">` | :white_check_mark: soundness of expression, matching mustache delimiters | :white_check_mark: | :x: | :x:
`<p>Hello {{ponyName}}</p>` | :white_check_mark: soundness of expression, matching mustache delimiters | :white_check_mark: | :x: | :x:
`<my-cmp></my-cmp>` | :white_check_mark: existence of directive |:white_check_mark: | :x: | :x:
`<my-cmp [(title)]="name">` | :white_check_mark: soundness of expression, existence of `title` input and `titleChange` output on directive or component with proper type | :white_check_mark: | :x: | :x:
`<video #movieplayer ...></video><button (click)="movieplayer.play()">` | :white_check_mark: type of new variable tracked and checked in other expressions | :white_check_mark: | :x: | :x:
`<video ref-movieplayer ...></video><button (click)="movieplayer.play()">` | :white_check_mark: |:white_check_mark: | :x: | :x:
`<p *myUnless="myExpression">...</p>` | :white_check_mark: desugared to `<template [myUnless]="myExpression"><p>...` and checked from there | :white_check_mark: | :x: | :x:
`<p>Card No.: {{cardNumber \| myCardNumberFormatter}}</p>` | :x: Pipes are not typechecked yet | :x: | :x: | :x:
`<my-component @deferred>` | :x: | :x: | :x: | :x:

Built-in directives | Validation | Auto-Complete | Navigation | Refactoring
--------------------|------------|---------------|------------|-------------
`<section *ngIf="showSection">` | :white_check_mark: type checking, check for the star | :white_check_mark: | :x: | :x:
`<li *ngFor="let item of list">` | :white_check_mark: type checking and new var, check for the star, catch accidental usage of `#item` | :white_check_mark: | :x: | :x:
`<div [ngClass]="{active: isActive, disabled: isDisabled}">` | :warning: Requires quotes around key value strings to work | :white_check_mark: | :x: | :x:

Forms | Validation | Auto-Complete | Navigation | Refactoring
------|------------|---------------|------------|-------------
`<input [(ngModel)]="userName">` | :white_check_mark: | :white_check_mark: | :x: | :x:
`<form #myform="ngForm">` | :white_check_mark: if `ngForm` is not an exported directive | :last_quarter_moon: completion of variable but ngForm not suggested | :x: | :x:

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
`template: 'Hello {{name}}'` | :white_check_mark: | :white_check_mark: | :x: | :x:
`templateUrl: 'my-component.html'` | :white_check_mark: | :x: | :x: | :x:
`styles: ['.primary {color: red}']` | :x: | :no_pedestrians: | :no_pedestrians: | :no_pedestrians:
`styleUrls: ['my-component.css']` | :x: | :x: | :x: | :x:
`directives: [MyDirective, MyComponent]` | :white_check_mark: must be directives or lists of directives, configuration affects view errors | :x: | :x: | :x:
`pipes: [MyPipe, OtherPipe]` | :x: | :x: | :x: | :x:
`exports: [Class, Enum, staticFn]` | :x: | :x: | :x: | :x:

Class field decorators for directives and components | Validation | Auto-Complete | Navigation | Refactoring
-----------------------------------------------------|------------|---------------|------------|-------------
`@Input() myProperty;` | :white_check_mark: | :no_pedestrians: | :x: | :x:
`@Input("name") myProperty;` | :white_check_mark: | :no_pedestrians: | :x: | :x:
`@Output() myEvent = new Stream<X>();` | :white_check_mark: Subtype of `Stream<T>` required, streamed type determines `$event` type | :no_pedestrians: | :x: | :x:
`@Output("name") myEvent = new Stream<X>();` | :white_check_mark: | :no_pedestrians: | :x: | :x:
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
`<ng-content select="foo"></ng-content>` | :white_check_mark: | :white_check_mark: | :x: | :x:
`<my-comp><foo></foo></my-comp>` | :white_check_mark: | :white_check_mark: | :x: | :x:
`<ng-content select=".foo[bar]"></ng-content>` | :white_check_mark: | :white_check_mark: | :x: | :x:
`<my-comp><div class="foo" bar></div></my-comp>` | :white_check_mark: | :white_check_mark: | :x: | :x:

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
