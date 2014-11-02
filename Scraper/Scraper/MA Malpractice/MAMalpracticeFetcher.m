//
//  MAMalpracticeFetcher.m
//  Scraper
//
//  Created by Finucane on 3/20/14.
//  Copyright (c) 2014 All rights reserved.
//

#define TIMEOUT 30
#define MAX_CONNECTIONS 100

#import "MAMalpracticeFetcher.h"
#import <MFLib/MFScannerCategory.h>
#import <MFLib/MFStringCategory.h>
#import <MFLib/insist.h>

@implementation MAMalpracticeIncident

/*
 Dates are scraped looking like this: 5/4/2004. return string representation that looks like
 YYYY-MM-DD.
 
*/
-(NSString*)formattedDate
{
  NSDateFormatter*formatter = [[NSDateFormatter alloc] init];
  insist (formatter);
  
  [formatter setDateFormat:@"m/d/yyyy"];
  NSDate*date = [formatter dateFromString:date_of_payment];
  [formatter setDateFormat:@"yyyy-mm-dd"];
  return [formatter stringFromDate:date];
}
@end

@implementation MAMalpractice

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
  for (MAMalpracticeIncident*incident in incidents)
  {
    [mutable appendFormat:@"%@|", [self e:license_number]];
    [mutable appendFormat:@"%@|", [incident formattedDate]];
    [mutable appendFormat:@"%@|", [self e:incident->category_of_payment]];
    [mutable appendFormat:@"%@|", [self e:speciality]];
    [mutable appendFormat:@"%@|", [self e:active_physicians]];
    [mutable appendFormat:@"%@|", [self e:physicians_with_malpractice]];
    [mutable appendFormat:@"%@", [self e:physician_id]];
    [mutable appendFormat:@"\n"];
  }
  return mutable;
}

+(NSString*)csvColumns
{
  return @"license_number|date_of_payment|category_of_payment|specialty|active_physicians|physicians_with_malpractice|physician_id\n";
}
@end

@implementation MAMalpracticeFetcher

-(id)init
{
  if ((self = [super init]))
  {
    /*make a webpage for the top level MA site which requires js*/
    webPage = [[MFWebPage alloc] initWithURL:@"http://profiles.ehs.state.ma.us/Profiles/Pages/FindAPhysician.aspx"];
    insist (webPage);
    
    /*make net stack to do simple web page fetching with*/
    net = [[MFNet alloc] initWithTimeout:TIMEOUT maxConnections:MAX_CONNECTIONS completionBlock:^(MFError *error) {}];
    insist (net);
  }
  return self;
}
/*
 get malpractice info from MA's doctor registration web site. we don't
 save a reference to block as an ivar and so it happens that we don't
 need to worry about retain cycles in the chain of block calls.
 
 license_number - a USA wide license number
 block - completion block for the fetch, this might be called on any thread.
 
 returns : nothing
 */

-(void)fetch:(NSString*)license_number block:(MAMalpracticeBlock)block
{
  insist (license_number && license_number.length);
  insist (block);
  insist (webPage);
  
  /*load the MA webpage so we can run some js in it*/
  [webPage load:^(MFWebPage*aWebPage, MFError*error) {
    
    insist (webPage == aWebPage);
    
    if (error)
    {
      block (error, nil, nil);
      return;
    }
    
    __unsafe_unretained MAMalpracticeFetcher*myself = self;
    
    /*make js code that sets the value of the license number input and then clicks the search button*/
    NSString*js = [NSString stringWithFormat:@"document.getElementById('ctl00_ContentPlaceHolder1_txtLicenseNumber').value='%@'; document.getElementById('ctl00_ContentPlaceHolder1_btnSearch').click();", license_number];
    
    /*run the js, this will result in a new page being loaded*/
    [webPage runReloadingJS:js block:^(MFWebPage*aWebPage, MFError*error) {
      
      insist (webPage == aWebPage);
      
      if (error)
      {
        block (error, nil, nil);
        return;
      }

      NSString*html = webPage.html;
      
      if (!html)
      {
        block ([MFError errorWithCode:MFErrorConnection format:@"empty html"], nil, nil);
        return;
      }
      NSScanner*scanner = [NSScanner scannerWithString:webPage.html];
      insist (scanner);
      
      NSString*physicianID;
      if (![scanner scanPast:@"PhysicianProfile.aspx?PhysicianID="] || ![scanner scanUpToString:@"'" intoString:&physicianID])
      {
        /*this happens when a license number fails to find a dr*/
        //NSLog (@"%@", webPage.html);
        block ([MFError errorWithCode:MFErrorNotFound format:@"couldn't lookup license_number %@", license_number], nil, nil);
        return;
      }
      
      //physicianID = @"18522";
      insist (net);
      [net addDataURL:
       [NSURL URLWithString:
        [NSString stringWithFormat:@"http://profiles.ehs.state.ma.us/Profiles/Pages/PhysicianProfile.aspx?PhysicianID=%@",
         physicianID]]
                 body:nil
                block:^(MFNetOperation*op) {
                  if (op.error)
                  {
                    block (op.error, nil, nil);
                    return;
                  }
                  [myself scrape:op block:block];
                  return;
                }];
    }];
    
  }];
}

