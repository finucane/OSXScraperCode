//
//  DateRange.h
//  CourtCrawler
//
//  Created by finucane on 4/7/14.
//  Copyright (c) 2014  All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MFDateRange : NSObject
{
  @private
  NSDateFormatter*formatter;
  NSDate*firstDate;
  NSDate*lastDate;
}

-(id)initWithFormat:(NSString*)format startDate:(NSString*)startDate;
-(NSString*)firstDate;
-(NSString*)lastDate;
-(NSArray*)divide;
-(BOOL)equals:(MFDateRange*)other;
+(void)dump:(NSArray*)dates;

@end
