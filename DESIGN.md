# DESIGN.md — MATRIX v2 (Android)

Status: DISETUJUI pemilik sistem 2026-10-18, lalu DIREVISI 2026-10-18 atas arahan pemilik:
"UI masih kaku dan kotak-kotak; buat modern seperti aplikasi m-banking/finance, ada bagian
lingkaran di header, lebih animatif namun tetap ringan." Revisi itu ditranskripsikan di §11.

## 1. Identitas

- **Produk:** aplikasi harian pegawai UPTD Labkesda Sumenep untuk absen wajah, melihat jadwal,
  mengajukan izin/cuti, memantau kinerja & jaspel, dan mendaftarkan pasien dari foto KTP.
- **Pemakai:** ATLM, staf administrasi, petugas kebersihan, sopir. Usia dan kefasihan HP beragam.
  Dibuka singkat, sering sambil berjalan masuk kantor atau di akhir shift malam.
- **Pekerjaan utama tiap layar:** satu keputusan, satu tombol utama. Absen adalah aksi paling
  sering; semua layar lain mengalah padanya.
- **Kepribadian:** tenang, teliti, bisa dipercaya. Angka akurat sampai detik, bahasa lugas,
  tidak menggurui dan tidak bercanda. Terasa seperti alat kerja yang rapi, bukan aplikasi promo.

## 2. Warna

Diambil dari logo MATRIX (salib hijau, sapuan merah). Maksimal 2 warna inti + 1 aksen.

| Token | Terang | Gelap | Dipakai untuk |
|---|---|---|---|
| `primary` | #047857 (emerald 700) | #34D399 | tombol utama, teks/ikon status "hadir/tepat waktu" |
| `primaryBright` | #059669 (emerald v1) | #10B981 | isian grafis saja (progres jam kerja, pita shift), tidak untuk teks |
| `primaryContainer` | #E7F6EF | #0B3B2C | latar kartu shift aktif, chip terpilih |
| `alert` (aksen) | #CB213D (merah logo, palet §12) | #F6A6B3 | HANYA masalah: telat, alpa, lupa absen pulang, error, potongan |
| `pending` | #AC4D0E (jingga palet §12) | #F8AA76 | HANYA status "menunggu" (izin pending, jaspel draft) |
| `ink` | #1C2421 | #E8EEEB | teks utama |
| `inkMuted` | #5B6661 | #A3B0AA | teks sekunder (kontras AA terhadap `surface`) |
| `surface` | #FFFFFF | #141A17 | kartu |
| `canvas` | #F4F6F4 | #0D1210 | latar layar (abu kehijauan tipis, bukan putih polos) |
| `line` | #DDE3DF | #26302B | garis pemisah, border input |

Aturan:
- Kontras dicek: putih di atas #059669 hanya 3.77:1 (gagal AA untuk teks biasa), karena itu
  tombol & teks memakai #047857 (5.48:1). Rose logo #E11D48 juga gagal di atas latar muda
  (4.06:1 di atas `alertContainer`), jadi teks alert memakai #BE123C (5.43:1). `inkMuted` di atas
  `canvas` 5.5:1, amber di atas `pendingContainer` 4.61:1, mode gelap `inkMuted` 7.86:1.
- **Tidak ada gradien hijau→merah** (v1 memakainya di mana-mana). Hijau dan merah punya arti
  berlawanan (baik vs masalah); dicampur jadi tidak berarti apa-apa.
- Rose muncul hanya bila ada masalah nyata. Layar tanpa masalah tidak menampilkan merah sama sekali,
  sehingga merah langsung terbaca sebagai "perlu perhatian".
- Tema mengikuti sistem HP (terang/gelap) dengan pilihan manual di Akun. Shift malam adalah
  alasan nyata mendukung mode gelap.

## 3. Tipografi

- **Plus Jakarta Sans** (Google Fonts, dibundel offline). Alasan: dirancang untuk identitas
  Jakarta/Indonesia, terbaca baik di layar kecil, dan punya angka tabular (`tnum`) sehingga timer
  jam kerja tidak "goyang" saat detik berganti. Menggantikan Poppins yang angkanya proporsional.
- Skala: 32/600 (angka fokus, mis. timer), 22/600 (judul layar), 17/600 (judul kartu),
  15/400 (isi), 13/500 (label), 12/400 (keterangan). Angka selalu `tnum`.
- Tidak ada huruf kapital semua dengan spasi lebar sebagai label dekoratif.

