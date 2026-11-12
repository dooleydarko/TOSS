import Foundation
import Network
#if canImport(TossSchema)
import TossSchema
#endif

public final class TossDiscoveryService: NSObject, NetServiceDelegate, NetServiceBrowserDelegate {
    public static let serviceType = "_toss._tcp."
    public static let domain = "local."

    // MARK: - Advertiser (Mac Receiver)
    private var netService: NetService?

    public func startAdvertising(name: String, port: Int32) {
        stopAdvertising()
        netService = NetService(domain: TossDiscoveryService.domain, type: TossDiscoveryService.serviceType, name: name, port: port)
        netService?.delegate = self
        
        let txtDict: [String: Data] = [
            "version": "1.0.0".data(using: .utf8)!,
            "platform": "macOS".data(using: .utf8)!
        ]
        netService?.setTXTRecord(NetService.data(fromTXTRecord: txtDict))
        netService?.publish()
        print("[TOSS Bonjour] Advertising '\(name)' on port \(port)")
    }

    public func stopAdvertising() {
        netService?.stop()
        netService = nil
    }

    // MARK: - Browser (iPhone Client)
    private var browser: NetServiceBrowser?
    private var resolvingServices: [NetService] = []
    public var onDeviceFound: ((TossDevice) -> Void)?
    public var onDeviceLost: ((String) -> Void)?

    public func startBrowsing() {
        stopBrowsing()
        browser = NetServiceBrowser()
        browser?.delegate = self
        browser?.searchForServices(ofType: TossDiscoveryService.serviceType, inDomain: TossDiscoveryService.domain)
        print("[TOSS Bonjour] Browsing for TOSS receivers...")
    }

    public func stopBrowsing() {
        browser?.stop()
        browser = nil
        for service in resolvingServices {
            service.stop()
        }
        resolvingServices.removeAll()
    }

    // NetServiceBrowserDelegate
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        resolvingServices.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        onDeviceLost?(service.name)
    }

    // NetServiceDelegate
    public func netServiceDidResolveAddress(_ sender: NetService) {
        guard let hostName = sender.hostName else { return }
        let port = sender.port
        let device = TossDevice(
            id: sender.name,
            name: sender.name,
            platform: "macOS",
            host: hostName.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
            port: port,
            isPaired: false,
            lastSeen: Date()
        )
        onDeviceFound?(device)
    }
}
