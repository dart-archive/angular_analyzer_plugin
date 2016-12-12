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

Download chrome depot tools, and clone this repository.

Then run 
```
./tools/get_deps.sh
cd server_plugin/bin
./make_snapshot
```

Back up `sdk_path/snapshots/analysis_server.dart.snapshot` and replace it with `server.snapshot`. Restart the dart analysis server by clicking the skull.

## Chart of Current Features

All regular dart errros (that is to say, errors defined purely by the dart language spec) are not shown in this list.

Bootstrapping | Validation | Auto-Complete | Navigation | Refactoring
--------------|------------|---------------|------------|-------------
`bootstrap(AppComponent, [MyService, provide(...)]);` | :no_pedestrians: Is there anything to validate here that the dart checker doesn't already catch? | :x: | :x: | :x:

Template syntax | Validation | Auto-Complete | Navigation | Refactoring
----------------|------------|---------------|------------|-------------
`<input [value]="firstName">` | :white_check_mark: soundness of expression, type of expression, existence of `value` on element or directive | :x: | :x: | :x:
`<input bind-value="firstName">` | :white_check_mark: | :x: | :x: | :x:
`<div [attr.role]="myAriaRole">` | :last_quarter_moon: soundness of expression, but no other validation | :x: | :x: | :x:
`<div [class.extra-sparkle]="isDelightful">` | :white_check_mark: validity of clasname, soundness of expression, type of expression must be bool | :x: | :x: | :x:
`<div [style.width.px]="mySize">` | :waning_gibbous_moon: soundness of expression, css properties are generally checked but not against a dictionary, same for units, expression must type to `int` if units are present | :x: | :x: | :x:
`<button (click)="readRainbow($event)">` | :white_check_mark: soundness of expression, type of `$event`, existence of output on component/element and DOM events which propagate can be tracked anywhere | :x: | :x: | :x:
`<button on-click="readRainbow($event)">` | :white_check_mark: | :x: | :x: | :x:
`<div title="Hello {{ponyName}}">` | :white_check_mark: soundness of expression, matching mustache delimiters | :x: | :x: | :x:
`<p>Hello {{ponyName}}</p>` | :white_check_mark: soundness of expression, matching mustache delimiters | :x: | :x: | :x:
`<my-cmp></my-cmp>` | :white_check_mark: Existence of directive | :x: | :x: | :x:
`<my-cmp [(title)]="name">` | :white_check_mark: soundness of expression, existence of `title` input and `titleChange` output on directive or component with proper type | :x: | :x: | :x:
`<video #movieplayer ...></video><button (click)="movieplayer.play()">` | :white_check_mark: Type of new variable tracked and checked in other expressions | :x: | :x: | :x:
`<video ref-movieplayer ...></video><button (click)="movieplayer.play()">` | :white_check_mark: | :x: | :x: | :x:
`<p *myUnless="myExpression">...</p>` | :white_check_mark: desugared to `<template [myUnless]="myExpression"><p>...` and checked from there | :x: | :x: | :x:
`<p>Card No.: {{cardNumber | myCardNumberFormatter}}</p>` | :poop: false errors will be reported | :x: | :x: | :x:

Built-in directives | Validation | Auto-Complete | Navigation | Refactoring
--------------------|------------|---------------|------------|-------------
`<section *ngIf="showSection">` | :white_check_mark: type checking, check for the star | :x: | :x: | :x:
`<li *ngFor="let item of list">` | :white_check_mark: type checking and new var, check for the star | :x: | :x: | :x:
`<div [ngClass]="{active: isActive, disabled: isDisabled}">` | :warning: Requires quotes around key value strings to work | :x: | :x: | :x:

Forms | Validation | Auto-Complete | Navigation | Refactoring
------|------------|---------------|------------|-------------
`<input [(ngModel)]="userName">` | :white_check_mark: | :x: | :x: | :x:
`<form #myform="ngForm">` | :white_check_mark: if `ngForm` is not an exported directive | :x: | :x: | :x:

Class decorators | Validation | Auto-Complete | Navigation | Refactoring
-----------------|------------|---------------|------------|-------------
`@Component(...) class MyComponent {}` | :white_check_mark: Validates directives list is all directives, that the template file exists, that a template is specified via string or URL but not both, requires a valid selector | :x: | :x: | :x:
`@View(...) class MyComponent {}` | :warning: Supported, requires `@Directive` or `@Component`, but doesn't catch ambigous cases such as templates defined in the `@View` as well as `@Component` | :x: | :x: | :x:
`@Directive(...) class MyDirective {}` | :white_check_mark: Validates directives list is all directives, that the template file exists, that a template is specified via string or URL but not both, requires a valid selector | :x: | :x: | :x:
`@Pipe(...) class MyPipe {}` | :x: | :x: | :x: | :x:
`@Injectable() class MyService {}` | :x: | :x: | :x: | :x:

