import SwiftUI
import YoooooSkillManagerCore

struct ToolIconView: View {
  var tool: AgentTool
  var size: CGFloat = 18

  var body: some View {
    icon
      .frame(width: size, height: size)
  }

  @ViewBuilder
  private var icon: some View {
    if let assetName = tool.iconAssetName {
      BrandIconImage(assetName: assetName, fallbackSystemName: tool.iconSystemName, size: size)
    } else {
      Image(systemName: tool.iconSystemName)
        .font(.system(size: size, weight: .regular))
        .foregroundStyle(.secondary)
    }
  }
}

struct BrandIconImage: View {
  var assetName: String
  var fallbackSystemName: String
  var size: CGFloat
  @Environment(\.colorScheme) private var colorScheme

  private var image: NSImage? {
    loadImage(named: "\(assetName)-\(colorScheme == .dark ? "dark" : "light")")
      ?? loadImage(named: assetName)
  }

  private var needsContrastPlate: Bool {
    assetName == "kimi"
  }

  private var contrastPlateColor: Color {
    colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.78)
  }

  private var iconPadding: CGFloat {
    needsContrastPlate ? max(2, size * 0.13) : 0
  }

  private var cornerRadius: CGFloat {
    max(4, size * 0.22)
  }

  private func loadImage(named name: String) -> NSImage? {
    guard let url = Bundle.module.url(
      forResource: name,
      withExtension: "png"
    ) else {
      return nil
    }

    return NSImage(contentsOf: url)
  }

  var body: some View {
    ZStack {
      if needsContrastPlate {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(contrastPlateColor)
      }

      if let image {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .scaledToFit()
          .padding(iconPadding)
      } else {
        Image(systemName: fallbackSystemName)
          .font(.system(size: size, weight: .regular))
          .foregroundStyle(.secondary)
      }
    }
  }
}
