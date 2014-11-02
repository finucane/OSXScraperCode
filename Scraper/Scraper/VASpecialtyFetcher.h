//
//  VASpecialtyFetcher.h
//  Scraper
//
//  Created by Data Entry iMac 1 on 4/7/14.
//  Copyright (c) 2014 All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MFLib/MFCsvThing.h>
#import <MFLib/MFNet.h>

@interface VASpecialtyItem : NSObject
{
  @public
  NSString*specialty_description;
  NSString*specialty_type;
}
@end

@interface VASpecialty : MFCsvThing
{
  @public
  NSString*mf_doctor_id;
  NSString*license_number;
  NSString*full_name;
  NSMutableArray*items;
}
-(id)init;
-(NSString*)csv;
+(NSString*)csvColumns;
@end

typedef void (^VASpecialtyBlock)(MFError*error, VASpecialty*specialty);

@interface VASpecialtyFetcher : NSObject
{
  @public
  MFNet*net;
}

-(id)init;
-(void)fetch:(NSString*)license_number block:(VASpecialtyBlock)block;

@end

