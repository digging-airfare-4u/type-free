import Foundation

/// OpenAI-compatible API client for refining transcription text.
final class LLMService {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Settings

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "llmEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "llmEnabled") }
    }

    static var apiBaseURL: String {
        get { UserDefaults.standard.string(forKey: "llmAPIBaseURL") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "llmAPIBaseURL") }
    }

    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: "llmAPIKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "llmAPIKey") }
    }

    static var model: String {
        get { UserDefaults.standard.string(forKey: "llmModel") ?? "gpt-4o-mini" }
        set { UserDefaults.standard.set(newValue, forKey: "llmModel") }
    }

    static var isConfigured: Bool {
        !apiBaseURL.isEmpty && !apiKey.isEmpty && !model.isEmpty
    }

    // MARK: - System Prompt

    private static let chineseSystemPrompt = """
    你是一个语音转文字后处理器，处理的内容来自互联网技术从业者，涉及编程语言、框架、API、Git、数据库、云服务等技术话题。

    按以下顺序依次处理，优先级从高到低：

    1. 纠错：修正语音识别导致的明显错误，无法确定时保持原样。
       - 中文同音错字：例："做/作"、"在/再"、"的/得/地"
       - 拼音/音译还原为英文：例："配森"→Python、"诶屁爱"→API（举一反三）
       - 知名产品/公司名统一用英文：例："克劳德"→Claude、"菲格玛"→Figma（举一反三）
       - 数字与版本号：例："v一"→v1、"4404"→404

    2. 去重：删除口语冗余，保留语义。
       - 连续重复词只保留一个：例："那个那个"→"那个"
       - 填充词直接删除：例："呃"、"啊"、"这个这个"
       - 同一意思反复表达时，保留最清晰的一次

    3. 结构化：仅当说话人明确表达枚举意图时，才用编号列表。
       - 触发信号：说话人说了"第一…第二"、"有两个问题"、"一是…二是…"等
       - 正常连续叙述不拆列表：例："我想先改接口，再更新文档" → 保持原句
       - 触发时格式：
         1. 第一要点
         2. 第二要点

    4. 润色：在不影响原意的前提下让表达更通顺，有疑问时保持原样。
       - 5字以内的短句直接保留，不润色
       - 修正因连读/吞音导致的明显漏词：例："把这接口"→"把这个接口"
       - 个人习惯表达和语言风格优先于语序调整

    最终只输出处理后的文本，不添加任何解释、标注或额外内容。
    """

    private static let genericSystemPrompt = """
    You are a speech-to-text post-processor for technical professionals discussing programming, APIs, Git, databases, cloud services, and other software topics.

    Follow these rules in order:

    1. Correct only obvious transcription mistakes. If uncertain, keep the original wording.
    2. Remove filler words and accidental repetition without changing meaning.
    3. Keep the original language as spoken. Do not translate unless the transcript itself clearly mixed languages.
    4. Preserve technical terms, product names, code identifiers, version numbers, and abbreviations.
    5. Only format as a numbered list when the speaker clearly indicates enumeration.

    Return only the processed text. Do not add explanations or extra commentary.
    """

    // MARK: - Refine

    func refine(text: String, language: String, completion: @escaping (String?) -> Void) {
        guard Self.isConfigured else {
            completion(nil)
            return
        }

        let baseURL = Self.apiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Self.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": Self.model,
            "messages": [
                ["role": "system", "content": Self.systemPrompt(for: language)],
                ["role": "user", "content": text]
            ],
            "temperature": 0,
            "max_tokens": 2048
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil)
            return
        }
        request.httpBody = bodyData

        session.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                completion(nil)
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = Self.extractContent(from: message),
                  let cleaned = Self.sanitize(content) else {
                completion(nil)
                return
            }

            completion(cleaned)
        }.resume()
    }

    /// Test the API connection. Returns (success, message).
    func testConnection(completion: @escaping (Bool, String) -> Void) {
        guard Self.isConfigured else {
            completion(false, "Please fill in all fields")
            return
        }

        let baseURL = Self.apiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/models") else {
            completion(false, "Invalid API Base URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(Self.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, "Connection failed: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid response")
                return
            }

            if httpResponse.statusCode == 200 {
                completion(true, "Connection successful!")
            } else {
                completion(false, "HTTP \(httpResponse.statusCode)")
            }
        }.resume()
    }

    private static func systemPrompt(for language: String) -> String {
        language.hasPrefix("zh") ? chineseSystemPrompt : genericSystemPrompt
    }

    private static func extractContent(from message: [String: Any]) -> String? {
        if let content = message["content"] as? String {
            return content
        }

        if let parts = message["content"] as? [[String: Any]] {
            let texts = parts.compactMap { $0["text"] as? String }
            guard !texts.isEmpty else { return nil }
            return texts.joined(separator: "\n")
        }

        return nil
    }

    private static func sanitize(_ content: String) -> String? {
        let cleaned = content
            .replacingOccurrences(of: #"<think>[\s\S]*?</think>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? nil : cleaned
    }
}
