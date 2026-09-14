import SwiftUI
import UIKit

struct ContentView: View {
    private let education = ["Okur yazar değil","Okur yazar","İlkokul","Ortaokul","Lise","Ön Lisans","Lisans","Yüksek Lisans","Doktora"]
    @State private var data = FormData()
    @State private var selectedImage: UIImage?
    @State private var showPicker = false
    @State private var busy = false
    @State private var status = ""
    @State private var error = false
    @State private var shareURL: URL?
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:14) {
                    if !status.isEmpty { Text(status).frame(maxWidth:.infinity,alignment:.leading).padding().background(error ? Color.red.opacity(0.10) : Color.green.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius:8)) }
                    section("1. Kimlik Fotoğrafını Seç ve Oku") {
                        Button("KİMLİK FOTOĞRAFINI SEÇ") { showPicker=true }.buttonStyle(MainButton())
                        Button(busy ? "OKUNUYOR…" : "KİMLİĞİ OKU") { runOCR() }.buttonStyle(MainButton()).disabled(selectedImage == nil || busy)
                        Text("Kimlik bilgileri yalnızca telefondaki yerel Apple Vision OCR ile okunur. Seçilen kimlik fotoğrafı uygulama klasörüne kalıcı olarak kaydedilmez.").font(.footnote).foregroundStyle(.secondary)
                    }
                    section("2. Kimlikten Gelen / Değişken Bilgiler") {
                        field("Yabancı Kimlik No",$data.ykn,.numberPad)
                        field("Adı",$data.ad)
                        field("Soyadı",$data.soyad)
                        field("Baba Adı",$data.baba)
                        field("Ana Adı",$data.ana)
                        field("Doğum Yeri",$data.dogumYeri)
                        field("Doğum Tarihi (GG.AA.YYYY)",$data.dogumTarihi,.numbersAndPunctuation)
                        field("Uyruğu / Ülke",$data.uyruk)
                        VStack(alignment:.leading,spacing:6){Text("Öğrenim Durumu").font(.headline);Picker("Öğrenim Durumu",selection:$data.ogrenim){ForEach(education,id:\.self){Text($0)}}.pickerStyle(.menu)}
                        field("İşe Giriş Tarihi (GG.AA.YYYY)",$data.iseGiris,.numbersAndPunctuation)
                        field("Referans Kodu",$data.referansKodu,.numberPad)
                    }
                    section("3. PDF'de Sabit Kullanılacak Bilgiler") {
                        Text("Firma: UĞUR ÖZTÜRK\nAdres: SÜMER MAH. İLAHİYAT CAD. ÖZEN ÇELİK İNŞAAT KAHRAMANMARAŞ DULKADİROĞLU No:28 / A\nVergi No: 0    Meslek: Beden İşçisi ( Genel)-96.22.02\nBelge Mahiyeti: TEKRAR    SGK İşyeri Sicil No: 4601202514732\n6356 Görev Kodu: 02    ÇSGB İş Kolu: 12").font(.footnote).frame(maxWidth:.infinity,alignment:.leading).padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius:8))
                    }
                    section("") {
                        Button("PDF OLUŞTUR VE PAYLAŞ") { generatePDF() }.buttonStyle(MainButton()).disabled(busy)
                        Text("PDF uygulamanın Belgeler alanına kaydedilir. Aynı kişi için mevcut dosyanın üzerine yazılmaz; _2, _3 şeklinde yeni dosya oluşturulur. Paylaş menüsünden Dosyalar'a kaydedebilir, AirDrop veya WhatsApp ile gönderebilirsiniz.").font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("GEÇİCİ KORUMA KİMLİĞİ → SGK İŞE GİRİŞ | SÜRÜM 6.6")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented:$showPicker){ImagePicker{selectedImage=$0;status="Kimlik fotoğrafı seçildi. KİMLİĞİ OKU düğmesine basın.";error=false}}
        .sheet(isPresented:$showShare){if let u=shareURL{ShareSheet(items:[u])}}
    }

    @ViewBuilder private func section<Content:View>(_ title:String,@ViewBuilder content:()->Content)->some View {
        VStack(alignment:.leading,spacing:12){if !title.isEmpty{Text(title).font(.title3.bold())};content()}.padding(16).background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius:12))
    }
    private func field(_ label:String,_ value:Binding<String>,_ keyboard:UIKeyboardType = .default)->some View {
        VStack(alignment:.leading,spacing:5){Text(label).font(.headline);TextField(label,text:value).textFieldStyle(.roundedBorder).keyboardType(keyboard).textInputAutocapitalization(.characters).autocorrectionDisabled()}
    }

    private func runOCR() {
        guard let image=selectedImage else{return};busy=true;status="Kimlik yerel OCR ile okunuyor…";error=false
        Task {
            do {
                let r=try await OCRService().read(image)
                await MainActor.run {
                    if !r.ykn.isEmpty{data.ykn=r.ykn};if !r.ad.isEmpty{data.ad=r.ad};if !r.soyad.isEmpty{data.soyad=r.soyad};if !r.baba.isEmpty{data.baba=r.baba};if !r.ana.isEmpty{data.ana=r.ana};if !r.dogumYeri.isEmpty{data.dogumYeri=r.dogumYeri};if !r.dogumTarihi.isEmpty{data.dogumTarihi=r.dogumTarihi};if !r.uyruk.isEmpty{data.uyruk=r.uyruk}
                    busy=false;status="Kimlik okundu. Alanları kontrol edip eksikleri tamamlayın.";error=false
                }
            } catch { await MainActor.run{busy=false;status="OCR HATASI: \(error.localizedDescription)";self.error=true} }
        }
    }
    private func generatePDF(){
        do { let u=try PDFGenerator.generate(data);shareURL=u;showShare=true;status="PDF oluşturuldu: \(u.lastPathComponent)";error=false }
        catch { status=error.localizedDescription;self.error=true }
    }
}

struct MainButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(.headline).foregroundStyle(.white).frame(maxWidth:.infinity).padding(.vertical,14).background(Color(red:24/255,green:59/255,blue:91/255).opacity(configuration.isPressed ? 0.8:1)).clipShape(RoundedRectangle(cornerRadius:6)) }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items:[Any]
    func makeUIViewController(context:Context)->UIActivityViewController{UIActivityViewController(activityItems:items,applicationActivities:nil)}
    func updateUIViewController(_ uiViewController:UIActivityViewController,context:Context){}
}
