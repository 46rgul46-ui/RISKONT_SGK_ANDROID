import Foundation
import UIKit
import CoreText
import CoreGraphics

final class PDFGenerator {
    private static let codabar: [Character:String] = [
        "0":"bsbsbSB","1":"bsbsBSb","2":"bsbSbsB","3":"BSbsbsb","4":"bsBsbSb",
        "5":"BsbsbSb","6":"bSbsbsB","7":"bSbsBsb","8":"bSBsbsb","9":"BsbSbsb"
    ]

    static func generate(_ input: FormData) throws -> URL {
        var d = input
        guard !Validators.normalize(d.ad).isEmpty, !Validators.normalize(d.soyad).isEmpty, !Validators.normalize(d.iseGiris).isEmpty else {
            throw AppValidationError.message("Ad, soyad ve işe giriş tarihi zorunludur.")
        }
        d.ykn = try Validators.validateYKN(d.ykn)
        if !Validators.normalize(d.dogumTarihi).isEmpty { d.dogumTarihi = try Validators.parseDateStrict(d.dogumTarihi, label:"Doğum tarihi", rejectFuture:true) }
        d.iseGiris = try Validators.parseDateStrict(d.iseGiris, label:"İşe giriş tarihi", rejectFuture:false)
        d.referansKodu = try Validators.validateReference(d.referansKodu)

        guard let templateURL = Bundle.main.url(forResource:"sgk_referans_form", withExtension:"pdf"),
              let provider = CGDataProvider(url: templateURL as CFURL),
              let pdf = CGPDFDocument(provider), let page = pdf.page(at:1) else {
            throw AppValidationError.message("SGK referans PDF şablonu bulunamadı veya bozuk.")
        }
        var mediaBox = page.getBoxRect(.mediaBox)
        let safe = Validators.safeFilePart("\(d.ad)_\(d.soyad)_\(d.ykn)")
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let out = uniqueURL(in: dir, base: "\(safe)_SGK_ISE_GIRIS_ON_DOLDURMA.pdf")
        guard let consumer = CGDataConsumer(url: out as CFURL), let ctx = CGContext(consumer:consumer, mediaBox:&mediaBox, nil) else {
            throw AppValidationError.message("PDF çıktı dosyası oluşturulamadı.")
        }
        ctx.beginPDFPage(nil)
        ctx.drawPDFPage(page)
        drawForm(ctx, pageHeight: mediaBox.height, d: d)
        ctx.endPDFPage(); ctx.closePDF()
        return out
    }

    private static func uniqueURL(in dir: URL, base: String) -> URL {
        let fm=FileManager.default
        let ext=(base as NSString).pathExtension, stem=(base as NSString).deletingPathExtension
        var u=dir.appendingPathComponent(base); var i=2
        while fm.fileExists(atPath:u.path) { u=dir.appendingPathComponent("\(stem)_\(i).\(ext)"); i += 1 }
        return u
    }

    private static func drawForm(_ ctx: CGContext, pageHeight: CGFloat, d: FormData) {
        ctx.saveGState(); defer { ctx.restoreGState() }
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(x:399.45,y:pageHeight-30.5,width:464.20-399.45,height:30.5-3.5))
        ctx.setFillColor(UIColor.black.cgColor)
        drawBarcode(ctx,pageHeight:pageHeight,code:d.referansKodu)
        putCenter(ctx,cx:431.80,baselineTop:36.0,text:d.referansKodu,size:7,pageH:pageHeight)
        let df=DateFormatter();df.locale=Locale(identifier:"en_US_POSIX");df.dateFormat="dd.MM.yyyy HH:mm:ss"
        putCenter(ctx,cx:431.80,baselineTop:46.0,text:df.string(from:Date()),size:7,pageH:pageHeight)

