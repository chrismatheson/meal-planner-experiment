import Foundation

enum IngredientTextNormaliser {
    struct NormalisationResult {
        let text: String?           // nil if no lines changed
        let totalLines: Int
        let normalisedLines: Int    // lines actually modified
        let unparseableLines: Int   // lines left untouched (no quantity found)
    }

    static func normalise(_ ingredientsText: String?) -> NormalisationResult {
        guard let input = ingredientsText, !input.isEmpty else {
            return NormalisationResult(text: nil, totalLines: 0, normalisedLines: 0, unparseableLines: 0)
        }

        let lines = input.components(separatedBy: "\n")
        var outputLines: [String] = []
        var normalisedCount = 0
        var unparseableCount = 0
        var anyChanged = false

        for line in lines {
            // Preserve blank lines as-is
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else {
                outputLines.append(line)
                continue
            }

            let normalised = IngredientNormaliser.normalise(line)

            // Check if the parsed line was unparseable
            if let parsed = IngredientLineParser.parse(line), parsed.confidence == .unparseable {
                unparseableCount += 1
            }

            if normalised != line {
                anyChanged = true
                normalisedCount += 1
            }
            outputLines.append(normalised)
        }

        let nonBlankLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count

        return NormalisationResult(
            text: anyChanged ? outputLines.joined(separator: "\n") : nil,
            totalLines: nonBlankLines,
            normalisedLines: normalisedCount,
            unparseableLines: unparseableCount
        )
    }
}
