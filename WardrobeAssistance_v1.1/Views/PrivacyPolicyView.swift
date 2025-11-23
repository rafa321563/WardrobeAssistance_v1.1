//
//  PrivacyPolicyView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                // Content Sections
                policySection(
                    icon: "hand.raised.fill",
                    title: localizedString("Data Collection", "Сбор данных"),
                    content: localizedString(
                        "Wardrobe Assistance collects only the information you provide: clothing images, item details (category, color, season, style), and outfit preferences. We do not collect personal identification information.",
                        "Wardrobe Assistance собирает только предоставленную вами информацию: фотографии одежды, детали предметов (категория, цвет, сезон, стиль) и предпочтения по образам. Мы не собираем персональные идентификационные данные."
                    )
                )
                
                policySection(
                    icon: "gear.circle.fill",
                    title: localizedString("Data Usage", "Использование данных"),
                    content: localizedString(
                        "Your data is used exclusively to provide wardrobe management services: generating outfit recommendations, organizing your clothing items, and personalizing your experience. We never sell or share your data with third parties.",
                        "Ваши данные используются исключительно для предоставления услуг управления гардеробом: генерация рекомендаций по образам, организация ваших предметов одежды и персонализация опыта. Мы никогда не продаем и не передаем ваши данные третьим лицам."
                    )
                )
                
                policySection(
                    icon: "internaldrive.fill",
                    title: localizedString("Data Storage", "Хранение данных"),
                    content: localizedString(
                        "All your wardrobe data is stored locally on your device. With iCloud Sync (Premium feature), your data is encrypted and synced securely across your Apple devices using Apple's CloudKit service. We do not have access to your iCloud data.",
                        "Все данные вашего гардероба хранятся локально на вашем устройстве. При использовании синхронизации iCloud (функция Premium) ваши данные шифруются и безопасно синхронизируются между вашими устройствами Apple с использованием сервиса CloudKit. У нас нет доступа к вашим данным iCloud."
                    )
                )
                
                policySection(
                    icon: "person.crop.circle.fill",
                    title: localizedString("User Rights", "Права пользователя"),
                    content: localizedString(
                        "You have full control over your data. You can view all your data within the app, delete individual items, clear all data, or export your wardrobe data (Premium feature). You can also cancel your subscription anytime through App Store settings.",
                        "Вы имеете полный контроль над своими данными. Вы можете просматривать все свои данные в приложении, удалять отдельные элементы, очищать все данные или экспортировать данные гардероба (функция Premium). Вы также можете отменить подписку в любое время через настройки App Store."
                    )
                )
                
                policySection(
                    icon: "creditcard.fill",
                    title: localizedString("Subscription Information", "Информация о подписке"),
                    content: localizedString(
                        "Subscription purchases are processed through Apple's App Store. We do not store payment information. Subscription status is verified through StoreKit 2, and subscription data is managed entirely by Apple.",
                        "Покупки подписок обрабатываются через App Store Apple. Мы не храним платежную информацию. Статус подписки проверяется через StoreKit 2, а данные подписки полностью управляются Apple."
                    )
                )
                
                policySection(
                    icon: "envelope.fill",
                    title: localizedString("Contact Us", "Свяжитесь с нами"),
                    content: localizedString(
                        "If you have any questions about this Privacy Policy, please contact us at: privacy@wardrobeassistance.app",
                        "Если у вас есть вопросы по этой Политике конфиденциальности, пожалуйста, свяжитесь с нами: privacy@wardrobeassistance.app"
                    )
                )
            }
            .padding()
        }
        .navigationTitle(localizedString("Privacy Policy", "Политика конфиденциальности"))
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
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedString("Privacy Policy", "Политика конфиденциальности"))
                        .font(.largeTitle)
                        .bold()
                    
                    Text(localizedString("Last updated: ", "Последнее обновление: ") + formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(localizedString(
                "Wardrobe Assistance is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application.",
                "Wardrobe Assistance стремится защищать вашу конфиденциальность. Эта Политика конфиденциальности объясняет, как мы собираем, используем и защищаем вашу информацию при использовании нашего мобильного приложения."
            ))
            .font(.body)
            .foregroundColor(.secondary)
            .padding(.top, 8)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Policy Section
    
    private func policySection(icon: String, title: String, content: String) -> some View {
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

#Preview("Light Mode") {
    NavigationView {
        PrivacyPolicyView()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    NavigationView {
        PrivacyPolicyView()
    }
    .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    NavigationView {
        PrivacyPolicyView()
    }
    .environment(\.sizeCategory, .accessibilityLarge)
}

