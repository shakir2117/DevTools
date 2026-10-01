import Foundation
import Security
import CryptoKit

public enum CertInspect {
    public static func describe(pem: String) -> ToolResult {
        if pem.utf8.count > 1_000_000 { return .failure("Input is larger than 1 MB.") }
        let trimmed = pem.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .success("") }
        if trimmed.contains("-----BEGIN") {
            guard let der = der(from: trimmed) else { return .failure("That PEM block is not valid Base64.") }
            return describe(data: der, source: trimmed)
        }
        guard let data = Data(base64Encoded: cleaned(trimmed)) else {
            return .failure("Paste a PEM certificate or certificate request.")
        }
        return describe(data: data, source: trimmed)
    }

    public static func describe(data: Data) -> ToolResult {
        if data.count > 1_000_000 { return .failure("File is larger than 1 MB.") }
        if let text = String(data: data, encoding: .utf8), text.contains("-----BEGIN") {
            return describe(pem: text)
        }
        return describe(data: data, source: "")
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let certificate = describe(pem: sampleCertificate)
        expect("cert subject", certificate.output.contains("DevKit Test"))
        expect("cert expiry", certificate.output.contains("Not Valid After"))
        let request = describe(pem: sampleRequest)
        expect("csr cn", request.output.contains("CN: DevKit Test"))
        expect("csr org", request.output.contains("O: DevKit"))
        expect("cert junk", describe(pem: "-----BEGIN CERTIFICATE-----\nnot pem\n-----END CERTIFICATE-----").issue != nil)
    }

    private static func describe(data: Data, source: String) -> ToolResult {
        if data.isEmpty { return .failure("The certificate data is empty.") }
        if let certificate = SecCertificateCreateWithData(nil, data as CFData) {
            return .success(certificateReport(certificate))
        }
        let subject = subjectLines(data)
        if subject.isEmpty { return .failure("That is not a certificate or a certificate request.") }
        var lines = ["Kind: certificate request"]
        lines.append(contentsOf: subject)
        if source.contains("BEGIN") { lines.append(source) }
        return .success(lines.joined(separator: "\n"))
    }

    private static func certificateReport(_ certificate: SecCertificate) -> String {
        var lines = ["Kind: certificate"]
        lines.append("Subject: \(SecCertificateCopySubjectSummary(certificate) as String? ?? "")")
        if let values = SecCertificateCopyValues(certificate, nil, nil) as? [String: Any] {
            lines.append(contentsOf: fields(values))
        }
        let der = SecCertificateCopyData(certificate) as Data
        lines.append("SHA-256: \(SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined())")
        return lines.joined(separator: "\n")
    }

    private static func fields(_ values: [String: Any]) -> [String] {
        var lines: [String] = []
        for (_, raw) in values {
            guard let record = raw as? [String: Any] else { continue }
            let label = record[kSecPropertyKeyLabel as String] as? String ?? ""
            let interesting = label.localizedCaseInsensitiveContains("valid")
                || label.localizedCaseInsensitiveContains("issuer")
                || label.localizedCaseInsensitiveContains("serial")
                || label.localizedCaseInsensitiveContains("DNS")
                || label.localizedCaseInsensitiveContains("alt")
            guard interesting, let value = record[kSecPropertyKeyValue as String] else { continue }
            let text = flatten(value)
            if !text.isEmpty { lines.append("\(label): \(text)") }
        }
        return lines.sorted()
    }

    private static func flatten(_ value: Any) -> String {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        if let date = value as? Date { return ISO8601DateFormatter().string(from: date) }
        if let array = value as? [Any] { return array.map(flatten).filter { !$0.isEmpty }.joined(separator: ", ") }
        if let record = value as? [String: Any], let inner = record[kSecPropertyKeyValue as String] {
            let label = record[kSecPropertyKeyLabel as String] as? String ?? ""
            let text = flatten(inner)
            return label.isEmpty ? text : "\(label): \(text)"
        }
        return ""
    }

    private static func subjectLines(_ data: Data) -> [String] {
        let bytes = [UInt8](data)
        let names: [Data: String] = [
            Data([0x55, 0x04, 0x03]): "CN",
            Data([0x55, 0x04, 0x06]): "C",
            Data([0x55, 0x04, 0x0A]): "O",
            Data([0x55, 0x04, 0x0B]): "OU",
        ]
        var lines: [String] = []
        var index = 0
        while index + 2 < bytes.count {
            if bytes[index] == 0x06, bytes[index + 1] < 0x80 {
                let length = Int(bytes[index + 1])
                let start = index + 2
                let end = start + length
                if end <= bytes.count {
                    let oid = Data(bytes[start..<end])
                    if let label = names[oid], let text = stringValue(bytes, at: end) {
                        lines.append("\(label): \(text)")
                    }
                    index = end
                    continue
                }
            }
            index += 1
        }
        return lines
    }

    private static func stringValue(_ bytes: [UInt8], at index: Int) -> String? {
        guard index + 2 <= bytes.count else { return nil }
        let tag = bytes[index]
        guard tag == 0x0C || tag == 0x13 || tag == 0x14 || tag == 0x16 || tag == 0x1E else { return nil }
        guard let (length, header) = derLength(bytes, at: index + 1) else { return nil }
        let start = index + 1 + header
        let end = start + length
        guard end <= bytes.count else { return nil }
        let slice = Data(bytes[start..<end])
        if tag == 0x1E { return String(data: slice, encoding: .utf16BigEndian) }
        return String(data: slice, encoding: .utf8)
    }

    private static func derLength(_ bytes: [UInt8], at index: Int) -> (Int, Int)? {
        guard index < bytes.count else { return nil }
        let first = bytes[index]
        if first < 0x80 { return (Int(first), 1) }
        let count = Int(first & 0x7F)
        guard count > 0, count <= 3, index + 1 + count <= bytes.count else { return nil }
        var length = 0
        for offset in 0..<count { length = (length << 8) | Int(bytes[index + 1 + offset]) }
        return (length, 1 + count)
    }

    private static func der(from pem: String) -> Data? {
        guard let begin = pem.range(of: "-----BEGIN "),
              let endMark = pem.range(of: "-----END ") else { return nil }
        let bodyStart = pem.range(of: "-----", range: begin.upperBound..<endMark.lowerBound)?.upperBound ?? begin.upperBound
        let body = String(pem[bodyStart..<endMark.lowerBound])
        return Data(base64Encoded: cleaned(body), options: .ignoreUnknownCharacters)
    }

    private static func cleaned(_ text: String) -> String {
        text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.map { String($0) }.joined()
    }

    private static let sampleCertificate = """
    -----BEGIN CERTIFICATE-----
    MIIDLzCCAhegAwIBAgIUPISxk6k6ALnoIWU6eKE64x9CZIwwDQYJKoZIhvcNAQEL
    BQAwJzEUMBIGA1UEAwwLRGV2S2l0IFRlc3QxDzANBgNVBAoMBkRldktpdDAeFw0y
    NjEwMDExMTA1NDVaFw0zNjA5MjgxMTA1NDVaMCcxFDASBgNVBAMMC0RldktpdCBU
    ZXN0MQ8wDQYDVQQKDAZEZXZLaXQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
    AoIBAQDiupo7oA5zhU6d6Vl/CixSHFFl3VApCrNBKHUBC4UUfWdHQal9Ntp4+QY8
    wFkd8yMI1ODtCiX3+PBlMm1V0Ku2qafHHNpLNrb1AdsRjRcVngir8eTh8X4IEZVH
    gPfMMEkbJC0LkHe0Q7xlbP+FuRqTkC/joMnc3PWs0sZ63A996wSvjkmR6K3n5AAi
    xsr3vAQcyoyGZldy8yQPjDcwrvkupSx/0BzR3KypcL4/2odaCH2ddsp2ms3m7M9s
    6vq7SIQ/60T+Zqqe2qvftO4UXtnxJcfWAZn/HrxNlZORo2SOB10gWuwRjOSrKKLh
    kyHJouTr+9jxfqA/QsmiXMaXhqTlAgMBAAGjUzBRMB0GA1UdDgQWBBSenMx4w/n0
    Q+GBNuyoMZKbV3zrGjAfBgNVHSMEGDAWgBSenMx4w/n0Q+GBNuyoMZKbV3zrGjAP
    BgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQCC0b9QVg94o7cQ0kNf
    xhn75TCGxFnRE1i4NuYGzp1xw6qvCATH3jzAG0iPXrjDdAUFdLx6ShS+6f+Jca/W
    Ge1iZ+3hLRzk1TW46maIi1dFFjLRW8Ma/EZZMwEe+WoXSSZT8p2yqsC6WIBF28/9
    YpNe2Uk0Z+/MAEfJ6wWISODuHxeIY0KVyirJat0EEsiSSnpxR69D1BPluABV6Cmv
    HGW8MgxjMU/goGKoaBDRfDKM7CGe9b9cz98wpyPGXpdThBdvhNEsWTlpznBf06pe
    ZB3Pq7n6aBMeZ8PLNpEu30d/cuic/e5ovOAs0VfdaxxuF6DCGy19j1yAKQzX7UNU
    F7dL
    -----END CERTIFICATE-----
    """

    private static let sampleRequest = """
    -----BEGIN CERTIFICATE REQUEST-----
    MIICbDCCAVQCAQAwJzEUMBIGA1UEAwwLRGV2S2l0IFRlc3QxDzANBgNVBAoMBkRl
    dktpdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOK6mjugDnOFTp3p
    WX8KLFIcUWXdUCkKs0EodQELhRR9Z0dBqX022nj5BjzAWR3zIwjU4O0KJff48GUy
    bVXQq7app8cc2ks2tvUB2xGNFxWeCKvx5OHxfggRlUeA98wwSRskLQuQd7RDvGVs
    /4W5GpOQL+Ogydzc9azSxnrcD33rBK+OSZHorefkACLGyve8BBzKjIZmV3LzJA+M
    NzCu+S6lLH/QHNHcrKlwvj/ah1oIfZ12ynaazebsz2zq+rtIhD/rRP5mqp7aq9+0
    7hRe2fElx9YBmf8evE2Vk5GjZI4HXSBa7BGM5KsoouGTIcmi5Ov72PF+oD9CyaJc
    xpeGpOUCAwEAAaAAMA0GCSqGSIb3DQEBCwUAA4IBAQC291jlF/GBliSrvvNomPfm
    bv+y+WC8sYvdUKl3es5hul2KrBpbuWUMEVuRX8KFxIT0IhTKODBgPlgVvrqanQJR
    5moHYTp2FwAhVOjAdnyE7D0n6kO/bCViavff/VifRPA5XutBsLbPSQw04WN5r0sE
    ICf1LDB9ACsM77aQuaTqz+rsf+36F8m4IfCIQUjWhpkQvc0SRKnnH6Dk60OSYlXu
    cDrU/sCijEv/7mEpOILlB8qJgH6RfhIl3QHWAuz+dFglIhFvpMwk8eghkGk07LZU
    Xf6DMFk62Tnf4OgApy877mh03Ka5iiFKC4GN+CDyNZy+Jvo+NYMtvh5wl0yT6k6R
    -----END CERTIFICATE REQUEST-----
    """
}
