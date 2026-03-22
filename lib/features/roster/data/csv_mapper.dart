// Smart column-mapping and validation utilities for CSV player import.

import 'dart:math';

enum SquadSyncField {
  fullName,
  firstName,
  lastName,
  email,
  phone,
  position,
  jerseyNumber,
  dateOfBirth,
  division,
  team,
  ignore;

  String get displayName {
    switch (this) {
      case SquadSyncField.fullName:
        return 'Full name';
      case SquadSyncField.firstName:
        return 'First name';
      case SquadSyncField.lastName:
        return 'Last name';
      case SquadSyncField.email:
        return 'Email';
      case SquadSyncField.phone:
        return 'Phone';
      case SquadSyncField.position:
        return 'Position';
      case SquadSyncField.jerseyNumber:
        return 'Jersey number';
      case SquadSyncField.dateOfBirth:
        return 'Date of birth';
      case SquadSyncField.division:
        return 'Division';
      case SquadSyncField.team:
        return 'Team';
      case SquadSyncField.ignore:
        return 'Ignore';
    }
  }
}

class ColumnMapping {
  const ColumnMapping({
    required this.originalHeader,
    required this.mappedField,
  });

  final String originalHeader;
  final SquadSyncField mappedField;

  ColumnMapping copyWith({SquadSyncField? mappedField}) {
    return ColumnMapping(
      originalHeader: originalHeader,
      mappedField: mappedField ?? this.mappedField,
    );
  }
}

class PlayerImportRow {
  const PlayerImportRow({
    this.email,
    this.firstName,
    this.lastName,
    this.fullNameOverride,
    this.phone,
    this.position,
    this.jerseyNumber,
    this.dateOfBirth,
    this.division,
    this.team,
    this.joinCode,
  });

  final String? email;
  final String? firstName;
  final String? lastName;
  final String? fullNameOverride;
  final String? phone;
  final String? position;
  final int? jerseyNumber;
  final String? dateOfBirth;
  final String? division;
  final String? team;

  /// Set after import for players created without email.
  final String? joinCode;

  String get fullName {
    if (fullNameOverride != null && fullNameOverride!.isNotEmpty) {
      return fullNameOverride!;
    }
    return [firstName, lastName]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' ');
  }

  PlayerImportRow copyWith({String? joinCode}) {
    return PlayerImportRow(
      email: email,
      firstName: firstName,
      lastName: lastName,
      fullNameOverride: fullNameOverride,
      phone: phone,
      position: position,
      jerseyNumber: jerseyNumber,
      dateOfBirth: dateOfBirth,
      division: division,
      team: team,
      joinCode: joinCode ?? this.joinCode,
    );
  }
}

class SkippedRow {
  const SkippedRow({
    required this.rowNumber,
    this.email,
    required this.reason,
  });

  final int rowNumber;
  final String? email;
  final String reason;
}

class ImportResult {
  const ImportResult({
    required this.totalRows,
    required this.successCount,
    required this.linkedCount,
    required this.invitedCount,
    required this.pendingCount,
    required this.skippedCount,
    required this.skippedRows,
    required this.playersWithCodes,
  });

  final int totalRows;
  final int successCount;
  final int linkedCount;
  final int invitedCount;

  /// Players added as pending_players (no email — join code generated).
  final int pendingCount;
  final int skippedCount;
  final List<SkippedRow> skippedRows;

  /// Name + join code pairs for players added without email.
  final List<({String name, String joinCode})> playersWithCodes;
}

/// Generates an 8-character alphanumeric join code.
/// Uses unambiguous characters (no 0/O/1/I).
String generatePlayerJoinCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
}

abstract final class CsvMapper {
  static final _emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');

