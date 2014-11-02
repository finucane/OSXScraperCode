//
//  MDCourtFetcher.m
//  CourtCrawler
//
//  Created by finucane on 4/3/14.
//  Copyright (c) 2014  All rights reserved.
//

#import "MDCourtFetcher.h"
#import "MFDateRange.h"
#import <MFLib/insist.h>
#import <MFLib/MFScannerCategory.h>
#import <MFLib/MFStringCategory.h>

#define MAX_CONNECTIONS 10
#define TIMEOUT 30
#define START_DATE @"01/01/2004"
#define DATE_FORMAT @"MM/dd/yyyy"



@implementation MDCase
-(id)init
{
  if ((self = [super init]))
  {
    data_source = @"Maryland Judiciary Case Search";
    capture_date = @"2014-03-31";
    state = @"MD";
  }
  return self;
}
@end

@implementation MDCourt
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
  NSMutableString*mutable = [[NSMutableString alloc] init];
  for (MDCase*item in items)
  {
    [mutable appendFormat:@"%@|", [self e:mf_doctor_id]];
    [mutable appendFormat:@"%@|", [self e:last_name]];
    [mutable appendFormat:@"%@|", [self e:first_name]];
    [mutable appendFormat:@"%@|", [self e:middle_name]];
    [mutable appendFormat:@"%@|", [self e:item->defendant_name]];
    [mutable appendFormat:@"%@|", [self e:item->address_line_1]];
    [mutable appendFormat:@"%@|", [self e:item->address_line_2]];
    [mutable appendFormat:@"%@|", [self e:item->address_line_3]];
    [mutable appendFormat:@"%@|", [self e:item->address_city]];
    [mutable appendFormat:@"%@|", [self e:item->address_state]];
    [mutable appendFormat:@"%@|", [self e:item->address_zip]];
    [mutable appendFormat:@"%@|", [self e:item->case_description]];
    [mutable appendFormat:@"%@|", [self e:item->allegation]];
    
    [mutable appendFormat:@"%@|", [self e:item->date_filed]];

    [mutable appendFormat:@"%@|", [self e:item->date_resolved]];
    [mutable appendFormat:@"%@|", [self e:item->case_number]];
    [mutable appendFormat:@"%@|", [self e:item->case_link]];
    [mutable appendFormat:@"%@|", [self e:item->jurisdiction]];
    [mutable appendFormat:@"%@|", [self e:item->amount]];
    [mutable appendFormat:@"%@|", [self e:item->case_resolution]];
    [mutable appendFormat:@"%@|", [self e:item->pdf_name]];
    [mutable appendFormat:@"%@|", [self e:item->data_source]];
    [mutable appendFormat:@"%@|", [self e:item->capture_date]];
    [mutable appendFormat:@"%@|", [self e:item->state]];
    [mutable appendFormat:@"%@|", [self e:item->person]];
    [mutable appendFormat:@"%@", [self e:item->notes]];
    
    [mutable appendFormat:@"\n"];
  }
  return mutable;
  
}
+(NSString*)csvColumns
{
  return @"mf_doctor_id|last_name|first_name|middle_name|defendant_name|address_line_1|address_line_2|address_line_3|address_city|address_state|address_zip_code|case_description|allegation|date_filed|date_resolved|case_number|case_link|jurisdiction|amount|case_resolution|pdf_name|data_source|capture_date|state|person|notes\n";
}

/*
 Dates are scraped looking like this:2014-03-31. return string representation that looks like
 YYYY-MM-DD.
 
 dead code don't need this since dates are already ok
 
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


@implementation MDCourtFetcher
-(id)init
{
  if ((self = [super init]))
  {
    /*make net stack to do simple web page fetching with*/
    net = [[MFNet alloc] initWithTimeout:TIMEOUT maxConnections:MAX_CONNECTIONS completionBlock:^(MFError *error) {}];
    insist (net);
    
    /*the initial search goes through js*/
    webPage = [[MFWebPage alloc] initWithURL:@"http://casesearch.courts.state.md.us/inquiry/processDisclaimer.jis"];
    
    /*worklist of urls to process*/
    searchUrls = [[NSMutableArray alloc] init];
    insist (searchUrls);
    
    detailUrls = [[NSMutableArray alloc]init];
    insist (detailUrls);
    
    /*make our list of acceptable case types*/
    caseTypes = @[@"medical malpractice", @"other tort", @"wrongful death"];
    
    dateRanges = [[NSMutableArray alloc] init];
    insist (dateRanges);
  }
  return self;
}

