// sleepEarly/Views/MenuBarView.swift
#if os(macOS)
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var settings: AppSettings
    var body: some View {
        Text("sleepEarly")
    }
}
#endif
