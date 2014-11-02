//
//  MFZipCodeDB.h
//  Geocoder
//
//  Created by finucane on 3/17/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

#import "MFDB.h"

@interface MFZipCodeDB : MFDB
{
  @private
  NSDictionary*states;
  NSArray*stateNames;
  NSArray*stateAbbreviations;
}

-(id)initWithPath:(NSString*)path;
-(NSString*)countyForZip:(NSString*)zip error:(MFError* __autoreleasing*)error;
-(NSString*)stateForZip:(NSString*)zip error:(MFError* __autoreleasing*)error;
-(BOOL)equalState:(NSString*)s1 state:(NSString*)s2;
-(BOOL)isState:(NSString*)s;
@end