## 4. Bentuk, ruang, elevasi

- Radius: 20 kartu, 28 sudut hero & bottom sheet, 14 input & tombol, lingkaran penuh untuk tombol
  Absen, aksi cepat, ikon status, dan avatar.
- Spasi berbasis 4: 4, 8, 12, 16, 24, 32. Gutter layar 16. Jarak antar-kelompok 24, dalam kelompok 12.
- Bayangan lembut untuk kartu (lihat §11), bayangan lebih tegas hanya untuk tombol Absen tengah.
- Tidak ada glassmorphism, glow, pola grid latar, atau ilustrasi stok.

## 5. Elemen ciri khas (bukan dekorasi)

**Pita shift.** Satu bilah horizontal yang menggambarkan hari kerja: jendela absen masuk,
jam kerja, jendela absen pulang, dan penanda "sekarang". Isinya data nyata dari jadwal.
- Beranda: versi besar, penanda bergerak sesuai jam, bagian yang sudah dijalani terisi hijau.
- Riwayat harian (Kinerja): versi mini per tanggal, menunjukkan masuk/pulang aktual vs jadwal,
  telat/pulang cepat ditandai rose di ujung yang bersangkutan.
- Jadwal: tabel shift tidak menyimpan warna, dan menambah warna per shift melanggar batas palet.
  Kelompok shift dibedakan dengan ikon + nama: pagi (matahari), siang (senja), malam (bulan),
  libur, izin.

## 6. Ikon

Material Symbols Rounded (bawaan Flutter, tidak menambah paket). Dipilih per relevansi:
wajah untuk absen wajah, kalender untuk jadwal, dokumen untuk izin, kartu identitas untuk scan KTP.
Tidak ada ikon "AI/sparkle", tidak ada emoji di teks UI (v1 memakai emoji di jenis izin; dihapus).

## 7. Gerak (dial MOTION 2)

Gerak hanya untuk menjelaskan perubahan keadaan:
- Absen berhasil: lingkaran tombol berubah jadi centang (300 ms) + getaran haptik pendek + suara TTS
  yang sudah ada. Ini momen paling penting; satu-satunya animasi yang "dirayakan".
- Pindah layar: shared-axis horizontal antar-tab, fade-through untuk detail (paket `animations`,
  sudah ada di v1). 220 ms, ease-out.
- Angka hasil muat (jam kerja bulan ini) naik dari nilai lama ke baru sekali, 400 ms.
- Penanda "sekarang" pada pita shift dan timer jam kerja bergerak karena memang waktu nyata.
- Tidak ada animasi berulang tanpa pemicu (tidak ada pulse/float/shimmer berulang).
  Memuat ditandai kerangka statis + teks "Memuat jadwal…".
- Menghormati setelan "kurangi animasi" Android (`MediaQuery.disableAnimations`).

## 8. Dial

Lihat §11 (revisi pemilik): ENERGY 3 · RHYTHM 2 · MOTION 3.

## 9. Bahasa

Indonesia, kalimat pendek, kata kerja di tombol ("Absen masuk", "Kirim pengajuan", "Simpan pasien").
Pesan error menyebut sebab dan langkah berikutnya. Nominal rupiah hanya tampil untuk jaspel yang
sudah dipublikasikan admin (aturan SiLAKES 2026-10-18).

## 10. Aksesibilitas

- Target sentuh minimal 48 dp. Kontras teks AA (4.5:1), elemen grafis 3:1.
- Teks tetap utuh sampai skala font 130%.
- Label TalkBack untuk tombol ikon, timer, dan pita shift ("Shift pagi, 07.30 sampai 14.30, sekarang 09.12").
- Status tidak hanya dibedakan warna: selalu ada teks atau ikon (mis. "Telat 4 mnt").

## 11. Revisi pemilik: gaya finance modern (menggantikan bagian yang bertentangan di atas)

- **Header hero** di layar utama (Beranda, Kinerja, Jadwal, Akun, layar masuk): blok hijau brand
  dengan sudut bawah membulat 28, berisi informasi utama layar dalam teks putih.
  - Gradien satu warna (emerald 700 -> 800) hanya di hero. Alasan: memisahkan lapisan "ringkasan
    saya" dari isi di bawahnya; bukan gradien hijau->merah, jadi tidak mencampur arti status.
  - **Lingkaran**: 2-3 lingkaran putih transparan (maks. 7%) di sudut hero, sebagian keluar bidang.
    Alasan: permintaan langsung pemilik sebagai motif identitas (gaya m-banking). Catatan antislop:
    lingkaran dekoratif biasanya dicurigai sebagai "orb" (R-01); dipertahankan karena diminta
    pemilik dan dibatasi hanya di hero.