-(BOOL)goodCase:(NSString*)s
{
  s = [s flattenHTML];
  s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  
  for (NSString*c in caseTypes)
  {
    if ([s caseInsensitiveCompare:c] == NSOrderedSame)
      return YES;
  }
  return NO;
}

/*make sure "s" starts w/ a / and has no &amp;'s*/
-(NSString*)cleanUrlPiece:(NSString*)s slash:(BOOL)slash
{
  if (slash && ![s hasPrefix:@"/"])
    s = [NSString stringWithFormat:@"/%@", s];
  s = [s stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
  s = [s stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"'\""]];
  return s;
}

-(void)fetchFirstName:(NSString*)first_name lastName:(NSString*)last_name block:(MDCourtBlock)block
{
  [searchUrls removeAllObjects];
  [detailUrls removeAllObjects];
  [dateRanges removeAllObjects];
  
  /*add the widest date range we search, if it's too broad we'll chop it up*/
  
  [dateRanges addObject:[[MFDateRange alloc] initWithFormat:DATE_FORMAT startDate:START_DATE]];
  [self nextDisclaimerPage:first_name lastName:last_name block:block];
}

-(void)nextDisclaimerPage:(NSString*)first_name lastName:(NSString*)last_name block:(MDCourtBlock)block
{
  //[MFDateRange dump:dateRanges];
  
  /*if there are no more date ranges, we are done with scraping all search result pages for first_name/last_name.
   now we have to work through all the detail page urls we've accumulated.
   */
  if (dateRanges.count == 0)
  {
    /*start index of detailsUrl at 0, make a new court to hold all the court items in, from each details page*/
    urlIndex = 0;
    court = [[MDCourt alloc] init];
    insist (court);
    
    [self nextDetailPage:first_name lastName:last_name block:block];
    return;
  }
  /*load the CT webpage so we can run some js in it*/
  [webPage load:^(MFWebPage*aWebPage, MFError*error) {
    
    insist (webPage == aWebPage);
    
    if (error)
    {
      block (error, nil);
      return;
    }
    
    //NSLog (@"%@", webPage.html);
    NSScanner*scanner = [NSScanner scannerWithString:webPage.html];
    
    /*if we actually got the disclaimer page, deal with it*/
    if ([scanner scanPast:@"<input name=\"disclaimer\""])
    {
      [webPage runJS:@"document.main.disclaimer.checked = true;"];
      [webPage runReloadingJS:@"document.forms[0].submit();"
                        block:^(MFWebPage*aWebPage, MFError *error) {
                          [self handleSearchPage:first_name lastName:last_name block:block];
                        }];
    }
    else
    {
      /*we are at the search page already*/
      [self handleSearchPage:first_name lastName:last_name block:block];
    }
    
  }];
}


-(void)handleSearchPage:(NSString*)first_name lastName:(NSString*)last_name block:(MDCourtBlock)block
{
  insist (first_name && last_name && block);
  insist (dateRanges.count);
  
  MFDateRange*dateRange = [dateRanges lastObject];
  
  [webPage runJS:@"document.querySelectorAll(\"input[name='exactMatchLn']\")[0].click();"];
  [webPage runJS:@"document.querySelectorAll(\"select[name='partyType']\")[0].value='DEF';"];
  [webPage runJS:@"document.querySelectorAll(\"input[value='CIVIL']\")[0].checked=true;"];
  [webPage runJS:@"document.querySelectorAll(\"input[value='C']\")[0].click();"];
  BOOL r;
  r = [webPage setName:@"firstName" value:first_name];
  [webPage setName:@"lastName" value:last_name];
  [webPage setName:@"filingStart" value:[dateRange firstDate]];
  [webPage setName:@"filingEnd" value:[dateRange lastDate]];
  
  [webPage runReloadingJS:@"document.querySelectorAll(\"input[type='submit']\")[0].click();"
                    block:^(MFWebPage*aWebPage, MFError *error) {
                      
                      [self handleFirstResultPage:first_name lastName:last_name block:block];
                      
                    }];
  
}

