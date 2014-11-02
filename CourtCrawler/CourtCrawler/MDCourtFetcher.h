//
//  MDCourtFetcher.h
//  CourtCrawler
//
//  Created by finucane on 4/3/14.
//  Copyright (c) 2014  All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MFLib/MFNet.h>
#import <MFLib/MFWebPage.h>
#import <MFLib/MFCsvThing.h>

@interface MDCase : NSObject
{
  @public
  NSString*defendant_name;
  NSString*address_line_1;
  NSString*address_line_2;
  NSString*address_line_3;
  NSString*address_city;
  NSString*address_state;
  NSString*address_zip;

  NSString*case_description;
  NSString*allegation;
  NSString*date_filed;
  NSString*date_resolved;

  NSString*case_number;
  NSString*case_link;
  NSString*jurisdiction;
  NSString*amount; //nil
  NSString*case_resolution;
  NSString*pdf_name; //nil
  NSString*data_source;//Maryland Judiciary Case Search
  NSString*capture_date;//2014-03-31
  NSString*person;//nil
  NSString*notes;//nil
  NSString*state;//"MD"
}
@end

@interface MDCourt : MFCsvThing
{
  @public
  NSString*mf_doctor_id;
  NSString*last_name;
  NSString*first_name;
  NSString*middle_name;
  NSMutableArray*items;
}
-(id)init;
-(NSString*)csv;
+(NSString*)csvColumns;

@end

typedef void (^MDCourtBlock)(MFError*error, MDCourt*court);

@interface MDCourtFetcher : NSObject
{
  @public
  MFNet*net;
  MFWebPage*webPage;
  NSArray*caseTypes;
  NSMutableArray*searchUrls;
  NSMutableArray*detailUrls;
  NSMutableArray*dateRanges;
  int urlIndex;
  MDCourt*court;
}
-(id)init;
-(void)fetchFirstName:(NSString*)first_name lastName:(NSString*)last_name block:(MDCourtBlock)block;

@end
