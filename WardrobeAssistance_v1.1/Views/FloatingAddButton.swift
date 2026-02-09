//
//  FloatingAddButton.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 10.02.26.
//

import SwiftUI

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    action()
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(AppDesign.Colors.primaryGradient)
                        .clipShape(Circle())
                        .shadow(color: AppDesign.Colors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, AppDesign.Spacing.l)
                .padding(.bottom, AppDesign.Spacing.l)
            }
        }
    }
}
