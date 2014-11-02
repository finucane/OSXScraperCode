//
//  MFDB.m
//  Geocoder
//
//  Created by finucane on 3/14/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

#import "MFDB.h"
#import "MFError.h"
#import "insist.h"

@implementation MFDB

/*
 create a database file if it doesn't exist, using the create string from format.
 
 path - full path to db file
 error - set on error
 format - printf style format for CREATE statement
 
 returns nil if error
*/

-(id)initWithPath:(NSString*)aPath error:(MFError*__autoreleasing*)error format:(NSString*)format, ...
{
  insist (aPath && error && format);
  
  if ((self = [self initWithPath:aPath]))
  {
    /*if the file already exists, we don't have to create it*/
    if ([[NSFileManager defaultManager] fileExistsAtPath:aPath])
      return self;
    
    /*create the db file*/
    const char*cPath = [path UTF8String];
    
    if (sqlite3_open (cPath, &connection) != SQLITE_OK)
    {
      *error = [MFError errorWithCode:MFErrorSql format:@"SQLite error %s", sqlite3_errmsg (connection)];
      return nil;
    }
    /*make query string from args*/
    va_list args;
    va_start(args, format);
    NSString*query = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    /*run the sql, it's a programmer error if it's not a create*/
    if (![self execError:error format:@"%@", query])
    {
      [self close];
      return nil;
    }
    [self close];
  }
  return self;
}
/*
 initialise a MDFB object. the database is left in the unopened state.
 aPath - fullpathname to database, which must already exist.
 
 returns : initialized MFDB object.
 */

-(id)initWithPath:(NSString*)aPath
{
  if ((self = [super init]))
  {
    insist (aPath && aPath.length);
    path = aPath;
    
    insist (!statement && !connection);
  }
  return self;
}

/*
 open database, if it's not already opened.
 error -- set if there is an error
 
 returns : false if there was an error
 */
-(BOOL)open:(MFError*__autoreleasing*)error
{
  insist (error);
  
  /*if database is open, this method is a no-op*/
  if (connection)
    return YES;
  
  const char*cPath = [path UTF8String];
  
  /*open db*/
  if (sqlite3_open (cPath, &connection) != SQLITE_OK)
  {
    *error = [MFError errorWithCode:MFErrorSql format:@"SQLite error %s", sqlite3_errmsg (connection)];
    return NO;
  }
  return YES;
}

/*
 close database, if it's not already closed. it is a programmer error if this is called
 on an open database with unfinalized statements.
 */

-(void)close
{
  /*if database is already closed, do nothing.*/
  if (!connection)
    return;
  
  /*free previous statement, if any*/
  if (statement)
    [self finalize];
  insist (!statement);
  
  /*close database. sqlite3_close will return SQLITE_BUSY if there are unfinalized statements,
   which is a programmer error*/
  
  int r = sqlite3_close (connection);
  insist (r == SQLITE_OK);
  connection = 0;
}

/*
 make sure we don't leak db resources, if the object is freed w/ the db still open ...
 this is not quite good since someone could be deallocing a db that's still got
 a non finalized statement, but we'll know this from an assertion.
 
 prolly this should be insist (![self opened]) instead, to find programmer errors
 */
-(void)dealloc
{
  [self close];
}

/*
 this method is so callers can assert on the the database being opened.
 
 returns : true if the database is open
 */
-(BOOL)isOpened
{
  return connection != 0;
}


/*
 execute a query.
 
 error - set if error
 format - printf style format string for query
 
 returns : false if there was an error.
 */

-(BOOL)execError:(NSError* __autoreleasing*)error format:(NSString*)format, ...
{
  insist (format && error);
  insist (connection);
  
  /*make query string from args*/
  va_list args;
  va_start(args, format);
  NSString*query = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);
  
  char*msg = 0;
  
  if (sqlite3_exec (connection, [query UTF8String], 0, 0, &msg) != SQLITE_OK)
  {
    *error = [MFError errorWithCode:MFErrorSql format:@"SQLite error %s", sqlite3_errmsg (connection)];
    sqlite3_free (msg);
    return NO;
  }
  return YES;
}

/*
 prepare a query. this should be matched with finalize to free resources. this is called
 with a variable length argument list so the query string can be made with printf style
 formatting. it is a programmer error to call this if the db is closed.
 
 error - set if there's an error
 format - printf style format string for query
 
 returns: false if there was an error
 */

-(BOOL) prepareError:(NSError* __autoreleasing*)error format:(NSString*)format, ...
{
  insist (error && format && connection);
  
  /*make query string from format and vargs*/
  va_list args;
  va_start(args, format);
  NSString*query = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);
  
  /*free previous statement, if any*/
  if (statement)
    [self finalize];
  insist (!statement);
  
  /*get temperary c string from obj-c string*/
  const char*cQuery = [query UTF8String];
  statement = 0;
  
  /*compile statement*/
  if (sqlite3_prepare_v2 (connection, cQuery, -1, &statement, NULL) != SQLITE_OK)
  {
    *error = [MFError errorWithCode:MFErrorSql format:@"SQLite error %s", sqlite3_errmsg (connection)];
    return NO;
  }
  
  insist (statement);
  return YES;
}

/*
 finalize statement. it's an error to call this if there's no current statement
 */
-(void)finalize
{
  insist (statement && connection);
  sqlite3_finalize (statement);
  statement = 0;
}

/*
 escape a string so it's a suitable value to be used in a sql statement.
 
 s - the string
 
 returns : escaped string
*/

+(NSString*)escape:(NSString*)s
{
  return [s stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
}

/*
 step to the next row of the statement results. for now don't worry about errors, any error is counted
 as the query results having run out of rows. it is a programmer error to call this if there's
 no active statement.
 
 returns : true if there was another row.
 */
-(BOOL)step
{
  insist (connection && statement);
  return sqlite3_step (statement) == SQLITE_ROW;
}

/*
 get a column as a string. it is a programmer error to call this on a column that's not text
 
 returns :  a string, or nil if the column was null
 */
-(NSString*)textOrNilAtColumn:(int)column
{
  insist (column >= 0);
  insist (sqlite3_column_type (statement, column) == SQLITE_TEXT || sqlite3_column_type (statement, column) == SQLITE_NULL);
  
  const char*cString = (const char*)sqlite3_column_text (statement, column);
  
  if (!cString)
    return nil;
  return [NSString stringWithUTF8String:cString];
}

/*
 get a column as a string. it is a programmer error to call this on a column that's not text
 
 returns : a string, if the column was null then the empty string
 */
-(NSString*)textAtColumn:(int)column
{
  insist (column >= 0);
  insist (sqlite3_column_type (statement, column) == SQLITE_TEXT || sqlite3_column_type (statement, column) == SQLITE_NULL);
  
  const char*cString = (const char*)sqlite3_column_text (statement, column);
  
  if (!cString)
    return @"";
  return [NSString stringWithUTF8String:cString];
}

/*
 get a column as an int
 
 returns : the column as an int (0 if the column is null)
 */
-(int) intAtColumn:(int)column
{
  insist (connection && statement);
  insist (column >= 0);
  insist (sqlite3_column_type (statement, column) == SQLITE_INTEGER || sqlite3_column_type (statement, column) == SQLITE_NULL);
  
  return sqlite3_column_int (statement, column);
}


@end
