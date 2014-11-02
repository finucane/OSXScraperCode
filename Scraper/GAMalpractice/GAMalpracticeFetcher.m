//
//  GAMalpracticeFetcher.m
//  Scraper
//
//  Created by Data Entry iMac 1 on 3/26/14.
//  Copyright (c) 2014 All rights reserved.
//

#import "GAMalpracticeFetcher.h"
#import <MFLib/MFCsvThing.h>
#import <MFLib/MFScannerCategory.h>
#import <MFLib/MFStringCategory.h>
#import <MFLib/insist.h>

#define TIMEOUT 30
#define MAX_CONNECTIONS 100
#define CONVICTION @"conviction"
#define MALPRACTICE_SETTLEMENT @"malpractice_settlement"
#define MALPRACTICE_JUDGEMENT @"malpractice_judgement"
#define SPECIALTY @"specialty"
#define NO_TYPE @"no_details"

@implementation GAMalpracticeItem

@end

@implementation GAMalpractice

-(id)init
{
  if ((self = [super init]))
  {
    items = [[NSMutableArray alloc] init];
    insist (items);
  }
  return self;
}
-(NSString*)csv
{
  /*the e for "emit" method accepts nil strings and returns the empty string, we are writing a sparse file here*/
  NSMutableString*mutable = [[NSMutableString alloc] init];
  for (GAMalpracticeItem*item in items)
  {
    [mutable appendFormat:@"%@|", [self e:license_number]];
    [mutable appendFormat:@"%@|", [self e:last_name]];
    [mutable appendFormat:@"%@|", [self e:full_name]];
    [mutable appendFormat:@"%@|", [self e:specialty]];
    [mutable appendFormat:@"%@|", [self e:designation]];
    [mutable appendFormat:@"%@|", [self e:item->type]];
    [mutable appendFormat:@"%@|", [GAMalpractice formatDate:item->date]];

    /*make amount a number by removing punctuation*/
    NSString*amount = [item->amount stringByRemovingCharactersInString:@"$,"];
    [mutable appendFormat:@"%@|", [self e:amount]];
    
    [mutable appendFormat:@"%@|", [self e:item->description_of_offense]];
    [mutable appendFormat:@"%@|", [self e:item->jurisdiction]];
    [mutable appendFormat:@"%@|", [self e:item->specialty_board]];
    [mutable appendFormat:@"%@", [self e:item->specialty_description]];
    
    [mutable appendFormat:@"\n"];
  }
  
  /*if there was nothing scraped in the detail page at least print out the top level information*/
  if (items.count == 0)
  {
    [mutable appendFormat:@"%@|", [self e:license_number]];
    [mutable appendFormat:@"%@|", [self e:last_name]];
    [mutable appendFormat:@"%@|", [self e:full_name]];
    [mutable appendFormat:@"%@|", [self e:specialty]];
    [mutable appendFormat:@"%@|", [self e:designation]];
    [mutable appendFormat:@"%@|", NO_TYPE];
    [mutable appendFormat:@"|"];
    [mutable appendFormat:@"|"];
    [mutable appendFormat:@"|"];
    [mutable appendFormat:@"|"];
    [mutable appendFormat:@"|"];
    [mutable appendFormat:@""];
   
    [mutable appendFormat:@"\n"];
  }
  return mutable;
}

+(NSString*)csvColumns
{
  return @"license_number|last_name|full_name|specialty|designation|type|date|amount|description_of_offense|jurisdiction|specialty_board|specialty_description\n";
}
/*
 Dates are scraped looking like this: 05/04/2004. return string representation that looks like
 YYYY-MM-DD.
 
 */
