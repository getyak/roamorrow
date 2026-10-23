import Foundation

/// Presentation only: one response keeps its original identity, text, sources and actions.
enum CompanionReplyLayout {
    static func parts(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        // Structured Markdown and links need their surrounding context. Never sentence-split
        // punctuation: abbreviations, decimals, URLs and quotations are not message boundaries.
        let lines = text.components(separatedBy: .newlines)
        let structured = lines.contains { line in
            let value = line.trimmingCharacters(in: .whitespaces)
            return line.hasPrefix("    ") || line.hasPrefix("\t")
                || value.hasPrefix("```") || value.hasPrefix("~~~") || value.hasPrefix(">")
                || value.hasPrefix("#") || value.hasPrefix("|") || value.hasPrefix("- ")
                || value.hasPrefix("* ") || value.hasPrefix("+ ")
                || value.range(of: #"^\d+[.)]\s"#, options: .regularExpression) != nil
                || value.range(of: #"^\[[^\]]+\]:"#, options: .regularExpression) != nil
                || value == "---" || value == "==="
        }
        guard !structured, !text.contains("]("), !text.contains("][") else { return [text] }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let parts = normalized.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard (2...3).contains(parts.count) else { return [text] }
        return parts
    }
}