-(void)handleFirstResultPage:(NSString*)first_name lastName:(NSString*)last_name block:(MDCourtBlock)block
{
  insist (searchUrls);
  
  NSString*html = webPage.html;
  
  //NSLog (@"%@", html);
  
  NSScanner*scanner = [NSScanner scannerWithString:html];
  insist (scanner);
  
  /*check to see if the date range was too large*/
  if ([scanner scanPast:@"The result set exceeds the limit of 500 records"])
  {
    /*replace the range with 2 smaller ranges by subdividing*/
    MFDateRange*range = [dateRanges lastObject];
    [dateRanges removeObjectAtIndex:dateRanges.count - 1];
    
    NSArray*newRanges = [range divide];
    insist (newRanges && newRanges.count == 2);
    [dateRanges addObjectsFromArray:newRanges];
    
    /*search again*/
    [self nextDisclaimerPage:first_name lastName:last_name block:block];
    return;
  }
  
  /*go back to the start since the 500 records test, above, got us to the end*/
  [scanner setScanLocation:0];
  
  if (![scanner scanPast:@"<span class=\"pagelinks\">"])
  {
    block ([MFError errorWithCode:MFErrorNotFound format:@"couldn't scan pagelinks"], nil);
    return;
  }
  
  /*if there's more than 1 page of search results, get all the 1, 2, 3 etc urls*/
  if (![html igrep:@"displaying all items.</span>"] &&
      ![html igrep:@"One item found.</span>"]
      )
  {
    while ([scanner scanPast:@"<a href=\"" beforeStrings:@[@"<th class=\"sortable\">", @"Next</a>"]])
    {
      NSString*s;
      
      if (![scanner scanUpToString:@"\"" intoString:&s])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan url"], nil);
        return;
      }
      
      s = [self cleanUrlPiece:s slash:YES];
      insist ([s hasPrefix:@"/inquiry"]);
      [searchUrls addObject:[NSString stringWithFormat:@"http://casesearch.courts.state.md.us%@", s]];
    }
  }
  
  /*scrape page 1, which is a special case since we already have it and there's no url to it*/
  urlIndex = -1;
  [self scrapeResultsPage:html firstName:(NSString*)first_name lastName:(NSString*)last_name block:(MDCourtBlock)block];
}

-(void)scrapeResultsPage:(NSString*)html firstName:(NSString*)first_name lastName:(NSString*)last_name block:(MDCourtBlock)block
{
  insist (html && first_name && last_name && block);
  
  NSScanner*scanner = [NSScanner scannerWithString:html];
  insist (scanner);
  
  if (![scanner scanPast:@"CaseSearch will only display"])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan start of details list"], nil);
    return;
  }
  
  //sometimes it's <a href=", others <a href='
  while ([scanner scanPast:@"inquiryDetail.jis?"])
  {
    /*get the url*/
    NSString*url,*s;
    if (![scanner scanUpToString:@">" intoString:&url])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan detail url"], nil);
      return;
    }
    
    /*take off the ' or the " from the end of the url*/
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"'\""]];
    
    insist (![s grep:@"<"]);
    
    /*now grab the case type*/
    /* we are up around here now...
     <td>Smith, John A III</td>
     <td></td>
     <td>Defendant</td>
     <td>Queen Anne's County Circuit Court</td>
     <td>Foreclosure</td>
     */
    
    if (![scanner scanPast:@"<td>"] ||
        ![scanner scanPast:@"<td>"] ||
        ![scanner scanPast:@"<td>"] ||
        ![scanner scanPast:@"<td>"] ||
        ![scanner scanPast:@"<td>"] ||
        ![scanner scanUpToString:@"</td>" intoString:&s])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan case type"], nil);
      return;
    }
    
    //NSLog (@"case %@", s);
    
    if (![self goodCase:s])
      continue;
    
    url = [self cleanUrlPiece:url slash:NO];
    insist (![url hasSuffix:@"\""]);
    insist (![url hasSuffix:@"'"]);
    
    [detailUrls addObject:[NSString stringWithFormat:@"http://casesearch.courts.state.md.us/inquiry/inquiryDetail.jis?%@", url]];
  }
  
  /*increment to the next url*/
  urlIndex++;
  
  if (urlIndex == searchUrls.count)
  {
    /*
     we have scraped all of the search pages for the current date range. do the next date range. we are coming
     off a network op queue so we're not on the main thread, make sure we get back onto the main thread because
     nextDisclaimerPage is using webkit.
     */
    [dateRanges removeLastObject];
    dispatch_async(dispatch_get_main_queue(),^{
      [self nextDisclaimerPage:first_name lastName:last_name block:block];
    });
    return;
  }
  
  /*fetch the next page*/
  __unsafe_unretained MDCourtFetcher*myself = self;
  
  // NSLog (@"%@", urls[urlIndex]);
  insist (net);
  [net addDataURL:
   [NSURL URLWithString:searchUrls[urlIndex]]
             body:nil
            block:^(MFNetOperation*op) {
              if (op.error)
              {
                block (op.error, nil);
                return;
              }
              NSString*html = op.dataAsString;
              
              [myself scrapeResultsPage:html firstName:first_name lastName:last_name block:block];
              return;
            }];
  
}

