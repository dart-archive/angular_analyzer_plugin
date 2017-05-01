import 'dart:collection';

import 'package:analyzer/src/summary/api_signature.dart';

abstract class FileHasher {
  ApiSignature getContentHash(String path);
  ApiSignature getUnitElementHash(String path);
}

class FileTracker {
  final FileHasher _fileHasher;

  FileTracker(this._fileHasher);

  final _RelationshipTracker _dartToDart = new _RelationshipTracker();
  final _RelationshipTracker _dartToHtml = new _RelationshipTracker();

  final Set<String> _dartFilesWithDartTemplates = new HashSet<String>();

  final Map<String, List<int>> htmlContentHashes = {};

  void rehashHtmlContents(String path) {
    htmlContentHashes[path] = _fileHasher.getContentHash(path).toByteList();
  }

  List<int> getHtmlContentHash(String path) {
    if (htmlContentHashes[path] == null) {
      rehashHtmlContents(path);
    }
    return htmlContentHashes[path];
  }

  void setDartHtmlTemplates(String dartPath, List<String> htmlPaths) {
    return _dartToHtml.setFileReferencesFiles(dartPath, htmlPaths);
  }

  void setDartHasTemplate(String dartPath, bool hasTemplate) {
    if (hasTemplate) {
      _dartFilesWithDartTemplates.add(dartPath);
    } else {
      _dartFilesWithDartTemplates.remove(dartPath);
    }
  }

  List<String> getHtmlPathsReferencedByDart(String dartPath) {
    return _dartToHtml.getFilesReferencedBy(dartPath);
  }

  List<String> getDartPathsReferencingHtml(String htmlPath) {
    return _dartToHtml.getFilesReferencingFile(htmlPath);
  }

  void setDartImports(String dartPath, List<String> imports) {
    _dartToDart.setFileReferencesFiles(dartPath, imports);
  }

  List<String> getHtmlPathsReferencingHtml(String htmlPath) {
    return _dartToHtml
        .getFilesReferencingFile(htmlPath)
        .map((dartPath) => _dartToDart.getFilesReferencingFile(dartPath))
        .fold(<String>[], (list, acc) => list..addAll(acc))
        .map((dartPath) => _dartToHtml.getFilesReferencedBy(dartPath))
        .fold(<String>[], (list, acc) => list..addAll(acc));
  }

  List<String> getDartPathsAffectedByHtml(String htmlPath) {
    return _dartToHtml
        .getFilesReferencingFile(htmlPath)
        .map((dartPath) => _dartToDart.getFilesReferencingFile(dartPath))
        .fold(<String>[], (list, acc) => list..addAll(acc))
        .where((dartPath) => _dartFilesWithDartTemplates.contains(dartPath))
        .toList();
  }

  List<String> getHtmlPathsAffectingDart(String dartPath) {
    if (_dartFilesWithDartTemplates.contains(dartPath)) {
      return getHtmlPathsAffectingDartContext(dartPath);
    }

    return [];
  }

  List<String> getHtmlPathsAffectingDartContext(String dartPath) {
    return _dartToDart
        .getFilesReferencedBy(dartPath)
        .map((dartPath) => _dartToHtml.getFilesReferencedBy(dartPath))
        .fold(<String>[], (list, acc) => list..addAll(acc));
  }

  ApiSignature getDartSignature(String dartPath) {
    final signature = new ApiSignature();
    signature.addBytes(_fileHasher.getUnitElementHash(dartPath).toByteList());
    for (final htmlPath in getHtmlPathsAffectingDart(dartPath)) {
      signature.addBytes(getHtmlContentHash(htmlPath));
    }
    return signature;
  }

  ApiSignature getHtmlSignature(String htmlPath) {
    final signature = new ApiSignature();
    signature.addBytes(getHtmlContentHash(htmlPath));
    for (final dartPath in getDartPathsReferencingHtml(htmlPath)) {
      signature.addBytes(_fileHasher.getUnitElementHash(dartPath).toByteList());
      for (final subHtmlPath in getHtmlPathsAffectingDartContext(dartPath)) {
        signature.addBytes(getHtmlContentHash(subHtmlPath));
      }
    }
    return signature;
  }
}

class _RelationshipTracker {
  Map<String, List<String>> _filesReferencedByFile = <String, List<String>>{};
  Map<String, List<String>> _filesReferencingFile = <String, List<String>>{};

  void setFileReferencesFiles(String filePath, List<String> referencesPaths) {
    Set<String> priorRelationships = new HashSet<String>();
    if (_filesReferencedByFile.containsKey(filePath)) {
      for (final referencesPath in _filesReferencedByFile[filePath]) {
        if (!referencesPaths.contains(referencesPath)) {
          _filesReferencingFile[referencesPath].remove(filePath);
        } else {
          priorRelationships.add(referencesPath);
        }
      }
    }

    _filesReferencedByFile[filePath] = referencesPaths;

    for (final referencesPath in referencesPaths) {
      if (priorRelationships.contains(referencesPath)) {
        continue;
      }

      if (!_filesReferencingFile.containsKey(referencesPath)) {
        _filesReferencingFile[referencesPath] = [filePath];
      } else {
        _filesReferencingFile[referencesPath].add(filePath);
      }
    }
  }

  List<String> getFilesReferencedBy(String filePath) {
    return _filesReferencedByFile[filePath] ?? [];
  }

  List<String> getFilesReferencingFile(String usesPath) {
    return _filesReferencingFile[usesPath] ?? [];
  }
}
