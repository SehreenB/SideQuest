import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            StartHeroView()
        }
    }
}
