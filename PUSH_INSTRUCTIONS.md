# 🚀 GitHub'a Push Talimatları

## ⚠️ Önemli: Repository Henüz Oluşturulmamış

Repository'yi oluşturmak için iki yöntem var:

## Yöntem 1: Cursor Source Control (ÖNERİLEN - Otomatik)

1. **Source Control** panelini açın:
   - `Ctrl+Shift+G` tuşlarına basın
   - VEYA sol menüden Source Control ikonuna tıklayın

2. **"Publish Branch"** butonuna tıklayın
   - Eğer görünmüyorsa, "..." menüsünden "Publish Branch" seçin

3. Repository bilgilerini girin:
   - **Repository name**: `pomodoro`
   - **Visibility**: `Public` seçin
   - **Description**: "A beautiful Pomodoro timer app with task management"

4. **Publish** butonuna tıklayın

Bu işlem otomatik olarak:
- ✅ GitHub'da repository oluşturacak
- ✅ Tüm commit'leri push edecek
- ✅ GitHub Actions'ı tetikleyecek

## Yöntem 2: GitHub Web (Manuel)

1. https://github.com/new adresine gidin

2. Repository bilgilerini doldurun:
   - **Repository name**: `pomodoro`
   - **Description**: "A beautiful Pomodoro timer app with task management"
   - **Public** seçin
   - **Initialize this repository with a README** seçmeyin (zaten var)
   - **Add .gitignore** seçmeyin (zaten var)
   - **Choose a license** seçmeyin (isteğe bağlı)

3. **Create repository** butonuna tıklayın

4. Terminal'de şu komutu çalıştırın:
   ```bash
   git push -u origin main
   ```

## ✅ Push Sonrası

Repository oluşturulup push edildikten sonra:

1. **GitHub Pages'i Aktif Edin:**
   - https://github.com/mefedursun/pomodoro → **Settings** → **Pages**
   - **Source**: **"GitHub Actions"** seçin
   - **Save**

2. **İlk Deploy:**
   - **Actions** sekmesine gidin
   - **"Deploy to GitHub Pages"** workflow'unu bulun
   - **"Run workflow"** → **"Run workflow"** butonuna tıklayın
   - 5-10 dakika bekleyin

3. **Live Demo:**
   - https://mefedursun.github.io/pomodoro/

## 📊 Hazır Commit'ler

Tüm dosyalar hazır ve commit edilmiş:

```
5c131c5 - Add setup completion guide
db136d8 - Clean up: Remove redundant files, update all references
eb4ff66 - Update README with live demo link and add quick start guide
2d3e70b - Initial commit: Pomodoro Timer App with web support
```

## 🎯 Hızlı Komutlar

```bash
# Repository durumunu kontrol et
git status

# Remote'u kontrol et
git remote -v

# Push et (repository oluşturulduktan sonra)
git push -u origin main
```

---

**💡 İpucu:** Cursor Source Control kullanmak en kolay yöntemdir. Otomatik olarak repository oluşturur ve push eder!

