import Foundation
import CryptoKit

public enum Hashing {
    public enum Algorithm: String, CaseIterable, Sendable {
        case md5, sha1, sha256, sha384, sha512

        public var title: String {
            switch self {
            case .md5: return "MD5"
            case .sha1: return "SHA-1"
            case .sha256: return "SHA-256"
            case .sha384: return "SHA-384"
            case .sha512: return "SHA-512"
            }
        }

        var blockSize: Int {
            switch self {
            case .md5, .sha1, .sha256: return 64
            case .sha384, .sha512: return 128
            }
        }
    }

    public static func hash(text: String, algorithm: Algorithm, hmacKey: String?) -> ToolResult {
        if text.utf8.count > 20_000_000 {
            return .failure("Text is larger than 20 MB. Hash it as a file instead.")
        }
        let keyData = hmacKey.map { Data($0.utf8) }
        let digest = digestHex(data: Data(text.utf8), algorithm: algorithm, hmacKey: keyData)
        return .success(format(digest, algorithm: algorithm, hmac: hmacKey != nil))
    }

    public static func hashFile(at url: URL, algorithm: Algorithm, hmacKey: String?) -> ToolResult {
        do {
            let keyData = hmacKey.map { Data($0.utf8) }
            let digest = try fileDigest(url: url, algorithm: algorithm, hmacKey: keyData)
            return .success(format(digest, algorithm: algorithm, hmac: hmacKey != nil))
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    public static func digestHex(data: Data, algorithm: Algorithm, hmacKey: Data?) -> String {
        let bytes: Data
        if let hmacKey {
            bytes = hmac(key: hmacKey, message: data, algorithm: algorithm)
        } else {
            bytes = digest(data, algorithm)
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        expect("md5 empty", digestHex(data: Data(), algorithm: .md5, hmacKey: nil) == "d41d8cd98f00b204e9800998ecf8427e")
        expect("md5 abc", digestHex(data: Data("abc".utf8), algorithm: .md5, hmacKey: nil) == "900150983cd24fb0d6963f7d28e17f72")
        expect("sha1 abc", digestHex(data: Data("abc".utf8), algorithm: .sha1, hmacKey: nil) == "a9993e364706816aba3e25717850c26c9cd0d89d")
        expect(
            "sha256 abc",
            digestHex(data: Data("abc".utf8), algorithm: .sha256, hmacKey: nil) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        let hmac = digestHex(
            data: Data("The quick brown fox jumps over the lazy dog".utf8),
            algorithm: .sha256,
            hmacKey: Data("key".utf8)
        )
        expect("hmac sha256", hmac == "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8")
        expect("hash empty text", hash(text: "", algorithm: .sha256, hmacKey: nil).issue == nil)
        expect("hash binary text", hash(text: String(repeating: "\u{0}", count: 3), algorithm: .md5, hmacKey: nil).issue == nil)
    }

    private static func format(_ hex: String, algorithm: Algorithm, hmac: Bool) -> String {
        let label = hmac ? "HMAC-\(algorithm.title)" : algorithm.title
        return "\(label)\n\(hex)"
    }

    private static func digest(_ data: Data, _ algorithm: Algorithm) -> Data {
        switch algorithm {
        case .md5: return Data(Insecure.MD5.hash(data: data))
        case .sha1: return Data(Insecure.SHA1.hash(data: data))
        case .sha256: return Data(SHA256.hash(data: data))
        case .sha384: return Data(SHA384.hash(data: data))
        case .sha512: return Data(SHA512.hash(data: data))
        }
    }

    private static func hmac(key: Data, message: Data, algorithm: Algorithm) -> Data {
        let pads = hmacPads(key: key, algorithm: algorithm)
        let inner = digest(pads.inner + message, algorithm)
        return digest(pads.outer + inner, algorithm)
    }

    private static func hmacPads(key: Data, algorithm: Algorithm) -> (inner: Data, outer: Data) {
        var keyData = key
        if keyData.count > algorithm.blockSize {
            keyData = digest(keyData, algorithm)
        }
        if keyData.count < algorithm.blockSize {
            keyData.append(Data(repeating: 0, count: algorithm.blockSize - keyData.count))
        }
        var inner = Data(count: algorithm.blockSize)
        var outer = Data(count: algorithm.blockSize)
        for index in 0..<algorithm.blockSize {
            inner[index] = keyData[index] ^ 0x36
            outer[index] = keyData[index] ^ 0x5c
        }
        return (inner, outer)
    }

    private static func fileDigest(url: URL, algorithm: Algorithm, hmacKey: Data?) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let pads = hmacKey.map { hmacPads(key: $0, algorithm: algorithm) }
        let bytes: Data
        switch algorithm {
        case .md5: bytes = try stream(handle, pads: pads) { Insecure.MD5() }
        case .sha1: bytes = try stream(handle, pads: pads) { Insecure.SHA1() }
        case .sha256: bytes = try stream(handle, pads: pads) { SHA256() }
        case .sha384: bytes = try stream(handle, pads: pads) { SHA384() }
        case .sha512: bytes = try stream(handle, pads: pads) { SHA512() }
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func stream<H: HashFunction>(_ handle: FileHandle, pads: (inner: Data, outer: Data)?, make: () -> H) throws -> Data {
        var hasher = make()
        if let pads {
            hasher.update(data: pads.inner)
        }
        while true {
            let chunk = try handle.read(upToCount: 1 << 20) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        let innerDigest = Data(hasher.finalize())
        guard let pads else { return innerDigest }
        var outer = make()
        outer.update(data: pads.outer)
        outer.update(data: innerDigest)
        return Data(outer.finalize())
    }
}
