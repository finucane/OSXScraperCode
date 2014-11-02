//
//  MESpecialtyFetcher.h
//  Scraper
//
//  Created by finucane on 3/25/14.
//  Copyright (c) 2014 All rights reserved.
//

/*
 
 
 Hi David,
 
 Here is the Maine state board link:
 
 http://www.pfr.maine.gov/ALMSOnline/ALMSQuery/SearchIndividual.aspx?Board=376&AspxAutoDetectCookieSupport=1
 
 The table with each license number for ME is in the attached SQLite database.
 
 I will need a csv back with the following columns populated:
 
 license_number
 last_name
 full_name
 status
 expiration_date
 specialty_description
 specialty_origin

 
 
*/

#import <Foundation/Foundation.h>
#import <MFLib/MFNet.h>
#import <MFLib/MFWebPage.h>
#import <MFLib/MFCsvThing.h>
#import <MFLib/MFWebPage.h>

@interface MESpecialtyItem : NSObject
{
@public
  NSString*specialty_description;
  NSString*specialty_origin;
}
@end


@interface MESpecialty : MFCsvThing
{
@public
  NSString*license_number;
  NSString*full_name;
  NSString*last_name;
  NSString*status;
  NSString*expiration_date;
  NSMutableArray*items;
}
-(id)init;
-(NSString*)csv;
+(NSString*)csvColumns;
+(NSString*)formatDate:(NSString*)date;

@end

typedef void (^MESpecialtyBlock)(MFError*error, MESpecialty*specialty);

@interface MESpecialtyFetcher : NSObject
{
  @private
  MFWebPage*webPage;
  MFNet*net;
}

-(id)init;
-(void)fetch:(NSString*)license_number block:(MESpecialtyBlock)block;

@end
