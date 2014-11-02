//
//  MFBingGeocoder.m
//  Geocoder
//
//  Created by finucane on 3/14/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

/*
 http://dev.virtualearth.net/REST/v1/Locations?countryRegion=us&adminDistrict=ca&locality=pasadena&postalCode=91103&addressLine=1332+lida+st&key=AuXYmDSyF7VAO12okpdYjYPr-0KGwpJAoRxEjl6r8zYaZCXeimmmEDjiZ8g0cw3V
 
 */


#import "MFBingGeocoder.h"
#import "MFZipCodeDB.h"
#import "insist.h"

@implementation MFBingGeocoder


/*
  start a request to the bing server to geocode an address. when the answer comes back, or on error, "block" is called. none of the arguments is optional
  (for instance zip).
 
  address - address lines of address
  city - city for address
  state - state
  zip - zip code
 
  returns nothing (result is in block).
*/

-(void)geocodeAddress:(NSString*)address city:(NSString*)city state:(NSString*)state zip:(NSString*)zip block:(MFGeocoderCompletionBlock)block
{
  /*make the url, being careful to percent escape the data*/
  NSString*url = [NSString stringWithFormat:
                  @"http://dev.virtualearth.net/REST/v1/Locations?countryRegion=us&adminDistrict=%@&locality=%@&postalCode=%@&addressLine=%@&key=%@",
                  [self urlEncode:state],
                  [self urlEncode:city],
                  [self urlEncode:zip],
                  [self urlEncode:address],
                   key];
  
  /*keep track of how many requests we've sent to Bing*/
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
    
    /*parse json response*/
    NSDictionary*dict = [op jsonDictionaryWithError:&error];
   
    //AppLog (@"result is %@\n\n", [op dataAsString]);
    
    NSString*status = dict [@"statusDescription"];
    if (![status isEqualToString:@"OK"])
    {
      block ([MFError errorWithCode:MFErrorServer format:@"bing api response %@", status], 0, 0, nil);
      return;
    }
    /*use obj-c dict&array literals*/
    NSArray*array = dict [@"resourceSets"];
    if (!array || array.count < 1)
    {
      block ([MFError errorWithCode:MFErrorJson format:@"missing resourceSets"], 0, 0, nil);
      return;
    }
    dict = array [0];
    array = dict [@"resources"];
    if (!array || array.count < 1)
    {
      block ([MFError errorWithCode:MFErrorJson format:@"missing resources"], 0, 0, nil);
      return;
    }
    NSDictionary*resourceDict = array [0];
    
    array = resourceDict [@"geocodePoints"];
    if (!array || array.count < 1)
    {
      block ([MFError errorWithCode:MFErrorJson format:@"missing geocodePoints"], 0, 0, nil);
      return;
    }
    dict = array [0];
    array = dict [@"coordinates"];
    if (!array || array.count < 2)
    {
      block ([MFError errorWithCode:MFErrorJson format:@"missing coordinates"], 0, 0, nil);
      return;
    }
    
    /*
      experimentally we know it's array[0] = lat, array[1] = lon since we are in the northern hemisphere
      and we looked at some sample output from florida, despite having a 100 kb json response to get 2 numbers,
      there's no way in the json to know which is which
     */
    /*finally get lat/lon*/
    
    NSNumber*lat = array [0];
    NSNumber*lon = array [1];
    
    /*get county, optionally*/
    NSDictionary*addressDict = resourceDict[@"address"];
    NSString*county = addressDict [@"adminDistrict2"];
    if (!county)
    {
      //AppLog (@"no adminDistrict2 from bing geocoder.");
    }
    else
      county = [MFGeocoder trimCounty:county];
    
    
   // AppLog (@"dict is %@", dict);
    
    /*call caller's block to notify the response came back, this will be on the network thread.*/
    block (error, [lat doubleValue], [lon doubleValue], county);
  }];
  
}

@end