Directive configuration | Validation | Auto-Complete | Navigation | Refactoring
------------------------|------------|---------------|------------|-------------
`@Directive(property1: value1, ...)` | :warning: deprecated, but supported | :x: | :x: | :x:
`selector: '.cool-button:not(a)'` | :waning_gibbous_moon: Not all selector syntax supported | :x: | :x: | :x:
`providers: [MyService, provide(...)]` | :x: | :x: | :x: | :x:
`inputs: ['myprop', 'myprop2: byname']` | :white_check_mark: | :x: | :x: | :x:
`outputs: ['myprop', 'myprop2: byname']` | :white_check_mark: | :x: | :x: | :x:

@Component extends @Directive, so the @Directive configuration applies to components as well

Component Configuration | Validation | Auto-Complete | Navigation | Refactoring
------------------------|------------|---------------|------------|-------------
`viewProviders: [MyService, provide(...)]` | :x: | :x: | :x: | :x:
`template: 'Hello {{name}}'` | :white_check_mark: | :x: | :x: | :x:
`templateUrl: 'my-component.html'` | :white_check_mark: | :x: | :x: | :x:
`styles: ['.primary {color: red}']` | :x: | :x: | :x: | :x:
`styleUrls: ['my-component.css']` | :x: | :x: | :x: | :x:
`directives: [MyDirective, MyComponent]` | :white_check_mark: must be directives or lists of directives, configuration affects view errors | :x: | :x: | :x:
`pipes: [MyPipe, OtherPipe]` | :x: | :x: | :x: | :x:

Class field decorators for directives and components | Validation | Auto-Complete | Navigation | Refactoring
-----------------------------------------------------|------------|---------------|------------|-------------
`@Input() myProperty;` | :white_check_mark: | :x: | :x: | :x:
`@Input("name") myProperty;` | :white_check_mark: | :x: | :x: | :x:
`@Output() myEvent = new EventEmitter();` | :white_check_mark: Subtype of `Stream<T>` required, streamed type determines `$event` type | :x: | :x: | :x:
`@Output("name") myEvent = new EventEmitter();` | :white_check_mark: | :x: | :x: | :x:
`@HostBinding('[class.valid]') isValid;` | :x: | :x: | :x: | :x:
`@HostListener('click', ['$event']) onClick(e) {...}` | :x: | :x: | :x: | :x:
`@ContentChild(myPredicate) myChildComponent;` | :x: | :x: | :x: | :x:
`@ContentChildren(myPredicate) myChildComponents;` | :x: | :x: | :x: | :x:
`@ViewChild(myPredicate) myChildComponent;` | :x: | :x: | :x: | :x:
`@ViewChildren(myPredicate) myChildComponents;` | :x: | :x: | :x: | :x:

Directive and component change detection and lifecycle hooks (implemented as class methods) | Validation | Auto-Complete | Navigation | Refactoring
--------------------------------------------------------------------------------------------|------------|---------------|------------|-------------
`MyAppComponent(MyService myService, ...) { ... }` | :x: | :x: | :x: | :x:
`ngOnChanges(changeRecord) { ... }` | :x: | :x: | :x: | :x:
`ngOnInit() { ... }` | :x: | :x: | :x: | :x:
`ngDoCheck() { ... }` | :x: | :x: | :x: | :x:
`ngAfterContentInit() { ... }` | :x: | :x: | :x: | :x:
`ngAfterContentChecked() { ... }` | :x: | :x: | :x: | :x:
`ngAfterViewInit() { ... }` | :x: | :x: | :x: | :x:
`ngAfterViewChecked() { ... }` | :x: | :x: | :x: | :x:
`ngOnDestroy() { ... }` | :x: | :x: | :x: | :x:

Dependency injection configuration | Validation | Auto-Complete | Navigation | Refactoring
-----------------------------------|------------|---------------|------------|-------------
`provide(MyService, useClass: MyMockService)` | :x: | :x: | :x: | :x:
`provide(MyService, useFactory: myFactory)` | :x: | :x: | :x: | :x:
`provide(MyValue, useValue: 41)` | :x: | :x: | :x: | :x:

Routing and navigation | Validation | Auto-Complete | Navigation | Refactoring
-----------------------|------------|---------------|------------|-------------
`@RouteConfig(const [ const Route(...) ])` | :x: | :x: | :x: | :x:
`<router-outlet></router-outlet>` | :no_pedestrians: Is there anything to validate here? | :x: | :x: | :x:
`<a [routerLink]="[ '/MyCmp', {myParam: 'value' } ]">` | :question: | :x: | :x: | :x:
`@CanActivate(() => ...)class MyComponent() {}` | :x: | :x: | :x: | :x:
`routerOnActivate(nextInstruction, prevInstruction) { ... }` | :x: | :x: | :x: | :x:
`routerCanReuse(nextInstruction, prevInstruction) { ... }` | :x: | :x: | :x: | :x:
`routerOnReuse(nextInstruction, prevInstruction) { ... }` | :x: | :x: | :x: | :x:
`routerCanDeactivate(nextInstruction, prevInstruction) { ... }` | :x: | :x: | :x: | :x:
`routerOnDeactivate(nextInstruction, prevInstruction) { ... }` | :x: | :x: | :x: | :x:
