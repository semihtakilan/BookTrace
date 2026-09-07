//
//  GoodreadsCSVCodec.swift
//  Models
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation

public enum GoodreadsCSVCodec {
    public enum CSVError: Error, Equatable, LocalizedError {
        case missingTitleColumn
        case malformedCSV
        case missingTitle(row: Int)

        public var errorDescription: String? {
            switch self {
            case .missingTitleColumn: "The CSV file must contain a Title column."
            case .malformedCSV: "The CSV file contains malformed quoted fields."
            case .missingTitle(let row): "The book on row \(row) has no title."
            }
        }
    }

    private static let columns = [
        "Book Id", "Title", "Author", "Author l-f", "Additional Authors", "ISBN", "ISBN13",
        "My Rating", "Average Rating", "Publisher", "Binding", "Number of Pages", "Year Published",
        "Original Publication Year", "Date Read", "Date Added", "Bookshelves", "Bookshelves with positions",
        "Exclusive Shelf", "My Review", "Spoiler", "Private Notes", "Read Count", "Owned Copies",
        "BookTrace ID", "Current Page", "Reading Status", "Favorite"
    ]

    public static func encode(_ entries: [LibraryEntry], timeZone: TimeZone = .current) -> String {
        let formatter = dateFormatter(timeZone: timeZone)
        let rows = entries.map { entry -> [String] in
            var row = Array(repeating: "", count: columns.count)
            let shelf: String
            switch entry.readingStatus {
            case .finished: shelf = "read"
            case .reading: shelf = "currently-reading"
            case .wishlist, .toRead, .abandoned: shelf = "to-read"
            }
            row[0] = entry.id.hasPrefix("local:goodreads:") ? String(entry.id.dropFirst("local:goodreads:".count)) : ""
            row[1] = safeCell(entry.book.title)
            row[2] = safeCell(entry.book.authors.first ?? "")
            row[4] = safeCell(entry.book.authors.dropFirst().joined(separator: ", "))
            row[6] = entry.book.isbn13 ?? ""
            row[7] = String(entry.rating ?? 0)
            row[11] = entry.effectivePageCount.map(String.init) ?? ""
            row[12] = entry.book.publicationYear ?? ""
            row[14] = entry.finishedDate.map(formatter.string) ?? ""
            row[15] = formatter.string(from: entry.addedDate)
            row[16] = safeCell(entry.categories.map(\.name).joined(separator: ", "))
            row[18] = shelf
            row[21] = safeCell(entry.notes ?? "")
            row[22] = entry.readingStatus == .finished ? "1" : "0"
            row[23] = entry.ownershipStatus == .owned ? "1" : "0"
            row[24] = safeCell(entry.id)
            row[25] = String(entry.currentPage)
            row[26] = entry.readingStatus.rawValue
            row[27] = entry.isFavorite ? "true" : "false"
            return row
        }
        return ([columns] + rows).map { $0.map(escaped).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// Imports local metadata immediately. ISBN enrichment is an optional
    /// network-layer concern and must not prevent a reader moving their library.
    public static func decode(_ csv: String, timeZone: TimeZone = .current) throws -> [LibraryEntry] {
        let rows = try parse(csv)
        guard let header = rows.first else { throw CSVError.missingTitleColumn }
        let names = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard names.contains("title") else { throw CSVError.missingTitleColumn }
        // Duplicate headings should not trap Dictionary(uniqueKeysWithValues:).
        var indices: [String: Int] = [:]
        for (index, name) in names.enumerated() where indices[name] == nil { indices[name] = index }
        let formatter = dateFormatter(timeZone: timeZone)
        var entries: [LibraryEntry] = []
        var seen = Set<String>()
        for (index, row) in rows.dropFirst().enumerated() {
            guard row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { continue }
            func field(_ name: String) -> String {
                guard let column = indices[name.lowercased()], row.indices.contains(column) else { return "" }
                return restoredCell(row[column]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let title = field("Title")
            guard !title.isEmpty else { throw CSVError.missingTitle(row: index + 2) }
            let isbn = normalizedISBN(field("ISBN13")) ?? normalizedISBN(field("ISBN"))
            let goodreadsID = field("Book Id")
            let sourceID = field("BookTrace ID")
            let id: String
            if !sourceID.isEmpty { id = sourceID }
            else if !goodreadsID.isEmpty { id = "local:goodreads:" + goodreadsID }
            else if let isbn { id = "local:isbn:" + isbn }
            else { id = "local:import:" + LibraryAnalytics.normalized(title + "|" + field("Author")) }
            guard seen.insert(id).inserted else { continue }
            let authors = ([field("Author")] + field("Additional Authors").components(separatedBy: ","))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let status = ReadingStatus(rawValue: field("Reading Status")) ?? {
                switch field("Exclusive Shelf").lowercased() {
                case "read": ReadingStatus.finished
                case "currently-reading": ReadingStatus.reading
                case "abandoned", "did-not-finish", "dnf": ReadingStatus.abandoned
                default: ReadingStatus.toRead
                }
            }()
            let notes = field("Private Notes").isEmpty ? field("My Review") : field("Private Notes")
            let pageCount = Int(field("Number of Pages")).flatMap { $0 > 0 ? $0 : nil }
            let categories = field("Bookshelves").components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty && !["read", "currently-reading", "to-read"].contains($0) }.map { Category(name: $0) }
            let year = field("Year Published")
            entries.append(LibraryEntry(
                book: BookReference(id: id, title: title, authors: authors, pageCount: pageCount,
                                    publishedDate: year.isEmpty ? nil : year, isbn13: isbn),
                readingStatus: status,
                ownershipStatus: (Int(field("Owned Copies")) ?? 0) > 0 ? .owned : .notOwned,
                currentPage: Int(field("Current Page")) ?? 0,
                categories: categories,
                addedDate: formatter.date(from: field("Date Added")) ?? Date(),
                rating: Int(field("My Rating")),
                finishedDate: formatter.date(from: field("Date Read")),
                notes: notes.isEmpty ? nil : notes,
                isFavorite: field("Favorite").lowercased() == "true" || categories.contains { $0.id == "favorites" }
            ))
        }
        return entries
    }

    // Goodreads dates describe a calendar day, not a UTC instant. Interpret and
    // export them in the reader's time zone so year boundaries stay in that year.
    private static func dateFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.isLenient = false
        return formatter
    }

    private static func normalizedISBN(_ value: String) -> String? {
        let cleaned = value.uppercased().filter { $0.isNumber || $0 == "X" }
        if cleaned.count == 13, cleaned.allSatisfy(\.isNumber) { return cleaned }
        guard cleaned.count == 10, cleaned.dropLast().allSatisfy(\.isNumber) else { return nil }
        // Goodreads often supplies ISBN-10 only; the app's lookup field is ISBN-13.
        let prefix = "978" + cleaned.dropLast()
        let sum = prefix.enumerated().reduce(0) { result, item in
            result + (item.element.wholeNumberValue ?? 0) * (item.offset.isMultiple(of: 2) ? 1 : 3)
        }
        return prefix + String((10 - sum % 10) % 10)
    }

    private static func escaped(_ value: String) -> String {
        value.contains(where: { [",", "\"", "\n", "\r"].contains($0) })
            ? "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : value
    }

    // Avoid turning user-authored titles or notes into spreadsheet formulas.
    private static func safeCell(_ value: String) -> String {
        guard let first = value.trimmingCharacters(in: .whitespacesAndNewlines).first,
              "=+-@".contains(first) else { return value }
        return "'" + value
    }

    private static func restoredCell(_ value: String) -> String {
        guard value.first == "'", let next = value.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines).first,
              "=+-@".contains(next) else { return value }
        return String(value.dropFirst())
    }

    private static func parse(_ input: String) throws -> [[String]] {
        var characters = Array(input)
        if characters.first == "\u{FEFF}" { characters.removeFirst() }
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var closedQuote = false
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if quoted {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        quoted = false
                        closedQuote = true
                    }
                } else { field.append(character) }
            } else if character == "," {
                row.append(field); field = ""; closedQuote = false
            } else if character == "\n" || character == "\r" || character == "\r\n" {
                row.append(field); rows.append(row)
                row = []; field = ""; closedQuote = false
                if character == "\r", index + 1 < characters.count, characters[index + 1] == "\n" { index += 1 }
            } else if character == "\"", field.isEmpty, !closedQuote {
                quoted = true
            } else if character == "\"" || closedQuote {
                throw CSVError.malformedCSV
            } else { field.append(character) }
            index += 1
        }
        guard !quoted else { throw CSVError.malformedCSV }
        if !field.isEmpty || !row.isEmpty || closedQuote { row.append(field); rows.append(row) }
        return rows
    }
}
