//
//  MFNetOperation.h
//  Geocoder
//
//  Created by finucane on 3/13/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MFNetOperation;
@class MFError;
@class MFNet;



typedef void (^MFNetOperationCompletionBlock)(MFNetOperation*);

@interface MFNetOperation : NSOperation <NSURLConnectionDelegate>
{
@private
  NSURLConnection*connection;
  BOOL isFinished;
  BOOL isExecuting;
  
@protected
  MFNetOperationCompletionBlock block;
  int numTries;
  NSURLRequest*request;
  MFError*error;
  MFNet*net;
  NSString*textEncodingName;
}

-(id)initWithRequest:(NSURLRequest*)request net:(MFNet*)net completionBlock:(MFNetOperationCompletionBlock)block;
-(id)initWithUrl:(NSString*)url net:(MFNet*)net completionBlock:(MFNetOperationCompletionBlock)block;
-(MFError*)error;
-(NSMutableArray*)jsonArrayWithError:(MFError*__autoreleasing*)error;
-(NSDictionary*)jsonDictionaryWithError:(MFError*__autoreleasing*)error;
-(NSString*)dataAsString;
-(int)numTries;
-(MFNetOperation*)retryWithNet:(MFNet*)net;
-(NSString*)url;
+(NSString*)stringOfRequest:(NSURLRequest*)req;

/*subclasses should call this on error*/
-(BOOL)die:(int)errorCode description:(NSString*)description;

/*concrete subclasses should override these*/
-(BOOL)appendData:(NSData*)data;
-(BOOL)resetData;
-(NSData*)data;

/*if overriding this call super at end*/
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)anError;

/*setting this to nonzero simulates errors in the entire "Net" module, this is for testing the code. an error rate of 5 means 1 out of 4 times
 operations will fail*/
+(void)setErrorRate:(unsigned)rate;

@end