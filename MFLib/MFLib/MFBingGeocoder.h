//
//  MFBingGeocoder.h
//  Geocoder
//
//  Created by finucane on 3/14/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

/*
 BingGeocoder is a class that geocodes addresses using the Bing map api.
*/

#import "MFNet.h"
#import "MFGeocoder.h"


@interface MFBingGeocoder : MFGeocoder

-(void)geocodeAddress:(NSString*)address city:(NSString*)city state:(NSString*)state zip:(NSString*)zip block:(MFGeocoderCompletionBlock)block;

@end
