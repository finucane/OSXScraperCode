//
//  MFTempDB.h
//  Geocoder
//
//  Created by Finucane on 3/16/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//


/*
  MFTempDB is a subclass of MFDB that only permits SELECT statements that
  dump to a temp table.
 
  the query specified in prepareError:format has to start with the SELECT keyword
  but should not end with any "AS TABLE" clauses.

*/
 
#import <Cocoa/Cocoa.h>
#import "MFDB.h"
 
@interface MFTempDB : MFDB
{
  @public
  int count;
}
-(BOOL)prepareError:(NSError* __autoreleasing*)error format:(NSString*)format, ...;
-(int)countError:(NSError* __autoreleasing*)error;
@end
