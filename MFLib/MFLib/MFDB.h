//
//  MFDB.h
//  Geocoder
//
//  Created by finucane on 3/14/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//


/*
 MDFB is a wrapper around sqlite, to make it easier to use.
 
 open and close are safe to be called even if the database is already opened or closed.
 this is to allow code that opens "if necessary", without having to worry about the actual
 state, which is tracked by the connection ivar being set or not.
 
 close should be called before the object is freed.
 
 
 */


#import <Foundation/Foundation.h>
#import "MFError.h"
#import <sqlite3.h>


@interface MFDB : NSObject
{
  @protected
  NSString*path;
  sqlite3*connection;
  sqlite3_stmt*statement;
}
-(id)initWithPath:(NSString*)path error:(MFError*__autoreleasing*)error format:(NSString*)format, ...;
-(id)initWithPath:(NSString*)path;
-(BOOL)open:(MFError*__autoreleasing*)error;
-(void)close;
-(BOOL)isOpened;
-(BOOL)execError:(NSError* __autoreleasing*)error format:(NSString*)format, ...;
-(BOOL)prepareError:(NSError* __autoreleasing*)error format:(NSString*)format, ...;
-(void)finalize;
-(BOOL)step;
+(NSString*)escape:(NSString*)s;
-(NSString*)textOrNilAtColumn:(int)column;
-(NSString*)textAtColumn:(int)column;
-(int)intAtColumn:(int)column;

@end
