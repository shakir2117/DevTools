import SwiftUI
import DevKitCore

struct JWTTool: Tool {
    let id = "jwt"
    let name = "JWT"
    let summary = "Decode claims, sign and verify HMAC, verify RS256"
    let symbol = "key.horizontal"
    let category = ToolCategory.encoders
    func makeView() -> AnyView { AnyView(JWTToolView()) }
}

private enum JWTMode: String, CaseIterable, Identifiable {
    case decode, sign, verifyHMAC, verifyRS256
    var id: String { rawValue }
    var title: String {
        switch self {
        case .decode: return "Decode"
        case .sign: return "Sign"
        case .verifyHMAC: return "Verify HMAC"
        case .verifyRS256: return "Verify RS256"
        }
    }
}

struct JWTToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var mode: JWTMode = .decode
    @State private var token = ""
    @State private var header = #"{"alg":"HS256","typ":"JWT"}"#
    @State private var payload = #"{"sub":"devkit"}"#
    @State private var secret = ""
    @State private var pem = ""
    @State private var algorithm: JWTCodec.HMACAlgorithm = .hs256
    @State private var output = ""
    @State private var issue: ToolIssue?
    @State private var restored = false
    @State private var gate = RunGate()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Mode", selection: $mode) {
                    ForEach(JWTMode.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                if mode == .sign || mode == .verifyHMAC {
                    Picker("Algorithm", selection: $algorithm) {
                        ForEach(JWTCodec.HMACAlgorithm.allCases, id: \.self) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .frame(maxWidth: 140)
                }
                Spacer()
                Button("Sample") { applySample() }
                Button("Clear") { clear() }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    field("Token", text: $token)
                    if mode == .sign {
                        field("Header JSON", text: $header)
                        field("Payload JSON", text: $payload)
                    }
                    if mode == .sign || mode == .verifyHMAC {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Secret")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            SecureField("HMAC secret", text: $secret)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    if mode == .verifyRS256 {
                        field("PEM public key", text: $pem)
                    }
                    Text("Result")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(output.isEmpty ? " " : output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(12)
            }
            if let issue {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(issue.display)
                    Spacer()
                }
                .font(.callout)
                .foregroundStyle(.red)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.08))
            }
        }
        .onAppear(perform: restore)
        .onChange(of: token) { _, _ in schedule(); persist() }
        .onChange(of: header) { _, _ in schedule(); persist() }
        .onChange(of: payload) { _, _ in schedule(); persist() }
        .onChange(of: secret) { _, _ in schedule(); persist() }
        .onChange(of: pem) { _, _ in schedule(); persist() }
        .onChange(of: mode) { _, _ in schedule(); persist() }
        .onChange(of: algorithm) { _, _ in schedule(); persist() }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: title == "Token" || title == "PEM public key" ? 88 : 64)
                .padding(6)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08)))
        }
    }

    private func schedule() {
        let generation = gate.bump()
        let mode = mode
        let token = token
        let header = header
        let payload = payload
        let secret = secret
        let pem = pem
        let algorithm = algorithm
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
            guard generation == gate.current() else { return }
            let result: ToolResult
            switch mode {
            case .decode:
                result = JWTCodec.describe(token)
            case .sign:
                result = JWTCodec.sign(header: header, payload: payload, secret: secret, algorithm: algorithm)
            case .verifyHMAC:
                result = JWTCodec.verifyHMAC(token: token, secret: secret, algorithm: algorithm)
            case .verifyRS256:
                result = JWTCodec.verifyRS256(token: token, pem: pem)
            }
            DispatchQueue.main.async {
                guard generation == gate.current() else { return }
                if mode == .sign, result.issue == nil {
                    self.token = result.output
                }
                output = result.output
                issue = result.issue
            }
        }
    }

    private func applySample() {
        token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        secret = "your-256-bit-secret"
        header = #"{"alg":"HS256","typ":"JWT"}"#
        payload = #"{"sub":"1234567890","name":"John Doe","iat":1516239022}"#
        mode = .decode
    }

    private func clear() {
        _ = gate.bump()
        token = ""
        output = ""
        issue = nil
        secret = ""
        pem = ""
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let object = model.loadOptionsObject(for: "jwt")
        token = object["token"] as? String ?? ""
        header = object["header"] as? String ?? header
        payload = object["payload"] as? String ?? payload
        secret = object["secret"] as? String ?? ""
        pem = object["pem"] as? String ?? ""
        if let value = object["mode"] as? String, let parsed = JWTMode(rawValue: value) { mode = parsed }
        if let value = object["algorithm"] as? String, let parsed = JWTCodec.HMACAlgorithm(rawValue: value) { algorithm = parsed }
        schedule()
    }

    private func persist() {
        guard restored else { return }
        model.saveOptionsObject([
            "token": token,
            "header": header,
            "payload": payload,
            "secret": secret,
            "pem": pem,
            "mode": mode.rawValue,
            "algorithm": algorithm.rawValue,
        ], for: "jwt")
    }
}
