# SekolahOS — Aplikasi Mobile Guru

Aplikasi Flutter untuk guru Pesantren Persis 50 Lembang. Backend: admin-siakad
(`/api/v1/teacher/*`, login memakai akun yang sama dengan panel admin).
Rencana & cakupan: `docs/TEACHER_MOBILE_APP_PLAN.md` di repo admin-siakad.

Repo ini **publik**: jangan commit kredensial, URL server internal, atau data nyata.

## Menjalankan

```
flutter pub get
flutter run --dart-define=API_BASE_URL=https://<host-staging>/api
```

Tanpa `API_BASE_URL`, default `http://10.0.2.2:8000/api` (emulator Android → `php artisan serve` di host).

## Status

Fase 1: login/logout/restore sesi dan kerangka navigasi (Beranda, Jadwal, Kotak masuk, Akun).
Beranda, Jadwal, Nilai (kelas, siswa, input nilai), Kotak masuk (Pengumuman, Agenda, Notifikasi) dan Akun (termasuk Rekap kehadiran) serta Presensi siswa per sesi (JP berurutan digabung) sudah terhubung ke `/home`, `/schedule`, `/classes`, `/agenda`, `/announcements`, `/notifications`, `/attendance/me`, `/lessons`, `/schedules/{id}/attendance`.

## Cek

```
flutter analyze
flutter test
```
