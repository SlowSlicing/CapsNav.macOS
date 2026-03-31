import Foundation

enum AppUpdateCheckResult: Equatable {
    case noUpdate
    case updateAvailable(AppUpdateInfo)
    case invalidPayload(String)
    case failed(String)
}

struct AppUpdateService {
    static let defaultFeedURL = URL(string: "https://slowslicing.me/CapsNav.macOS/updates/latest.json")!

    let feedURL: URL
    var urlSession: URLSession = .shared

    func fetchLatestUpdate(currentVersion: AppVersion?) async -> AppUpdateCheckResult {
        do {
            let (data, response) = try await urlSession.data(from: feedURL)

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                return .failed("更新服务返回异常状态（\(httpResponse.statusCode)）。")
            }

            let info = try AppUpdateInfo.decoder.decode(AppUpdateInfo.self, from: data)

            guard let remoteVersion = AppVersion(info.version) else {
                return .invalidPayload("更新源里的版本号格式无效。")
            }

            guard let currentVersion else {
                return .updateAvailable(info)
            }

            return remoteVersion > currentVersion ? .updateAvailable(info) : .noUpdate
        } catch let decodingError as DecodingError {
            return .invalidPayload(decodingError.localizedDescription)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
