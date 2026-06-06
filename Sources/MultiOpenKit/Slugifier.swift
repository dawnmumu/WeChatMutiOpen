import Foundation

public struct Slugifier {
    public init() {}

    public func slug(_ input: String) -> String {
        let latin = input
            .applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) ?? input

        let lowered = latin.lowercased()
        var result = ""
        var previousWasDash = false

        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                previousWasDash = false
            } else if !previousWasDash {
                result.append("-")
                previousWasDash = true
            }
        }

        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "clone" : trimmed
    }

    public func bundleIdentifierComponent(_ input: String) -> String {
        let lowered = input.lowercased()
        var result = ""
        var previousWasSeparator = false

        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if scalar == "." || scalar == "-" {
                if !previousWasSeparator {
                    result.unicodeScalars.append(scalar == "." ? "." : "-")
                    previousWasSeparator = true
                }
            } else if !previousWasSeparator {
                result.append("-")
                previousWasSeparator = true
            }
        }

        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
        return trimmed.isEmpty ? "app" : trimmed
    }
}
