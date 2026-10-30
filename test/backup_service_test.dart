import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_2/features/backup/services/backup_service.dart';

void main() {
  group('BackupService.temCabecalhoSqlite', () {
    test('devolve true para os 16 bytes do cabeçalho SQLite seguidos de 0', () {
      final bytes = 'SQLite format 3'.codeUnits;
      expect(BackupService.temCabecalhoSqlite([...bytes, 0]), isTrue);
    });

    test('devolve false para bytes diferentes', () {
      final bytes = 'SQLite format 3'.codeUnits;
      final diferente = List<int>.from(bytes)..last = bytes.last ^ 1;
      expect(BackupService.temCabecalhoSqlite(diferente), isFalse);
    });

    test('devolve false para lista com menos de 16 bytes', () {
      expect(BackupService.temCabecalhoSqlite([1, 2, 3]), isFalse);
      expect(BackupService.temCabecalhoSqlite([]), isFalse);
    });
  });

  group('BackupService.carimbo', () {
    test('gera carimbo no formato esperado', () {
      expect(
        BackupService.carimbo(DateTime(2026, 10, 9, 7, 5, 3)),
        '20261009_070503',
      );
    });
  });
}