- **Kartu menumpuk**: kartu fokus (shift hari ini, jaspel) menumpuk 24-32 dp ke atas hero.
  Kartu putih radius 20, tanpa garis, bayangan lembut. Alasan elevasi: kartu itu benar-benar berada
  di atas hero; kartu lain di kanvas memakai bayangan yang sama tapi lebih tipis.
- **Cincin progres** (lingkaran): jam kerja bulan ini ditampilkan sebagai cincin yang terisi
  di hero Beranda & Kinerja, seperti saldo di aplikasi bank. Melengkapi pita shift.
- **Tombol Absen bundar** di tengah navigasi bawah (seperti tombol QRIS di m-banking): aksi
  paling sering, selalu satu ketukan dari layar mana pun.
- **Aksi cepat** berbentuk ikon dalam lingkaran berwarna muda + label (Absen, Izin, Pasien KTP,
  Jaspel).
- **Ikon status dalam lingkaran** pada daftar & metrik menggantikan kotak bergaris.
- Dial baru: **ENERGY 3 · RHYTHM 2 · MOTION 3**.
  - Gerak tetap ringan: hanya opacity/transform/implicit animation, tanpa paket animasi berat,
    tanpa loop tanpa pemicu.
  - Masuk layar bertahap (stagger 60 ms, sekali), cincin terisi dari 0, angka naik, kartu
    mengecil 3% saat ditekan, hero menyusut halus saat digulir.
  - Semua mati bila "kurangi animasi" aktif.

## 12. Palet MATRIX (revisi pemilik 2026-10-18)

Permintaan pemilik: warna tidak hanya hijau & putih; semua warna (termasuk merah muda, ungu,
dan lainnya) diturunkan dari palet MATRIX dengan komposisi proporsional dan lembut.

- **Cara diturunkan:** dari hijau brand (#047857) dan merah logo. Setiap warna dihitung ulang
  supaya LUMINANS-nya setara (bukan sekadar lightness HSL): teks/ikon 5,5:1 terhadap putih
  (sama dengan hijau brand) dan 4,87:1 terhadap latar lembutnya. Hasilnya tidak ada warna yang
  terasa lebih berat; semuanya satu keluarga.
- **Komposisi:** kanvas netral dominan, hijau brand utama (hero, tombol, progres), warna
  pendukung hanya sebagai aksen kecil (lingkaran ikon, sel kalender, latar chip).
- **Kategori, bukan status.** Status tetap tiga: hijau baik, merah masalah, jingga menunggu.

| Nama | Teks/ikon (terang) | Latar (terang) | Teks (gelap) | Latar (gelap) | Dipakai untuk |
|---|---|---|---|---|---|
| Hijau MATRIX | #047857 | #E7F6EF | #34D399 | #0B3B2C | utama, hadir, absen |
| Emas | #8D6007 | #FDF0D6 | #F4AF26 | #372A10 | shift pagi, poin, jaspel, cuti |
| Langit | #136EA7 | #E4F4FE | #72C4F8 | #162E3E | shift siang, pasien KTP, sakit |
| Nila | #4F5CD3 | #EFF0FC | #B1B8F1 | #25294E | shift malam, suara |
| Ungu | #8947CA | #F5EFFC | #CEAFEE | #362447 | izin/cuti di jadwal, izin pribadi |
| Merah muda | #BC2C80 | #FCEDF6 | #F0A5D1 | #441F35 | libur ("tanggal merah" dilunakkan) |
| Merah logo | #CB213D | #FDEDF0 | #F6A6B3 | #4A1D25 | status masalah saja |
| Jingga | #AC4D0E | #FEEEE4 | #F8AA76 | #402615 | status menunggu saja |
| Abu batu | #596B7F | #EEF1F5 | #ACBED2 | #282C31 | netral, tanpa jadwal |

Catatan antislop: batas palet R-29 (2-3 inti + 1 aksen) dilampaui atas permintaan eksplisit
pemilik. Diterima karena tiap warna terikat satu kategori data yang konsisten, sama
luminansnya, dan shift selalu disertai ikon + huruf (P/S/M/L/I) sehingga tidak bergantung
pada warna saja.
