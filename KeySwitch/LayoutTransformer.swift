import Cocoa

class LayoutTransformer {
    static let shared = LayoutTransformer()
    
    private init() {}
    
    // Character maps between layouts
    // Format: [fromLayoutID: [toLayoutID: [char: char]]]
    private var layoutMaps: [String: [String: [Character: Character]]] = [:]
    
    /// Creates map between two layouts
    private func createMap(from fromLayout: String, to toLayout: String) -> [Character: Character] {
        // Check cache
        if let cachedMap = layoutMaps[fromLayout]?[toLayout] {
            return cachedMap
        }
        
        // Create map for US ↔ UA
        var map: [Character: Character] = [:]
        
        if fromLayout.contains("US") && toLayout.contains("Ukrainian") {
            map = createUSToUAMap()
        } else if fromLayout.contains("Ukrainian") && toLayout.contains("US") {
            map = createUAToUSMap()
        }
        
        // Save to cache
        if layoutMaps[fromLayout] == nil {
            layoutMaps[fromLayout] = [:]
        }
        layoutMaps[fromLayout]?[toLayout] = map
        
        return map
    }
    
    /// Map US → UA
    private func createUSToUAMap() -> [Character: Character] {
        return [
            "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н", "u": "г", "i": "ш", "o": "щ", "p": "з",
            "a": "ф", "s": "і", "d": "в", "f": "а", "g": "п", "h": "р", "j": "о", "k": "л", "l": "д",
            "z": "я", "x": "ч", "c": "с", "v": "м", "b": "і", "n": "т", "m": "ь",
            "Q": "Й", "W": "Ц", "E": "У", "R": "К", "T": "Е", "Y": "Н", "U": "Г", "I": "Ш", "O": "Щ", "P": "З",
            "A": "Ф", "S": "І", "D": "В", "F": "А", "G": "П", "H": "Р", "J": "О", "K": "Л", "L": "Д",
            "Z": "Я", "X": "Ч", "C": "С", "V": "М", "B": "І", "N": "Т", "M": "Ь",
            "[": "х", "]": "ї", "\\": "є",
            "{": "Х", "}": "Ї", "|": "Є",
            ";": "ж", "'": "є",
            ":": "Ж", "\"": "Є",
            ",": "б", ".": "ю", "/": ".",
            "<": "Б", ">": "Ю", "?": ","
        ]
    }
    
    /// Map UA → US
    private func createUAToUSMap() -> [Character: Character] {
        return [
            "й": "q", "ц": "w", "у": "e", "к": "r", "е": "t", "н": "y", "г": "u", "ш": "i", "щ": "o", "з": "p",
            "ф": "a", "і": "s", "в": "d", "а": "f", "п": "g", "р": "h", "о": "j", "л": "k", "д": "l",
            "я": "z", "ч": "x", "с": "c", "м": "v", "и": "b", "т": "n", "ь": "m",
            "Й": "Q", "Ц": "W", "У": "E", "К": "R", "Е": "T", "Н": "Y", "Г": "U", "Ш": "I", "Щ": "O", "З": "P",
            "Ф": "A", "І": "S", "В": "D", "А": "F", "П": "G", "Р": "H", "О": "J", "Л": "K", "Д": "L",
            "Я": "Z", "Ч": "X", "С": "C", "М": "V", "И": "B", "Т": "N", "Ь": "M",
            "х": "[", "ї": "]", "є": "\\",
            "Х": "{", "Ї": "}", "Є": "|",
            "ж": ";",
            "Ж": ":",
            "б": ",", "ю": ".", ".": "/",
            "Б": "<", "Ю": ">", ",": "?"
        ]
    }
    
    /// Transforms text from one layout to another
    func transformText(_ text: String, from fromLayout: String, to toLayout: String) -> String {
        let map = createMap(from: fromLayout, to: toLayout)
        
        return String(text.map { char in
            return map[char] ?? char
        })
    }
    
    /// Transforms text using Layout objects
    func transformText(_ text: String, from fromLayout: KeyboardLayout, to toLayout: KeyboardLayout) -> String {
        return transformText(text, from: fromLayout.id, to: toLayout.id)
    }
}

