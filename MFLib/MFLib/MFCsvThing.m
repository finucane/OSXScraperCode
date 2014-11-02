//
//  CsvThing.m
//  Scraper
//
//  Created by finucane on 3/25/14.
//  Copyright (c) 2014 mf. All rights reserved.
//

#import "MFCsvThing.h"
#import <MFLib/MFStringCategory.h>
#import <MFLib/insist.h>

@implementation MFCsvThing

/*escape pipes*/
-(NSString*)e:(NSString*)s
{
  if (!s) return @"";
  
  insist (s);
  s = [s detag];//get rid of <br> etc
  s = [s stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]; //handle the 1 case of html escape we care about
  s = [s stringByReplacingOccurrencesOfString:@"|" withString:@" "];
  s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
  s = [s stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
  s = [s stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
  s = [s stringWithoutRepeatedString:@" "];
  s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  
  return s;
}
@end
