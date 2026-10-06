import Foundation
import Cocoa

// Bridge to libMAC C API
@_silgen_name("CompressFileW")
func CompressFileW(_ input: UnsafePointer<UInt32>?, _ output: UnsafePointer<UInt32>?, _ level: Int32, _ callback: UnsafeRawPointer?, _ threads: Int32, _ tag: UnsafeRawPointer?, _ readFull: Bool) -> Int32

@_silgen_name("DecompressFileW")
func DecompressFileW(_ input: UnsafePointer<UInt32>?, _ output: UnsafePointer<UInt32>?, _ callback: UnsafeRawPointer?, _ threads: Int32) -> Int32

@_silgen_name("VerifyFileW")
func VerifyFileW(_ input: UnsafePointer<UInt32>?, _ callback: UnsafeRawPointer?, _ quick: Bool, _ threads: Int32) -> Int32

@_silgen_name("ConvertFileW")
func ConvertFileW(_ input: UnsafePointer<UInt32>?, _ output: UnsafePointer<UInt32>?, _ level: Int32, _ callback: UnsafeRawPointer?, _ threads: Int32) -> Int32

class MACProcessor {
    static let buildMarker = "MACProcessor-BUILD-UTF32-v4"

    func stringToWide(_ s: String) -> [UInt32] {
        var result: [UInt32] = []
        for scalar in s.unicodeScalars {
            result.append(UInt32(scalar.value))
        }
        result.append(0)
        return result
    }
    
    func process(file: MACFile, mode: Int, level: Int) {
        DispatchQueue.main.async {
            file.status = "Processing..."
        }
        
        let inputPath = file.url.path
        let outputPath = getOutputPath(for: file, mode: mode)
        
        var result = -1
        if mode == 0 {
            result = compressFile(inputPath: inputPath, outputPath: outputPath, level: level)
        } else if mode == 1 {
            result = decompressFile(inputPath: inputPath, outputPath: outputPath)
        } else if mode == 2 {
            result = verifyFile(inputPath: inputPath)
        } else if mode == 3 {
            result = convertFile(inputPath: inputPath, outputPath: outputPath, level: level)
        } else if mode == 4 {
            result = makeAPLFile(inputPath: inputPath)
        }
        
        let errorDesc = errorDescription(result)
        DispatchQueue.main.async {
            if mode == 2 {
                file.status = (result == 0) ? "Verified OK" : "Verify Failed (\(result)): \(errorDesc)"
            } else {
                file.status = (result == 0) ? "Completed" : "Failed (\(result)): \(errorDesc)"
            }
        }
    }
    
    func errorDescription(_ code: Int) -> String {
        switch code {
        case 0: return "Success"
        case 1002: return "Invalid input file"
        case 1003: return "Invalid output file"
        case 1005: return "Unsupported bit depth"
        case 1006: return "Unsupported sample rate"
        case 1007: return "Unsupported channel count"
        case 1009: return "Invalid checksum"
        case 1010: return "Error decompressing frame"
        case 1013: return "Unsupported file type"
        case 1014: return "Unsupported file version"
        case 2000: return "Insufficient memory"
        case 4000: return "User stopped processing"
        case 4001: return "Skipped"
        case -1: return "Undefined error"
        default: return "Error \(code)"
        }
    }
    
    func getOutputPath(for file: MACFile, mode: Int) -> String {
        let url = file.url
        let dir = url.deletingLastPathComponent().path
        let name = url.deletingPathExtension().lastPathComponent
        if mode == 0 || mode == 3 {
            return "\(dir)/\(name).ape"
        } else if mode == 1 {
            return "\(dir)/\(name).wav"
        } else if mode == 4 {
            return "\(dir)/\(name).apl"
        }
        return url.path
    }
    
    func compressFile(inputPath: String, outputPath: String, level: Int) -> Int {
        let macLevel = [1000, 2000, 3000, 4000, 5000][level]
        var inWide = stringToWide(inputPath)
        var outWide = stringToWide(outputPath)
        let ret = CompressFileW(&inWide, &outWide, Int32(macLevel), nil, 1, nil, false)
        return Int(ret)
    }
    
    func decompressFile(inputPath: String, outputPath: String) -> Int {
        var inWide = stringToWide(inputPath)
        var outWide = stringToWide(outputPath)
        let ret = DecompressFileW(&inWide, &outWide, nil, 1)
        return Int(ret)
    }
    
    func verifyFile(inputPath: String) -> Int {
        var inWide = stringToWide(inputPath)
        let ret = VerifyFileW(&inWide, nil, false, 1)
        return Int(ret)
    }
    
