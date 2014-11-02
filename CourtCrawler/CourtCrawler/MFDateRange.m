//
//  DateRange.m
//  CourtCrawler
//
//  Created by finucane on 4/7/14.
//  Copyright (c) 2014  All rights reserved.
//

#import "MFDateRange.h"
#import <MFLib/insist.h>

@implementation MFDateRange

/*
 intialize a date range starting from startDate and ending now.
 format defines how the date strings look, for the startDate parameter
 and the firstDate and lastDate methods.
 
 format - a date format string, for instance "MM/DD/YYYY".
 startDate - the lower bound of the date range
 */
-(id)initWithFormat:(NSString*)format startDate:(NSString*)startDate
{
  if ((self = [super init]))
  {
    formatter = [[NSDateFormatter alloc] init];
    insist (formatter);
    
    [formatter setDateFormat:format];
    firstDate = [formatter dateFromString:startDate];
    lastDate = [NSDate date];
  }
  return self;
}

-(id)initWithFormatter:(NSDateFormatter*)aFormatter a:(NSDate*)a b:(NSDate*)b
{
  insist (aFormatter && a && b);
  
  if ((self = [super init]))
  {
    formatter = aFormatter;
    firstDate = a;
    lastDate = b;
  }
  return self;
}
-(NSString*)firstDate
{
  insist (formatter);
  return [formatter stringFromDate:firstDate];
}
-(NSString*)lastDate
{
  insist (formatter);
  return [formatter stringFromDate:lastDate];
  
}
/*
 subdivide the date range into 2 equal parts
 returns:array of 2 ranges that add up to the original range
 */
-(NSArray*)divide
{
  NSTimeInterval distance = [lastDate timeIntervalSinceDate:firstDate];
  distance = distance/2.0;
  
  NSDate*midPoint = [firstDate dateByAddingTimeInterval:distance];
  
  /*get the next day after middate so we don't overlap*/
  
  NSDate*midPointNext = [midPoint dateByAddingTimeInterval:60 * 60 * 24];
  
  return
  @[
    [[MFDateRange alloc]initWithFormatter:formatter a:firstDate b:midPoint],
    [[MFDateRange alloc]initWithFormatter:formatter a:midPointNext b:lastDate]
    ];
}

-(BOOL)equals:(MFDateRange*)other
{
  return [[self firstDate] isEqualToString:[other firstDate]] && [[self lastDate] isEqualToString:[other lastDate]];
}

+(void)dump:(NSArray*)dates
{
  insist (dates);
  NSMutableString*mutable = [[NSMutableString alloc] init];
  insist (mutable);
  
  for (MFDateRange*dr in dates)
    [mutable appendFormat:@"[%@,%@]", [dr firstDate], [dr lastDate]];
  NSLog (@"%@", mutable);
}

@end
