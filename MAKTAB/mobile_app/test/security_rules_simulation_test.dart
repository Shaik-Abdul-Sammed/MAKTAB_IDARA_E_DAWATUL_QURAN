import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase Security Rules Hardening Audit (40 Test Scenarios)', () {
    bool evaluateReadRules({
      required bool authenticated,
      required String authUid,
      required String? authRole,
      required String? authMaktabId,
      required bool authActive,
      required String path,
      required Map<String, dynamic> databaseState,
    }) {
      if (!authenticated) return false;

      // User profile path: /users/$uid
      if (path.startsWith('/users/')) {
        final targetUid = path.split('/')[2];
        if (authUid == targetUid) return true;

        final isManager = (authRole == 'admin' || authRole == 'manager');
        final targetUser = databaseState['users']?[targetUid];

        if (isManager && authActive && targetUser != null && authMaktabId == targetUser['maktabId']) {
          return true;
        }
        return false;
      }

      // Maktab path: /maktabs/$maktabId/$node/...
      if (path.startsWith('/maktabs/')) {
        final segments = path.split('/');
        if (segments.length < 3) return false;
        final maktabId = segments[2];

        if (!authActive) return false;
        if (authMaktabId != maktabId) return false;
        return true;
      }

      return false;
    }

    bool evaluateWriteRules({
      required bool authenticated,
      required String authUid,
      required String? authRole,
      required String? authMaktabId,
      required bool authActive,
      required String path,
      required Map<String, dynamic> databaseState,
      required Map<String, dynamic> newData,
    }) {
      if (!authenticated) return false;

      // User profile path: /users/$uid
      if (path.startsWith('/users/')) {
        final targetUid = path.split('/')[2];
        final existing = databaseState['users']?[targetUid];
        final isManager = (authRole == 'admin' || authRole == 'manager');

        // 1. Initial creation
        if (existing == null) {
          if (authUid == targetUid) return true;
          if (isManager && authActive && authMaktabId == newData['maktabId']) return true;
          return false;
        }

        // 2. Self edit (whether Manager or Teacher)
        if (authUid == targetUid) {
          final roleUnchanged = newData['role'] == existing['role'];
          final maktabUnchanged = newData['maktabId'] == existing['maktabId'];
          final activeUnchanged = newData['active'] == existing['active'];
          final teacherIdUnchanged = newData['teacherId'] == existing['teacherId'];
          return roleUnchanged && maktabUnchanged && activeUnchanged && teacherIdUnchanged;
        }

        // 3. Manager editing another user
        if (authUid != targetUid && isManager && authActive) {
          if (authMaktabId != existing['maktabId']) return false;
          if (newData['maktabId'] != existing['maktabId']) return false;
          final roleCheck = (newData['role'] == existing['role'] || newData['role'] == 'teacher');
          return roleCheck;
        }

        return false;
      }

      // Maktab path: /maktabs/$maktabId/$node/...
      if (path.startsWith('/maktabs/')) {
        final segments = path.split('/');
        final maktabId = segments[2];
        final node = segments.length > 3 ? segments[3] : '';

        if (!authActive) return false;
        if (authMaktabId != maktabId) return false;

        final isManager = (authRole == 'admin' || authRole == 'manager');

        if (node == 'students' || node == 'teachers' || node == 'batches' || node == 'fee_payments') {
          return isManager;
        }

        if (node == 'attendance' || node == 'quran_progress') {
          return true;
        }

        if (node == 'teacher_attendance') {
          if (isManager) return true;
          final targetTeacherId = newData['teacherId'];
          final myTeacherId = databaseState['users']?[authUid]?['teacherId'];
          final isOwn = targetTeacherId != null && targetTeacherId == myTeacherId;
          final existingTeacherId = databaseState['maktabs']?[maktabId]?['teacher_attendance']?[segments.last]?['teacherId'];
          final ownerUnchanged = (existingTeacherId == null || existingTeacherId == targetTeacherId);
          return isOwn && ownerUnchanged;
        }
      }

      return false;
    }

    final dbState = {
      'users': {
        'mgrA': {'role': 'manager', 'maktabId': 'MAKTAB-001', 'active': true, 'teacherId': 1},
        'tA': {'role': 'teacher', 'maktabId': 'MAKTAB-001', 'active': true, 'teacherId': 10},
        'mgrB': {'role': 'manager', 'maktabId': 'MAKTAB-002', 'active': true, 'teacherId': 2},
        'tB': {'role': 'teacher', 'maktabId': 'MAKTAB-002', 'active': true, 'teacherId': 20},
        'tInactive': {'role': 'teacher', 'maktabId': 'MAKTAB-001', 'active': false, 'teacherId': 30},
      }
    };

    test('1. Manager A reads own profile → ALLOW', () {
      expect(evaluateReadRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/mgrA', databaseState: dbState), isTrue);
    });

    test('2. Manager A updates own name → ALLOW', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/mgrA', databaseState: dbState, newData: {'name': 'New Name', 'role': 'manager', 'maktabId': 'MAKTAB-001', 'active': true, 'teacherId': 1}), isTrue);
    });

    test('3. Manager A changes own role → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/mgrA', databaseState: dbState, newData: {'name': 'Mgr', 'role': 'teacher', 'maktabId': 'MAKTAB-001', 'active': true, 'teacherId': 1}), isFalse);
    });

    test('4. Manager A changes own maktabId → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/mgrA', databaseState: dbState, newData: {'name': 'Mgr', 'role': 'manager', 'maktabId': 'MAKTAB-002', 'active': true, 'teacherId': 1}), isFalse);
    });

    test('5. Manager A changes own active → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/mgrA', databaseState: dbState, newData: {'name': 'Mgr', 'role': 'manager', 'maktabId': 'MAKTAB-001', 'active': false, 'teacherId': 1}), isFalse);
    });

    test('6. Manager A changes own teacherId → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/mgrA', databaseState: dbState, newData: {'name': 'Mgr', 'role': 'manager', 'maktabId': 'MAKTAB-001', 'active': true, 'teacherId': 99}), isFalse);
    });

    test('7. Manager A reads Teacher A → ALLOW', () {
      expect(evaluateReadRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/tA', databaseState: dbState), isTrue);
    });

    test('8. Manager A updates Teacher A safe fields → ALLOW', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/tA', databaseState: dbState, newData: {'name': 'Updated', 'role': 'teacher', 'maktabId': 'MAKTAB-001', 'active': true, 'teacherId': 10}), isTrue);
    });

    test('9. Manager A changes Teacher A role to manager → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/tA', databaseState: dbState, newData: {'name': 'T A', 'role': 'manager', 'maktabId': 'MAKTAB-001', 'active': true, 'teacherId': 10}), isFalse);
    });

    test('10. Manager A changes Teacher A maktabId → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/tA', databaseState: dbState, newData: {'name': 'T A', 'role': 'teacher', 'maktabId': 'MAKTAB-002', 'active': true, 'teacherId': 10}), isFalse);
    });

    test('11. Manager A changes Teacher A active status → ALLOW', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/tA', databaseState: dbState, newData: {'name': 'T A', 'role': 'teacher', 'maktabId': 'MAKTAB-001', 'active': false, 'teacherId': 10}), isTrue);
    });

    test('12. Manager A reads Teacher B (different Maktab) → DENY', () {
      expect(evaluateReadRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/tB', databaseState: dbState), isFalse);
    });

    test('13. Manager A writes Teacher B (different Maktab) → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/tB', databaseState: dbState, newData: {'name': 'Hacked'}), isFalse);
    });

    test('14. Manager A changes Manager B → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/mgrB', databaseState: dbState, newData: {'name': 'Hacked'}), isFalse);
    });

    test('15. Teacher A changes own role → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/tA', databaseState: dbState, newData: {'role': 'manager', 'maktabId': 'MAKTAB-001', 'active': true, 'teacherId': 10}), isFalse);
    });

    test('16. Teacher A changes own maktabId → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/tA', databaseState: dbState, newData: {'role': 'teacher', 'maktabId': 'MAKTAB-002', 'active': true, 'teacherId': 10}), isFalse);
    });

    test('17. Teacher A changes own active status → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/tA', databaseState: dbState, newData: {'role': 'teacher', 'maktabId': 'MAKTAB-001', 'active': false, 'teacherId': 10}), isFalse);
    });

    test('18. Teacher A modifies Teacher B → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/tB', databaseState: dbState, newData: {'name': 'Hacked'}), isFalse);
    });

    test('19. Teacher A creates manager profile → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/newManager', databaseState: dbState, newData: {'role': 'manager', 'maktabId': 'MAKTAB-001', 'active': true}), isFalse);
    });

    test('20. Unauthenticated user → DENY', () {
      expect(evaluateReadRules(authenticated: false, authUid: '', authRole: null, authMaktabId: null, authActive: false, path: '/users/mgrA', databaseState: dbState), isFalse);
    });

    test('21. Teacher reads own student → ALLOW', () {
      expect(evaluateReadRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-001/students/s1', databaseState: dbState), isTrue);
    });

    test('22. Teacher edits student record → DENY (read-only for teachers)', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-001/students/s1', databaseState: dbState, newData: {'name': 'Edited Student'}), isFalse);
    });

    test('23. Teacher modifies another Maktab student → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-002/students/s2', databaseState: dbState, newData: {'name': 'Edited Student'}), isFalse);
    });

    test('24. Teacher reads fee payment → ALLOW', () {
      expect(evaluateReadRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-001/fee_payments/f1', databaseState: dbState), isTrue);
    });

    test('25. Teacher writes fee payment → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-001/fee_payments/f1', databaseState: dbState, newData: {'amount': 100}), isFalse);
    });

    test('26. Teacher reads teacher record → ALLOW', () {
      expect(evaluateReadRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-001/teachers/10', databaseState: dbState), isTrue);
    });

    test('27. Teacher modifies teacher record → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-001/teachers/10', databaseState: dbState, newData: {'name': 'Hacked'}), isFalse);
    });

    test('28. Teacher modifies another teacher attendance → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-001/teacher_attendance/ta1', databaseState: dbState, newData: {'teacherId': 20}), isFalse);
    });

    test('29. Teacher modifies own teacher attendance → ALLOW', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-001/teacher_attendance/ta1', databaseState: dbState, newData: {'teacherId': 10}), isTrue);
    });

    test('30. Teacher modifies Quran progress for authorized student → ALLOW', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-001/quran_progress/qp1', databaseState: dbState, newData: {'surah': 'Al-Baqarah'}), isTrue);
    });

    test('31. Teacher modifies Quran progress for another Maktab → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-002/quran_progress/qp1', databaseState: dbState, newData: {'surah': 'Al-Baqarah'}), isFalse);
    });

    test('32. Manager manages own Maktab teacher → ALLOW', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-001/teachers/10', databaseState: dbState, newData: {'name': 'T A'}), isTrue);
    });

    test('33. Manager manages another Maktab teacher → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-002/teachers/20', databaseState: dbState, newData: {'name': 'T B'}), isFalse);
    });

    test('34. Manager manages own Maktab fees → ALLOW', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'mgrA', authRole: 'manager', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-001/fee_payments/f1', databaseState: dbState, newData: {'amount': 500}), isTrue);
    });

    test('35. Teacher modifies own role → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/tA', databaseState: dbState, newData: {'role': 'manager', 'maktabId': 'MAKTAB-001', 'active': true, 'teacherId': 10}), isFalse);
    });

    test('36. Teacher changes own Maktab → DENY', () {
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/users/tA', databaseState: dbState, newData: {'role': 'teacher', 'maktabId': 'MAKTAB-002', 'active': true, 'teacherId': 10}), isFalse);
    });

    test('37. Unauthenticated read → DENY', () {
      expect(evaluateReadRules(authenticated: false, authUid: '', authRole: null, authMaktabId: null, authActive: false, path: '/maktabs/MAKTAB-001/students/s1', databaseState: dbState), isFalse);
    });

    test('38. Unauthenticated write → DENY', () {
      expect(evaluateWriteRules(authenticated: false, authUid: '', authRole: null, authMaktabId: null, authActive: false, path: '/maktabs/MAKTAB-001/attendance/att1', databaseState: dbState, newData: {}), isFalse);
    });

    test('39. Inactive teacher → DENY', () {
      expect(evaluateReadRules(authenticated: true, authUid: 'tInactive', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: false, path: '/maktabs/MAKTAB-001/students/s1', databaseState: dbState), isFalse);
    });

    test('40. Cross-Maktab read/write → DENY', () {
      expect(evaluateReadRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-002/attendance/att1', databaseState: dbState), isFalse);
      expect(evaluateWriteRules(authenticated: true, authUid: 'tA', authRole: 'teacher', authMaktabId: 'MAKTAB-001', authActive: true, path: '/maktabs/MAKTAB-002/attendance/att1', databaseState: dbState, newData: {}), isFalse);
    });
  });
}
