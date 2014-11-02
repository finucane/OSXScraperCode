//
//  MFGeocoder.m
//  Geocoder
//
//  Created by Data Entry iMac 1 on 3/17/14.
//  Copyright (c) 2014  All rights reserved.
//

#import "MFGeocoder.h"
#import "insist.h"

#define TIMEOUT 10.0 //seconds
#define MAX_CONNECTIONS 1000

@implementation MFGeocoder

/*
 initialize an MFGeocoder object.
 key - a bing map api key
 
 returns : the MFGeocoder initialized
*/


-(id)initWithKey:(NSString*)aKey
{
  insist (aKey);
  
  if ((self = [super initWithTimeout:TIMEOUT maxConnections:MAX_CONNECTIONS completionBlock:^(MFError*error)
               {
               }]))
  {
    /*save the key so we can use it in constructing the urls*/
    key = aKey;
    
    /*we keep track of how many requests we send because we care about the daily limits.*/
    numRequests = 0;
  }
  return self;
}

-(void)setKey:(NSString *)aKey
{
  insist (aKey);
  key = aKey;
}

-(int)numRequests
{
  return numRequests;
}

-(void)geocodeAddress:(NSString*)address city:(NSString*)city state:(NSString*)state zip:(NSString*)zip block:(MFGeocoderCompletionBlock)block
{
  insist (0);
}

/*
 strip off any trailing " County" or "Co."
 
 county - a county string
 returns : name of county w/out county etc on the end.
 */
+(NSString*)trimCounty:(NSString*)county
{
  insist (county);
  
  NSArray*suffixes = @[@" county", @" co."];
  
  for (NSString*suffix in suffixes)
  {
    county = [county stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([[county lowercaseString] hasSuffix:suffix])
    {
      county = [county substringToIndex:county.length - suffix.length];
      return county;
    }
  }
  return county;
}


@end
