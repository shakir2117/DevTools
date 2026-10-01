import Foundation
import Darwin
import Network
import Security
import CryptoKit

public enum DNSLookup {
    public static let types = ["A", "AAAA", "MX", "TXT", "CNAME", "NS", "SOA", "PTR", "SRV", "CAA"]

    public static func lookup(name: String, type: String, useDoH: Bool) -> ToolResult {
        guard let host = HostCheck.hostname(name) else { return .failure("That is not a DNS name.") }
        guard types.contains(type) else { return .failure("That record type is not supported.") }
        if useDoH { return doh(host, type: type) }
        return dig(host, type: type)
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        expect("dns dash host", lookup(name: "-f", type: "A", useDoH: false).issue != nil)
    }

    private static func dig(_ name: String, type: String) -> ToolResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/dig")
        process.arguments = ["+ttlunits", name, type]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure("Could not run dig: \(error.localizedDescription)")
        }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .failure("dig returned no output.")
        }
        return .success(output)
    }

    private static func doh(_ name: String, type: String) -> ToolResult {
        var components = URLComponents(string: "https://cloudflare-dns.com/dns-query")
        components?.queryItems = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "type", value: type)]
        guard let url = components?.url else { return .failure("Could not build the DoH URL.") }
        var request = URLRequest(url: url)
        request.setValue("application/dns-json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        let box = ResultBox(.failure("DNS request did not finish."))
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            defer { semaphore.signal() }
            if let error {
                box.set(.failure(error.localizedDescription))
                return
            }
            guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                box.set(.failure("The DoH response was not JSON."))
                return
            }
            let answers = object["Answer"] as? [[String: Any]] ?? []
            if answers.isEmpty {
                box.set(.success(String(data: data, encoding: .utf8) ?? "No answers."))
                return
            }
            let lines = answers.map { answer in
                let data = answer["data"] as? String ?? ""
                let ttl = answer["TTL"] as? Int ?? 0
                return "TTL \(ttl)\t\(data)"
            }
            box.set(.success(lines.joined(separator: "\n")))
        }
        task.resume()
        semaphore.wait()
        return box.get()
    }
}

public enum WhoisClient {
    public static func lookup(_ query: String) async -> ToolResult {
        guard let name = HostCheck.hostname(query) else { return .failure("Enter a domain or IP address.") }
        let start = name.contains(":") || ipv4(name) ? "whois.arin.net" : "whois.iana.org"
        var server = start
        var raw = ""
        var seen = Set<String>()
        for _ in 0..<6 {
            if !seen.insert(server).inserted { break }
            let chunk = await fetch(server: server, query: name)
            raw += "\n----- \(server) -----\n\(chunk)"
            if let next = referral(in: chunk), next != server {
                server = next
                continue
            }
            break
        }
        let fields = parsedFields(raw)
        return .success("Parsed fields:\n\(fields)\n\nRaw:\n\(raw.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let sample = "Registrar: Example\nReferralServer: whois://whois.example.net\nCreation Date: 1999-01-01\n"
        expect("whois referral", referral(in: sample) == "whois.example.net")
        expect("whois field", parsedFields(sample).contains("Registrar: Example"))
    }

    static func referral(in text: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            let lower = line.lowercased()
            if lower.contains("referralserver:") || lower.hasPrefix("whois:") || lower.contains("whois server:") {
                let value = line.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                let host = value.replacingOccurrences(of: "whois://", with: "").replacingOccurrences(of: "rwhois://", with: "").split(separator: "/").first.map(String.init) ?? ""
                let cleaned = host.split(separator: ":").first.map(String.init) ?? ""
                if HostCheck.hostname(cleaned) != nil { return cleaned }
            }
        }
        return nil
    }

    private static func parsedFields(_ text: String) -> String {
        let keys = ["registrar", "creation date", "created", "registry expiry date", "expir", "name server", "nserver", "orgname", "netname", "country", "status"]
        let lines = text.split(whereSeparator: \.isNewline).map(String.init).filter { line in
            let lower = line.lowercased()
            return keys.contains { lower.contains($0) } && line.contains(":")
        }
        return lines.isEmpty ? "(no common fields parsed)" : lines.joined(separator: "\n")
    }

