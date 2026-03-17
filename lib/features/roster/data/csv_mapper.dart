// Smart column-mapping and validation utilities for CSV player import.

enum SquadSyncField {
  firstName,
  lastName,
  email,
  phone,
  position,
  jerseyNumber,
  dateOfBirth,
  ignore;

  String get displayName {
    switch (this) {
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
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.position,
    this.jerseyNumber,
    this.dateOfBirth,
  });

  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? position;
  final int? jerseyNumber;
  final String? dateOfBirth;

  String get fullName => [firstName, lastName]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' ');
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
    required this.skippedCount,
    required this.skippedRows,
  });

  final int totalRows;
  final int successCount;
  final int linkedCount;
  final int invitedCount;
  final int skippedCount;
  final List<SkippedRow> skippedRows;
}

abstract final class CsvMapper {
  static final _emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');

  /// Maps a CSV column header to a [SquadSyncField] using case-insensitive
  /// fuzzy matching. Returns [SquadSyncField.ignore] when no match is found.
  static SquadSyncField matchColumn(String header) {
    final h = header.trim().toLowerCase();

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

    if (firstNames.contains(h)) return SquadSyncField.firstName;
    if (lastNames.contains(h)) return SquadSyncField.lastName;
    if (emails.contains(h)) return SquadSyncField.email;
    if (phones.contains(h)) return SquadSyncField.phone;
    if (positions.contains(h)) return SquadSyncField.position;
    if (jerseys.contains(h)) return SquadSyncField.jerseyNumber;
    if (dobs.contains(h)) return SquadSyncField.dateOfBirth;
    return SquadSyncField.ignore;
  }

  /// Extracts field values from [row] using [mappings] and validates the result.
  /// Returns null when the email is missing or invalid.
  static PlayerImportRow? validateAndTransformRow(
    Map<String, dynamic> row,
    List<ColumnMapping> mappings,
  ) {
    String? email;
    String? firstName;
    String? lastName;
    String? phone;
    String? position;
    int? jerseyNumber;
    String? dateOfBirth;

    for (final mapping in mappings) {
      if (mapping.mappedField == SquadSyncField.ignore) continue;
      final value = row[mapping.originalHeader]?.toString().trim();
      if (value == null || value.isEmpty) continue;

      switch (mapping.mappedField) {
        case SquadSyncField.email:
          email = value;
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
        case SquadSyncField.ignore:
          break;
      }
    }

    if (email == null || email.isEmpty) return null;
    if (!_emailRegex.hasMatch(email)) return null;

    return PlayerImportRow(
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      position: position,
      jerseyNumber: jerseyNumber,
      dateOfBirth: dateOfBirth,
    );
  }
}
