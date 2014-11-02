//
//  MFGoogleGeocoder.h
//  Geocoder
//
//  Created by finucane on 3/17/14.
//  Copyright (c) 2014  All rights reserved.
//

#import "MFGeocoder.h"

@interface MFGoogleGeocoder : MFGeocoder

-(void)geocodeAddress:(NSString*)address city:(NSString*)city state:(NSString*)state zip:(NSString*)zip block:(MFGeocoderCompletionBlock)block;

@end
