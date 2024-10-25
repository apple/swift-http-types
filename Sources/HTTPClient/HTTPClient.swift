import Foundation
import HTTPTypes

public protocol HTTPClientProtocol {
  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  func execute(for request: HTTPRequest, from body: Data?) async throws -> (Data, HTTPResponse)
}