    private static func fetch(server: String, query: String) async -> String {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(server), port: 43, using: .tcp)
            let collected = DataBox()
            let gate = Once()
            let finish: @Sendable (String) -> Void = { text in
                guard gate.claim() else { return }
                connection.cancel()
                continuation.resume(returning: text)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let payload = Data("\(query)\r\n".utf8)
                    connection.send(content: payload, completion: .contentProcessed { error in
                        if error != nil { finish("Send failed: \(error?.localizedDescription ?? "")") }
                    })
                case .failed(let error):
                    finish(error.localizedDescription)
                default:
                    break
                }
            }
            func receive() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
                    if let data { collected.append(data) }
                    if isComplete || error != nil {
                        let data = collected.snapshot()
                        finish(String(data: data, encoding: .utf8) ?? "Binary WHOIS response, \(data.count) bytes.")
                    } else {
                        receive()
                    }
                }
            }
            receive()
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 12) {
                finish(String(data: collected.snapshot(), encoding: .utf8) ?? "")
            }
        }
    }

    private static func ipv4(_ text: String) -> Bool {
        let parts = text.split(separator: ".")
        return parts.count == 4 && parts.allSatisfy { Int($0).map { (0...255).contains($0) } == true }
    }
}

public enum TLSInspect {
    public static func inspect(host: String, port: Int) async -> ToolResult {
        let name = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return .failure("Enter a host name.") }
        guard (1...65535).contains(port) else { return .failure("Port must be from 1 to 65535.") }
        return await withCheckedContinuation { continuation in
            let tls = NWProtocolTLS.Options()
            let queue = DispatchQueue(label: "devkit.tls")
            let gate = Once()
            let finish: @Sendable (ToolResult) -> Void = { result in
                guard gate.claim() else { return }
                continuation.resume(returning: result)
            }
            sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, trust, complete in
                let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
                finish(.success(Self.report(trust: secTrust, host: name)))
                complete(true)
            }, queue)
            let parameters = NWParameters(tls: tls)
            guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
                finish(.failure("Port must be from 1 to 65535."))
                return
            }
            let connection = NWConnection(host: NWEndpoint.Host(name), port: endpointPort, using: parameters)
            connection.stateUpdateHandler = { state in
                if case let .failed(error) = state {
                    finish(.failure(error.localizedDescription))
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 15) {
                connection.cancel()
                finish(.failure("Timed out waiting for the TLS handshake."))
            }
        }
    }

    static func report(trust: SecTrust, host: String) -> String {
        var error: CFError?
        let trusted = SecTrustEvaluateWithError(trust, &error)
        let certificates = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
        var lines = ["Host: \(host)", "SecTrust: \(trusted ? "trusted" : "not trusted")"]
        if let error { lines.append("Trust error: \(error.localizedDescription)") }
        for (offset, certificate) in certificates.enumerated() {
            let index = offset
            lines.append("")
            lines.append("Certificate \(index + 1)")
            lines.append("Subject: \(SecCertificateCopySubjectSummary(certificate) as String? ?? "")")
            if let values = SecCertificateCopyValues(certificate, nil, nil) as? [String: Any] {
                lines.append(contentsOf: describe(values))
            }
            let der = SecCertificateCopyData(certificate) as Data
            lines.append("SHA-256: \(SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined())")
            lines.append(pem(der))
        }
        return lines.joined(separator: "\n")
    }

    private static func describe(_ values: [String: Any]) -> [String] {
        var lines: [String] = []
        for (key, raw) in values {
            guard let record = raw as? [String: Any] else { continue }
            let label = record[kSecPropertyKeyLabel as String] as? String ?? key
            if let value = record[kSecPropertyKeyValue as String] {
                let text = flatten(value)
                if !text.isEmpty && (label.localizedCaseInsensitiveContains("validity") || label.localizedCaseInsensitiveContains("issuer") || label.localizedCaseInsensitiveContains("serial") || label.localizedCaseInsensitiveContains("DNS") || label.localizedCaseInsensitiveContains("alt")) {
                    lines.append("\(label): \(text)")
                }
            }
        }
        if let notAfter = expiry(values) {
            let days = Int(notAfter.timeIntervalSinceNow / 86_400)
            lines.append("Days to expiry: \(days)")
        }
        return lines
    }

    private static func expiry(_ values: [String: Any]) -> Date? {
        for (_, raw) in values {
            guard let record = raw as? [String: Any],
                  let label = record[kSecPropertyKeyLabel as String] as? String,
                  label.localizedCaseInsensitiveContains("not valid after") || label == "Not Valid After",
                  let number = record[kSecPropertyKeyValue as String] as? NSNumber else { continue }
            return Date(timeIntervalSinceReferenceDate: number.doubleValue)
        }
        return nil
    }

    private static func flatten(_ value: Any) -> String {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        if let date = value as? Date { return ISO8601DateFormatter().string(from: date) }
        if let array = value as? [Any] { return array.map(flatten).filter { !$0.isEmpty }.joined(separator: ", ") }
        if let record = value as? [String: Any], let inner = record[kSecPropertyKeyValue as String] {
            let label = record[kSecPropertyKeyLabel as String] as? String
            let text = flatten(inner)
            return label == nil ? text : "\(label ?? ""): \(text)"
        }
        return ""
    }

    private static func pem(_ der: Data) -> String {
        let encoded = der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN CERTIFICATE-----\n\(encoded)\n-----END CERTIFICATE-----"
    }
}

