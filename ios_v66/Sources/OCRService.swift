import Foundation
import UIKit
import Vision
import CoreImage

final class OCRService {
    private let ciContext = CIContext(options: nil)
    private let rois: [(String, CGRect)] = [
        ("ykn", CGRect(x:0.47,y:0.425,width:0.49,height:0.038)),
        ("ad", CGRect(x:0.47,y:0.463,width:0.49,height:0.037)),
        ("soyad", CGRect(x:0.47,y:0.500,width:0.49,height:0.038)),
        ("baba", CGRect(x:0.47,y:0.538,width:0.49,height:0.038)),
        ("ana", CGRect(x:0.47,y:0.576,width:0.49,height:0.038)),
        ("dogum_yeri", CGRect(x:0.47,y:0.614,width:0.49,height:0.038)),
        ("dogum_tarihi", CGRect(x:0.47,y:0.652,width:0.49,height:0.038)),
        ("medeni", CGRect(x:0.47,y:0.690,width:0.49,height:0.038)),
        ("aile_no", CGRect(x:0.47,y:0.728,width:0.49,height:0.038)),
        ("uyruk", CGRect(x:0.47,y:0.766,width:0.49,height:0.038)),
        ("kayit_tarihi", CGRect(x:0.47,y:0.804,width:0.49,height:0.041))
    ]

    func read(_ source: UIImage) async throws -> FormData {
        let normalized = normalizeOrientation(source)
        let rectified = try await rectify(normalized)
        let oriented = try await chooseOrientation(rectified)
        var raw: [String:String] = [:]
        for (key, roi) in rois {
            let numeric = key == "ykn" || key == "aile_no"
            raw[key] = try recognize(oriented, topLeftROI: roi, numeric: numeric, minConfidence: 0.42)
        }
        var d = FormData()
        var ykn = Validators.digits(raw["ykn"] ?? "")
        if let m = ykn.range(of: #"\d{11}"#, options: .regularExpression) { ykn = String(ykn[m]) }
        else if ykn.count > 11 { ykn = String(ykn.suffix(11)) }
        d.ykn = ykn
        d.ad = Validators.cleanName(raw["ad"] ?? "")
        d.soyad = Validators.cleanName(raw["soyad"] ?? "")
        d.baba = Validators.cleanName(raw["baba"] ?? "")
        d.ana = Validators.cleanName(raw["ana"] ?? "")
        d.dogumYeri = Validators.cleanName(raw["dogum_yeri"] ?? "")
        d.dogumTarihi = Validators.normalizeDateOCR(raw["dogum_tarihi"] ?? "")
        d.uyruk = Validators.cleanName(raw["uyruk"] ?? "")
        return d
    }

    private func chooseOrientation(_ image: UIImage) async throws -> UIImage {
        let wide = image.size.width > image.size.height
        let angles: [CGFloat] = wide ? [90,270] : [0,180]
        var best = image, bestScore = Int.min
        for a in angles {
            let candidate = a == 0 ? image : rotate(image, degrees: a)
            let score = (try? orientationScore(candidate)) ?? -1
            if score > bestScore { bestScore = score; best = candidate }
        }
        return best
    }

    private func orientationScore(_ image: UIImage) throws -> Int {
        var score = 0
        if let yr = rois.first(where: {$0.0 == "ykn"})?.1 {
            let s = try recognize(image, topLeftROI: yr, numeric: true, minConfidence: 0.25)
            let d = Validators.digits(s)
            if let r = d.range(of: #"\d{11}"#, options: .regularExpression) {
                let x = String(d[r]); score += 12; if x.hasPrefix("99") { score += 12 }
            } else if d.count >= 8 { score += 4 }
        }
        for key in ["ad","soyad"] {
            if let roi = rois.first(where: {$0.0 == key})?.1 {
                let s = try recognize(image, topLeftROI: roi, numeric: false, minConfidence: 0.30)
                let letters = s.replacingOccurrences(of: #"[^A-Za-zÇĞİÖŞÜçğıöşü]"#, with: "", options: .regularExpression)
                if letters.count >= 2 { score += 3 }
            }
        }
        return score
    }

    private func recognize(_ image: UIImage, topLeftROI: CGRect, numeric: Bool, minConfidence: Float) throws -> String {
        guard let cg = image.cgImage else { return "" }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = !numeric
        if req.supportedRecognitionLanguages.contains("tr-TR") { req.recognitionLanguages = ["tr-TR"] }
        req.regionOfInterest = CGRect(x: topLeftROI.minX, y: 1.0 - topLeftROI.maxY, width: topLeftROI.width, height: topLeftROI.height)
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        try handler.perform([req])
        let candidates = (req.results ?? []).compactMap { $0.topCandidates(1).first }.filter { $0.confidence >= minConfidence }
        let text = candidates.map(\.string).joined(separator: " ")
        return Validators.normalize(numeric ? Validators.digits(text) : text)
    }

    private func normalizeOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return downsample(image, maxSide: 2600) }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let r = UIGraphicsImageRenderer(size: image.size, format: format)
        let out = r.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
        return downsample(out, maxSide: 2600)
    }

    private func downsample(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let m = max(image.size.width, image.size.height)
        guard m > maxSide else { return image }
        let s = maxSide / m
        let size = CGSize(width: image.size.width*s, height: image.size.height*s)
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).image { _ in image.draw(in: CGRect(origin:.zero,size:size)) }
    }

    private func rectify(_ image: UIImage) async throws -> UIImage {
        guard let cg = image.cgImage else { return image }
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 25
        request.minimumSize = 0.18
        request.minimumConfidence = 0.35
        request.quadratureTolerance = 35
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        try handler.perform([request])
        guard let rect = (request.results ?? []).max(by: { area($0) < area($1) }), area(rect) > 0.18 else { return image }
        let ci = CIImage(cgImage: cg)
        let w = ci.extent.width, h = ci.extent.height
        func p(_ v: CGPoint) -> CIVector { CIVector(x: v.x*w, y: v.y*h) }
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return image }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(p(rect.topLeft), forKey: "inputTopLeft")
        filter.setValue(p(rect.topRight), forKey: "inputTopRight")
        filter.setValue(p(rect.bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(p(rect.bottomRight), forKey: "inputBottomRight")
        guard let out = filter.outputImage, let outCG = ciContext.createCGImage(out, from: out.extent) else { return image }
        return UIImage(cgImage: outCG)
    }

    private func area(_ r: VNRectangleObservation) -> CGFloat {
        let pts = [r.topLeft,r.topRight,r.bottomRight,r.bottomLeft]
        var sum: CGFloat = 0
        for i in 0..<4 { let a=pts[i], b=pts[(i+1)%4]; sum += a.x*b.y - b.x*a.y }
        return abs(sum)/2
    }

    private func rotate(_ image: UIImage, degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180
        var newRect = CGRect(origin:.zero,size:image.size).applying(CGAffineTransform(rotationAngle:radians))
        newRect.origin = .zero
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: newRect.size, format: f).image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: newRect.width/2, y: newRect.height/2)
            c.rotate(by: radians)
            image.draw(in: CGRect(x:-image.size.width/2,y:-image.size.height/2,width:image.size.width,height:image.size.height))
        }
    }
}
