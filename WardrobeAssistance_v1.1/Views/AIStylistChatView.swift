//
//  AIStylistChatView.swift
//  WardrobeAssistance_v1.1
//
//  Created by Рафаэл Латыпов on 22.11.25.
//

import SwiftUI

struct AIStylistChatView: View {
    @EnvironmentObject var styleAssistant: AIStyleAssistant
    @State private var messageText: String = ""

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(styleAssistant.messages) { message in
                            HStack {
                                if message.role == .assistant {
                                    assistantBubble(message.text)
                                    Spacer()
                                } else {
                                    Spacer()
                                    userBubble(message.text)
                                }
                            }
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: styleAssistant.messages.count) { _ in
                    if let lastID = styleAssistant.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            if let error = styleAssistant.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            HStack(spacing: 12) {
                TextField("Спроси про стиль, тренды или уход...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)

                if styleAssistant.isProcessing {
                    ProgressView()
                } else {
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .padding(10)
                            .background(
                                ZStack {
                                    Color.blue
                                    Color.black.opacity(0.1)
                                }
                            )
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
        }
        .navigationTitle("AI Stylist")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        styleAssistant.send(message: trimmed)
        messageText = ""
    }

    private func assistantBubble(_ text: String) -> some View {
        Text(text)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(16)
    }

    private func userBubble(_ text: String) -> some View {
        Text(text)
            .padding(12)
            .background(
                ZStack {
                    Color.blue
                    Color.black.opacity(0.1)
                }
            )
            .foregroundColor(.white)
            .cornerRadius(16)
    }
}

#Preview {
    AIStylistChatView()
        .environmentObject(AIStyleAssistant(wardrobeViewModel: WardrobeViewModel()))
}

