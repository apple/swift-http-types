import Foundation
import HTTPClient
import HTTPTypes
import HTTPTypesFoundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS) || compiler(>=6)
  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  extension URLSession: HTTPClientProtocol {
    public func execute(
      for request: HTTPRequest,
      from bodyData: Data?
    ) async throws -> (Data, HTTPResponse) {
      if let bodyData {
        try await self.upload(for: request, from: bodyData)
      } else {
        try await self.data(for: request)
      }
    }
  }

  extension HTTPClientProtocol where Self == URLSession {
    public static func urlSession(_ urlSession: Self) -> Self {
      return urlSession
    }
  }
#endif