public enum IPLookup {
    public static func lookup(ip: String, provider: String) async -> (report: String, latitude: Double?, longitude: Double?) {
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "https://ipwho.is/{ip}" : provider
        let target = trimmed.isEmpty || trimmed == "my ip" ? "" : trimmed
        let urlString = template.replacingOccurrences(of: "{ip}", with: target)
        guard let url = URL(string: urlString), url.scheme == "https" else { return ("The provider must be an https URL.", nil, nil) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let object = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let lat = object["latitude"] as? Double
            let lon = object["longitude"] as? Double
            let payload: [String: Any] = object.isEmpty ? ["body": String(data: data, encoding: .utf8) ?? ""] : object
            let pretty = (try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            return ("HTTP \(status)\n\(pretty)", lat, lon)
        } catch {
            return (error.localizedDescription, nil, nil)
        }
    }
}

public enum NetDiagnostics {
    public static func run(host: String, samples: Int) async -> String {
        guard let name = HostCheck.hostname(host) else { return "Enter a host name, not a command." }
        let count = min(10, max(1, samples))
        var lines: [String] = []
        lines.append(pathStatus())
        lines.append("Local addresses:\n\(localAddresses())")
        let dnsStart = Date()
        let resolved = await resolve(name)
        lines.append(String(format: "DNS: %.0f ms %@", Date().timeIntervalSince(dnsStart) * 1000, resolved))
        let tcp = await connectTime(name, port: 443)
        lines.append(tcp)
        lines.append(await httpTiming(name))
        lines.append(ping(name, count: count))
        return lines.joined(separator: "\n\n")
    }

    private static func pathStatus() -> String {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "devkit.path")
        let semaphore = DispatchSemaphore(value: 0)
        let box = TextBox("unavailable")
        monitor.pathUpdateHandler = { path in
            box.set("\(path.status) satisfied=\(path.status == .satisfied) expensive=\(path.isExpensive)")
            semaphore.signal()
            monitor.cancel()
        }
        monitor.start(queue: queue)
        _ = semaphore.wait(timeout: .now() + 2)
        return "Path: \(box.get())"
    }

