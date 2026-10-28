/// Quotes a column name, optionally qualified by a table or schema name.
///
/// A field name is always treated as an identifier, never as SQL syntax.
String sqlIdentifier(String identifier, {bool qualified = false}) {
  final parts = qualified ? identifier.split('.') : [identifier];
  if (parts.any((part) => part.isEmpty || part.contains('\u0000'))) {
    throw ArgumentError.value(
        identifier, 'identifier', 'Invalid SQL identifier');
  }
  return parts.map((part) => '`${part.replaceAll('`', '``')}`').join('.');
}

/// Quotes each name in an optional comma-separated ORDER BY field list.
String sqlOrderBy(String fields) => fields
    .split(',')
    .map((field) => sqlIdentifier(field.trim(), qualified: true))
    .join(', ');
