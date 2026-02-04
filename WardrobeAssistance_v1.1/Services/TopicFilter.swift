//
//  TopicFilter.swift
//  WardrobeAssistance_v1.1
//
//  Created by AI Assistant
//

import Foundation
import NaturalLanguage

/// Filters user messages to determine if they are wardrobe-related
final class TopicFilter {
    static let shared = TopicFilter()

    private init() {}

    // MARK: - Fashion Keywords (Russian + English)

    private let fashionKeywords: Set<String> = [
        // Russian - General
        "одежда", "гардероб", "образ", "стиль", "наряд", "комплект", "аутфит",
        "вещи", "носить", "надеть", "примерить", "подобрать", "сочетать",

        // Russian - Categories
        "платье", "юбка", "брюки", "джинсы", "шорты", "футболка", "рубашка",
        "свитер", "кофта", "куртка", "пальто", "плащ", "пиджак", "блузка",
        "майка", "топ", "костюм", "жакет", "кардиган", "толстовка", "худи",
        "водолазка", "туника", "комбинезон", "боди", "легинсы", "колготки",

        // Russian - Footwear
        "обувь", "туфли", "ботинки", "кроссовки", "сапоги", "босоножки",
        "сандалии", "балетки", "мокасины", "лоферы", "кеды", "слипоны",

        // Russian - Accessories
        "аксессуары", "сумка", "рюкзак", "шарф", "платок", "пояс", "ремень",
        "шляпа", "кепка", "панама", "берет", "перчатки", "очки", "украшения",
        "часы", "браслет", "кольцо", "серьги", "колье", "бусы", "галстук",

        // Russian - Colors
        "цвет", "черный", "белый", "серый", "красный", "синий", "зеленый",
        "желтый", "оранжевый", "розовый", "фиолетовый", "коричневый", "бежевый",
        "голубой", "темный", "светлый", "яркий", "пастельный", "нейтральный",

        // Russian - Style & Occasion
        "повседневный", "формальный", "деловой", "спортивный", "вечерний",
        "уличный", "кэжуал", "классика", "тренд", "мода", "модный", "стильный",
        "работа", "свидание", "вечеринка", "праздник", "прогулка", "спорт",
        "встреча", "событие", "выход", "офис", "дом", "отдых", "путешествие",

        // Russian - Weather
        "погода", "холодно", "тепло", "жарко", "дождь", "снег", "ветер",
        "солнце", "зима", "весна", "лето", "осень", "сезон", "температура",

        // Russian - Actions
        "подойдет", "подходит", "сочетается", "идет", "носить", "выбрать",
        "купить", "добавить", "примерить", "одеть", "надеть", "снять",

        // Russian - Materials
        "ткань", "хлопок", "шерсть", "кожа", "джинс", "шелк", "лен", "мех",
        "синтетика", "вискоза", "трикотаж", "замша", "бархат", "атлас",

        // English - General
        "clothes", "clothing", "wardrobe", "outfit", "style", "fashion", "wear",
        "dress", "garment", "attire", "apparel", "wear", "fashion", "trend",

        // English - Categories
        "dress", "skirt", "pants", "jeans", "shorts", "shirt", "blouse", "top",
        "sweater", "jacket", "coat", "suit", "blazer", "cardigan", "hoodie",
        "tshirt", "t-shirt", "tank", "leggings", "tights", "jumpsuit", "romper",

        // English - Footwear
        "shoes", "boots", "sneakers", "sandals", "heels", "flats", "loafers",
        "moccasins", "slippers", "slides", "pumps", "oxfords", "brogues",

        // English - Accessories
        "accessories", "bag", "purse", "backpack", "scarf", "hat", "belt",
        "cap", "beanie", "gloves", "sunglasses", "jewelry", "watch", "bracelet",
        "necklace", "earrings", "ring", "tie", "bowtie",

        // English - Colors
        "color", "black", "white", "gray", "red", "blue", "green", "yellow",
        "orange", "pink", "purple", "brown", "beige", "navy", "bright", "dark",
        "light", "pastel", "neutral", "multicolor",

        // English - Style & Occasion
        "casual", "formal", "business", "sporty", "evening", "streetwear",
        "classic", "trendy", "work", "date", "party", "wedding", "office",
        "home", "travel", "workout", "gym", "beach", "outdoor",

        // English - Weather
        "weather", "cold", "warm", "hot", "rain", "snow", "wind", "sunny",
        "winter", "spring", "summer", "fall", "autumn", "season", "temperature",

        // English - Actions
        "match", "combine", "pair", "coordinate", "mix", "wear", "try", "pick",
        "choose", "select", "buy", "shop", "add", "remove", "style",

        // English - Materials
        "fabric", "cotton", "wool", "leather", "denim", "silk", "linen", "fur",
        "synthetic", "knit", "suede", "velvet", "satin", "polyester", "nylon"
    ]

    // MARK: - Public Methods

    /// Filters a user message to determine if it's wardrobe-related
    func filter(message: String) -> FilterResult {
        let lowercased = message.lowercased()

        // Check for direct keyword matches
        for keyword in fashionKeywords {
            if lowercased.contains(keyword) {
                return .wardrobeRelated
            }
        }

        // Use NaturalLanguage for more sophisticated analysis
        if analyzeWithNaturalLanguage(message) {
            return .wardrobeRelated
        }

        return .notRelated
    }

    // MARK: - Private Methods

    private func analyzeWithNaturalLanguage(_ text: String) -> Bool {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var hasClothingNouns = false
        var hasStyleVerbs = false

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            let word = String(text[tokenRange]).lowercased()

            // Check if word is fashion-related
            if fashionKeywords.contains(word) {
                if tag == .noun {
                    hasClothingNouns = true
                } else if tag == .verb {
                    hasStyleVerbs = true
                }
            }

            return true
        }

        return hasClothingNouns || hasStyleVerbs
    }
}
