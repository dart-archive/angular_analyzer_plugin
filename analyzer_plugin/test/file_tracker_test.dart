import 'package:angular_analyzer_plugin/src/file_tracker.dart';
import 'package:analyzer/src/summary/api_signature.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';
import 'package:typed_mock/typed_mock.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FileTrackerTest);
  });
}

@reflectiveTest
class FileTrackerTest {
  FileTracker _fileTracker;
  _FileHasherMock _fileHasher;

  void setUp() {
    _fileHasher = new _FileHasherMock();
    _fileTracker = new FileTracker(_fileHasher);
  }

  void test_dartHasTemplate() {
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html"]);
    expect(_fileTracker.getHtmlPathsReferencedByDart("foo.dart"),
        equals(["foo.html"]));
  }

  void test_dartHasTemplates() {
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html", "foo_bar.html"]);
    expect(_fileTracker.getHtmlPathsReferencedByDart("foo.dart"),
        equals(["foo.html", "foo_bar.html"]));
  }

  void test_templateHasDart() {
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html"]);
    expect(_fileTracker.getDartPathsReferencingHtml("foo.html"),
        equals(["foo.dart"]));
  }

  void test_notReferencedDart() {
    expect(_fileTracker.getDartPathsReferencingHtml("foo.html"), equals([]));
  }

  void test_notReferencedHtml() {
    expect(_fileTracker.getDartPathsReferencingHtml("foo.dart"), equals([]));
  }

  void test_templatesHaveDart() {
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html"]);
    _fileTracker.setDartHtmlTemplates("foo_test.dart", ["foo.html"]);
    expect(_fileTracker.getDartPathsReferencingHtml("foo.html"),
        equals(["foo.dart", "foo_test.dart"]));
  }

  void test_templatesHaveDartRepeated() {
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html"]);
    _fileTracker.setDartHtmlTemplates("foo_test.dart", ["foo.html"]);
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html"]);
    expect(_fileTracker.getDartPathsReferencingHtml("foo.html"),
        equals(["foo.dart", "foo_test.dart"]));
  }

  void test_templatesHaveDartRemove() {
    _fileTracker.setDartHtmlTemplates("foo_test.dart", ["foo.html"]);
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html"]);
    _fileTracker.setDartHtmlTemplates("foo_test.dart", []);
    expect(_fileTracker.getDartPathsReferencingHtml("foo.html"),
        equals(["foo.dart"]));
  }

  void test_templatesHaveDartComplex() {
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html", "foo_b.html"]);
    _fileTracker
        .setDartHtmlTemplates("foo_test.dart", ["foo.html", "foo_b.html"]);
    _fileTracker.setDartHtmlTemplates("unrelated.dart", ["unrelated.html"]);
    expect(_fileTracker.getDartPathsReferencingHtml("foo.html"),
        equals(["foo.dart", "foo_test.dart"]));
    expect(_fileTracker.getDartPathsReferencingHtml("foo_b.html"),
        equals(["foo.dart", "foo_test.dart"]));

    _fileTracker.setDartHtmlTemplates("foo_test.dart", ["foo_b.html"]);
    expect(_fileTracker.getDartPathsReferencingHtml("foo.html"),
        equals(["foo.dart"]));
    expect(_fileTracker.getDartPathsReferencingHtml("foo_b.html"),
        equals(["foo.dart", "foo_test.dart"]));

    _fileTracker.setDartHtmlTemplates("foo_test.dart", ["foo.html"]);
    expect(_fileTracker.getDartPathsReferencingHtml("foo.html"),
        equals(["foo.dart", "foo_test.dart"]));
    expect(_fileTracker.getDartPathsReferencingHtml("foo_b.html"),
        equals(["foo.dart"]));

    _fileTracker
        .setDartHtmlTemplates("foo_test.dart", ["foo.html", "foo_test.html"]);
    expect(_fileTracker.getDartPathsReferencingHtml("foo.html"),
        equals(["foo.dart", "foo_test.dart"]));
    expect(_fileTracker.getDartPathsReferencingHtml("foo_b.html"),
        equals(["foo.dart"]));
    expect(_fileTracker.getDartPathsReferencingHtml("foo_test.html"),
        equals(["foo_test.dart"]));

    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html"]);
    _fileTracker.setDartHtmlTemplates("foo_b.dart", ["foo_b.html"]);
    expect(_fileTracker.getDartPathsReferencingHtml("foo.html"),
        equals(["foo.dart", "foo_test.dart"]));
    expect(_fileTracker.getDartPathsReferencingHtml("foo_b.html"),
        equals(["foo_b.dart"]));
    expect(_fileTracker.getDartPathsReferencingHtml("foo_test.html"),
        equals(["foo_test.dart"]));
  }

  void test_htmlHasHtmlEmpty() {
    expect(_fileTracker.getHtmlPathsReferencingHtml("foo.html"), equals([]));
  }

