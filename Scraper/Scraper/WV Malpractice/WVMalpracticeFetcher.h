//
//  WVMalpracticeFetcher.h
//  Scraper
//
//  Created by finucane on 3/24/14.
//  Copyright (c) 2014 All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MFLib/MFCsvThing.h>
#import <MFLib/MFNet.h>
#import <MFLib/MFWebPage.h>

//http://www.wvbom.wv.gov/licenseDMDetail.asp?IndividualID=2509#M

@interface WVMalpracticeIncident : NSObject
{
@public
  NSString*malpractice_reason;
  NSString*action_type;
  NSString*loss_date;
  NSString*action_date;
  NSString*amount;
  NSString*insurance_company;
  NSString*file_number;
  NSString*adjudicating_body;
  NSString*case_number;
  NSString*notes;
}
+(NSString*)formatDate:(NSString*)date;
@end


@interface WVMalpractice : MFCsvThing
{
@public
  NSString*license_number;
  NSString*speciality;
  NSString*individual_id;
  NSString*full_name;
  NSString*last_name;
  NSMutableArray*incidents;
}
-(id)init;
-(NSString*)csv;
+(NSString*)csvColumns;
@end

typedef void (^WVMalpracticeBlock)(MFError*error, NSArray*malpractices);

@interface WVMalpracticeFetcher : NSObject
{
@private
  int numFetched;
  MFNet*net;
  NSMutableArray*malpractices;
}

-(id)init;
-(void)fetch:(NSString*)license_number block:(WVMalpracticeBlock)block;

@end
