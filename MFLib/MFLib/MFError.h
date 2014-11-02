//
//  MFError.h
//  Geocoder
//
//  Created by finucane on 3/13/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MFError : NSError

+(MFError*)errorWithCode:(int)code description:(NSString*)description;
+(MFError*)errorWithCode:(int)code format:(NSString*)format, ...;
+(MFError*)errorWithCode:(int)code error:(NSError*)error;
+(MFError*)randomError;

typedef enum MFErrorCode
{
  MFErrorCancelled = 0,
  MFErrorConnection,
  MFErrorDisconnected,
  MFErrorTimeout,
  MFErrorHttp,
  MFErrorServer,
  MFErrorJson,
  MFErrorFile,
  MFErrorSql,
  MFErrorScrape,
  MFErrorNotFound,
  MFErrorNumErrors,
}MFErrorCode;

extern NSString*const kMFErrorDomain;
@end
