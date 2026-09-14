import Foundation

struct FormData {
    var ykn = ""
    var ad = ""
    var soyad = ""
    var baba = ""
    var ana = ""
    var dogumYeri = ""
    var dogumTarihi = ""
    var uyruk = ""
    var ogrenim = "Okur yazar değil"
    var iseGiris = ""
    var referansKodu = "529516095"
}

enum AppValidationError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let s): return s }
    }
}

enum Validators {
    static func normalize(_ s: String?) -> String {
        (s ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func digits(_ s: String?) -> String { (s ?? "").filter { $0.isNumber } }

    static func validateYKN(_ input: String) throws -> String {
        let d = digits(input)
        guard d.count == 11 else { throw AppValidationError.message("Yabancı Kimlik No 11 haneli olmalıdır.") }
        guard d.hasPrefix("99") else { throw AppValidationError.message("Yabancı Kimlik No 99 ile başlamalıdır.") }
        guard Set(d).count > 1 else { throw AppValidationError.message("Yabancı Kimlik No geçersizdir.") }
        return d
    }

    static func validateReference(_ input: String) throws -> String {
        let d = digits(input)
        guard d.count == 9, normalize(input) == d else { throw AppValidationError.message("Referans kodu tam 9 rakam olmalıdır.") }
        return d
    }

    private static let strictFormats = ["dd.MM.yyyy", "yyyy-MM-dd", "dd/MM/yyyy", "dd-MM-yyyy"]
    static func parseDateStrict(_ input: String, label: String, rejectFuture: Bool) throws -> String {
        let s = normalize(input)
        guard !s.isEmpty else { throw AppValidationError.message("\(label) boş bırakılamaz.") }
        if s.range(of: #"(^|\D)\d{1,2}[./-]\d{1,2}[./-]\d{2}($|\D)"#, options: .regularExpression) != nil {
            throw AppValidationError.message("\(label) 4 haneli yıl içermelidir.")
        }
        let locale = Locale(identifier: "en_US_POSIX")
        var parsed: Date?
        for f in strictFormats {
            let df = DateFormatter(); df.locale = locale; df.dateFormat = f; df.isLenient = false
            if let d = df.date(from: s) { parsed = d; break }
        }
        guard let date = parsed else { throw AppValidationError.message("\(label) geçersizdir. GG.AA.YYYY biçimini kullanın.") }
        let y = Calendar(identifier: .gregorian).component(.year, from: date)
        guard (1900...2100).contains(y) else { throw AppValidationError.message("\(label) yılı 1900-2100 arasında olmalıdır.") }
        if rejectFuture && date > Date() { throw AppValidationError.message("\(label) gelecekte olamaz.") }
        let out = DateFormatter(); out.locale = locale; out.dateFormat = "dd.MM.yyyy"
        return out.string(from: date)
    }

    static func normalizeDateOCR(_ raw: String) -> String {
        let s = normalize(raw)
        let patterns = [#"(\d{1,2})[./-](\d{1,2})[./-](\d{4})"#, #"(\d{4})[./-](\d{1,2})[./-](\d{1,2})"#]
        for (idx, p) in patterns.enumerated() {
            guard let re = try? NSRegularExpression(pattern: p), let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { continue }
            func g(_ n: Int) -> String { Range(m.range(at: n), in: s).map { String(s[$0]) } ?? "" }
            let d: String, mo: String, y: String
            if idx == 0 { d=g(1); mo=g(2); y=g(3) } else { y=g(1); mo=g(2); d=g(3) }
            return String(format: "%02d.%02d.%04d", Int(d) ?? 0, Int(mo) ?? 0, Int(y) ?? 0)
        }
        return ""
    }

    static func cleanName(_ s: String) -> String {
        let allowed = s.replacingOccurrences(of: #"[^A-Za-zÇĞİÖŞÜçğıöşüÂâÊêÎîÔôÛû\s'\-]"#, with: " ", options: .regularExpression)
        return normalize(allowed).uppercased(with: Locale(identifier: "en_US_POSIX"))
    }

    static func safeFilePart(_ s: String) -> String {
        let x = normalize(s).replacingOccurrences(of: #"[^A-Za-z0-9ÇĞİÖŞÜçğıöşü._-]+"#, with: "_", options: .regularExpression)
        return x.trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
    }
}
