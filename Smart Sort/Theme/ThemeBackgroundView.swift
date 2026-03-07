import SwiftUI

struct ThemeBackgroundView: View {
    private let theme = TrashTheme()

    var body: some View {
        theme.appBackground
            .ignoresSafeArea()
    }
}
