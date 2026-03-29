// sleepEarly/Views/FrictionView.swift
import SwiftUI

struct FrictionView: View {
    @Binding var isPresented: Bool
    var body: some View {
        Button("Fermer") { isPresented = false }
    }
}
