import SafariServices

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        // The shared authenticated loopback protocol owns synchronization in both browsers.
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["protocolVersion": 1, "transport": "loopback", "port": 19287]]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
