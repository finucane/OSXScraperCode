//
//  MFGoogleGeocoder.m
//  Geocoder
//
//  Created by finucane on 3/17/14.
//  Copyright (c) 2014  All rights reserved.
//

/*
 
 https://maps.googleapis.com/maps/api/geocode/json?address=1600+Amphitheatre+Parkway,+Mountain+View,+CA&sensor=false&key=API_KEY
 
 */
#import "MFGoogleGeocoder.h"
#import "MFZipCodeDB.h"
#import "insist.h"

@implementation MFGoogleGeocoder

/*
 start a request to the google map server to geocode an address. when the answer comes back, or on error, "block" is called.
 
 address - address lines of address
 city - city for address
 state - state
 zip - zip code (optional)
 
 returns nothing (result is in block).
 */

-(void)geocodeAddress:(NSString*)address city:(NSString*)city state:(NSString*)state zip:(NSString*)zip block:(MFGeocoderCompletionBlock)block
{
  insist (address && city && state);
  
  /*make the url, being careful to percent escape the data*/
  NSString*url = [NSString stringWithFormat:
                  @"https://maps.googleapis.com/maps/api/geocode/json?key=%@&sensor=false&address=%@,+%@+%@",
                  key,
                  [self urlEncode:address],
                  [self urlEncode:city],
                  [self urlEncode:state]];
  
  /*if there is a zip code, append it to the url, this is being appended to the "address" component of the url*/
  if (zip && zip.length)
    url = [url stringByAppendingFormat:@",+%@", zip];
  
  
  /*keep track of how many requests we've sent*/
  numRequests++;
  
  /*send off the request which will call the caller's completion block on completion or error.*/
  [self addDataURL:[NSURL URLWithString:url] body:nil block:^(MFNetOperation*op){
    
    if (op.error)
    {
      block (op.error, 0, 0, nil);
      return;
    }
    /*deal with the response.*/
    MFError*error;
    
    //    AppLog (@"result is %@\n\n", [op dataAsString]);

    /*parse json response*/
    NSDictionary*dict = [op jsonDictionaryWithError:&error];
    
    NSString*status = dict [@"status"];
    if (![status isEqualToString:@"OK"])
    {
      block ([MFError errorWithCode:MFErrorServer format:@"google api response %@", status], 0, 0, nil);
      return;
    }
    /*use obj-c dict&array literals*/
    NSArray*array = dict [@"results"];
    if (!array || array.count < 1)
    {
      block ([MFError errorWithCode:MFErrorJson format:@"missing results"], 0, 0, nil);
      return;
    }
    dict = array [0];
    NSArray*address_components = dict [@"address_components"];
    
    dict = dict [@"geometry"];
    if (!dict)
    {
      block ([MFError errorWithCode:MFErrorJson format:@"missing geometry"], 0, 0, nil);
      return;
    }
    dict = dict [@"location"];
    if (!dict)
    {
      block ([MFError errorWithCode:MFErrorJson format:@"missing location"], 0, 0, nil);
      return;
    }
    
    NSNumber*lat = dict [@"lat"];
    NSNumber*lon = dict [@"lng"];
    
    if (!lat || !lon)
    {
      block ([MFError errorWithCode:MFErrorJson format:@"missing lat/lon"], 0, 0, nil);
      return;
    }
    
    /*get optional county*/
    NSString*county = [MFGoogleGeocoder countyFromAddressComponents:address_components];
    if (!county)
    {
     // AppLog (@"no administrative_area_level_2 from google geocoder.");
    }
    else
      county = [MFGeocoder trimCounty:county];
    
    // AppLog (@"dict is %@", dict);
    
    /*call caller's block to notify the response came back, this will be on the network thread.*/
    block (error, [lat doubleValue], [lon doubleValue], county);
  }];
}

+(NSString*)countyFromAddressComponents:(NSArray*)address_components
{
  if (!address_components)
    return nil;
  
  for (NSDictionary*dict in address_components)
  {
    NSArray*types = dict [@"types"];
    if (types)
    {
      for (NSString*type in types)
      {
        if ([type isEqualToString:@"administrative_area_level_2"])
        {
          return dict [@"long_name"];
        }
      }
    }
  }
  return nil;
}
@end
