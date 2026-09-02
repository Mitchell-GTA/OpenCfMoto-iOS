// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - Root App Container

import SwiftUI

public struct AppRootView: View {
    @StateObject private var viewModel = DashHUDViewModel()

    public init() {
        // Dark theme for TabBar
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
    }

    public var body: some View {
        TabView {
            MainDashboardView(viewModel: viewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "speedometer")
                }

            RouteManagerView(viewModel: viewModel)
                .tabItem {
                    Label("Rutas GPX", systemImage: "map.fill")
                }

            GarageView(viewModel: viewModel)
                .tabItem {
                    Label("Garaje", systemImage: "motorcycle")
                }
        }
        .accentColor(.cyan)
    }
}

#if DEBUG
struct AppRootView_Previews: PreviewProvider {
    static var previews: some View {
        AppRootView()
            .preferredColorScheme(.dark)
    }
}
#endif