/*
 scrape a PhysicianProfile page for
 
 license_number
 date_of_payment
 category_of_payment
 specialty
 active_physicians
 physicians_with_malpractice
 physician_id
 
 html - the page source
 block - malpractice block
 
 returns : nothing
 */

-(void)scrape:(MFNetOperation*)op block:(MAMalpracticeBlock)block
{
  insist (op && block);
  
  NSString*html = op.dataAsString;
  
  //NSLog (@"%@", html);
  
  NSScanner*scanner = [NSScanner scannerWithString:html];
  insist (scanner);
  NSString*s;
  NSString*physicianID;
  
  //NSLog (@"%@", op.url);
  
  if (![scanner scanPast:@"PhysicianProfile.aspx?PhysicianID="] || ![scanner scanUpToString:@"\"" intoString:&physicianID])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find PhysicianProfile.aspx?PhysicianID= %@", op.url], nil, nil);
    return;
  }
  if (![scanner scanPast:@"Help/Viewing_a_Physician_Profile.htm#Physician_Information\">License Number"] || ![scanner scanPast:@"<td>"])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find start of License Number %@", op.url], nil, nil);
    return;
  }
  if (![scanner scanUpToString:@"</td>" intoString:&s])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find license number string %@",  op.url], nil, nil);
    return;
  }
  /*if the html doesn't contain <ul class=​"MalpracticeFacts">​…​</ul>​ then the dr has no malpractice info.*/
  if (![scanner scanPast:@"class=\"MalpracticeFacts\""])
  {
    block (nil, nil, physicianID);
    return;
  }
  
  /*make a malpractice object to return the data in*/
  MAMalpractice*malpractice = [[MAMalpractice alloc] init];
  insist (malpractice);
  malpractice->license_number = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  malpractice->physician_id = physicianID;
  
  if (![scanner scanPast:@"Help/Viewing_a_Physician_Profile.htm#Malpractice_Information_\""] ||
      ![scanner scanPast:@">"] ||
      ![scanner scanPast:@"Details for Payments in "])

  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find start of speciality %@",  op.url], nil, physicianID);
    return;
  }
  
  if (![scanner scanUpToString:@"Specialty" intoString:&s])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't speciality %@",  op.url], nil, physicianID);
    return;
  }
  malpractice->speciality = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  while ([scanner scanPast:@"<td align=\"left\">" before:@"/tbody"])
  {
    MAMalpracticeIncident*incident = [[MAMalpracticeIncident alloc] init];
    insist (incident);
    
    if (![scanner scanUpToString:@"</td>" intoString:&s])
    {
      block ([MFError errorWithCode:MFErrorScrape description:@"couldn't find malpractice date"], nil, physicianID);
      return;
    }
    incident->date_of_payment = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (![scanner scanPast:@"<td align=\"left\">"])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find start of malpractice amount %@",  op.url], nil, physicianID);
      return;
    }

    if (![scanner scanUpToString:@"</td>" intoString:&s])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find malpractice amount %@",  op.url], nil, physicianID);
      return;
    }
    incident->category_of_payment = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [malpractice->incidents addObject:incident];
  }
  
  /*grab active physicians*/
  if (![scanner scanPast:@"<b>"] || ![scanner scanUpToString:@"</b>" intoString:&s])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find <b> for active_physicians %@",  op.url], nil, physicianID);
    return;
  }
  malpractice->active_physicians = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  
  /*grab malpractice physicians*/
  if (![scanner scanPast:@"<b>"] || ![scanner scanUpToString:@"</b>" intoString:&s])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find <b> for physicians_with_malpractice %@",  op.url], nil, physicianID);
    return;
  }
  malpractice->physicians_with_malpractice = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  block (nil, malpractice, physicianID);
}

@end
