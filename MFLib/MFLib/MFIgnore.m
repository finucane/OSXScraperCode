//
//  MFDoNotScrape.m
//  CourtCrawler
//
//  Created by finucane on 4/3/14.
//  Copyright (c) 2014  All rights reserved.
//

#import "MFIgnore.h"
#import <MFLib/MFError.h>
#import <MFLib/insist.h>

@implementation MFIgnore

/*
 remember means 'ignore' is turned on
*/
-(BOOL)reset:(int)which remember:(BOOL)remember error:(MFError*__autoreleasing*)error
{
  NSString*bundlePath = [[NSBundle mainBundle] bundlePath];
  NSString*appName = [[NSFileManager defaultManager] displayNameAtPath: bundlePath];

  NSError*other;
  
  NSFileManager*fileManager = [NSFileManager defaultManager];
  
  /*create application support folder if it's not there*/
  NSString*folder = [NSString stringWithFormat:@"~/Library/Application Support/%@/", appName];
  folder = [folder stringByExpandingTildeInPath];
  
  if ([fileManager fileExistsAtPath:folder] == NO)
  {
    if (![fileManager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:&other])
    {
      *error = [MFError errorWithCode:MFErrorFile error:other];
      return NO;
    }
  }
  
  /*make path for db file, for creating or removing, folder has / on end*/
  NSString*path = [NSString stringWithFormat:@"%@/%d.db", folder, which];
  path = [path stringByExpandingTildeInPath];
  
  /*if we are not remembering, get rid of any old doNotScrape db, and also any db file for this scrape. */
  if (!remember)
  {
    if (db)
    {
      [db close];
      db = nil;
    }
    if ([fileManager fileExistsAtPath:path] && ![fileManager removeItemAtPath:path error:&other])
    {
      *error = [MFError errorWithCode:MFErrorFile error:other];
      return NO;
    }
  }
  else
  {
    /*we are remembering. if the db file exists just open it, otherwise create it*/
    if ([fileManager fileExistsAtPath:path])
    {
      db = [[MFDB alloc] initWithPath:path];
      insist (db);
      if (![db open:error])
        return NO;
    }
    else
    {
      /*file doesn't exist, we need to create it*/
      db = [[MFDB alloc] initWithPath:path error:error format:@"create table ignore (tag text)"];
      insist (db);
      if (![db open:error])
        return NO;
    }
  }
  return YES;
}


-(BOOL)ignore:(NSString*)tag result:(BOOL*)result error:(MFError*__autoreleasing*)error
{
  insist (tag && result && error);
  
  *result = NO;
  
  /*if there's no db, scrape*/
  if (!db)
    return YES; //result is in *result
  
  if (![db prepareError:error format:@"SELECT * FROM 'ignore' WHERE tag='%@'", [MFDB escape:tag]])
    return NO;
  
  /*if the licenseNumber existed in the table, it means don't scrape*/\
  *result =  [db step];
  [db finalize];
  if (*result)
  {
    //  NSLog (@"not scraping %@", licenseNumber);
  }
  return YES;
}

-(BOOL)update:(NSString*)tag error:(MFError*__autoreleasing*)error
{
  /*if there's no db, do nothing*/
  if (!db)
    return YES;
  
  //NSLog (@"updateDoNotScrape %@", licenseNumber);
  
  /*add the license number to the table, meaning don't scrape it again*/
  return [db execError:error format:@"INSERT OR REPLACE INTO ignore(tag) VALUES ('%@')", [MFDB escape:tag]];
}

@end
