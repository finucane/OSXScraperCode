
//  GAMalpracticeFetcher.h
//  Scraper
//
//  Created by finucane on 3/26/14.
//  Copyright (c) 2014 All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MFLib/MFCsvThing.h>
#import <MFLib/MFNet.h>
#import <MFLib/MFWebPage.h>
#import "MFFetcher.h"

@interface GAMalpracticeItem : NSObject
{
  @public
  NSString*type;
  NSString*date;
  NSString*amount;
  NSString*description_of_offense;
  NSString*jurisdiction;
  NSString*specialty_board;
  NSString*specialty_description;
}
@end


@interface GAMalpractice : MFCsvThing
{
@public
  NSString*license_number;
  NSString*last_name;
  NSString*full_name;
  NSString*specialty;//from search results page
  NSString*designation;
  NSMutableArray*items;
}
-(id)init;
-(NSString*)csv;
+(NSString*)csvColumns;
@end

typedef void (^GAMalpracticeBlock)(MFError*error, GAMalpractice*malpractice);

@interface GAMalpracticeFetcher : MFFetcher
{
  @private
  MFNet*net;
  MFWebPage*webPage;
}

-(id)init;
-(void)fetch:(NSString*)license_number block:(GAMalpracticeBlock)block;

@end
