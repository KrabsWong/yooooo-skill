import Foundation

public enum FrontmatterParser {
  public static func parse(_ content: String) -> [String: String] {
    let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
    let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    guard lines.first == "---" else {
      return [:]
    }

    guard let endIndex = lines.dropFirst().firstIndex(where: { $0 == "---" }) else {
      return [:]
    }

    let frontmatter = Array(lines[1..<endIndex])
    var metadata: [String: String] = [:]
    var index = 0

    while index < frontmatter.count {
      let line = frontmatter[index]
      guard let parsed = parseKeyValue(line) else {
        index += 1
        continue
      }

      let marker = parsed.value.trimmingCharacters(in: .whitespaces)
      if isBlockMarker(marker) {
        let block = parseBlock(lines: frontmatter, from: index + 1, marker: marker)
        metadata[parsed.key] = block.text
        index = block.nextIndex
      } else {
        metadata[parsed.key] = parseScalar(parsed.value)
        index += 1
      }
    }

    return metadata
  }

  private static func parseKeyValue(_ line: String) -> (key: String, value: String)? {
    guard let colon = line.firstIndex(of: ":") else {
      return nil
    }

    let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
    guard !key.isEmpty, key.allSatisfy(isPortableKeyCharacter) else {
      return nil
    }

    let valueStart = line.index(after: colon)
    return (key, String(line[valueStart...]))
  }

  private static func isPortableKeyCharacter(_ character: Character) -> Bool {
    character.isLetter || character.isNumber || character == "-" || character == "_"
  }

  private static func parseScalar(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    guard trimmed.count >= 2 else {
      return trimmed
    }

    if (trimmed.first == "\"" && trimmed.last == "\"") || (trimmed.first == "'" && trimmed.last == "'") {
      let unquoted = String(trimmed.dropFirst().dropLast())
      return unquoted
        .replacingOccurrences(of: "\\\"", with: "\"")
        .replacingOccurrences(of: "\\'", with: "'")
    }

    return trimmed
  }

  private static func isBlockMarker(_ marker: String) -> Bool {
    ["|", "|-", "|+", ">", ">-", ">+"].contains(marker)
  }

  private static func parseBlock(lines: [String], from startIndex: Int, marker: String) -> (text: String, nextIndex: Int) {
    var blockLines: [String] = []
    var index = startIndex
    var blockIndent: Int?

    while index < lines.count {
      let line = lines[index]
      if parseKeyValue(line) != nil {
        break
      }

      if line.trimmingCharacters(in: .whitespaces).isEmpty {
        blockLines.append("")
        index += 1
        continue
      }

      let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count
      guard indent > 0 else {
        break
      }

      blockIndent = min(blockIndent ?? indent, indent)
      blockLines.append(line)
      index += 1
    }

    let normalized = blockLines.map { line in
      guard let blockIndent, line.count >= blockIndent else {
        return line.trimmingCharacters(in: .whitespaces)
      }

      let start = line.index(line.startIndex, offsetBy: blockIndent)
      return String(line[start...])
    }

    let text = marker.hasPrefix("|")
      ? normalized.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
      : normalized.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")

    return (text, index)
  }
}
