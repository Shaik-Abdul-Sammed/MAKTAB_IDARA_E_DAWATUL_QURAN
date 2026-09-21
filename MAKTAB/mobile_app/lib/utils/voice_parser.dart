import '../models/student.dart';

class ParsedVoiceAttendanceResult {
  final Map<int, String> studentStatuses;
  final List<String> matchedNames;
  final List<String> unmatchedTokens;
  final String originalText;

  ParsedVoiceAttendanceResult({
    required this.studentStatuses,
    required this.matchedNames,
    required this.unmatchedTokens,
    required this.originalText,
  });
}

class VoiceParser {
  /// Parses natural language spoken attendance input into structured student statuses
  static ParsedVoiceAttendanceResult parseAttendanceVoiceInput(
    String text,
    List<Student> batchStudents,
  ) {
    final Map<int, String> statuses = {};
    final List<String> matchedNames = [];
    final List<String> unmatchedTokens = [];

    if (text.trim().isEmpty || batchStudents.isEmpty) {
      return ParsedVoiceAttendanceResult(
        studentStatuses: statuses,
        matchedNames: matchedNames,
        unmatchedTokens: unmatchedTokens,
        originalText: text,
      );
    }

    final cleanText = text.toLowerCase().trim();

    // Check Bulk Commands
    if (cleanText.contains('all present') || cleanText.contains('sab present') || cleanText.contains('everyone present') || cleanText.contains('all haazir')) {
      for (var s in batchStudents) {
        if (s.id != null) {
          statuses[s.id!] = 'Present';
          matchedNames.add(s.name);
        }
      }
      return ParsedVoiceAttendanceResult(
        studentStatuses: statuses,
        matchedNames: matchedNames,
        unmatchedTokens: unmatchedTokens,
        originalText: text,
      );
    }

    if (cleanText.contains('all absent') || cleanText.contains('sab absent') || cleanText.contains('everyone absent')) {
      for (var s in batchStudents) {
        if (s.id != null) {
          statuses[s.id!] = 'Absent';
          matchedNames.add(s.name);
        }
      }
      return ParsedVoiceAttendanceResult(
        studentStatuses: statuses,
        matchedNames: matchedNames,
        unmatchedTokens: unmatchedTokens,
        originalText: text,
      );
    }

    // Segment input by commas, periods, ANDs, or newlines
    final segments = cleanText
        .replaceAll(RegExp(r'[\.\;\n]'), ',')
        .replaceAll(' and ', ',')
        .replaceAll(' aur ', ',')
        .split(',');

    for (var rawSegment in segments) {
      final segment = rawSegment.trim();
      if (segment.isEmpty) continue;

      // Extract status keyword
      String? statusFound;

      if (_containsWord(segment, ['absent', 'gair haazir', 'ghair hazir', 'gairhazir', 'chutti', 'nahi aaya', 'bimar'])) {
        statusFound = 'Absent';
      } else if (_containsWord(segment, ['late', 'deri', 'der', 'late aaya'])) {
        statusFound = 'Late';
      } else if (_containsWord(segment, ['leave', 'rukhsat', 'ruksat', 'chutti par'])) {
        statusFound = 'Leave';
      } else if (_containsWord(segment, ['present', 'haazir', 'hazir', 'ayyah', 'aaya', 'aaye'])) {
        statusFound = 'Present';
      }

      // Default status if student name mentioned alone without status word
      statusFound ??= 'Present';

      // Match against batch students
      bool matched = false;
      for (var student in batchStudents) {
        if (student.id == null) continue;

        if (_isNameMatch(student.name, segment)) {
          statuses[student.id!] = statusFound;
          matchedNames.add('${student.name} -> $statusFound');
          matched = true;
        }
      }

      if (!matched && segment.length > 2) {
        unmatchedTokens.add(segment);
      }
    }

    return ParsedVoiceAttendanceResult(
      studentStatuses: statuses,
      matchedNames: matchedNames,
      unmatchedTokens: unmatchedTokens,
      originalText: text,
    );
  }

  static bool _containsWord(String target, List<String> words) {
    for (var w in words) {
      if (target.contains(w)) return true;
    }
    return false;
  }

  static const Set<String> _honorifics = {'mr', 'mrs', 'shaik', 'syed'};

  static int _levenshtein(String a, String b) {
    final s1 = a.toLowerCase();
    final s2 = b.toLowerCase();
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((min, val) => val < min ? val : min);
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[s2.length];
  }

  static double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final dist = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1 - (dist / maxLen);
  }

  static bool _isNameMatch(String fullName, String segment) {
    final cleanName = fullName.toLowerCase().trim();
    final cleanSegment = segment.toLowerCase().trim();

    // Direct substring match
    if (cleanSegment.contains(cleanName)) return true;

    final nameTokens = cleanName.split(RegExp(r'\s+'));
    final segmentTokens = cleanSegment.split(RegExp(r'\s+'));

    // Fuzzy matching: accept any token pair where _similarity(target, token) >= 0.75
    for (final nameToken in nameTokens) {
      if (nameToken.length < 3 || _honorifics.contains(nameToken)) continue;

      for (final segToken in segmentTokens) {
        if (segToken.length < 3) continue;
        if (_similarity(nameToken, segToken) >= 0.75) {
          return true;
        }
      }
    }

    // Direct token containment fallback
    for (final token in nameTokens) {
      if (token.length >= 3 && !_honorifics.contains(token)) {
        if (cleanSegment.contains(token)) return true;
      }
    }

    // Fallback match for first/last name
    if (nameTokens.isNotEmpty && nameTokens.last.length >= 3 && !_honorifics.contains(nameTokens.last)) {
      if (cleanSegment.contains(nameTokens.last)) return true;
    }

    return false;
  }

  /// Parses spoken voice input into matching checklist question completion statuses
  static Set<int> parseChecklistVoiceInput(String text, List<dynamic> questions) {
    final Set<int> completedIds = {};
    if (text.trim().isEmpty) return completedIds;

    final cleanText = text.toLowerCase().trim();

    // Check bulk completion
    if (cleanText.contains('all done') || cleanText.contains('all complete') || cleanText.contains('sab ho gaya')) {
      for (var q in questions) {
        if (q.id != null) completedIds.add(q.id!);
      }
      return completedIds;
    }

    for (var q in questions) {
      final qText = (q.text as String).toLowerCase();
      final qTokens = qText.split(RegExp(r'\s+')).where((t) => t.length > 3).toList();

      bool match = false;
      if (cleanText.contains(qText)) {
        match = true;
      } else {
        for (var t in qTokens) {
          if (cleanText.contains(t)) {
            match = true;
            break;
          }
        }
      }

      if (match && q.id != null) {
        completedIds.add(q.id!);
      }
    }
    return completedIds;
  }
}
