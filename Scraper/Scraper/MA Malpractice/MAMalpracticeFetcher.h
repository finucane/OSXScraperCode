//
//  MAMalpracticeFetcher.h
//  Scraper
//
//  Created by Finucane on 3/20/14.
//  Copyright (c) 2014 All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MFLib/MFWebPage.h>
#import <MFLib/MFCsvThing.h>
#import <MFLib/MFNet.h>

@interface MAMalpracticeIncident : NSObject
{
  @public
  NSString*date_of_payment;
  NSString*category_of_payment;
}
-(NSString*)formattedDate;
@end


@interface MAMalpractice : MFCsvThing
{
  @public
  NSString*license_number;
  NSString*speciality;
  NSString*active_physicians;
  NSString*physicians_with_malpractice;
  NSString*physician_id;
  NSMutableArray*incidents;
}
-(id)init;
-(NSString*)csv;
+(NSString*)csvColumns;
@end

typedef void (^MAMalpracticeBlock)(MFError*error, MAMalpractice*malpractice, NSString*physicianID);

@interface MAMalpracticeFetcher : NSObject
{
  @private
  MFWebPage*webPage;
  MFNet*net;
}

-(id)init;
-(void)fetch:(NSString*)license_number block:(MAMalpracticeBlock)block;

@end