    func convertFile(inputPath: String, outputPath: String, level: Int) -> Int {
        let macLevel = [1000, 2000, 3000, 4000, 5000][level]
        var inWide = stringToWide(inputPath)
        var outWide = stringToWide(outputPath)
        let ret = ConvertFileW(&inWide, &outWide, Int32(macLevel), nil, 1)
        return Int(ret)
    }
    
    // MARK: - APL ("Make APL") support

    private static let aplFilenameTemplate = "ARTIST - ALBUM - TRACK# - TITLE"

    func makeAPLFile(inputPath: String) -> Int {
        let ext = URL(fileURLWithPath: inputPath).pathExtension.lowercased()
        if ext == "cue" {
            return makeAPLFromCUE(cuePath: inputPath)
        } else if ext == "ape" || ext == "mac" {
            return makeAPLFromAPE(apePath: inputPath)
        }
        return 1013 // ERROR_UNSUPPORTED_FILE_TYPE
    }

    // Creates a single APL link file that references the whole APE file.
    private func makeAPLFromAPE(apePath: String) -> Int {
        let url = URL(fileURLWithPath: apePath)
        guard apeSampleRate(apePath) != nil else { return -1 }
        let outURL = url.deletingLastPathComponent()
            .appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".apl")
        let header = aplHeader(imageFile: url.lastPathComponent, startBlock: 0, finishBlock: -1)
        return writeAPL(outURL: outURL, header: header, tags: [])
    }

    // Parses a CUE sheet and writes one APL link file per track (matches the Windows GUI).
    private func makeAPLFromCUE(cuePath: String) -> Int {
        let cueURL = URL(fileURLWithPath: cuePath)
        let dir = cueURL.deletingLastPathComponent()
        guard let cueText = readTextFile(cuePath) else { return 1002 }

        var albumArtist = ""
        var albumTitle = ""
        var imageFile = ""
        var tracks: [(title: String, artist: String, start: String)] = []
        var current: (title: String, artist: String, start: String)? = nil

        for rawLine in cueText.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let upper = line.uppercased()
            if upper.hasPrefix("PERFORMER ") {
                let value = extractQuoted(line)
                if current != nil { current?.artist = value } else { albumArtist = value }
            } else if upper.hasPrefix("TITLE ") {
                let value = extractQuoted(line)
                if current != nil { current?.title = value } else { albumTitle = value }
            } else if upper.hasPrefix("FILE ") {
                imageFile = extractQuoted(line)
            } else if upper.hasPrefix("TRACK ") {
                if let finished = current { tracks.append(finished) }
                current = (title: "", artist: "", start: "0")
            } else if upper.hasPrefix("INDEX 01 ") {
                let value = line.dropFirst("INDEX 01 ".count).trimmingCharacters(in: .whitespaces)
                if current != nil { current?.start = String(value) }
            }
        }
        if let finished = current { tracks.append(finished) }

        guard !tracks.isEmpty, !imageFile.isEmpty else { return 1002 }

        let imageURL = dir.appendingPathComponent(imageFile)
        guard let sampleRate = apeSampleRate(imageURL.path), sampleRate > 0 else { return 1002 }

        let startSeconds = tracks.map { cueTimeToSeconds($0.start) }
        var wroteAny = false
        for index in 0..<tracks.count {
            let track = tracks[index]
            let artist = track.artist.isEmpty ? albumArtist : track.artist
            let startBlock = Int64((Double(sampleRate) * startSeconds[index]).rounded())
            let finishBlock: Int64 = (index + 1 < tracks.count)
                ? Int64((Double(sampleRate) * startSeconds[index + 1]).rounded())
                : -1

            var name = Self.aplFilenameTemplate
            name = name.replacingOccurrences(of: "ARTIST", with: artist)
            name = name.replacingOccurrences(of: "ALBUM", with: albumTitle)
            name = name.replacingOccurrences(of: "TRACK#", with: String(format: "%02d", index + 1))
            name = name.replacingOccurrences(of: "TITLE", with: track.title)
            name = sanitizeAPLName(name)

            let outURL = dir.appendingPathComponent(name + ".apl")
            let header = aplHeader(imageFile: imageFile, startBlock: startBlock, finishBlock: finishBlock)
            let tags: [(String, String)] = [
                ("Artist", artist),
                ("Album", albumTitle),
                ("Title", track.title),
                ("Track", String(format: "%02d", index + 1)),
            ]
            if writeAPL(outURL: outURL, header: header, tags: tags) == 0 { wroteAny = true }
        }
        return wroteAny ? 0 : -1
    }

    private func aplHeader(imageFile: String, startBlock: Int64, finishBlock: Int64) -> String {
        let image = (imageFile as NSString).lastPathComponent
        return "[Monkey's Audio Image Link File]\r\n" +
            "Image File=\(image)\r\n" +
            "Start Block=\(startBlock)\r\n" +
            "Finish Block=\(finishBlock)\r\n"
    }

    private func writeAPL(outURL: URL, header: String, tags: [(String, String)]) -> Int {
        var data = Data(header.utf8)
        let tagData = apeTagData(tags)
        if tagData.isEmpty {
            data.append(contentsOf: Array("\r\n----- APE TAG (DO NOT TOUCH!!!) -----\r\n".utf8))
        } else {
            data.append(contentsOf: Array("\r\n----- APE TAG (DO NOT TOUCH!!!) -----\r\n".utf8))
            data.append(tagData)
        }
        do {
            try data.write(to: outURL)
            return 0
        } catch {
            return 1001 // ERROR_IO_WRITE
        }
    }

    // Builds an APE tag (fields + footer), matching the layout written by libMAC.
    private func apeTagData(_ tags: [(String, String)]) -> Data {
        var entries: [(name: String, value: String, size: Int)] = []
        for (name, value) in tags where !value.isEmpty {
            let size = 8 + name.utf8.count + 1 + value.utf8.count
            entries.append((name: name, value: value, size: size))
        }
        guard !entries.isEmpty else { return Data() }

        entries.sort { a, b in
            if a.size != b.size { return a.size < b.size }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        var fields = Data()
        for entry in entries {
            fields.append(le32(UInt32(entry.value.utf8.count)))
            fields.append(le32(0)) // UTF-8 text
            fields.append(contentsOf: Array(entry.name.utf8))
            fields.append(0)
            fields.append(contentsOf: Array(entry.value.utf8))
        }

        var footer = Data()
        footer.append(contentsOf: Array("APETAGEX".utf8))
        footer.append(le32(2000)) // version
        footer.append(le32(UInt32(fields.count) + 32))
        footer.append(le32(UInt32(entries.count)))
        footer.append(le32(0x40000000)) // contains footer, no header
        footer.append(Data(repeating: 0, count: 8))

        var out = fields
        out.append(footer)
        return out
    }

    private func le32(_ value: UInt32) -> Data {
        var little = value.littleEndian
        return Data(bytes: &little, count: 4)
    }

    private func readTextFile(_ path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        if let text = String(data: data, encoding: .utf8) {
            return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        }
        return String(data: data, encoding: .utf16)
    }

    private func extractQuoted(_ line: String) -> String {
        guard let first = line.firstIndex(of: "\"") else {
            return line.split(separator: " ").dropFirst().joined(separator: " ")
        }
        let remainder = line[line.index(after: first)...]
        if let second = remainder.firstIndex(of: "\"") {
            return String(remainder[..<second])
        }
        return String(remainder)
    }

    private func cueTimeToSeconds(_ time: String) -> Double {
        let parts = time.split(separator: ":").map { Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
        let minutes = parts.count > 0 ? parts[0] : 0
        let seconds = parts.count > 1 ? parts[1] : 0
        let frames = parts.count > 2 ? parts[2] : 0
        return Double(minutes) * 60.0 + Double(seconds) + Double(frames) / 75.0
    }

    private func sanitizeAPLName(_ name: String) -> String {
        let invalid: Set<Character> = ["?", "\"", "\\", "/", "<", ">", "*", "|", ":"]
        var result = String(name.map { invalid.contains($0) ? "-" : $0 })
        if result.lowercased().hasSuffix(".apl") { result = String(result.dropLast(4)) }
        return result
    }

    // Reads the sample rate directly from the APE descriptor/header.
    private func apeSampleRate(_ path: String) -> Int64? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 1024 * 1024)
        guard let range = data.range(of: Data("MAC ".utf8)) else { return nil }
        let macStart = range.lowerBound
        guard data.count >= macStart + 12 else { return nil }
        let descriptorBytes = readLE32(data, at: macStart + 8)
        let headerStart = macStart + Int(descriptorBytes)
        guard data.count >= headerStart + 24 else { return nil }
        let sampleRate = readLE32(data, at: headerStart + 20)
        return Int64(sampleRate)
    }

    private func readLE32(_ data: Data, at offset: Int) -> UInt32 {
        return data.withUnsafeBytes { raw -> UInt32 in
            let bytes = raw.bindMemory(to: UInt8.self)
            return UInt32(bytes[offset]) |
                (UInt32(bytes[offset + 1]) << 8) |
                (UInt32(bytes[offset + 2]) << 16) |
                (UInt32(bytes[offset + 3]) << 24)
        }
    }
}
