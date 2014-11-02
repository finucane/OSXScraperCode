//
//  CTMalpracticeFetcher.m
//  Scraper
//
//  Created byfinucane on 3/31/14.
//  Copyright (c) 2014 All rights reserved.
//

#import "CTMalpracticeFetcher.h"
#import <MFLib/MFScannerCategory.h>
#import <MFLib/MFStringCategory.h>
#import <MFLib/insist.h>

#define TIMEOUT 30
#define MAX_CONNECTIONS 100
#define JAVASCRIPT_SECONDS 0.05
#define JAVASCRIPT_TRIES 20
#define MALPRACTICE @"malpractice"
#define HOSPITAL_DISCIPLINE @"hospital_discipline"
#define CONVICTION @"conviction"

@implementation CTMalpractice

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
  for (CTMalpracticeItem*item in items)
  {
    insist (item->type.length && item->type.length);
    
    [mutable appendFormat:@"%@|", [self e:license_number]];
    [mutable appendFormat:@"%@|", [self e:full_name]];
    [mutable appendFormat:@"%@|", [self e:item->type]];
    [mutable appendFormat:@"%@|", [CTMalpractice formatDate:item->date]];
    [mutable appendFormat:@"%@|", [self e:item->payment_category]];
    [mutable appendFormat:@"%@|", [self e:item->specialty]];
    [mutable appendFormat:@"%@|", [self e:item->hospital_name]];
    [mutable appendFormat:@"%@|", [self e:item->city]];
    [mutable appendFormat:@"%@|", [self e:item->state]];
    [mutable appendFormat:@"%@|", [self e:item->country]];
    [mutable appendFormat:@"%@|", [self e:item->disciplinary_action]];
    [mutable appendFormat:@"%@|", [self e:item->conviction]];
    
    [mutable appendFormat:@"\n"];
  }
  return mutable;
  
}
+(NSString*)csvColumns
{
  return @"license_number|full_name|type|date|payment_category|specialty|hospital_name|city|state|country|disciplinary_action|conviction\n";
  
}
/*
 Dates are scraped looking like this:  01/21/2013 return string representation that looks like
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

@implementation CTMalpracticeItem
@end

@implementation CTMalpracticeFetcher

-(id)init
{
  if ((self = [super init]))
  {
    /*make net stack to do simple web page fetching with*/
    net = [[MFNet alloc] initWithTimeout:TIMEOUT maxConnections:MAX_CONNECTIONS completionBlock:^(MFError *error) {}];
    insist (net);
    
    /*the initial search goes through js*/
    webPage = [[MFWebPage alloc] initWithURL:@"https://www.elicense.ct.gov/Lookup/LicenseLookup.aspx"];
  }
  return self;
}


-(void)fetch:(NSString*)license_number block:(CTMalpracticeBlock)block
{
  /*load the CT webpage so we can run some js in it*/
  [webPage load:^(MFWebPage*aWebPage, MFError*error) {
    
    insist (webPage == aWebPage);
    
    if (error)
    {
      block (error, nil);
      return;
    }
    
    [webPage runJS:@"document.getElementById('ctl00_MainContentPlaceHolder_ucLicenseLookup_ctl01_ddCredPrefix').value='1';"];
    [webPage runJS:[NSString stringWithFormat:@"document.getElementById('ctl00_MainContentPlaceHolder_ucLicenseLookup_ctl01_tbLicenseNumber').value='%@';", license_number]];
    
    /*there is going to be a delay until the page re-writes itself to produce the result.*/
    
    [webPage runJSTries:JAVASCRIPT_TRIES delay:JAVASCRIPT_SECONDS jsString:@"document.getElementById('btnLookup').click();" block:^BOOL(MFWebPage*aWebPage, BOOL timedOut) {
      
      NSScanner*scanner = [NSScanner scannerWithString:aWebPage.html];
      
      /*check the dr not found case*/
      if ([scanner scanPast:@"No records found"])
      {
        block ([MFError errorWithCode:MFErrorNotFound format:@"couldn't look up %@", license_number], nil);
        return NO;//don't keep trying
      }
      
      /*now the case where the js isn't finished*/
      [scanner setScanLocation:0];
      if (![scanner scanPast:@"ctl00_MainContentPlaceHolder_ucLicenseLookup_gvSearchResults_ctl03_HyperLinkDetail"])
        return YES; //expected text hasn't appeared, keep waiting
      
      /*now deal w/ the search results*/
      [self handleSearchResults:webPage.html licenseNumber:license_number block:block];
      return NO;
    }];
  }];
}

