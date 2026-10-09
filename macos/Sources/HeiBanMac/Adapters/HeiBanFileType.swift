import UniformTypeIdentifiers

/// Version 1 is the shared, editable JSON document, using a distinct Finder type.
enum HeiBanFileType {
    static let document = UTType(exportedAs: "com.bear.heiban.document", conformingTo: .json)
}
