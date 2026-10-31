import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_sekolah_os/services/auth_service.dart';

AuthenticatedTeacher _t(String name) => AuthenticatedTeacher(id: 1, name: name);

void main() {
  group('nameParts splits the name from its degrees', () {
    test('degrees without a comma', () {
      final p = _t('Anggi Gusela S.Pd. M.Ag.').nameParts;
      expect((p.main, p.degrees), ('Anggi Gusela', 'S.Pd. M.Ag.'));
    });

    test('a comma before the degrees is not left on the name', () {
      final p = _t('Ahmad Fulan, S.Pd.').nameParts;
      expect((p.main, p.degrees), ('Ahmad Fulan', 'S.Pd.'));
    });

    test('a one-word name with degrees', () {
      final p = _t('Farhahd S.Si., M.Pd.').nameParts;
      expect((p.main, p.degrees), ('Farhahd', 'S.Si., M.Pd.'));
    });

    test('a leading title stays with the name', () {
      final p = _t('H. Ahmad Fulan S.Pd').nameParts;
      expect((p.main, p.degrees), ('H. Ahmad Fulan', 'S.Pd'));
    });

    test('no degrees, one word, or empty', () {
      expect(_t('Siti Aminah').nameParts.degrees, '');
      expect(_t('Siti Aminah').nameParts.main, 'Siti Aminah');
      expect(_t('Ali').nameParts.main, 'Ali');
      expect(_t('').nameParts.main, '');
    });
  });
}
