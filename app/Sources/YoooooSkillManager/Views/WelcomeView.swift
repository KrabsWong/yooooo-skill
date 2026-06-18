import SwiftUI

struct WelcomeView: View {
  var body: some View {
    ContentUnavailableView(
      "Yooooo Skill Manager",
      systemImage: "shippingbox",
      description: Text("Select an app, skill, or project from the sidebar.")
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