        let ykn=Validators.digits(d.ykn); let xs:[CGFloat]=[55,79,103,127,151,175,199,223,247,271,294]
        for (i,ch) in ykn.prefix(11).enumerated() { put(ctx,x:xs[i],baselineTop:84.65,text:String(ch),maxWidth:12,size:7,minSize:4.5,pageH:pageHeight) }
        put(ctx,x:205,baselineTop:115.65,text:d.ad,maxWidth:105,size:7,minSize:4.5,pageH:pageHeight)
        put(ctx,x:205,baselineTop:130.65,text:d.soyad,maxWidth:105,size:7,minSize:4.5,pageH:pageHeight)
        put(ctx,x:205,baselineTop:160.65,text:d.baba,maxWidth:105,size:7,minSize:4.5,pageH:pageHeight)
        put(ctx,x:205,baselineTop:175.65,text:d.ana,maxWidth:105,size:7,minSize:4.5,pageH:pageHeight)
        put(ctx,x:205,baselineTop:190.65,text:d.dogumYeri,maxWidth:105,size:7,minSize:4.5,pageH:pageHeight)
        if !d.dogumTarihi.isEmpty { let a=d.dogumTarihi.split(separator:"."); if a.count==3 { put(ctx,x:205,baselineTop:205.65,text:"\(a[2])-\(a[1])-\(a[0])",maxWidth:105,size:7,minSize:4.5,pageH:pageHeight) } }
        put(ctx,x:206,baselineTop:219.65,text:d.uyruk,maxWidth:104,size:7,minSize:4.5,pageH:pageHeight)
        put(ctx,x:204,baselineTop:234.65,text:d.ogrenim,maxWidth:106,size:7,minSize:4.5,pageH:pageHeight)
        put(ctx,x:297,baselineTop:384.65,text:"4601202514732",maxWidth:105,size:7,minSize:4.5,pageH:pageHeight)
        put(ctx,x:207,baselineTop:447.58,text:d.iseGiris,maxWidth:120,size:7,minSize:4.5,pageH:pageHeight)
        put(ctx,x:207,baselineTop:463.08,text:"Beden İşçisi ( Genel)-96.22.02",maxWidth:195,size:7,minSize:4.5,pageH:pageHeight)
        put(ctx,x:478,baselineTop:486,text:"02",maxWidth:28,size:7,minSize:4.5,pageH:pageHeight)
        put(ctx,x:137,baselineTop:556.08,text:"12",maxWidth:55,size:7,minSize:4.5,pageH:pageHeight)
        let fixed:[(CGFloat,CGFloat,String,CGFloat)] = [
            (207,600.65,"2",18),(234,600.65,"4341",30),(272,600.65,"01",18),(297,600.65,"01",18),(322,600.65,"1070532",72),
            (404,600.65,"046",34),(447,600.65,"11",23),(478,600.65,"74",23),(509,600.65,"000",38),(404,620.58,"0",130),
            (72,656.65,"UĞUR ÖZTÜRK",235),(317,659.01,"SÜMER MAH. İLAHİYAT CAD. ÖZEN ÇELİK İNŞAAT",230),(317,667.15,"KAHRAMANMARAŞ DULKADİROĞLU No:28 / A",230)
        ]
        for f in fixed { put(ctx,x:f.0,baselineTop:f.1,text:f.2,maxWidth:f.3,size:7,minSize:4.5,pageH:pageHeight) }
    }

    private static func drawBarcode(_ ctx: CGContext, pageHeight: CGFloat, code: String) {
        var x:CGFloat=399.95; let yTop:CGFloat=4, h:CGFloat=26, narrow:CGFloat=0.595327, wideRatio:CGFloat=3, gap:CGFloat=0.595327
        for (ci,ch) in code.enumerated() {
            guard let p=codabar[ch] else { continue }
            for e in p {
                let bar=(e=="b" || e=="B"), wide=(e=="B" || e=="S"), ww=narrow*(wide ? wideRatio:1)
                if bar { ctx.fill(CGRect(x:x,y:pageHeight-yTop-h,width:ww,height:h)) }
                x += ww
            }
            if ci != code.count-1 { x += gap }
        }
    }

    private static func font(_ size: CGFloat) -> CTFont { CTFontCreateUIFontForLanguage(.system, size, nil)! }
    private static func line(_ text:String,_ size:CGFloat) -> CTLine {
        let a:[NSAttributedString.Key:Any]=[kCTFontAttributeName as NSAttributedString.Key:font(size)]
        return CTLineCreateWithAttributedString(NSAttributedString(string:text,attributes:a))
    }
    private static func width(_ text:String,_ size:CGFloat) -> CGFloat { CGFloat(CTLineGetTypographicBounds(line(text,size),nil,nil,nil)) }
    private static func drawText(_ ctx:CGContext,x:CGFloat,baselineTop:CGFloat,text:String,size:CGFloat,scaleX:CGFloat,pageH:CGFloat) {
        ctx.saveGState(); defer{ctx.restoreGState()}
        ctx.textMatrix = .identity
        ctx.translateBy(x:x,y:pageH-baselineTop)
        ctx.scaleBy(x:scaleX,y:1)
        ctx.textPosition = .zero
        CTLineDraw(line(text,size),ctx)
    }
    private static func put(_ ctx:CGContext,x:CGFloat,baselineTop:CGFloat,text:String,maxWidth:CGFloat,size:CGFloat,minSize:CGFloat,pageH:CGFloat) {
        let s=Validators.normalize(text); if s.isEmpty{return}
        var fs=size, w=width(s,fs)
        while fs > minSize && w > maxWidth { fs=max(minSize,fs-0.08); w=width(s,fs) }
        let scale = (w > maxWidth && w > 0) ? max(0.55,maxWidth/w) : 1
        drawText(ctx,x:x,baselineTop:baselineTop,text:s,size:fs,scaleX:scale,pageH:pageH)
    }
    private static func putCenter(_ ctx:CGContext,cx:CGFloat,baselineTop:CGFloat,text:String,size:CGFloat,pageH:CGFloat) {
        let s=Validators.normalize(text); if s.isEmpty{return}; let w=width(s,size)
        drawText(ctx,x:cx-w/2,baselineTop:baselineTop,text:s,size:size,scaleX:1,pageH:pageH)
    }
}