  void test_htmlHasHtmlEmptyNoImportedDart() {
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html"]);
    expect(_fileTracker.getHtmlPathsReferencingHtml("foo.html"), equals([]));
  }

  void test_htmlHasHtmlEmptyNoHtml() {
    _fileTracker.setDartHtmlTemplates("foo.dart", []);
    _fileTracker.setDartImports("foo.dart", ["bar.dart"]);
    _fileTracker.setDartHtmlTemplates("bar.dart", ["bar.html"]);
    expect(_fileTracker.getHtmlPathsReferencingHtml("bar.html"), equals([]));
  }

  void test_htmlHasHtml() {
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html"]);
    _fileTracker.setDartImports("foo.dart", ["bar.dart"]);
    _fileTracker.setDartHtmlTemplates("bar.dart", ["bar.html"]);
    expect(_fileTracker.getHtmlPathsReferencingHtml("bar.html"),
        equals(["foo.html"]));
  }

  void test_htmlHasHtmlMultipleResults() {
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html", "foo_b.html"]);
    _fileTracker.setDartImports("foo.dart", ["bar.dart", "baz.dart"]);
    _fileTracker.setDartHtmlTemplates("bar.dart", ["bar.html"]);
    _fileTracker.setDartHtmlTemplates("baz.dart", ["baz.html", "baz_b.html"]);
    expect(_fileTracker.getHtmlPathsReferencingHtml("bar.html"),
        equals(["foo.html", "foo_b.html"]));
    expect(_fileTracker.getHtmlPathsReferencingHtml("baz.html"),
        equals(["foo.html", "foo_b.html"]));
    expect(_fileTracker.getHtmlPathsReferencingHtml("baz_b.html"),
        equals(["foo.html", "foo_b.html"]));
  }

  void test_htmlHasHtmlButNotGrandchildren() {
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html"]);
    _fileTracker.setDartImports("foo.dart", ["child.dart"]);
    _fileTracker.setDartHtmlTemplates("child.dart", ["child.html"]);
    _fileTracker.setDartImports("child.dart", ["grandchild.dart"]);
    _fileTracker.setDartHtmlTemplates("grandchild.dart", ["grandchild.html"]);
    expect(_fileTracker.getHtmlPathsReferencingHtml("child.html"),
        equals(["foo.html"]));
    expect(_fileTracker.getHtmlPathsReferencingHtml("grandchild.html"),
        equals(["child.html"]));
  }

  void test_htmlHasDartEmpty() {
    expect(_fileTracker.getDartPathsAffectedByHtml("foo.html"), equals([]));
  }

  void test_htmlHasDartEmptyNoImportedDart() {
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html"]);
    expect(_fileTracker.getDartPathsAffectedByHtml("foo.html"), equals([]));
  }

  void test_htmlHasDartEmptyNotDartTemplate() {
    _fileTracker.setDartImports("foo.dart", ["bar.dart"]);
    _fileTracker.setDartHtmlTemplates("bar.dart", ["bar.html"]);
    expect(_fileTracker.getDartPathsAffectedByHtml("bar.html"), equals([]));
  }

  void test_htmlHasDart() {
    _fileTracker.setDartHasTemplate("foo.dart", true);
    _fileTracker.setDartImports("foo.dart", ["bar.dart"]);
    _fileTracker.setDartHtmlTemplates("bar.dart", ["bar.html"]);
    expect(_fileTracker.getDartPathsAffectedByHtml("bar.html"),
        equals(["foo.dart"]));
  }

  void test_htmlAffectingDartEmpty() {
    expect(_fileTracker.getHtmlPathsAffectingDart("foo.dart"), equals([]));
  }

  void test_htmlAffectingDartEmptyNoImportedDart() {
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html"]);
    expect(_fileTracker.getHtmlPathsAffectingDart("foo.dart"), equals([]));
  }

  void test_htmlAffectingDartEmptyNotDartTemplate() {
    _fileTracker.setDartImports("foo.dart", ["bar.dart"]);
    _fileTracker.setDartHtmlTemplates("bar.dart", ["bar.html"]);
    expect(_fileTracker.getHtmlPathsAffectingDart("foo.dart"), equals([]));
  }

  void test_htmlAffectingDart() {
    _fileTracker.setDartHasTemplate("foo.dart", true);
    _fileTracker.setDartImports("foo.dart", ["bar.dart"]);
    _fileTracker.setDartHtmlTemplates("bar.dart", ["bar.html"]);
    expect(_fileTracker.getHtmlPathsAffectingDart("foo.dart"),
        equals(["bar.html"]));
  }

