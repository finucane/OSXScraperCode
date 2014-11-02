//
//  MFGeocoder.h
//  Geocoder
//
//  Created by Data Entry iMac 1 on 3/17/14.
//  Copyright (c) 2014  All rights reserved.
//

/*
  Abstract class for geocoding over a network api. subclasses should overrride geocodeAddress:
*/

#import "MFNet.h"

typedef void (^MFGeocoderCompletionBlock)(MFError*error, double lat, double lon, NSString*county);

@interface MFGeocoder : MFNet
{
  @protected
  NSString*key;
  int numRequests;
}

-(id)initWithKey:(NSString*)aKey;
-(void)setKey:(NSString*)key;
-(int)numRequests;
+(NSString*)trimCounty:(NSString*)county;

/*for subclasses to override*/
-(void)geocodeAddress:(NSString*)address city:(NSString*)city state:(NSString*)state zip:(NSString*)zip block:(MFGeocoderCompletionBlock)block;
@end
