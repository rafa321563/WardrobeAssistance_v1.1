//
//  AIStylistChatView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

struct AIStylistChatView: View {
    @EnvironmentObject var styleAssistant: AIStyleAssistant
    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext

    @State private var messageText: String = ""
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(styleAssistant.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                                .environmentObject(wardrobeViewModel)
                                .environment(\.managedObjectContext, viewContext)
                        }

                        if styleAssistant.isProcessing {
                            TypingIndicator()
                        }
                    }
                    .padding()
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: styleAssistant.messages.count) { _ in
                    if let lastMessage = styleAssistant.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Quick Action Chips
            if !styleAssistant.isProcessing {
                QuickActionChips()
                    .environmentObject(styleAssistant)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }

            MessageInputBar(
                text: $messageText,
                isProcessing: styleAssistant.isProcessing,
                onSend: {
                    styleAssistant.send(message: messageText)
                    messageText = ""
                }
            )
        }
        .navigationTitle("AI Стилист")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)

                // Show suggested outfit if available
                if let outfitItems = message.suggestedOutfit, !outfitItems.isEmpty {
                    OutfitPreview(itemIDs: outfitItems)
                        .environmentObject(wardrobeViewModel)
                        .environment(\.managedObjectContext, viewContext)
                }

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

struct OutfitPreview: View {
    let itemIDs: [UUID]

    @EnvironmentObject var wardrobeViewModel: WardrobeViewModel
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💡 Рекомендованный образ:")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(itemIDs, id: \.self) { itemID in
                        if let item = wardrobeViewModel.getItem(by: itemID, context: viewContext) {
                            VStack(spacing: 4) {
                                if let fileName = item.imageFileName,
                                   let image = ImageFileManager.shared.loadImage(filename: fileName) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 60)
                                }

                                if let name = item.name {
                                    Text(name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 60)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct QuickActionChips: View {
    @EnvironmentObject var styleAssistant: AIStyleAssistant

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ChipButton(icon: "🌤️", title: "На сегодня") {
                    styleAssistant.requestDailyOutfit()
                }

                ChipButton(icon: "💼", title: "На работу") {
                    styleAssistant.requestWorkOutfit()
                }

                ChipButton(icon: "❤️", title: "На свидание") {
                    styleAssistant.requestDateOutfit()
                }

                ChipButton(icon: "🎨", title: "Тренды") {
                    styleAssistant.requestTrends()
                }
            }
        }
    }
}

struct ChipButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(icon)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TypingIndicator: View {
    @State private var dotCount = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .opacity(dotCount == index ? 1.0 : 0.4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                dotCount = (dotCount + 1) % 3
            }
        }
    }
}

struct MessageInputBar: View {
    @Binding var text: String
    let isProcessing: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Напишите сообщение...", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)

            if isProcessing {
                ProgressView()
            } else {
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .padding(10)
                        .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
    }
}

#Preview {
    NavigationView {
        AIStylistChatView()
            .environmentObject(AIStyleAssistant(wardrobeViewModel: WardrobeViewModel()))
            .environmentObject(WardrobeViewModel())
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
