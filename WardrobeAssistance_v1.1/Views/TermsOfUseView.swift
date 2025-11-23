//
//  TermsOfUseView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

struct TermsOfUseView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                // Content Sections
                termsSection(
                    icon: "checkmark.circle.fill",
                    title: localizedString("Acceptance of Terms", "Принятие условий"),
                    content: localizedString(
                        "By downloading, installing, or using Wardrobe Assistance, you agree to be bound by these Terms of Use. If you do not agree, please do not use the App.",
                        "Загружая, устанавливая или используя Wardrobe Assistance, вы соглашаетесь соблюдать эти Условия использования. Если вы не согласны, пожалуйста, не используйте приложение."
                    )
                )
                
                termsSection(
                    icon: "creditcard.fill",
                    title: localizedString("Subscription Terms", "Условия подписки"),
                    content: localizedString(
                        "Premium Subscription: Monthly subscription with 7-day free trial. Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. You can cancel anytime through your Apple ID account settings. Refunds are processed through Apple's refund process.",
                        "Премиум подписка: Ежемесячная подписка с 7-дневным бесплатным пробным периодом. Подписки автоматически продлеваются, если не отменены не менее чем за 24 часа до окончания текущего периода. Вы можете отменить в любое время через настройки вашего Apple ID. Возвраты обрабатываются через процесс возврата Apple."
                    )
                )
                
                termsSection(
                    icon: "person.fill.checkmark",
                    title: localizedString("User Responsibilities", "Обязанности пользователя"),
                    content: localizedString(
                        "You are responsible for the content you upload to the App. You retain ownership of all photos and data you add. You agree not to use the App for any illegal purpose, attempt to reverse engineer or modify the App, or share your account with others.",
                        "Вы несете ответственность за контент, который загружаете в приложение. Вы сохраняете право собственности на все фотографии и данные, которые добавляете. Вы соглашаетесь не использовать приложение в незаконных целях, не пытаться взломать или модифицировать приложение, и не делиться своей учетной записью с другими."
                    )
                )
                
                termsSection(
                    icon: "c.circle.fill",
                    title: localizedString("Intellectual Property", "Интеллектуальная собственность"),
                    content: localizedString(
                        "The App and its features are protected by copyright and trademark laws. All rights not expressly granted are reserved. You do not acquire any ownership rights by using the App.",
                        "Приложение и его функции защищены законами об авторском праве и товарных знаках. Все права, прямо не предоставленные, зарезервированы. Вы не приобретаете никаких прав собственности при использовании приложения."
                    )
                )
                
                termsSection(
                    icon: "exclamationmark.triangle.fill",
                    title: localizedString("Limitation of Liability", "Ограничение ответственности"),
                    content: localizedString(
                        "The App is provided 'as is' without warranties of any kind. We are not liable for any damages arising from use of the App. AI recommendations are suggestions only and not guaranteed to be accurate or suitable for your needs.",
                        "Приложение предоставляется 'как есть' без каких-либо гарантий. Мы не несем ответственности за любой ущерб, возникший в результате использования приложения. Рекомендации AI являются лишь предложениями и не гарантируют точность или пригодность для ваших нужд."
                    )
                )
                
                termsSection(
                    icon: "xmark.circle.fill",
                    title: localizedString("Termination", "Прекращение"),
                    content: localizedString(
                        "We may terminate or suspend your access to the App at any time for violation of these terms. You may stop using the App at any time. Upon termination, your right to use the App will immediately cease.",
                        "Мы можем прекратить или приостановить ваш доступ к приложению в любое время за нарушение этих условий. Вы можете прекратить использование приложения в любое время. При прекращении ваше право на использование приложения немедленно прекращается."
                    )
                )
                
                termsSection(
                    icon: "envelope.fill",
                    title: localizedString("Contact", "Контакты"),
                    content: localizedString(
                        "For questions about these Terms of Use, please contact us at: support@wardrobeassistance.app",
                        "По вопросам об этих Условиях использования, пожалуйста, свяжитесь с нами: support@wardrobeassistance.app"
                    )
                )
            }
            .padding()
        }
        .navigationTitle(localizedString("Terms of Use", "Условия использования"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(localizedString("Done", "Готово")) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedString("Terms of Use", "Условия использования"))
                        .font(.largeTitle)
                        .bold()
                    
                    Text(localizedString("Last updated: ", "Последнее обновление: ") + formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(localizedString(
                "These Terms of Use govern your use of Wardrobe Assistance. Please read them carefully before using the App.",
                "Эти Условия использования регулируют ваше использование Wardrobe Assistance. Пожалуйста, внимательно прочитайте их перед использованием приложения."
            ))
            .font(.body)
            .foregroundColor(.secondary)
            .padding(.top, 8)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Terms Section
    
    private func termsSection(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .frame(width: 28)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Helpers
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        formatter.locale = Locale(identifier: locale == "ru" ? "ru_RU" : "en_US")
        return formatter.string(from: Date())
    }
    
    private func localizedString(_ english: String, _ russian: String) -> String {
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        return locale == "ru" ? russian : english
    }
}

#Preview {
    NavigationView {
        TermsOfUseView()
    }
}

