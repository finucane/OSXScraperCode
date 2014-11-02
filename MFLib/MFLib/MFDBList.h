//
//  MFDBList.h
//  Geocoder
//
//  Created by Finucane on 3/20/14.
//  Copyright (c) 2014  All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MFLib/MFTempDB.h>

@interface MFDBList : NSObject
{
  @protected
  MFTempDB*tempDB;
}
-(id)initWithPath:(NSString*)path;
-(NSArray*)getMore:(int)count;
-(id)getOneMore;
-(void)end;
-(int)countError:(NSError* __autoreleasing*)error;

/*for subclases to override*/
- (id)parseRow;

@end
