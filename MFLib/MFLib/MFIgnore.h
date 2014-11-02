//
//  MFIgnore.h
//  CourtCrawler
//
//  Created by finucane on 4/3/14.
//  Copyright (c) 2014  All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MFLib/MFDB.h>

@interface MFIgnore : NSObject
{
  @public
  MFDB*db;
}
-(BOOL)reset:(int)which remember:(BOOL)remember error:(MFError*__autoreleasing*)error;
-(BOOL)update:(NSString*)tag error:(MFError*__autoreleasing*)error;
-(BOOL)ignore:(NSString*)tag result:(BOOL*)result error:(MFError*__autoreleasing*)error;

@end
