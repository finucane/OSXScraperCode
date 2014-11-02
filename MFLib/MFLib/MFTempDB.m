//
//  MFTempDB.m
//  Geocoder
//
//  Created by Finucane on 3/16/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

#import "MFTempDB.h"
#import "insist.h"

#define TEMP_TABLE @"temp_table"
#define TEMP_DATABASE @"temp"

@implementation MFTempDB

/*
 prepare a select statement that returns its data into a temp table in the the temp database.
 it is a programmer error to call this with any query that's not a select.
 
 error - set if there was an error
 format - printf style format string and args for a select query
 
 returns : false if there was an error.
 */

-(BOOL) prepareError:(NSError* __autoreleasing*)error format:(NSString*)format, ...
{
  /*make query string from format and vargs*/
  va_list args;
  va_start(args, format);
  NSString*query = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);
  
  query = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  insist ([query hasPrefix:@"SELECT"] || [query hasPrefix:@"select"]);
  
  /*get rid of any old temp table*/
  if (![self execError:error format:@"DROP TABLE IF EXISTS %@.%@",TEMP_DATABASE, TEMP_TABLE])
    return NO;
  
  /*
    forget previous row count. we're going to cache this value so we don't have to keep executing a query
    to get it.
  */
  count = -1;
  
  /*prepend create temp table as stuff to select query*/
  query = [NSString stringWithFormat:@"CREATE TEMP TABLE %@.%@ AS %@", TEMP_DATABASE, TEMP_TABLE, query];
  
  /*execute the create*/
  if (![self execError:error format:query])
    return NO;
 
  /*make a query to step through the resulting table*/
  query = [NSString stringWithFormat:@"SELECT * from %@.%@",TEMP_DATABASE, TEMP_TABLE];
  
  /*let base class do the prepare*/
  return [super prepareError:error format:query];
}

/*
 return number of rows returned by select statement. it is a programmer
 error to call this if there wasn't a previous prepareError:format call, or if the
 db isn't opened
 
 returns - number of rows in temp database table, -1 if error.
*/
-(int)countError:(NSError* __autoreleasing*)error
{
  insist (error);
  insist ([self isOpened]);
  
  /*return cached value if any*/
  if (count >= 0)
    return count;
  
  /*select count(*) doesn't work for some reason, do do this the hard (or slow) way*/
  NSString*query = [NSString stringWithFormat:@"SELECT * from %@.%@", TEMP_DATABASE, TEMP_TABLE];
  
  /*get temperary c string from obj-c string*/
  const char*cQuery = [query UTF8String];
  
  sqlite3_stmt*countStatement = 0;
  
  /*compile statement*/
  if (sqlite3_prepare_v2 (connection, cQuery, -1, &countStatement, NULL) != SQLITE_OK)
  {
    *error = [MFError errorWithCode:MFErrorSql format:@"SQLite error %s", sqlite3_errmsg (connection)];
    return -1;
  }

  /*count the rows*/
  for (count = 0; sqlite3_step (countStatement) == SQLITE_ROW; count++);

  sqlite3_finalize (countStatement);
  return count;
}

@end
