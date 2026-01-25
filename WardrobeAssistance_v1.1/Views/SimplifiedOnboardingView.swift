//
//  SimplifiedOnboardingView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

struct SimplifiedOnboardingView: View {
    let onComplete: () -> Void
    
    @State private var currentPage = 0
    @State private var dontShowAgain = false
    
    let pages = [
        OnboardingPageData(
            icon: "photo.on.rectangle",
            title: "Your Digital Closet",
            subtitle: "Organize all your clothes in one place",
            gradient: [.blue, .cyan]
        ),
        OnboardingPageData(
            icon: "sparkles",
            title: "AI-Powered Style",
            subtitle: "Get personalized outfit recommendations",
            gradient: [.purple, .pink]
        ),
        OnboardingPageData(
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Your Style",
            subtitle: "See what you wear most",
            gradient: [.orange, .red]
        )
    ]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: pages[currentPage].gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)
            
            VStack {
                // Skip button (только если не последняя страница)
                if currentPage < pages.count - 1 {
                    HStack {
                        Spacer()
                        Button("Skip") {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            complete()
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                    }
                } else {
                    Spacer().frame(height: 60)
                }
                
                // Content
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        SimplifiedPageContent(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page Indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? .white : .white.opacity(0.3))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.bottom, 20)
                
                // CTA Button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        complete()
                    }
                }) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                        .font(AppDesign.Typography.bodyBold)
                        .foregroundColor(pages[currentPage].gradient[0])
                }
                .buttonStyle(PremiumButtonStyle(
                    gradient: LinearGradient(colors: [.white], startPoint: .leading, endPoint: .trailing)
                ))
                .padding(.horizontal, AppDesign.Spacing.l)
                
                // Don't show again (только на последней странице)
                if currentPage == pages.count - 1 {
                    Toggle("Don't show again", isOn: $dontShowAgain)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppDesign.Spacing.l)
                        .padding(.top, AppDesign.Spacing.m)
                }
                
                Spacer().frame(height: 40)
            }
        }
    }
    
    private func complete() {
        if dontShowAgain {
            UserDefaults.standard.set(true, forKey: "dontShowOnboardingAgain")
        }
        onComplete()
    }
}

struct SimplifiedPageContent: View {
    let page: OnboardingPageData
    
    var body: some View {
        VStack(spacing: AppDesign.Spacing.xl) {
            Spacer()
            
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            VStack(spacing: AppDesign.Spacing.m) {
                Text(page.title)
                    .font(AppDesign.Typography.largeTitle)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(AppDesign.Typography.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppDesign.Spacing.xl)
            }
            
            Spacer()
        }
    }
}

struct OnboardingPageData {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
}

