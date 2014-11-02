//
//  VASpecialtyFetcher.m
//  Scraper
//
//  Created by Data Entry iMac 1 on 4/7/14.
//  Copyright (c) 2014 All rights reserved.
//

#import "VASpecialtyFetcher.h"
#import <MFLib/MFNet.h>
#import <MFLib/insist.h>
#import <MFLib/MFScannerCategory.h>
#import <MFLib/MFStringCategory.h>

#define TIMEOUT 30
#define MAX_CONNECTIONS 100

@implementation VASpecialty
-(id)init
{
  if ((self = [super init]))
  {
    /*make array to store multiple incidents in*/
    items = [[NSMutableArray alloc] init];
    insist (items);
  }
  return self;
}
-(NSString*)csv
{
  insist (license_number && license_number.length);
  
  NSMutableString*mutable = [[NSMutableString alloc] init];
  for (VASpecialtyItem*item in items)
  {
    [mutable appendFormat:@"%@|", mf_doctor_id];
    [mutable appendFormat:@"%@|", license_number];
    [mutable appendFormat:@"%@|", [self e:full_name]];
    [mutable appendFormat:@"%@|", [self e:item->specialty_description]];
    [mutable appendFormat:@"%@", [self e:item->specialty_type]];
    
    [mutable appendFormat:@"\n"];
  }
  return mutable;
  
}
+(NSString*)csvColumns
{
  return @"mf_doctor_id|license_number|full_name|specialty_description|specialty_type\n";
}

@end

@implementation VASpecialtyItem

@end

@implementation VASpecialtyFetcher

-(id)init
{
  if ((self = [super init]))
  {
    /*make net stack to do simple web page fetching with*/
    net = [[MFNet alloc] initWithTimeout:TIMEOUT maxConnections:MAX_CONNECTIONS completionBlock:^(MFError *error) {}];
    insist (net);
  }
  return self;
}

-(void)fetch:(NSString*)license_number block:(VASpecialtyBlock)block
{
  VASpecialtyFetcher*myself = self;
  
  insist (net);
  [net addDataURL:
   [NSURL URLWithString:
    [NSString stringWithFormat:@"https://secure01.virginiainteractive.org/dhp/cgi-bin/search_publicdb.cgi?search_type=4&license_no=%@", license_number]]
             body:nil
            block:^(MFNetOperation*op) {
              
              if (op.error)
              {
                block (op.error, nil);
                return;
              }
              [myself handleResults:op licenseNumber:license_number block:block];
            }];

}


-(void)handleResults:(MFNetOperation*)op licenseNumber:(NSString*)license_number block:(VASpecialtyBlock)block
{
  insist (op && license_number && block);
  
  NSString*html = [op dataAsString];
  insist (html);
  
  NSScanner*scanner = [NSScanner scannerWithString:html];
  //NSLog (@"%@",html);
  
  if ([scanner scanPast:@"Sorry, The record you requested does not exist"])
  {
    block ([MFError errorWithCode:MFErrorNotFound format:@"couldn't look up %@", license_number], nil);
    return;
  }
  
  [scanner setScanLocation:0];
  
  NSString*blob;
  if (![scanner scanPast:@"class=\"textbigb\">License Information</TD></TR>"] ||
      ![scanner scanPast:@"<tr align=left valign=top><th>Specialization<"]||
      ![scanner scanPast:@"<td>"] ||
      ![scanner scanUpToString:@"</td></tr>" intoString:&blob])
  {
    block ([MFError errorWithCode:MFErrorNotFound format:@"couldn't scan speciality blob %@", op.url], nil);
    return;
  }
  
  VASpecialty*specialty = [[VASpecialty alloc] init];
  specialty->license_number = license_number;

  NSScanner*blobScanner = [NSScanner scannerWithString:blob];
  
  NSString*s;
  while ([blobScanner scanUpToString:@"(<a" intoString:&s])
  {
    VASpecialtyItem*item = [[VASpecialtyItem alloc] init];
    insist (item);
    item->specialty_description = [s flattenHTML];
    
    if (![blobScanner scanPast:@">"] || ![blobScanner scanUpToString:@"</a>" intoString:&s])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan specialty type %@", op.url], nil);
      return;
    }
    item->specialty_type = [s detag];
    [specialty->items addObject:item];
    
    if (![blobScanner scanPast:@"</a>)"])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan past paren %@", op.url], nil);
      return;
    }
  }
  
  if (![scanner scanPast:@"th>Name</th>"] ||
      ![scanner scanPast:@"<td>"]||
      ![scanner scanUpToString:@"</td>" intoString:&s])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan specialty name %@", op.url], nil);
    return;
  }
  specialty->full_name = s;
  
  block (nil, specialty);
}
@end
