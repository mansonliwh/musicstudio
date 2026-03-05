import Foundation
import Combine

class APIClient {
    static let shared = APIClient()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    func request<T: Decodable>(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil
    ) -> AnyPublisher<T, APIError> {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw APIError.unauthorized
                case 429:
                    throw APIError.rateLimited
                case 500...599:
                    throw APIError.serverError(httpResponse.statusCode)
                default:
                    throw APIError.httpError(httpResponse.statusCode)
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.decodingError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func post<T: Decodable, U: Encodable>(
        url: URL,
        headers: [String: String] = [:],
        body: U
    ) -> AnyPublisher<T, APIError> {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        guard let bodyData = try? encoder.encode(body) else {
            return Fail(error: APIError.encodingError).eraseToAnyPublisher()
        }
        
        return request(url: url, method: "POST", headers: headers, body: bodyData)
    }
    
    func get<T: Decodable>(
        url: URL,
        headers: [String: String] = [:]
    ) -> AnyPublisher<T, APIError> {
        return request(url: url, method: "GET", headers: headers)
    }
    
    func downloadFile(
        from url: URL,
        to destinationURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let localURL = localURL else {
                completion(.failure(APIError.downloadFailed))
                return
            }
            
            do {
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                completion(.success(destinationURL))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    func pollForResult<T: Decodable>(
        url: URL,
        headers: [String: String],
        interval: TimeInterval = 2.0,
        maxAttempts: Int = 60
    ) -> AnyPublisher<T, APIError> {
        var attempts = 0
        
        return Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .tryMap { _ -> T in
                attempts += 1
                if attempts > maxAttempts {
                    throw APIError.timeout
                }
                
                let semaphore = DispatchSemaphore(value: 0)
                var result: Result<T, APIError>?
                
                self.get(url: url, headers: headers)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                result = .failure(error)
                            }
                            semaphore.signal()
                        },
                        receiveValue: { value in
                            result = .success(value)
                            semaphore.signal()
                        }
                    )
                    .store(in: &self.cancellables)
                
                semaphore.wait()
                
                switch result {
                case .success(let value):
                    return value
                case .failure(let error):
                    throw error
                case .none:
                    throw APIError.timeout
                }
            }
            .first()
            .mapError { error in
                error as? APIError ?? APIError.unknown
            }
            .eraseToAnyPublisher()
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    case decodingError(Error)
    case encodingError
    case downloadFailed
    case timeout
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .unauthorized:
            return "未授权，请检查API密钥"
        case .rateLimited:
            return "请求过于频繁，请稍后重试"
        case .serverError(let code):
            return "服务器错误 (\(code))"
        case .httpError(let code):
            return "HTTP错误 (\(code))"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .encodingError:
            return "数据编码错误"
        case .downloadFailed:
            return "下载失败"
        case .timeout:
            return "请求超时"
        case .unknown:
            return "未知错误"
        }
    }
}