  /// Maps a CSV column header to a [SquadSyncField] using case-insensitive
  /// fuzzy matching. Returns [SquadSyncField.ignore] when no match is found.
  static SquadSyncField matchColumn(String header) {
    final h = header.trim().toLowerCase();

    const fullNames = {
      'name', 'full name', 'fullname', 'full_name', 'player name', 'player',
    };
    const firstNames = {
      'first name', 'firstname', 'first_name',
      'given name', 'givenname', 'fname', 'forename',
    };
    const lastNames = {
      'last name', 'lastname', 'last_name',
      'surname', 'family name', 'familyname', 'lname',
    };
    const emails = {
      'email', 'email address', 'emailaddress', 'e-mail', 'e_mail',
    };
    const phones = {
      'phone', 'mobile', 'mob', 'cell', 'contact',
      'phone number', 'phonenumber', 'contact number',
    };
    const positions = {
      'position', 'pos', 'role', 'playing position',
    };
    const jerseys = {
      'jersey', 'number', 'shirt', 'squad number',
      'jersey number', 'shirt number', 'no', '#',
    };
    const dobs = {
      'dob', 'date of birth', 'dateofbirth', 'birthday',
      'birth date', 'birthdate', 'born',
    };
    const divisions = {
      'division', 'div', 'grade', 'league',
    };
    const teams = {
      'team', 'team name', 'squad',
    };

    if (fullNames.contains(h)) return SquadSyncField.fullName;
    if (firstNames.contains(h)) return SquadSyncField.firstName;
    if (lastNames.contains(h)) return SquadSyncField.lastName;
    if (emails.contains(h)) return SquadSyncField.email;
    if (phones.contains(h)) return SquadSyncField.phone;
    if (positions.contains(h)) return SquadSyncField.position;
    if (jerseys.contains(h)) return SquadSyncField.jerseyNumber;
    if (dobs.contains(h)) return SquadSyncField.dateOfBirth;
    if (divisions.contains(h)) return SquadSyncField.division;
    if (teams.contains(h)) return SquadSyncField.team;
    return SquadSyncField.ignore;
  }

  /// Extracts field values from [row] using [mappings] and validates the result.
  /// Returns null when the row has no usable name.
  /// Email is now optional — rows without email get a join code generated.
  static PlayerImportRow? validateAndTransformRow(
    Map<String, dynamic> row,
    List<ColumnMapping> mappings,
  ) {
    String? email;
    String? firstName;
    String? lastName;
    String? fullNameOverride;
    String? phone;
    String? position;
    int? jerseyNumber;
    String? dateOfBirth;
    String? division;
    String? team;

    for (final mapping in mappings) {
      if (mapping.mappedField == SquadSyncField.ignore) continue;
      final value = row[mapping.originalHeader]?.toString().trim();
      if (value == null || value.isEmpty) continue;

      switch (mapping.mappedField) {
        case SquadSyncField.fullName:
          fullNameOverride = value;
        case SquadSyncField.email:
          // Only accept valid emails
          if (_emailRegex.hasMatch(value)) email = value;
        case SquadSyncField.firstName:
          firstName = value;
        case SquadSyncField.lastName:
          lastName = value;
        case SquadSyncField.phone:
          phone = value;
        case SquadSyncField.position:
          position = value;
        case SquadSyncField.jerseyNumber:
          jerseyNumber = int.tryParse(value);
        case SquadSyncField.dateOfBirth:
          dateOfBirth = value;
        case SquadSyncField.division:
          division = value;
        case SquadSyncField.team:
          team = value;
        case SquadSyncField.ignore:
          break;
      }
    }

    // Require at least a name
    final computedName = fullNameOverride?.isNotEmpty == true
        ? fullNameOverride!
        : [firstName, lastName]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' ');
    if (computedName.isEmpty) return null;

    return PlayerImportRow(
      email: email,
      firstName: firstName,
      lastName: lastName,
      fullNameOverride: fullNameOverride,
      phone: phone,
      position: position,
      jerseyNumber: jerseyNumber,
      dateOfBirth: dateOfBirth,
      division: division,
      team: team,
    );
  }
}