  void test_htmlHasDartNotGrandchildren() {
    _fileTracker.setDartHasTemplate("foo.dart", true);
    _fileTracker.setDartImports("foo.dart", ["child.dart"]);
    _fileTracker.setDartHtmlTemplates("child.dart", ["child.html"]);
    _fileTracker.setDartImports("child.dart", ["grandchild.dart"]);
    _fileTracker.setDartHtmlTemplates("grandchild.dart", ["grandchild.html"]);
    expect(_fileTracker.getDartPathsAffectedByHtml("child.html"),
        equals(["foo.dart"]));
    expect(
        _fileTracker.getDartPathsAffectedByHtml("grandchild.html"), equals([]));
  }

  void test_htmlHasDartMultiple() {
    _fileTracker.setDartHasTemplate("foo.dart", true);
    _fileTracker.setDartImports("foo.dart", ["bar.dart", "baz.dart"]);
    _fileTracker.setDartHtmlTemplates("bar.dart", ["bar.html", "bar_b.html"]);
    _fileTracker.setDartHtmlTemplates("baz.dart", ["baz.html", "baz_b.html"]);
    expect(_fileTracker.getDartPathsAffectedByHtml("bar.html"),
        equals(["foo.dart"]));
    expect(_fileTracker.getDartPathsAffectedByHtml("bar_b.html"),
        equals(["foo.dart"]));
    expect(_fileTracker.getDartPathsAffectedByHtml("baz.html"),
        equals(["foo.dart"]));
    expect(_fileTracker.getDartPathsAffectedByHtml("baz_b.html"),
        equals(["foo.dart"]));
  }

  void test_htmlHasDartGetSignature() {
    _fileTracker.setDartHasTemplate("foo.dart", true);
    _fileTracker.setDartImports("foo.dart", ["bar.dart"]);
    _fileTracker.setDartHtmlTemplates("bar.dart", ["bar.html"]);

    ApiSignature fooDartElementSignature = new ApiSignature();
    fooDartElementSignature.addInt(1);
    ApiSignature barHtmlSignature = new ApiSignature();
    barHtmlSignature.addInt(2);

    when(_fileHasher.getContentHash("bar.html")).thenReturn(barHtmlSignature);
    when(_fileHasher.getUnitElementHash("foo.dart"))
        .thenReturn(fooDartElementSignature);

    ApiSignature expectedSignature = new ApiSignature();
    expectedSignature.addBytes(fooDartElementSignature.toByteList());
    expectedSignature.addBytes(barHtmlSignature.toByteList());

    expect(_fileTracker.getDartSignature("foo.dart").toHex(),
        equals(expectedSignature.toHex()));
  }

  void test_htmlHasHtmlGetSignature() {
    _fileTracker.setDartHtmlTemplates("foo.dart", ["foo.html"]);
    _fileTracker.setDartHtmlTemplates("foo_test.dart", ["foo.html"]);
    _fileTracker.setDartImports("foo.dart", ["bar.dart"]);
    _fileTracker.setDartHtmlTemplates("bar.dart", ["bar.html"]);

    ApiSignature fooHtmlSignature = new ApiSignature();
    fooHtmlSignature.addInt(1);
    ApiSignature fooDartElementSignature = new ApiSignature();
    fooDartElementSignature.addInt(2);
    ApiSignature fooTestDartElementSignature = new ApiSignature();
    fooDartElementSignature.addInt(3);
    ApiSignature barHtmlSignature = new ApiSignature();
    barHtmlSignature.addInt(4);

    when(_fileHasher.getContentHash("foo.html")).thenReturn(fooHtmlSignature);
    when(_fileHasher.getContentHash("bar.html")).thenReturn(barHtmlSignature);
    when(_fileHasher.getUnitElementHash("foo.dart"))
        .thenReturn(fooDartElementSignature);
    when(_fileHasher.getUnitElementHash("foo_test.dart"))
        .thenReturn(fooTestDartElementSignature);

    ApiSignature expectedSignature = new ApiSignature();
    expectedSignature.addBytes(fooHtmlSignature.toByteList());
    expectedSignature.addBytes(fooDartElementSignature.toByteList());
    expectedSignature.addBytes(barHtmlSignature.toByteList());
    expectedSignature.addBytes(fooTestDartElementSignature.toByteList());

    expect(_fileTracker.getHtmlSignature("foo.html").toHex(),
        equals(expectedSignature.toHex()));
  }

  void test_minimallyRehashesHtml() {
    ApiSignature fooHtmlSignature = new ApiSignature();
    fooHtmlSignature.addInt(1);
    when(_fileHasher.getContentHash("foo.html")).thenReturn(fooHtmlSignature);

    for (var i = 0; i < 3; ++i) {
      _fileTracker.getHtmlContentHash("foo.html");
      verify(_fileHasher.getContentHash("foo.html")).once();
    }

    for (var i = 0; i < 3; ++i) {
      _fileTracker.rehashHtmlContents("foo.html");
      verify(_fileHasher.getContentHash("foo.html")).times(2);
    }
  }
}

class _FileHasherMock extends TypedMock implements FileHasher {}
