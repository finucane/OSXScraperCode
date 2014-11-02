//
//  WVMalpracticeFetcher.m
//  Scraper
//
//  Created by finucane on 3/24/14.
//  Copyright (c) 2014 All rights reserved.
//


#define TIMEOUT 10
#define MAX_CONNECTIONS 100
#define MAX_TRIES 3

#import "WVMalpracticeFetcher.h"
#import <MFLib/MFScannerCategory.h>
#import <MFLib/MFStringCategory.h>
#import <MFLib/insist.h>

@implementation WVMalpracticeIncident

/*
 Dates are scraped looking like this: 5/4/2004. return string representation that looks like
 YYYY-MM-DD.
 
 */
+(NSString*)formatDate:(NSString*)dateString
{
  insist (dateString);
  NSDateFormatter*formatter = [[NSDateFormatter alloc] init];
  insist (formatter);
  
  [formatter setDateFormat:@"m/d/yyyy"];
  NSDate*date = [formatter dateFromString:dateString];
  [formatter setDateFormat:@"yyyy-mm-dd"];
  NSString*s = [formatter stringFromDate:date];
  if (!s)
  {
    //NSLog (@"dateString is %@", dateString);
    return @"";
  }
  return s;
}
@end

@implementation WVMalpractice

-(id)init
{
  if ((self = [super init]))
  {
    /*make array to store multiple incidents in*/
    incidents = [[NSMutableArray alloc] init];
    insist (incidents);
  }
  return self;
}


/*make cvs string for Malpractice, including newlines*/
-(NSString*)csv
{
  NSMutableString*mutable = [[NSMutableString alloc] init];
  for (WVMalpracticeIncident*incident in incidents)
  {
    /*make amount a number by removing punctuation*/
    NSString*amount = [incident->amount stringByRemovingCharactersInString:@"$,."];
    
    [mutable appendFormat:@"%@|", [self e:license_number]];
    [mutable appendFormat:@"%@|", [self e:individual_id]];
    [mutable appendFormat:@"%@|", [self e:last_name]];
    [mutable appendFormat:@"%@|", [self e:full_name]];
    [mutable appendFormat:@"%@|", [self e:speciality]];
    [mutable appendFormat:@"%@|", [self e:incident->malpractice_reason]];
    [mutable appendFormat:@"%@|", [self e:incident->action_type]];
    [mutable appendFormat:@"%@|", [WVMalpracticeIncident formatDate:incident->loss_date]];
    [mutable appendFormat:@"%@|", [WVMalpracticeIncident formatDate:incident->action_date]];
    [mutable appendFormat:@"%@|", [self e:amount]];
    [mutable appendFormat:@"%@|", [self e:incident->insurance_company]];
    [mutable appendFormat:@"%@|", [self e:incident->file_number]];
    [mutable appendFormat:@"%@|", [self e:incident->adjudicating_body]];
    [mutable appendFormat:@"%@| ", [self e:incident->case_number]];
    [mutable appendFormat:@"%@", [self e:incident->notes]];
    
    [mutable appendFormat:@"\n"];
  }
  return mutable;
}

+(NSString*)csvColumns
{
  return @"license_number|individual_id|last_name|full_name|specialty|malpractice_reason|action_type|loss_date|action_date|amount|insurance_company|file_number|adjudicating_body|case_number|notes\n";
}
@end

@implementation WVMalpracticeFetcher

-(id)init
{
  if ((self = [super init]))
  {
    //http://www.wvbom.wv.gov/licenseSearch.asp?QueueNumber=2&Radio=3&keywordNumber=02655"]
    
    /*make net stack to do simple web page fetching with*/
    net = [[MFNet alloc] initWithTimeout:TIMEOUT maxConnections:MAX_CONNECTIONS completionBlock:^(MFError *error) {}];
    insist (net);
    
    /*make array of malpractices to deal with multiple search results*/
    malpractices = [[NSMutableArray alloc] init];
    insist (malpractices);
  }
  return self;
}

/*
 get malpractice info from WV board of medicine web site. we don't
 save a reference to block as an ivar and so it happens that we don't
 need to worry about retain cycles in the chain of block calls.
 
 license_number - a USA wide license number
 block - completion block for the fetch, this might be called on any thread.
 
 returns : nothing
 */

