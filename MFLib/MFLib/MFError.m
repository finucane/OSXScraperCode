//
//  MFError.m
//  Geocoder
//
//  Created by finucane on 3/13/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

#import "MFError.h"
#import "insist.h"
#include <stdarg.h>


NSString*const kMFErrorDomain = @"kMFErrorDomain";

@implementation MFError
+(MFError*)errorWithCode:(int)code description:(NSString*)description
{
  return [MFError errorWithDomain:kMFErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:description}];
}

+(MFError*)errorWithCode:(int)code format:(NSString*)format, ...
{
  va_list args;
  va_start(args, format);
  NSString*description = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);
  return [MFError errorWithCode:code description:description];
}

+(MFError*)errorWithCode:(int)code error:(NSError*)error
{
  return [MFError errorWithDomain:kMFErrorDomain code:code userInfo:error.userInfo];
}

-(NSString*)stringForCode:(MFErrorCode)code
{
  switch (code)
  {
    case MFErrorCancelled: return @"Cancelled";
    case MFErrorConnection: return @"Connection";
    case MFErrorDisconnected: return @"Network Down";
    case MFErrorTimeout: return @"Timeout";
    case MFErrorHttp: return @"Http";
    case MFErrorServer: return @"Server";
    case MFErrorJson: return @"JSON";
    case MFErrorFile: return @"File System";
    case MFErrorSql: return @"SQL";
    case MFErrorScrape: return @"Scrape";
    case MFErrorNotFound: return @"Not Found";

    default:insist (0);
  }
  return @"";
}

+(MFError*)randomError
{
  return [MFError errorWithCode:arc4random_uniform (MFErrorNumErrors - 1) + 1 description:@"Random error."];
}

-(NSString*)localizedDescription
{
  return [NSString stringWithFormat:@"MFError \"%@\" %@", [self stringForCode:(MFErrorCode) self.code], self.userInfo];
}
@end;
