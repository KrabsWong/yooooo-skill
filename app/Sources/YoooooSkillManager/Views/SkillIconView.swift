import AppKit
import SwiftUI
import YoooooSkillManagerCore

struct SkillIconView: View {
  var skill: SkillInfo
  var size: CGFloat = 20
  var usesCategoryTint = true

  private var kind: SkillIconKind {
    SkillIconKind.resolve(for: skill)
  }

  var body: some View {
    Image(systemName: kind.systemName)
      .font(.system(size: size, weight: .regular))
      .symbolRenderingMode(.hierarchical)
      .foregroundStyle(usesCategoryTint ? kind.tint : Color.secondary)
      .frame(width: size + 2, height: size + 2)
      .help(kind.label)
  }
}

private enum SkillIconKind {
  case ai
  case automation
  case browser
  case calendar
  case chart
  case code
  case comic
  case communication
  case compression
  case conversion
  case diagram
  case document
  case finance
  case image
  case mail
  case presentation
  case research
  case security
  case spreadsheet
  case writing
  case generic

  static func resolve(for skill: SkillInfo) -> SkillIconKind {
    let text = [
      skill.name,
      skill.directoryName,
      skill.description,
      skill.source
    ]
    .joined(separator: " ")
    .lowercased()

    func contains(_ tokens: [String]) -> Bool {
      tokens.contains { text.contains($0) }
    }

    if contains(["compress", "optimize", "webp", "png", "jpeg", "jpg"]) {
      return .compression
    }

    if contains(["diagram", "flowchart", "sequence", "mind map", "architecture", "topology", "state machine"]) {
      return .diagram
    }

    if contains(["infographic", "chart", "visualization", "visualize", "report", "analytics"]) {
      return .chart
    }

    if contains(["comic", "cartoon", "panel", "漫画"]) {
      return .comic
    }

    if contains(["gemini", "openai", "anthropic", "agent", "ai ", "llm", "prompt"]) {
      return .ai
    }

    if contains(["cover", "illustrator", "illustration", "image", "photo", "svg", "图片", "图像"]) {
      return .image
    }

    if contains(["markdown", "html", "docx", "pdf", "document", "format"]) {
      return .document
    }

    if contains(["electron", "extract", "javascript", "typescript", "code", "api", "script"]) {
      return .code
    }

    if contains(["browser", "web", "website", "url", "http"]) {
      return .browser
    }

    if contains(["wechat", "weibo", "post", "publish", "social", "twitter"]) {
      return .communication
    }

    if contains(["convert", "transform", "migration", "to-"]) {
      return .conversion
    }

    if contains(["write", "article", "blog", "copy", "text", "content"]) {
      return .writing
    }

    if contains(["search", "research", "crawl", "scrape"]) {
      return .research
    }

    if contains(["calendar", "schedule", "event"]) {
      return .calendar
    }

    if contains(["email", "mail"]) {
      return .mail
    }

    if contains(["sheet", "spreadsheet", "csv", "table"]) {
      return .spreadsheet
    }

    if contains(["slide", "presentation", "ppt"]) {
      return .presentation
    }

    if contains(["finance", "stock", "earnings", "trading"]) {
      return .finance
    }

    if contains(["security", "secret", "sandbox", "permission"]) {
      return .security
    }

    if contains(["workflow", "automation", "task", "tool"]) {
      return .automation
    }

    return .generic
  }

  private var preferredSymbols: [String] {
    switch self {
    case .ai:
      return ["sparkles", "wand.and.stars"]
    case .automation:
      return ["gearshape.2", "gearshape"]
    case .browser:
      return ["globe", "safari"]
    case .calendar:
      return ["calendar"]
    case .chart:
      return ["chart.xyaxis.line", "chart.bar.xaxis", "chart.bar"]
    case .code:
      return ["chevron.left.forwardslash.chevron.right", "curlybraces"]
    case .comic:
      return ["rectangle.stack", "square.on.square"]
    case .communication:
      return ["paperplane", "megaphone"]
    case .compression:
      return ["archivebox", "arrow.down.right.and.arrow.up.left"]
    case .conversion:
      return ["arrow.left.arrow.right", "arrow.triangle.2.circlepath"]
    case .diagram:
      return ["point.3.connected.trianglepath.dotted", "arrow.triangle.branch", "square.grid.2x2"]
    case .document:
      return ["doc.text", "doc"]
    case .finance:
      return ["dollarsign.chart.line", "chart.line.uptrend.xyaxis", "dollarsign.circle"]
    case .image:
      return ["photo.on.rectangle", "photo"]
    case .mail:
      return ["envelope"]
    case .presentation:
      return ["rectangle.on.rectangle", "play.rectangle"]
    case .research:
      return ["magnifyingglass"]
    case .security:
      return ["lock.shield", "lock"]
    case .spreadsheet:
      return ["tablecells", "table"]
    case .writing:
      return ["doc.richtext", "text.book.closed", "doc.text"]
    case .generic:
      return ["square.stack.3d.up", "shippingbox"]
    }
  }

  var systemName: String {
    preferredSymbols.first { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }
      ?? "shippingbox"
  }

  var label: String {
    switch self {
    case .ai:
      return "AI skill"
    case .automation:
      return "Automation skill"
    case .browser:
      return "Web skill"
    case .calendar:
      return "Calendar skill"
    case .chart:
      return "Chart skill"
    case .code:
      return "Code skill"
    case .comic:
      return "Comic skill"
    case .communication:
      return "Publishing skill"
    case .compression:
      return "Compression skill"
    case .conversion:
      return "Conversion skill"
    case .diagram:
      return "Diagram skill"
    case .document:
      return "Document skill"
    case .finance:
      return "Finance skill"
    case .image:
      return "Image skill"
    case .mail:
      return "Email skill"
    case .presentation:
      return "Presentation skill"
    case .research:
      return "Research skill"
    case .security:
      return "Security skill"
    case .spreadsheet:
      return "Spreadsheet skill"
    case .writing:
      return "Writing skill"
    case .generic:
      return "Skill"
    }
  }

  var tint: Color {
    switch self {
    case .ai:
      return .purple
    case .automation:
      return .gray
    case .browser:
      return .blue
    case .calendar:
      return .red
    case .chart:
      return .orange
    case .code:
      return .teal
    case .comic:
      return .pink
    case .communication:
      return .cyan
    case .compression:
      return .brown
    case .conversion:
      return .indigo
    case .diagram:
      return .mint
    case .document:
      return .secondary
    case .finance:
      return .green
    case .image:
      return .purple
    case .mail:
      return .blue
    case .presentation:
      return .orange
    case .research:
      return .secondary
    case .security:
      return .red
    case .spreadsheet:
      return .green
    case .writing:
      return .indigo
    case .generic:
      return .secondary
    }
  }
}
