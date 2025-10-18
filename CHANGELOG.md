# 6.2.0
- added a new execute method the returns the no. of rows updated.

# 6.1.0
- Upgraded to dcli 8.1

# 6.0.0
- Fixed
Eliminated a serious server-side prepared statement leak caused by unfreed PreparedStmt handles.
All database queries now correctly deallocate prepared statements.

All users SHOULD upgraded to 6.0.0

- Changed
Db.query() is now internal; external callers should use:
You should use the higher level 'select', 'delete' etc.
If you need to run a raw query then use:
    Db.withResults(...) 

- Added
New test (statement_leak_test.dart) to verify withResults correctly cleans up.


# 5.0.1
- upgraded to dcli 7.x

# 5.0.0
- updated the readme to highlight that we have a code generator.
- Upgraded to dcli 6.x and upped the base dart version to 3.5 Fixed resulting lints fro upgrading to lint_hard 5.x change the default db name (used by testing) to smo - we probably shouldn't have a default db name but rather throw.

# 4.1.0-beta.1
- upgrade dependencies.

# 4.1.0-alpha.1
- upgraded to dcli 4.0.0-alpha.1

# 4.0.0
- updated min sdk to 3.0
- 
# 3.1.0-beta.3
- Fix: row.tryCustom was calling tryInt rather than tryString to get an initial value causing radix exceptions when the custom value was not an int (the normal case).

# 3.1.0-beta.2
- Added a log message to indicate a successful connection to mysql after a prior failure.
- removed unused method.

# 3.1.0-beta.1
- converted to using mysql_client as it supports the latest mysql auth. Current beta version has an issue as the mysql_client fails if you try to connect over ssl, set useSSL to false to bypass this issue for the moment.

# 3.0.5
fixed a transitive import on dcli_core.

# 3.0.4
- upgraded to dcli 1.17.3

# 3.0.2
- changed the log levels to reduce sperious logging.

# 3.0.1
- Made the field keys caseinsenstive as mysql column names are case insensitive.
- spelling.

# 3.0.0-beta.3
- BREAKING: renamed querySingle to queryColumn. Created new querySingle which returns a single row of columns.
- BREAKING: changed the tableName named argument on DaoTenant to a positional argument for consistency with the Dao class.
- Breaking: changed asCustom to return nnbd type and added tryCustom to return null type.
- BREAKING: changed all tryAs... methods to try... for consistency.
- BREAKING: for consistency I've changed withTransation's 'action' argument to be a named argument. This delivers better consistency with other method signatures.
- BREAKING: for consistency I've changed withTransation's 'action' argument to be a named argument. This delivers better consistency with other method signatures.
- Added new method Dao.queryWithAdaptor which allows you to run adhoc queries and placing the result into a non-entity based class.
- added, offset, limit, orderBy and sortDirection to Dao.getListByField
- Exposed the build_dao as an executable which can create dao and model classes from a schema.
- Added a function tquery to provide easy access to executing queries outside the context of a dao.
- Added a fromArgs ctor to the DbPool.
- Moved the schema management functions into their own folder.
- also made withNoConstraints take a named arg for action.
- Added check to withTenant if -1 is passed as the tenant id. We now throw.

# 3.0.0-beta.2
- Added a set of methods to help manage your mysql schema.
- The withTransaction method takes an optional DbPool which if passed will be used rather than calling DbPool.
- added an addWhere arg to the tenant appenders so you can control whether it needs to add an where clause or not.
- Added a Dao.removeAll method.
- corrected the doco for inTenantScope
- Added method to create a pool without a database so that you can use it to create/drop schemas. 
- Removed a hardcoded default db name. 
- Added a method to retrieve the dbname the pool was created with.

# 3.0.0-beta.1
- changed the default transaction nesting to 'nested' as this is the most common operation.
- cleanedup the tenantbypass logic.
- withTenantBypass now returns a value.
- added check in 'update' for a valid id and added a helpful message if the id is notSet.
- added standard method for attaching tenant id.
- colour coded log messages based on sql action

# 2.0.1
- A number of multi-tenant fixes.

# 2.0.0

# 1.4.0-beta.2
- reworked tenant implementation to simplify the UI. updated the readme to include doco on tenants.
- additional unit tests.
- changed tenantColumnName to tenantFieldName for consistency.

# 1.4.0-beta.1
- Added support for mulit-tenancy.
- Improved the exception handling and logging when a mysqlexception is throw. We now (mostly) throw a coherent stack trace.
- added the date_time class and created exensions for same. 
- Breaking: moved to the 2.16 beta so we could generated co-herent stack traces when mysql exceptions are thrown.
- Breaking: renamed the fieldAsXX methods to asXX. Introduced tryAsXX method that can return a null replacing any of the fieldAsXXNulllable methods.
- Added methods tryByXX  which returns a null type.
- Added querySingle so you can get a single row with a single value returned. handy for sum type queries.
- Added the date_time package so we can support Date and Time files (as apposed to DateTime). Also added Money2 so we can store/retrieve monetary amounts.
- Added addtional field conversions.
- Added a query count to make it easier to associated log statements for the same query
- Added a 'debugName' to withTransaction.
- Fixed a bug where the excess connection future wasn't been shutdown which stop applications for exiting. We now use  a timer and cancel it when DbPool.close() is called.
- Added an extension class to the Date class to add in parsing.
- added getSingle and fieldAsStringNullable
- added test to confirm that the same db can't be allocated when transations overlap.
- fixed bug where a window existed during allocate where the same connection could be allocated twice.
- add isolate to log statement.

# 1.3.2
- modified withTransaction to allow the return of a nullable value

# 1.3.1
- the connection retry logic now gives up immediately on access denied as that is never going to recover.
- added missing async on transaction action.
- added missing awaits when running a transation causing connections to be released whilst the transaction was still running.
- Fixed a bug where the transaction wasn't releasing a connection on normal completion.
- We now throw if you attempt to use the DbPool after it has been closed.
- Added logic to detect connections that haven't been released or are in a transaction when the pool is closed.
- upgraded to latest version of di_zone2 package. 
- added logic to cleanup and close the pool for unit testing. Enabled the logger output during testing.

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