-(void)handleSearchResults:(NSString*)html licenseNumber:(NSString*)license_number block:(CTMalpracticeBlock)block
{
  insist (html && license_number && block);
  
  NSScanner*scanner = [NSScanner scannerWithString:html];
  insist (scanner);
  
  int r = [scanner scanPast:@"ctl00_MainContentPlaceHolder_ucLicenseLookup_gvSearchResults_ctl03_HyperLinkDetail"];
  insist (r);
  
  
  [webPage runJSTries:JAVASCRIPT_TRIES delay:JAVASCRIPT_SECONDS jsString:@"document.getElementById('ctl00_MainContentPlaceHolder_ucLicenseLookup_gvSearchResults_ctl03_HyperLinkDetail').click();" block:^BOOL(MFWebPage*aWebPage, BOOL timedOut) {
    
    if (timedOut)
    {
      //40049 etc don't have profiles, consider this normal
      block ([MFError errorWithCode:MFErrorNotFound format:@"couldn't get profile %@, after waiting %d times", license_number, JAVASCRIPT_TRIES], nil);
      return NO; //don't keep waiting
    }
    
    NSString*html = aWebPage.html;
    
    NSScanner*scanner = [NSScanner scannerWithString:html];
    NSString*s;
    
    if (![scanner scanPast:@"ctl00_MainContentPlaceHolder_ucLicenseDetailPopup_btnSnapshot"] ||
        ![scanner scanPast:@"onclick=\"window.open('"] ||
        ![scanner scanUpToString:@"'" intoString:&s])
      return YES; //keep waiting
    
    
    /*quick and dirty. we know there's only going to be this entity*/
    s = [s stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    
    CTMalpracticeFetcher*myself = self;
    
    insist (net);
    [net addDataURL:
     [NSURL URLWithString:
      [NSString stringWithFormat:@"https://www.elicense.ct.gov/Lookup/%@", s]]
               body:nil
              block:^(MFNetOperation*op) {
                if (op.error)
                {
                  block (op.error, nil);
                  return;
                }
                [myself handleProfileResults:op licenseNumber:license_number block:block];
              }];
    return NO;
  }];
  
}


-(void)asyncWaitForProfile:(NSString*)license_number block:(CTMalpracticeBlock)block
{
  
  
}

/*
 
 https://www.elicense.ct.gov/SnapshotViewer.aspx?cid=537957&key=6cf4dcb7-2b27-4d59-b475-18ccecb67bdf
 
 some of the items scanned will end up being pure html meaning "empty" but that's ok since the e for emit
 method will strip that all out before writing csv.
 
 date is a special case since we need to do a date conversion so ...
 
 do the right thing, that's what [self clean] is
 
 */

-(NSString*)clean:(NSString*)s
{
  insist (s);
  s = [s stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
  return [[s detag] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

-(void)handleProfileResults:(MFNetOperation*)op licenseNumber:(NSString*)license_number block:(CTMalpracticeBlock)block
{
  NSString*html = op.dataAsString;
  NSString*s;
  
  NSScanner*scanner = [NSScanner scannerWithString:html];
  insist (scanner);
  
  CTMalpractice*malpractice = [[CTMalpractice alloc] init];
  insist (malpractice);
  malpractice->license_number = license_number;
  
  if (![scanner scanPast:@"<TD width=\"25%\" class=\"I1\" nowrap>Name</TD>"] ||
      ![scanner scanPast:@"<TD class=\"I4\">"] ||
      ![scanner scanUpToString:@"</td>" intoString:&s])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find name %@", license_number], nil);
    return;
  }
  malpractice->full_name = [self clean:s];
  
  /*here we discovered it's bad to "inspect element" rather than read the html itself from safari, because
   inspect element gives us massaged strings. fortunately scanner is not case sensitive, but there are other
   bad things that inspect element does, for instance hide &nspb;s and so on.
   */
  [scanner setScanLocation:0];
  
  if (![scanner scanPast:@"<td class=\"SubHeader I1 Section\" colspan=\"2\">Medical Malpractice Information</td>"])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find Medical Malpractice Information %@", license_number], nil);
    return;
  }
  
  if ([scanner scanPast:@"<TD>Specialty&nbsp;</TD>" before:@"<TD class=\"SubHeader I1 Section\""])
  {
    while ([scanner scanPast:@"<TR>" before:@"<TD class=\"SubHeader I1 Section\""] &&
           [scanner scanPast:@"<TD>" before:@"<TD class=\"SubHeader I1 Section\""])
    {
      CTMalpracticeItem*item = [[CTMalpracticeItem alloc]init];
      insist (item);
      item->type = MALPRACTICE;
      
      if (![scanner scanUpToString:@"<BR></TD>" intoString:&s])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan date %@", license_number], nil);
        return;
      }
      item->date = [self clean:s];
      
      if (![scanner scanPast:@"<TD>"] || ![scanner scanUpToString:@"</TD>" intoString:&s])
      {
        
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan payment category %@", license_number], nil);
        return;
      }
      /*these have stuff in them like <BR> and &nbsp; but the CVSThing e for "emit" method is going to strip them off*/
      item->payment_category = [self clean:s];
      
      if (![scanner scanPast:@"<TD>"] || ![scanner scanUpToString:@"</TD>" intoString:&s])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan specialty %@", license_number], nil);
        return;
      }
      if (![s hasPrefix:@"<BR>"])
      {
        insist (![s hasPrefix:@"<"]);
        item->specialty = [self clean:s];
      }
      [malpractice->items addObject:item];
    }
  }
  [scanner setScanLocation:0];
  
  
  //26993
  if ([scanner scanPast:@"Connecticut Hospital Discipline</td>"])
  {
    if ([scanner scanPast:@"<TD>Disciplinary Action" before:@"<TD class=\"SubHeader I1 Section\""])
    {
      while ([scanner scanPast:@"<TR>" before:@"<TD class=\"SubHeader I1 Section\""] &&
             [scanner scanPast:@"<TD>" before:@"<TD class=\"SubHeader I1 Section\""])
      {
        CTMalpracticeItem*item = [[CTMalpracticeItem alloc]init];
        insist (item);
        item->type = HOSPITAL_DISCIPLINE;
        
        if (![scanner scanUpToString:@"</TD>" intoString:&s])
        {
          block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan hospital name %@", license_number], nil);
          return;
        }
        item->hospital_name = [self clean:s];
        
        if (![scanner scanPast:@"<TD>"] || ![scanner scanUpToString:@"</TD>" intoString:&s])
        {
          block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan city %@", license_number], nil);
          return;
        }
        item->city = [self clean:s];
        
        if (![scanner scanPast:@"<TD>"] || ![scanner scanUpToString:@"</TD>" intoString:&s])
        {
          block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan state %@", license_number], nil);
          return;
        }
        item->state = [self clean:s];
        
        if (![scanner scanPast:@"<TD>"] || ![scanner scanUpToString:@"</TD>" intoString:&s])
        {
          block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan country %@", license_number], nil);
          return;
        }
        item->country = [self clean:s];
        
        if (![scanner scanPast:@"<TD>"] || ![scanner scanUpToString:@"</TD>" intoString:&s])
        {
          block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan date %@", license_number], nil);
          return;
        }
        item->date = [self clean:s];
        
        if (![scanner scanPast:@"<TD>"] || ![scanner scanUpToString:@"</TD>" intoString:&s])
        {
          block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan disciplinary_action %@", license_number], nil);
          return;
        }
        item->disciplinary_action = [self clean:s];
        
        [malpractice->items addObject:item];
      }
    }
  }
  
  [scanner setScanLocation:0];
  
  //44519
  if (![scanner scanPast:@"Felony Convictions</TD>"])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't find Felony Convictions %@", license_number], nil);
    return;
  }
  
  if ([scanner scanPast:@"<TD>Conviction&nbsp;</TD>" before:@"<TD class=\"SubHeader I1 Section\""])
  {
    while ([scanner scanPast:@"<TR>" before:@"<TD class=\"SubHeader I1 Section\""] &&
           [scanner scanPast:@"<TD>" before:@"<TD class=\"SubHeader I1 Section\""])
    {
      CTMalpracticeItem*item = [[CTMalpracticeItem alloc]init];
      insist (item);
      item->type = CONVICTION;
      
      if (![scanner scanUpToString:@"</TD>" intoString:&s])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan date %@", license_number], nil);
        return;
      }
      item->date = [self clean:s];
      
      if (![scanner scanPast:@"<TD>"] || ![scanner scanUpToString:@"</TD>" intoString:&s])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan date %@", license_number], nil);
        return;
      }
      item->conviction = [self clean:s];
      [malpractice->items addObject:item];
    }
  }
  block (nil, malpractice);
}
@end
