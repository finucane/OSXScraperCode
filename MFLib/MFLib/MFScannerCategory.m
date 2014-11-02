//
//  MFScannerCategory.m
//  MFLib
//
//  Created by finucane on 3/20/14.
//  Copyright (c) 2014 mf. All rights reserved.
//

#import "MFScannerCategory.h"
#import <MFLib/insist.h>

@implementation NSScanner (ScannerCategory)

-(BOOL) scanPast:(NSString*)s
{
  [self scanUpToString:s intoString:nil];
  return ![self isAtEnd] && [self scanString:s intoString:nil];
}

-(BOOL) scanFrom:(unsigned)startLocation upTo:(unsigned)stopLocation intoString:(NSString**)aString
{
  insist (aString && stopLocation >= startLocation);
  
  NSString*string = [self string];
  insist (string);
  
  if (stopLocation <= startLocation || stopLocation > [string length]) return NO;
  
  *aString = [[string substringWithRange: NSMakeRange (startLocation, stopLocation - startLocation)]
    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  
  [self setScanLocation: stopLocation == [string length] ? stopLocation - 1: stopLocation];
  
  return YES;
}

-(BOOL) scanPast:(NSString*)s before:(NSString*)stopString
{
  unsigned long location = [self scanLocation];
  
  /*find stop location*/
  [self scanUpToString:stopString intoString:nil];
  unsigned long stopLocation = [self scanLocation];
  
  /*restore location*/
  [self setScanLocation:location];
  
  [self scanUpToString:s intoString:nil];
   
  /*see if we found something*/
  if (![self isAtEnd] && [self scanLocation] < stopLocation)
  {
    [self scanString:s intoString:nil];
    return YES;
  }
  
  /*not found. restore location*/
  [self setScanLocation: location];
  return NO;
}
-(BOOL) scanPast:(NSString*)s beforeStrings:(NSArray*)strings
{
  unsigned long location = [self scanLocation];
  unsigned long stopLocation = self.string.length;
  
  /*find the location of the nearest stop string*/
  for (NSString*s in strings)
  {
    [self setScanLocation:location];
    
    /*find stop location*/
    [self scanUpToString:s intoString:nil];
    unsigned long loc = [self scanLocation];
    if (loc < stopLocation)
      stopLocation = loc;
  }
  
  /*restore location*/
  [self setScanLocation:location];
  
  [self scanUpToString:s intoString:nil];
  
  /*see if we found something*/
  if (![self isAtEnd] && [self scanLocation] < stopLocation)
  {
    [self scanString:s intoString:nil];
    return YES;
  }
  
  /*not found. restore location*/
  [self setScanLocation: location];
  return NO;
}
@end