-(void)nextDetailPage:(NSString*)first_name lastName:(NSString*)last_name block:(MDCourtBlock)block
{
  insist (first_name && last_name && block);
  insist (detailUrls);
  
  /*if there are no more detail urls, we are done with first_name/last_name*/
  if (urlIndex >= detailUrls.count)
  {
    block (nil, court); //done!!
    return;
  }
  
  /*fetch the next page*/
  __unsafe_unretained MDCourtFetcher*myself = self;
  
  // NSLog (@"%@", urls[urlIndex]);
  insist (net);
  [net addDataURL:
   [NSURL URLWithString:detailUrls [urlIndex]]
             body:nil
            block:^(MFNetOperation*op) {
              if (op.error)
              {
                block (op.error, nil);
                return;
              }
              [myself scrapeDetailsPage:op firstName:first_name lastName:last_name block:block];
              return;
            }];
  
  urlIndex++;
}

-(NSString*)clean:(NSString*)s
{
  insist (s);
  s = [s stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
  s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
  s = [s detag];
  s = [s stringWithoutRepeatedString:@" "];
  s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  return s;
}

/*
 return yes if text scraped as "Jesse D Dawkins" matches first_name jesse last_name dawkins.
 s is already cleaned so there's no extra spaces.
 
 "Del Rosario, David A T
 Deborja, Narciso A.
 */
-(BOOL)goodName:(NSString*)s firstName:(NSString*)first_name lastName:(NSString*)last_name
{
  NSLog (@"comparing %@ with %@ %@", s, first_name, last_name);
  
  s = [s stringByReplacingOccurrencesOfString:@"M D," withString:@""];
  s = [s stringByReplacingOccurrencesOfString:@"m d," withString:@""];

  /*get tokens*/
  NSArray*words = [s componentsSeparatedByString:@" "];
  
  /*copy out to array omitting esqs and mds*/
  NSMutableArray*components = [[NSMutableArray alloc] init];
  for (NSString*s in words)
  {
    if (s.length &&
        ![s caseInsensitiveCompare:@"esq"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"esq,"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"sr"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"sr,"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"jr"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"jr,"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"ii"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"ii,"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"rn"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"rn,"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"r.n."] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"r.n.,"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"md"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"md,"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"m.d."] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"m.d.,"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"m.d"] == NSOrderedSame &&
        ![s caseInsensitiveCompare:@"m.d,"] == NSOrderedSame
        )
      [components addObject:s];
  }
  
  if (components.count < 2)
  {
    NSLog (@"bad name:%@", s);
    return NO;
  }
  
  NSString*first = components [0];
  NSString*last = [components lastObject];
  
  
  /*if we are like Deborja, Narciso A. or Del Rosario, David A T then deal w/ it. get the first name component ending in a comma, make
    the first name the next component after that, make the last name the whole input string up to but not including
    the comma
   */
  int commaIndex = 0;
  for (commaIndex = 0; commaIndex < components.count && ![components[commaIndex] hasSuffix:@","];commaIndex++);
  
  if (commaIndex < components.count - 1)
  {
    first = components [commaIndex + 1];
    last = [s substringToString:@","];
  }
  
  return [first caseInsensitiveCompare:first_name] == NSOrderedSame && [last caseInsensitiveCompare:last_name] == NSOrderedSame;
}

