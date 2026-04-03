// sleepEarly/ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .home

    enum Tab: Int, CaseIterable {
        case home, history, settings

        var icon: String {
            switch self {
            case .home:     return "moon.stars.fill"
            case .history:  return "chart.bar.fill"
            case .settings: return "slider.horizontal.3"
            }
        }

        var label: String {
            switch self {
            case .home:     return "Accueil"
            case .history:  return "Historique"
            case .settings: return "Réglages"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(Tab.home)
                HistoryView()
                    .tag(Tab.history)
                SettingsView()
                    .tag(Tab.settings)
            }
            .ignoresSafeArea()

            CustomTabBar(selectedTab: $selectedTab)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Theme.backgroundElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(Theme.borderGlass, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 8)
        )
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }
}

private struct TabBarItem: View {
    let tab: ContentView.Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? Theme.accentPrimary : Theme.textTertiary)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.accentPrimary.opacity(isSelected ? 0.12 : 0))
                    .padding(.horizontal, 4)
            )
        }
        .buttonStyle(.plain)
    }
}