+(NSString*)formatDate:(NSString*)dateString
{
  if (!dateString) return @"";
  
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

@implementation GAMalpracticeFetcher

-(id)init
{
  if ((self = [super init]))
  {
    /*make net stack to do simple web page fetching with*/
    net = [[MFNet alloc] initWithTimeout:TIMEOUT maxConnections:MAX_CONNECTIONS completionBlock:^(MFError *error) {}];
    insist (net);
    
    /*we use this page to get last name, expiration, and status from*/
    webPage = [[MFWebPage alloc] initWithURL:@"https://services.georgia.gov/dch/mebs/jsp/index.jsp"];
    
    busy = NO;
  }
  return self;
}

-(void)fetch:(NSString*)license_number block:(GAMalpracticeBlock)block
{
  insist (!busy);
  busy = YES;

#if 0
  GAMalpractice*malpractice = [[GAMalpractice alloc] init];

  malpractice->license_number = license_number;
  [self scrapeTopLevel:malpractice licenseNumber:license_number block:block];
  return;
#endif
  
  __unsafe_unretained GAMalpracticeFetcher*myself = self;
    
  insist (net);
  [net addDataURL:
   [NSURL URLWithString:
    [NSString stringWithFormat:@"https://www.gaphysicianprofile.org/profile.ShowProfileAction.action?lic_nbr=%@",license_number]]
             body:nil
            block:^(MFNetOperation*op) {
              if (op.error)
              {
                myself->busy = NO;
                block (op.error, nil);
                return;
              }
              [myself handleDetailResults:op licenseNumber:license_number block:block];
              return;
            }];
  
}

-(void)handleDetailResults:(MFNetOperation*)op licenseNumber:(NSString*)license_number block:(GAMalpracticeBlock)block
{
  NSString*html = op.dataAsString;
  NSString*s;
  
  NSScanner*scanner = [NSScanner scannerWithString:html];
  insist (scanner);
  
  GAMalpractice*malpractice = [[GAMalpractice alloc] init];
  insist (malpractice);
  
  if (![scanner scanPast:@"<font size=\"-1\">Physician's Name:"] ||
      ![scanner scanPast:@"color=#0000ff>"]||
      ![scanner scanUpToString:@"</font>" intoString:&s])
  {
    /*this happens when a license number fails to find a dr*/
    //NSLog (@"%@", webPage.html);
    busy = NO;
    block ([MFError errorWithCode:MFErrorNotFound format:@" find Physician's name in %@", op.url], nil);
    return;
  }
  malpractice->full_name = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  /*look for Designation*/
  if (![scanner scanPast:@">Designation:</td>"] ||
      ![scanner scanPast:@"<td width=\"30%\">"] ||
      ![scanner scanUpToString:@"</td>"intoString:&s])
  {
    //NSLog (@"%@", webPage.html);
    busy = NO;
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan designation %@", op.url], nil);
    return;
  }
  malpractice->designation = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  
  /*look for convictions, 006873*/
  if (![scanner scanPast:@"Below is a list of the physician's criminal offenses"])
  {
    //NSLog (@"%@", webPage.html);
    busy = NO;
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't lookup %@", op.url], nil);
    return;
  }
  
  while ([scanner scanPast:@"<div align=\"left\">" before:@"</table>"])
  {
    GAMalpracticeItem*item = [[GAMalpracticeItem alloc] init];
    insist (item);
    item->type = CONVICTION;
    
    if (![scanner scanUpToString:@"</div>" intoString:&s])
    {
      //description_of_offense
      busy = NO;
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find description_of_offense  %@", op.url], nil);
      return;
    }
    item->description_of_offense = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (![scanner scanPast:@"<div align=\"left\">"] || ![scanner scanUpToString:@"</div>" intoString:&s])
    {
      //offense_date
      busy = NO;
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find offense date  %@", op.url], nil);
      return;
    }
    item->date = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (![scanner scanPast:@"<div align=\"left\">"] || ![scanner scanUpToString:@"</div>" intoString:&s])
    {
      //jurisdiction
      busy = NO;
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find jurisdiction  %@", op.url], nil);
      return;
    }
    item->jurisdiction = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [malpractice->items addObject:item];
    
  }
  
  /*go back and look for judgements 010895*/
  [scanner setScanLocation:0];
  if (![scanner scanPast:@"List of medical malpractice court judgment"])
  {
    /*this happens when a license number fails to find a dr*/
    //NSLog (@"%@", webPage.html);
    busy = NO;
    block ([MFError errorWithCode:MFErrorNotFound format:@"couldn't lookup %@", op.url], nil);
    return;
  }
  
  while ([scanner scanPast:@"<td align=\"left\" height=\"10\">" before:@"</table>"])
  {
    GAMalpracticeItem*item = [[GAMalpracticeItem alloc] init];
    insist (item);
    item->type = MALPRACTICE_JUDGEMENT;
    
    if (![scanner scanUpToString:@"</td>" intoString:&s])
    {
      busy = NO;
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find date of judgement  %@", op.url], nil);
      return;
    }
    item->date = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (![scanner scanPast:@"align=\"left\">"] || ![scanner scanUpToString:@"</td>" intoString:&s])
    {
      //amount
      busy = NO;
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find amount %@", op.url], nil);
      return;
    }
    item->amount = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    [malpractice->items addObject:item];
  }
  
  /*go back and look for settlements 008017*/
  [scanner setScanLocation:0];
  if (![scanner scanPast:@"List of settlements required to be reported"] ||
      ![scanner scanPast:@"<table>"] ||
      ![scanner scanPast:@"<table"])
  {
    /*this happens when a license number fails to find a dr*/
    //NSLog (@"%@", webPage.html);
    busy = NO;
    block ([MFError errorWithCode:MFErrorNotFound format:@"couldn't lookup %@", op.url], nil);
    return;
  }
  
  while ([scanner scanPast:@"<td align=\"left\" height=\"10\">" before:@"</table>"])
  {
    GAMalpracticeItem*item = [[GAMalpracticeItem alloc] init];
    insist (item);
    item->type = MALPRACTICE_SETTLEMENT;
    
    if (![scanner scanUpToString:@"</td>" intoString:&s])
    {
      busy = NO;
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find date of settlement  %@", op.url], nil);
      return;
    }
    item->date = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (![scanner scanPast:@"align=\"left\">"] || ![scanner scanUpToString:@"</td>" intoString:&s])
    {
      //amount
      busy = NO;
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find amount %@", op.url], nil);
      return;
    }
    item->amount = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    [malpractice->items addObject:item];
  }
  
  /*go back and look for specialty board*/
  [scanner setScanLocation:0];
  if (![scanner scanPast:@"List of applicable specialty board certifications"])
  {
    /*this happens when a license number fails to find a dr*/
    //NSLog (@"%@", webPage.html);
    busy = NO;
    block ([MFError errorWithCode:MFErrorNotFound format:@"couldn't lookup %@", op.url], nil);
    return;
  }
  
  if ([scanner scanPast:@"<b>CERTIFYING BOARD</td>"])
  {
    while ([scanner scanPast:@"<div align=\"left\">" before:@"</table>"])
    {
      GAMalpracticeItem*item = [[GAMalpracticeItem alloc] init];
      insist (item);
      item->type = SPECIALTY;
      
      if (![scanner scanUpToString:@"</div>" intoString:&s])
      {
        busy = NO;
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find specialty board  %@", op.url], nil);
        return;
      }
      item->specialty_board = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      
      if (![scanner scanPast:@"<td width=\"40%\" align=\"left\">"] || ![scanner scanUpToString:@"</td>" intoString:&s])
      {
        busy = NO;
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find specialty description %@", op.url], nil);
        return;
      }
      item->specialty_description = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      
      [malpractice->items addObject:item];
    }
  }
  dispatch_async(dispatch_get_main_queue(),^{
    
    /*we have to do this on the main thread, and we came back on a separate thread from MFNet*/
    [self scrapeTopLevel:malpractice licenseNumber:license_number block:block];
  });
}

-(void)scrapeTopLevel:(GAMalpractice*)malpractice licenseNumber:(NSString*)license_number block:(GAMalpracticeBlock)block
{
  insist (malpractice && license_number && block);
  insist (webPage);
  
  /*load the GA webpage so we can run some js in it*/
  [webPage load:^(MFWebPage*aWebPage, MFError*error) {
    
    insist (webPage == aWebPage);
    
    if (error)
    {
      busy = NO;
      block (error, nil);
      return;
    }
    __unsafe_unretained GAMalpracticeFetcher*myself = self;
    
    /*make js code that sets the value of the license number input and then clicks the search button*/
    NSString*js = [NSString stringWithFormat:@"document.getElementById('lnum').value='%@'; document.getElementById('btn2').click();", license_number];
    
    /*run the js, this will result in a new page being loaded*/
    [webPage runReloadingJS:js block:^(MFWebPage*aWebPage, MFError*error) {
      
      insist (webPage == aWebPage);
      
      if (error)
      {
        busy = NO;
        block (error, nil);
        return;
      }
      
      [myself handleTopLevelResults:webPage.html malpractice:malpractice licenseNumber:license_number block:block];
      return;
    }];
  }];
}

-(void)handleTopLevelResults:(NSString*)html malpractice:(GAMalpractice*)malpractice licenseNumber:(NSString*)license_number block:(GAMalpracticeBlock)block
{
  insist (html && malpractice && license_number && block);
  
  //NSLog (@"%@", html);
  
  NSScanner*scanner = [NSScanner scannerWithString:html];
  insist (scanner);
  
  NSString*s;
  
  if (![scanner scanPast:@"<br>Issue / Expiration Dates</a>"] ||
      ![scanner scanPast:@"<tr class=\"odd\">"] ||
      ![scanner scanPast:@"</td>"] ||
      ![scanner scanPast:@"<td>"] ||
      ![scanner scanUpToString:@"<br>" intoString:&s])
  {
    busy = NO;
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan name %@", license_number], nil);
    return;
  }
  malpractice->last_name = [[s substringToString:@","] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  malpractice->license_number = license_number;
  
  if (![scanner scanPast:@"<td>"] ||
      ![scanner scanUpToString:@"</td>" intoString:&s])
  {
    busy = NO;
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan specialty %@", license_number], nil);
    return;
  }
  malpractice->specialty = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  busy = NO;
  block (nil, malpractice);
  
}
@end