    private static func localAddresses() -> String {
        var addresses: [String] = []
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return "(none)" }
        defer { freeifaddrs(first) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            let interface = current.pointee
            if let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) || address.pointee.sa_family == UInt8(AF_INET6) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let name = String(cString: interface.ifa_name)
                    addresses.append("\(name) \(String(cString: host))")
                }
            }
            cursor = interface.ifa_next
        }
        return addresses.isEmpty ? "(none)" : addresses.joined(separator: "\n")
    }

    private static func resolve(_ host: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var hints = addrinfo()
                hints.ai_family = AF_UNSPEC
                hints.ai_socktype = SOCK_STREAM
                var info: UnsafeMutablePointer<addrinfo>?
                let code = getaddrinfo(host, "443", &hints, &info)
                defer { if info != nil { freeaddrinfo(info) } }
                if code != 0 {
                    continuation.resume(returning: String(cString: gai_strerror(code)))
                    return
                }
                var results: [String] = []
                var cursor = info
                while let current = cursor {
                    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(current.pointee.ai_addr, current.pointee.ai_addrlen, &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                        results.append(String(cString: hostBuffer))
                    }
                    cursor = current.pointee.ai_next
                }
                continuation.resume(returning: results.isEmpty ? "no addresses" : results.joined(separator: ", "))
            }
        }
    }

    private static func connectTime(_ host: String, port: UInt16) async -> String {
        await withCheckedContinuation { continuation in
            let started = Date()
            guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: "TCP connect failed: invalid port")
                return
            }
            let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp)
            let gate = Once()
            let finish: @Sendable (String) -> Void = { text in
                guard gate.claim() else { return }
                connection.cancel()
                continuation.resume(returning: text)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(String(format: "TCP connect: %.0f ms", Date().timeIntervalSince(started) * 1000))
                case .failed(let error):
                    finish("TCP connect failed: \(error.localizedDescription)")
                default:
                    break
                }
            }
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 8) {
                finish("TCP connect timed out")
            }
        }
    }

    private static func httpTiming(_ host: String) async -> String {
        guard let url = URL(string: "https://\(host)/") else { return "HTTP: invalid host" }
        let delegate = MetricGate()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        let started = Date()
        do {
            let (_, response) = try await session.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let total = Date().timeIntervalSince(started) * 1000
            return String(format: "HTTP %d in %.0f ms\n%@", status, total, delegate.summary)
        } catch {
            return "HTTP: \(error.localizedDescription)"
        }
    }

    private static func ping(_ host: String, count: Int) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", String(count), host]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "ping failed: \(error.localizedDescription)"
        }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output.isEmpty ? "ping returned no output." : output
    }
}

enum HostCheck {
    static func hostname(_ raw: String) -> String? {
        let host = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty || host.count > 253 || host.hasPrefix("-") || host.hasPrefix("@") { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:")
        if host.unicodeScalars.contains(where: { !allowed.contains($0) }) { return nil }
        return host
    }
}

private final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: ToolResult
    init(_ value: ToolResult) { self.value = value }
    func set(_ value: ToolResult) {
        lock.lock()
        self.value = value
        lock.unlock()
    }
    func get() -> ToolResult {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private final class TextBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String
    init(_ value: String) { self.value = value }
    func set(_ value: String) {
        lock.lock()
        self.value = value
        lock.unlock()
    }
    func get() -> String {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Data()
    func append(_ data: Data) {
        lock.lock()
        value.append(data)
        lock.unlock()
    }
    func snapshot() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}

private final class MetricGate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    var summary = ""

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let lines = metrics.transactionMetrics.map { metric -> String in
            func ms(_ start: Date?, _ end: Date?) -> String {
                guard let start, let end else { return "-" }
                return String(format: "%.0f ms", end.timeIntervalSince(start) * 1000)
            }
            return "DNS \(ms(metric.domainLookupStartDate, metric.domainLookupEndDate)), connect \(ms(metric.connectStartDate, metric.connectEndDate)), TLS \(ms(metric.secureConnectionStartDate, metric.secureConnectionEndDate)), request \(ms(metric.requestStartDate, metric.requestEndDate)), response \(ms(metric.responseStartDate, metric.responseEndDate))"
        }
        summary = lines.joined(separator: "\n")
    }
}
