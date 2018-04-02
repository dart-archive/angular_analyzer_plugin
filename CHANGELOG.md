## Unpublished Changes

- Fixed a bug where parts' templateUrls should be relative to the parts' library
  and not the part itself.
- Added support for === operator.

## 0.0.14

- Fixed issues with locating sources in Windows
- Fixed an order-of-operations bug where getting completions before errors
  suppressed the subsequent error notification.
- Fixed a performance problem due to new navigation features, and correctness
  issue where local unsaved changes were used in html navigation line/offset
  info.
- Fixed crashes in latest IntelliJ due to new navigation features
- Upgrade package:analyzer to support newest dart semantics.
- Fixed crash autocompleting before a comment
- Upgraded package:analyzer for latest dart semantics + bug fixes
- Upgraded package:analyzer_plugin for fix with autocompleting members on
  dynamic values

## 0.0.13

- Fixed a memory leak cause by a stream with no listener
- Support FutureOr-typed inputs
- Upgrade package:analyzer to support newest dart semantics.

## 0.0.12

- Support `(focusin)` and `(focusout)` events.
- Fix crash autocompleting an input in a star-attr when the input name matches
  the star attr text exactly.
- Bugfix regarding quotes in attribute selector values. For example, `[x="y"]`
  now correctly expects the value `y` for some attr `x`.
- Allow (and suggest) `List` instead of `QueryList`. Note, QueryList is still
  supported, for now.

Some larger items:

### Allow custom events with custom types to be specified. (#485)

Example syntax:

```
  analyzer:
    plugins:
      angular:
        enabled: true
        custom_events:
          doodle:
            type: DoodleEvent
            path: 'package:doodle/events.dart'
          poodle:
            type: PoodleEvent
            path: 'package:doodle/events.dart'
```

### Add new options for ContentChild(ren) in prep for deprecating ElementRef;
    
Accept (for the moment) ElementRef, Element, and HtmlElement (the
latter two being from dart:html).

Ensure HtmlElement and Element use read: x when @ContentChild('foo'), and check
assignability for the read: type.

Note, we currently don't differentiate SVG and HTML, so we accept either type
for either case at the moment.

## 0.0.11

- *@View no longer supported.*
- Clearer error for templates that are included from unconventional components.
  Usually, this is from test components where this occurs.
- Allow `directives: VARIABLE` in addition to `directives: const [VARIABLE]`.
- Functional Directive support
- Handle optional parameters in pipes
- Change "overcomplicated templates" error (templates set to const strings that
  are calculated rather than defined full-form, making error ranges difficult or
  impossible to provide) to a hint from an error.
- Expect angular classes to be in `package:angular` (though still look at
  `package:angular2` if that is missing).
- Check that reductions (ie, `(keyup.space)`) are only on key events.
- Support angular security, which otherwise produces assignment errors.
- *Plugin loading mechanism changed.*
- Support `<audio>` tag.
- Handle directive inheritance.

Some larger items:

### Allow custom tag names

Example syntax:

```
  analyzer:
    plugins:
      angular:
        enabled: true
        custom_tag_names:
          - foo
          - bar
          - baz
```

Most errors related to custom tags are suppressed, because custom tags are often
handled by other frameworks (ie, polymer).

# 0.0.10

Started changelog.
