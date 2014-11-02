//
//  MFDBList.m
//  Geocoder
//
//  Created by Finucane on 3/20/14.
//  Copyright (c) 2014  All rights reserved.
//

#import "MFDBList.h"
#import <MFLib/insist.h>

@implementation MFDBList


/*
 initialize a DBList.
 
 path - full pathname to database
 
 returns : initialized DBList.
 */

-(id)initWithPath:(NSString*)path
{
  insist (path && path.length);
  
  if ((self = [super init]))
  {
    tempDB = [[MFTempDB alloc] initWithPath:path];
    insist (tempDB);
  }
  return self;
}


/*
 return the number of items resulting from the last select*Begin call
 */

-(int)countError:(NSError* __autoreleasing*)error
{
  insist (error && tempDB);
  return [tempDB countError:error];
}

/*
 return an array of the next "count" objects fetched from select*Begin. if there are no more objects
 return an empty array.
 
 returns : an array of not more than "count" objects, perhaps less if there were no more rows.
*/
-(NSArray*)getMore:(int)count;
{
  insist (count >= 0);
  
  NSMutableArray*mutable = [[NSMutableArray alloc] init];
  insist (mutable);
  
  /*collect all the rows into objects, using derived class's implementation of parseRow*/
  while (count-- && [tempDB step])
  {
    [mutable addObject:[self parseRow]];
  }
  
  /*return list of drs*/
  return mutable;
}

/*
 get next object in list, if any.
 
 returns : an object, or nil of there are none left
 */
-(id)getOneMore
{
  NSArray*doctors = [self getMore:1];
  insist (doctors);
  return doctors.count ? doctors [0] : nil;
}

-(void)end
{
  [tempDB finalize];
  [tempDB close];
}

-(id)parseRow
{
  insist (0);
  return nil;
}

@end
