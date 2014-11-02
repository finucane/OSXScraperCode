//
//  CTFetcher.h
//  Scraper
//
//  Created by finucane on 3/31/14.
//  Copyright (c) 2014 All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MFLib/MFNet.h>
#import <MFLib/MFWebPage.h>
#import <MFLib/MFCsvThing.h>

//  return @"license_number|full_name|type|date|payment_category|specialty|hospital_name|city|state|country|disciplinary_action|conviction|\n";


@interface CTMalpracticeItem : NSObject
{
  @public
  NSString*type;
  NSString*date;
  NSString*payment_category;
  NSString*specialty;
  NSString*hospital_name;
  NSString*city;
  NSString*state;
  NSString*country;
  NSString*disciplinary_action;
  NSString*conviction;
}
@end

@interface CTMalpractice : MFCsvThing
{
  @public
  NSString*license_number;
  NSString*full_name;
  NSMutableArray*items;
}
-(id)init;
-(NSString*)csv;
+(NSString*)csvColumns;
@end

typedef void (^CTMalpracticeBlock)(MFError*error, CTMalpractice*malpractice);


@interface CTMalpracticeFetcher : NSObject
{
  @private
  MFNet*net;
  MFWebPage*webPage;
}

-(id)init;
-(void)fetch:(NSString*)license_number block:(CTMalpracticeBlock)block;

@end
