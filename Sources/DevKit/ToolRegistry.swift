import SwiftUI

enum ToolRegistry {
    static let all: [any Tool] = [
        JSONFormatterTool(),
        URLParserTool(),
        XMLFormatterTool(),
        YAMLFormatterTool(),
        SQLFormatTool(),
        HTMLMarkupTool(),
        CodeBeautifierTool(),
        CodeMinifierTool(),
        Base64Tool(),
        URLEncoderTool(),
        UnicodeEscapeTool(),
        SnowflakeTool(),
        HTMLEntityTool(),
        JWTTool(),
        JSONYAMLTool(),
        PlistTool(),
        DotEnvTool(),
        SemverTool(),
        CSVJSONTool(),
        XMLToJSONTool(),
        JSONToCSVTool(),
        NumberBaseTool(),
        TimestampTool(),
        DateTool(),
        ColorTool(),
        UnitTool(),
        FileSizeTool(),
        HashTool(),
        IDGeneratorTool(),
        PasswordTool(),
        UserAgentTool(),
        RegexTool(),
        UnicodeTool(),
        HexTool(),
        ChmodTool(),
        JSONSchemaTool(),
        CertTool(),
        ImageMetaTool(),
        DiffTool(),
        JSONPathTool(),
        CSVViewerTool(),
        MarkdownTool(),
        HTMLPreviewTool(),
        CronTool(),
        QRGeneratorTool(),
        GitignoreTool(),
        LaunchdTool(),
        QRReaderTool(),
        PDFTool(),
        HTTPClientTool(),
        RequestBuilderTool(),
        CurlTool(),
        HTTPStatusTool(),
        WebSocketTool(),
        DNSTool(),
        WhoisTool(),
        IPLookupTool(),
        TLSTool(),
        DiagnosticsTool(),
    ]

    static func tool(id: String) -> (any Tool)? {
        all.first { $0.id == id }
    }

    static func matching(_ query: String) -> [any Tool] {
        all.compactMap { tool -> (Int, any Tool)? in
            guard let score = Fuzzy.score(query: query, name: tool.name, summary: tool.summary) else { return nil }
            return (score, tool)
        }
        .sorted { lhs, rhs in
            if lhs.0 == rhs.0 { return lhs.1.name < rhs.1.name }
            return lhs.0 > rhs.0
        }
        .map(\.1)
    }
}
