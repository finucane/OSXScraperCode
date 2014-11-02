//
//  MESpecialtyFetcher.m
//  Scraper
//
//  Created by finucane on 3/25/14.
//  Copyright (c) 2014 All rights reserved.
//

#import "MESpecialtyFetcher.h"
#import <MFLib/MFScannerCategory.h>
#import <MFLib/MFStringCategory.h>
#import <MFLib/insist.h>

#define TIMEOUT 10
#define MAX_CONNECTIONS 100

@implementation MESpecialtyItem

@end

@implementation MESpecialty

-(id)init;
{
  if ((self = [super init]))
  {
    /*make array to store multiple incidents in*/
    items = [[NSMutableArray alloc] init];
    insist (items);
  }
  return self;
}

/*make cvs string for Speciality, including newlines*/
-(NSString*)csv
{
  NSMutableString*mutable = [[NSMutableString alloc] init];
  for (MESpecialtyItem*item in items)
  {
    [mutable appendFormat:@"%@|", [self e:license_number]];
    [mutable appendFormat:@"%@|", [self e:last_name]];
    [mutable appendFormat:@"%@|", [self e:full_name]];
    [mutable appendFormat:@"%@|", [self e:status]];
    [mutable appendFormat:@"%@|", [self e:[MESpecialty formatDate:expiration_date]]];
    [mutable appendFormat:@"%@|", [self e:item->specialty_description]];
    [mutable appendFormat:@"%@", [self e:item->specialty_origin]];

    [mutable appendFormat:@"\n"];
  }
  return mutable;
}

+(NSString*)csvColumns
{
  return @"license_number|last_name|full_name|status|expiration_date|specialty_description|specialty_origin\n";
}

/*
 Dates are scraped looking like this: 05/04/2004. return string representation that looks like
 YYYY-MM-DD.
 
 */
+(NSString*)formatDate:(NSString*)dateString
{
  insist (dateString);
  NSDateFormatter*formatter = [[NSDateFormatter alloc] init];
  insist (formatter);
  
  [formatter setDateFormat:@"mm/dd/yyyy"];
  NSDate*date = [formatter dateFromString:dateString];
  [formatter setDateFormat:@"yyyy-mm-dd"];
  NSString*s = [formatter stringFromDate:date];
  if (!s)
  {
    NSLog (@"dateString is %@", dateString);
    return @"";
  }
  return s;
}
@end


@implementation MESpecialtyFetcher

-(id)init
{
  if ((self = [super init]))
  {
    
  //http://www.pfr.maine.gov/ALMSOnline/ALMSQuery/SearchIndividual.aspx?Board=376&AspxAutoDetectCookieSupport=1
    //http://www.pfr.maine.gov/ALMSOnline/ALMSQuery/SearchIndividual.aspx

    /*make a webpage for the top level ME site which requires js*/
    webPage = [[MFWebPage alloc] initWithURL:@"http://www.pfr.maine.gov/ALMSOnline/ALMSQuery/SearchIndividual.aspx"];
    insist (webPage);

    /*make net stack to do simple web page fetching with*/
    net = [[MFNet alloc] initWithTimeout:TIMEOUT maxConnections:MAX_CONNECTIONS completionBlock:^(MFError *error) {}];
    insist (net);
  }
  return self;
}

-(void)fetch:(NSString*)license_number block:(MESpecialtyBlock)block
{
  /*load the MA webpage so we can run some js in it*/
  [webPage load:^(MFWebPage*aWebPage, MFError*error) {
    
    insist (webPage == aWebPage);
    
    if (error)
    {
      block (error, nil);
      return;
    }
    __unsafe_unretained MESpecialtyFetcher*myself = self;
    
    /*make js code that sets the value of the license number input and then clicks the search button*/
     NSString*js = [NSString stringWithFormat:@"document.getElementById('scRegulator').value=''; document.getElementById('scLicenseNo').value='%@'; document.getElementById('btnSearch').click();", license_number];
    /*run the js, this will result in a new page being loaded*/
    [webPage runReloadingJS:js block:^(MFWebPage*aWebPage, MFError*error) {
      
      insist (webPage == aWebPage);
      
      if (error)
      {
        block (error, nil);
        return;
      }
    
      [myself handleSearchResults:webPage.html licenseNumber:license_number block:block];
      return;
    
    
    }];
  }];
}

