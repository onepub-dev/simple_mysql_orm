# 1.3.0
- Added in logic to test if a connection is valid and if not replace it with a new connection. This allows us to wait for the db on startup and survive restarts of the db.
- Fixed the connection pool which I had blindly copied from another project. It has been 'sharing' out the same connection. Now a connection can only be obtained by one caller. It must be released before it can be re-obtained. Also implemented a background thread to release excess connections at the rate of one per minute.
- Improved the error message when a user tries to access a transation when no transation is in scope.

# 1.2.0
- Added Dao.getAll method to return all rows in a table.

# 1.1.1
- moved to di_zone2 until scope is released.
- Added examples and readme.
- renamed deleteByEntity to remove.

# 1.1.0
- Added rollback method to allow a transaction to manually be rolled back.
- Added support for json encoding maps when saving a field to db.
- Fixed the formatting of date fields when inserting/updating.
- improved logging. We know use the logging package.
- Added additional unit testing for all the forms of a Transaction.

## 1.0.0

- Initial version.
