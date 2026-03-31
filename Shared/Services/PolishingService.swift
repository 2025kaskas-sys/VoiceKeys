import Foundation

final class PolishingService {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func polish(text: String, outputLanguage: String, outputLocale: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return text
        }

        let systemPrompt: String

        if outputLocale == "zh-Hans" {
            // Chinese: just polish, no translation
            systemPrompt = """
            你的任务是把语音转文字的原始中文输出整理成自然、清晰的文字。
            原始文字来自语音识别，可能有：重复啰嗦、口语化表达、没有标点、错别字。
            你必须：
            1. 去掉明显的重复和口头禅（嗯、就是说、你知道吧），但保留说话人的语气和风格
            2. 整理成通顺的句子，加标点符号，修正错别字
            3. 适度精简，但不要过度压缩——保持自然、像人说的话
            4. 保持原意和说话人的个性
            只输出整理后的文字，不要回答问题，不要解释，不要加引号。
            """
        } else {
            // English/Spanish: translate from Chinese
            systemPrompt = """
            你的任务是把用户的中文语音识别文字翻译成\(outputLanguage)。
            原始文字是中文语音识别输出，可能有重复、口头禅、错别字。
            你必须：
            1. 先理解中文原意（忽略重复和口头禅）
            2. 翻译成自然、地道的\(outputLanguage)
            3. 不要逐字翻译，要意译，让母语者读起来自然
            4. 加正确的标点符号
            只输出翻译后的\(outputLanguage)文字，不要保留中文，不要解释，不要加引号。
            """
        }

        let body: [String: Any] = [
            "model": "moonshot-v1-8k",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "max_tokens": 1024
        ]

        var request = URLRequest(url: URL(string: "https://api.moonshot.ai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return text
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let choices = json?["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            let polished = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return polished.isEmpty ? text : polished
        }

        return text
    }
}