-(void)scrapeDetailsPage:(MFNetOperation*)op firstName:(NSString*)first_name lastName:(NSString*)last_name block:(MDCourtBlock)block
{
  insist (op);
  
  if ([last_name caseInsensitiveCompare:@"Adler"] == NSOrderedSame &&
      [first_name caseInsensitiveCompare:@"Richard"] == NSOrderedSame)
  {
    NSLog (@"here");
  }
  NSString*html = op.dataAsString;
  
  insist (html && first_name && last_name && block);
  
  MDCase*item = [[MDCase alloc] init];
  insist (item);
  
  item->case_link = op.url;
  
  NSString*s;
  NSScanner*scanner = [NSScanner scannerWithString:html];
  insist (scanner);
  
  if (![scanner scanPast:@"<span class=\"FirstColumnPrompt\">Court System:"] ||
      ![scanner scanPast:@"<span class=\"Value\">"] ||
      ![scanner scanUpToString:@"</span>" intoString:&s])
  {
    //some really turn up empty*/
    /*
     http://casesearch.courts.state.md.us/inquiry/inquiryDetail.jis?caseId=03C12006478&loc=55&detailLoc=CC
     */
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan court system %@", op.url], nil);
    return;
  }
  item->jurisdiction = [self clean:s];
  
  if (![scanner scanPast:@"<span class=\"FirstColumnPrompt\">Case Number:"] ||
      ![scanner scanPast:@"<span class=\"Value\">"] ||
      ![scanner scanUpToString:@"</span>" intoString:&s])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan case number"], nil);
    return;
  }
  item->case_number = [self clean:s];
  
  unsigned long location = [scanner scanLocation];
  
  
  
  if (![scanner scanPast:@"<span class=\"FirstColumnPrompt\">Title:"] ||
      ![scanner scanPast:@"<span class=\"Value\">"] ||
      ![scanner scanUpToString:@"</span>" intoString:&s])
  {
    [scanner setScanLocation:location];
  }
  else
  {
    item->case_description = [self clean:s];
  }
  
  location = [scanner scanLocation];

  if (![scanner scanPast:@"<span class=\"FirstColumnPrompt\">Case Type:"] ||
      ![scanner scanPast:@"<span class=\"Value\">"] ||
      ![scanner scanUpToString:@"</span>" intoString:&s])
  {
    [scanner setScanLocation:location];
  }
  else
  {
    item->allegation = [self clean:s];
  }
  NSString*filingDate = @"Filing Date:";
  if (![html igrep:filingDate])
  {
    filingDate = @"Date Filed";
  }
  location = [scanner scanLocation];
  if (![scanner scanPast:[NSString stringWithFormat:@"Prompt\">%@", filingDate]]||
      ![scanner scanPast:@"<span class=\"Value\">"] ||
      ![scanner scanUpToString:@"</span>" intoString:&s])
  {
    [scanner setScanLocation:location];
  }
  else
  {
    item->date_filed = [self clean:s];
  }
  
  /*get a new scanner to the end of the case info section so we can get optional data*/
  NSString*blob;
  if (![scanner scanUpToString:@"<HR" intoString:&blob])
  {
    block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan blob to end case info section"], nil);
    return;
  }
  
  NSScanner*blobScanner = [NSScanner scannerWithString:blob];
  insist (blobScanner);
  
  if ([blobScanner scanPast:@"<span class=\"FirstColumnPrompt\">Case Disposition:"] &&
      [blobScanner scanPast:@"<span class=\"Value\">"] &&
      [blobScanner scanUpToString:@"</span>" intoString:&s])
  {
    item->case_resolution = [self clean:s];
  }
  
  [blobScanner setScanLocation:0];
  if ([blobScanner scanPast:@"<span class=\"Prompt\">Disposition Date:"] &&
      [blobScanner scanPast:@"<span class=\"Value\">"] &&
      [blobScanner scanUpToString:@"</span>" intoString:&s])
  {
    item->date_resolved = [self clean:s];
  }
  
  location = [scanner scanLocation];
  
  BOOL hasPartyTypes = YES;
  if (![scanner scanPast:@"<H5>Defendant/Respondent Information</H5>"])
  {
    [scanner setScanLocation:location];
    if (![scanner scanPast:@"<H5>Defendant Information</H5>"])
    {
      block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan to start of defendant info"], nil);
      return;
    }
    hasPartyTypes = NO;
  }
  
  if (hasPartyTypes)
  {
    NSArray*stopStrings = @[@"<H5>Document Tracking</H5>", @"<H5>Attorney Information </H5>"];

    while ([scanner scanPast:@"<span class=\"FirstColumnPrompt\">Party Type:" beforeStrings:stopStrings])
    {
      if (![scanner scanPast:@"<span class=\"Value\">"] ||
          ![scanner scanUpToString:@"</span>" intoString:&s])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan party type"], nil);
        return;
      }
      s = [self clean:s];
      s = [s lowercaseString];
      
      if (![s isEqualToString:@"defendant"]&&
          ![s isEqualToString:@"third party defendant"])
        continue;
      
      if (![scanner scanPast:@"<span class=\"FirstColumnPrompt\">Name:" beforeStrings:stopStrings] ||
          ![scanner scanPast:@"<span class=\"Value\">"] ||
          ![scanner scanUpToString:@"</span>" intoString:&s])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan defendant name"], nil);
        return;
      }
      
      s = [self clean:s];
      
      /*if the name doesn't match the dr...*/
      if (![self goodName:s firstName:first_name lastName:last_name])
        continue;
      
      item->defendant_name = s;

      if (![scanner scanPast:@"<span class=\"FirstColumnPrompt\">Address:" beforeStrings:stopStrings] ||
          ![scanner scanPast:@"<span class=\"Value\">"])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan address"], nil);
        return;
      }
      if ([scanner scanUpToString:@"</span>" intoString:&s])
        item->address_line_1 = [self clean:s];
      
      if (![scanner scanPast:@"<span class=\"FirstColumnPrompt\">City:" beforeStrings:stopStrings] ||
          ![scanner scanPast:@"<span class=\"Value\">"])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan city"], nil);
        return;
      }
      if ([scanner scanUpToString:@"</span>" intoString:&s])
        item->address_city = [self clean:s];
      
      item->address_city = [self clean:s];
      if (![scanner scanPast:@"<span class=\"Prompt\">Zip Code:" beforeStrings:stopStrings] ||
          ![scanner scanPast:@"<span class=\"Value\">"])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan zip code"], nil);
        return;
      }
      if ([scanner scanUpToString:@"</span>" intoString:&s])
        item->address_zip = [self clean:s];
      
      break;
    }
  }
  else
  {
    NSArray*stopStrings = @[@"<H5>Document Tracking</H5>", @"<H5>Issues Information</H5>", @"<H5>Attorney Information </H5>"];
    while ([scanner scanPast:@"<span class=\"FirstColumnPrompt\">Name:" beforeStrings:stopStrings])
    {
      if (![scanner scanPast:@"<span class=\"Value\">"] ||
          ![scanner scanUpToString:@"</span>" intoString:&s])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan defendant name"], nil);
        return;
      }
      
      s = [self clean:s];
      
      /*if the name doesn't match the dr...*/
      if (![self goodName:s firstName:first_name lastName:last_name])
        continue;
     
      item->defendant_name = s;

      if (![scanner scanPast:@"<span class=\"FirstColumnPrompt\">Address:" beforeStrings:stopStrings] ||
          ![scanner scanPast:@"<span class=\"Value\">"])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan address"], nil);
        return;
      }
      if ([scanner scanUpToString:@"</span>" intoString:&s])
        item->address_line_1 = [self clean:s];
     
      
      if (![scanner scanPast:@"<span class=\"Value\">" before:@"<span class=\"FirstColumnPrompt\">"] ||
          ![scanner scanUpToString:@"</span>" intoString:&s])
      {
        block ([MFError errorWithCode:MFErrorScrape format:@"couldn't scan city,state,zip"], nil);
        return;
      }
      /*if we can't get city,state,zip from the scraped line, save it as address_line_2*/
      if (![self parseCityStateZip:(NSString*)s item:item])
      {
        item->address_line_2 = [self clean:s];
      }
    }
  }
  
  [court->items addObject:item];
  [self nextDetailPage:first_name lastName:last_name block:block];
}

-(BOOL)parseCityStateZip:(NSString*)s item:(MDCase*)item
{
  insist (s && item);
//  SILVER SPRING MD 20906
  
  /*trim and get rid of any extra spaces and tags etc*/
  s = [self clean:s];
  
  
  NSArray*components = [s componentsSeparatedByString:@" "];
  if (components.count < 3)
    return NO;
  
  item->address_zip = [components lastObject];
  item->address_state = components [components.count - 2];
  item->address_city = [s substringToString:item->address_state];//weak
  
  return YES;
}

@end