-(void)handleSearchResults:(NSString*)html licenseNumber:(NSString*)license_number block:(MESpecialtyBlock)block
{
  //NSLog (@"%@", html);
  
  NSScanner*scanner = [NSScanner scannerWithString:html];
  insist (scanner);
  NSString*lastName;
  NSString*href;
  
  if (![scanner scanPast:@"<td style=\"width:40%;\">"] ||
      ![scanner scanPast:@"<a href=\""] ||
      ![scanner scanUpToString:@"\"" intoString:&href])
  {
    /*this happens when a license number fails to find a dr*/
    //NSLog (@"%@", webPage.html);
    block ([MFError errorWithCode:MFErrorNotFound format:@"couldn't lookup license_number %@", license_number], nil);
    return;
  }
  
  if (![scanner scanPast:@">"] || ![scanner scanUpToString:@"</a>" intoString:&lastName])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find last,first"], nil);
    return;
  }

  lastName = [[lastName substringToString:@","] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  
  __unsafe_unretained MESpecialtyFetcher*myself = self;

  insist (net);
  [net addDataURL:
   [NSURL URLWithString:
    [NSString stringWithFormat:@"http://www.pfr.maine.gov/ALMSOnline/ALMSQuery/%@", href]]
             body:nil
            block:^(MFNetOperation*op) {
              if (op.error)
              {
                block (op.error, nil);
                return;
              }
              [myself handleDetailResults:op licenseNumber:license_number lastName:lastName block:block];
              return;
            }];

}

-(void)handleDetailResults:(MFNetOperation*)op licenseNumber:(NSString*)license_number lastName:last_name block:(MESpecialtyBlock)block
{
  insist (op && license_number &&  last_name && block);
  
  NSString*html = op.dataAsString;
  
  //NSLog (@"%@", html);
  
  NSScanner*scanner = [NSScanner scannerWithString:html];
  insist (scanner);
  NSString*s;
  
  MESpecialty*specialty = [[MESpecialty alloc] init];
  insist (specialty);
  specialty->last_name = last_name;

  if (![scanner scanPast:@"<h2 class=\"Name\">"] || ![scanner scanUpToString:@"</h2>" intoString:&s])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan name h2, %@", license_number], nil);
    return;
  }
  specialty->full_name = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  if (![scanner scanPast:@"<div>License Number:</div>"] ||
      ![scanner scanPast:@"<div class=\"attributeCell\">"] ||
      ![scanner scanUpToString:@"</div>" intoString:&s])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan license number, %@", license_number], nil);
    return;
  }
  specialty->license_number = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  if (![scanner scanPast:@"<div>Status:</div>"] ||
      ![scanner scanPast:@".\">"] ||
      ![scanner scanUpToString:@"</a>" intoString:&s])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan status, %@", license_number], nil);
    return;
  }
  specialty->status = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  if (![scanner scanPast:@"<div>Expiration Date:</div>"] ||
      ![scanner scanPast:@"<div class=\"attributeCell\">"] ||
      ![scanner scanUpToString:@"</div>" intoString:&s])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't expiration date, %@", license_number], nil);
    return;
  }
  specialty->expiration_date = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  
  if (![scanner scanPast:@"<p class=\"SectionText\">The Board does not verify current specialties"] ||
      ![scanner scanPast:@"<tbody class=\"collapsehere\">"])
  {
    block ([MFError errorWithCode:MFErrorNotFound format:@"couldn't find start of specialty table %@", license_number], nil);
    return;
  }
  
  while ([scanner scanPast:@"<tr>" before:@"</tbody>"])
  {
    MESpecialtyItem*item = [[MESpecialtyItem alloc] init];
    insist (item);
    
    if (![scanner scanPast:@"<td>"] || ![scanner scanUpToString:@"</td>" intoString:&s])
    {
      block ([MFError errorWithCode:MFErrorNotFound format:@"couldn't scan description td %@", license_number], nil);
      return;
    }
    item->specialty_description = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
   
    if (![scanner scanPast:@"<td>"] || ![scanner scanUpToString:@"</td>" intoString:&s])
    {
      block ([MFError errorWithCode:MFErrorNotFound format:@"couldn't scan origin td %@", license_number], nil);
      return;
    }
    item->specialty_origin = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    [specialty->items addObject:item];
  }
  
  block (nil, specialty);
}


@end