-(void)fetch:(NSString*)license_number block:(WVMalpracticeBlock)block
{
  insist (license_number && license_number.length);
  insist (block);
  
  /*pad license number with leading zeros to make it 5 chars*/
  license_number = [license_number stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  
  while (license_number.length < 5)
    license_number = [NSString stringWithFormat:@"0%@", license_number];
  __unsafe_unretained WVMalpracticeFetcher*myself = self;
  
  insist (net);
  [net addDataURL:
   [NSURL URLWithString:
    [NSString stringWithFormat:@"http://www.wvbom.wv.gov/licenseSearch.asp?QueueNumber=2&Radio=3&keywordNumber=%@",
     license_number]]
             body:nil
            block:^(MFNetOperation*op) {
              if (op.error)
              {
                block (op.error, nil);
                return;
              }
              [myself handleSearchResults:op licenseNumber:license_number block:block];
              return;
            }];
  
}

/*
 scrape the results of a license number search.
*/

-(void)handleSearchResults:(MFNetOperation*)op licenseNumber:(NSString*)licenseNumber block:(WVMalpracticeBlock)block
{
  insist (op && licenseNumber &&  block);
  insist (malpractices);
  NSString*html = op.dataAsString;
  
  //NSLog (@"%@", html);
  
  NSScanner*scanner = [NSScanner scannerWithString:html];
  insist (scanner);
  NSString*individualID;
  
  /*get rid of any old malpractices, from previous runs*/
  [malpractices removeAllObjects];
  
  /*get malpractice items if any*/
  while ([scanner scanPast:@"onclick='javascript:location.href=\"licenseSearch.asp?"] &&
         [scanner scanPast:@"&IndividualID="] &&
         [scanner scanUpToString:@"\"" intoString:&individualID])
  {
    
    WVMalpractice*malpractice = [[WVMalpractice alloc] init];
    insist (malpractice);
    
    NSString*lastName;
    /*grab last,first*/
    if (![scanner scanPast:@"style=\"padding-left: 3px\">"] || ! [scanner scanUpToString:@"</TD>" intoString:&lastName])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find last,first %@", op.url], nil);
      return;
    }
    malpractice->last_name = [[lastName substringToString:@","] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    malpractice->license_number = licenseNumber;
    malpractice->individual_id = individualID;
    [malpractices addObject:malpractice];
    
  }
  /*if there were none, we are done*/
  if (![malpractices count])
  {
    block (nil, nil);
    return;
  }
  
  /*fetch first dr's info*/
  numFetched = 0;
  [self fetchNext:block];
}

-(void)fetchNext:(WVMalpracticeBlock)block
{
  insist (malpractices);
  insist (numFetched >= 0 && numFetched <= malpractices.count);
  
  /*check to see if we're done*/
  if (numFetched == [malpractices count])
  {
    insist (numFetched > 0);
    block (nil, malpractices);
    return;
  }
  
  WVMalpractice*malpractice = malpractices [numFetched];
  insist (malpractice);
  
  __unsafe_unretained WVMalpracticeFetcher*myself = self;
  
  insist (net);
  [net addDataURL:
   [NSURL URLWithString:
    [NSString stringWithFormat:@"http://www.wvbom.wv.gov/licenseDMDetail.asp?IndividualID=%@#M",
     malpractice->individual_id]]
             body:nil
            block:^(MFNetOperation*op) {
              if (op.error)
              {
                block (op.error, nil);
                return;
              }
              [myself handleMalpracticeResults:op malpractice:malpractice block:block];
              return;
            }];
}

-(void)handleMalpracticeResults:(MFNetOperation*)op malpractice:(WVMalpractice*)malpractice block:(WVMalpracticeBlock)block
{
  insist (op && block);
  
  NSString*html = op.dataAsString;
  NSString*s;
  
  if (!html)
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"empty html %@", op.url], nil);
    return;
  }
  //NSLog (@"%@", html);
  
  NSScanner*scanner = [NSScanner scannerWithString:html];
  insist (scanner);
 
  /*we already have an individual id, but just sanity check*/
  
  if (![scanner scanPast:@"?IndividualID="] || ![scanner scanUpToString:@"\"" intoString:&s])
  {
    //NSLog (@"%@", html);
    
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find IndividualID %@", op.url], nil);
    return;
  }

  if (![scanner scanPast:@"<td class=\"label8\">Full Name: </td>"] ||
      ![scanner scanPast:@"<b>"] ||
      ![scanner scanUpToString:@"</b>" intoString:&s])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find full name %@", op.url], nil);
  }
  
  s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  s = [s stringWithoutRepeatedString:@" "];
  malpractice->full_name = s;
  
  /*get speciality which is optional*/
  unsigned long scanLocation = [scanner scanLocation];
  
  if (![scanner scanPast:@"Primary Specialty<br>"] ||
      ![scanner scanPast:@"<td class=\"search8\">"] ||
      ![scanner scanUpToString:@"</td>" intoString:&s])
  {
    //block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find Primary Specialty %@", op.url], nil);
    [scanner setScanLocation:scanLocation];
    malpractice->speciality = @"";
  }
  else
  {
    malpractice->speciality = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  }
  
  /*there might not be any malpractice records*/
  if (![scanner scanPast:@"<b>Malpractice Records"])
  {
    block (nil, nil);
    return;
  }
  
  while ([scanner scanPast:@"<td class=\"search9hl\">Malpractice Record"])
  {
    WVMalpracticeIncident*incident = [[WVMalpracticeIncident alloc] init];
    insist (incident);
    
    unsigned long scanLocation = [scanner scanLocation];
    
    /*get malpractice reason, which is optional*/
    if ([scanner scanPast:@"Malpractice Reason:" before:@"Action Type"])
    {
      if (![scanner scanPast:@"<td class=\"search8\">" before:@"Action Type"] ||
          ![scanner scanUpToString:@"</td>" intoString:&s])
        
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find malpractice reason %@", op.url], nil);
        return;
      }
      incident->malpractice_reason = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    else
    {
      incident->malpractice_reason = @"";
    }
    
    /*back up to before optional tokens*/
    [scanner setScanLocation:scanLocation];
    
    if (![scanner scanPast:@"Action Type:"] || ![scanner scanPast:@"<td class=\"search8\">"] ||
        ![scanner scanUpToString:@"</td>" intoString:&s])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find Action Type: %@", op.url], nil);
      return;
    }
    incident->action_type = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (![scanner scanPast:@"Loss Date:"] || ![scanner scanPast:@"<td class=\"search8\">"] ||
        ![scanner scanUpToString:@"</td>" intoString:&s])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find Loss Date: %@", op.url], nil);
      return;
    }
    incident->loss_date = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (![scanner scanPast:@"Action Date:"] || ![scanner scanPast:@"<td class=\"search8\">"] ||
        ![scanner scanUpToString:@"</td>" intoString:&s])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find Action Date: %@", op.url], nil);
      return;
    }
    incident->action_date = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (![scanner scanPast:@"Amount:"] || ![scanner scanPast:@"<td class=\"search8\">"] ||
        ![scanner scanUpToString:@"</td>" intoString:&s])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find Amount: %@", op.url], nil);
      return;
    }
    incident->amount = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (![scanner scanPast:@"Insurance Company:"] || ![scanner scanPast:@"<td class=\"search8\">"] ||
        ![scanner scanUpToString:@"</td>" intoString:&s])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find Insurance Company:: %@", op.url], nil);
      return;
    }
    incident->insurance_company = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (![scanner scanPast:@"File Number:"] || ![scanner scanPast:@"<td class=\"search8\">"] ||
        ![scanner scanUpToString:@"</td>" intoString:&s])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find File Number: %@", op.url], nil);
      return;
    }
    incident->file_number = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    /*get adjudicating body & case number which are optional*/
    scanLocation = [scanner scanLocation];
    
    if ([scanner scanPast:@"Adjucating Body:" before:@"td class=\"label8\">Notes:"])
    {
      if (![scanner scanPast:@"<td class=\"search8\">"] || ![scanner scanUpToString:@"</td>" intoString:&s])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find Adjudicating Body: %@", op.url], nil);
        return;
      }
      incident->adjudicating_body = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if (![scanner scanPast:@"Case Number of Adjucating Body:"] || ![scanner scanPast:@"<td class=\"search8\">"] ||
          ![scanner scanUpToString:@"</td>" intoString:&s])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find File Number: %@", op.url], nil);
        return;
      }
      incident->case_number = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    else
    {
      [scanner setScanLocation:scanLocation];
      incident->case_number = @"";
      incident->adjudicating_body = @"";
    }
    if (![scanner scanPast:@"Notes:"] || ![scanner scanPast:@"<td class=\"search8\">"] ||
        ![scanner scanUpToString:@"</td>" intoString:&s])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find Notes: %@", op.url], nil);
      return;
    }
    incident->notes = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    [malpractice->incidents addObject:incident];
    
  }
  numFetched++;
  [self fetchNext:block];
}

@end
