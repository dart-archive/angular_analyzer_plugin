// TODO get this code working with new plugin arch
//class AngularOccurrencesContributor implements OccurrencesContributor {
//  @override
//  void computeOccurrences(
//      OccurrencesCollector collector, AnalysisContext context, Source source) {
//    //List<Source> librarySources = context.getLibrariesContaining(source);
//    //for (Source librarySource in librarySources) {
//    //  // directives
//    //  {
//    //    List<AbstractDirective> directives = context.getResult(
//    //        new LibrarySpecificUnit(librarySource, source), DIRECTIVES_IN_UNIT);
//    //    for (AbstractDirective directive in directives) {
//    //      _addDirectiveOccurrences(collector, directive);
//    //    }
//    //  }
//    //  // templates
//    //  {
//    //    List<Template> templates = context.getResult(
//    //        new LibrarySpecificUnit(librarySource, source), DART_TEMPLATES);
//    //    for (Template template in templates) {
//    //      _addTemplateOccurrences(collector, template);
//    //    }
//    //  }
//    //}
//  }
//
//  void addDirectiveOccurrences(
//      OccurrencesCollector collector, AbstractDirective directive) {
//    final elementsOffsets = <engine.PropertyAccessorElement, List<int>>{};
//    for (final input in directive.inputs) {
//      final setter = input.setter;
//      if (setter == null) {
//        continue;
//      }
//      var offsets = elementsOffsets[setter];
//      if (offsets == null) {
//        offsets = <int>[setter.nameOffset];
//        elementsOffsets[setter] = offsets;
//      }
//      offsets.add(input.setterRange.offset);
//    }
//    // convert map into Occurrences
//    elementsOffsets.forEach((setter, offsets) {
//      final protocolElement = _newProtocolElementForEngine(setter);
//      final length = protocolElement.location.length;
//      final occurrences =
//          new protocol.Occurrences(protocolElement, offsets, length);
//      collector.addOccurrences(occurrences);
//    });
//  }
//
//  void addTemplateOccurrences(
//      OccurrencesCollector collector, Template template) {
//    final elementsOffsets = <AngularElement, List<int>>{};
//    for (final resolvedRange in template.ranges) {
//      final element = resolvedRange.element;
//      var offsets = elementsOffsets[element];
//      if (offsets == null) {
//        offsets = <int>[element.nameOffset];
//        elementsOffsets[element] = offsets;
//      }
//      offsets.add(resolvedRange.range.offset);
//    }
//    // convert map into Occurrences
//    elementsOffsets.forEach((angularElement, offsets) {
//      final length = angularElement.nameLength;
//      final protocolElement = _newProtocolElement(angularElement);
//      final occurrences =
//          new protocol.Occurrences(protocolElement, offsets, length);
//      collector.addOccurrences(occurrences);
//    });
//  }
//
//  engine.Element _canonicalizeElement(engine.Element element) {
//    var canonical = element;
//    if (canonical is engine.PropertyAccessorElement) {
//      canonical = (canonical as engine.PropertyAccessorElement).variable;
//    }
//    if (canonical is Member) {
//      canonical = (canonical as Member).baseElement;
//    }
//    return canonical;
//  }
//
//  protocol.Element _newProtocolElement(AngularElement angularElement) {
//    final name = angularElement.name;
//    final length = name.length;
//    if (angularElement is DartElement) {
//      final dartElement = angularElement.element;
//      return _newProtocolElementForEngine(dartElement);
//    }
//    return new protocol.Element(protocol.ElementKind.UNKNOWN, name, 0,
//        location: new protocol.Location(angularElement.source.fullName,
//            angularElement.nameOffset, length, -1, -1));
//  }
//
//  protocol.Element _newProtocolElementForEngine(engine.Element dartElement) {
//    final cannonical = _canonicalizeElement(dartElement);
//    return protocol.convertElement(cannonical);
//  }
//}
