//
//  MFNet.m
//  Geocoder
//
//  Created by finucane on 3/13/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

#import "insist.h"
#import <CoreData/CoreData.h>
#import "MFNet.h"
#import "MFNetOperation.h"
#import "MFNetDataOperation.h"
#import "MFNetFileOperation.h"
#import <stdlib.h>

/*default value for this, to limit the size of the queue*/
#define MAX_PENDING 32000

@implementation MFNet


-(id)initWithTimeout:(NSTimeInterval)aTimeout maxConnections:(int)maxConnections completionBlock:(MFNetCompletionBlock)block
{
  insist (block);
  
  if (self = [super init])
  {
    operationQueue = [[NSOperationQueue alloc] init];
    insist (operationQueue);
    
    /*save a bunch of parameters*/
    timeout = aTimeout;
    operationQueue.maxConcurrentOperationCount = maxConnections;
    completionBlock = block;
    
    totalSent = _totalCompleted = 0;
    _maxPending = MAX_PENDING;
  }
  return self;
}


/*for anyone to cancel with.*/
-(void)cancel
{
  insist (self && operationQueue);
  insist ([NSThread isMainThread]);
  
  [operationQueue cancelAllOperations];
  
  originalError = [MFError errorWithCode:MFErrorCancelled description:@""];
}

-(int)pending
{
  insist (totalSent >= _totalCompleted);
  return totalSent - _totalCompleted;
}

/*this is to make sure the cancel logic is always followed by subclasses, since it's required to
 deal with draining the operation queue and returning the actual error to the upper layers
 */
-(void)callCompletionBlock:(MFError*)error
{
  insist (completionBlock);
  completionBlock (originalError ? originalError : error);
  completionBlock = nil;
}

-(void)dieWithError:(MFError*)error
{
  insist ([NSThread isMainThread]);
  
  /*if we are the real error, handle it here. everything else is a side effect of the first error or a cancel call*/
  if (error.code != MFErrorCancelled)
  {
    /*give up on whatever we might have been planning on doing*/
    [operationQueue cancelAllOperations];
    
    /*remember the actual error*/
    originalError = error;
  }
  
  insist (originalError);
  /*call completion block if the operation queue is drained*/
  if ([self pending] == 0)
    [self callCompletionBlock:originalError];
}
-(void)die:(MFErrorCode)code description:(NSString*)description
{
  [self dieWithError:[MFError errorWithCode:code description:description]];
}

/*make a json request, with some optional array/dictionary stuff to attach as json*/
-(NSURLRequest*)requestWithUrl:(NSURL*)url body:(id)body
{
  insist (url);
  
  NSMutableURLRequest*request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:timeout];
  
  if (body)
  {
    insist ([body isKindOfClass:[NSArray class]] || [body isKindOfClass:[NSDictionary class]]);
    
    __autoreleasing NSError *dc = nil;
    NSData*json = [NSJSONSerialization dataWithJSONObject:body options:0 error:&dc];
    insist (json);
    
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
    
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody: json];
  }
  return request;
}

/*make an upload request*/
-(NSURLRequest*)requestWithUrl:(NSURL*)url data:(NSData*)data
{
  insist (url && data);
  
  NSMutableURLRequest*request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:timeout];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  [request setHTTPMethod: @"POST"];
  
  NSString*boundary = @"---------------------------114782935826962";
  NSString*contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
  [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
  
  NSMutableData*body = [NSMutableData data];
  [body appendData:[[NSString stringWithFormat:@"--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  [body appendData:[@"Content-Disposition: form-data; name=\"param1\"; filename=\"thefilename\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  [body appendData:data];
  [body appendData:[[NSString stringWithFormat:@"r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  [request setHTTPBody:body];
  return request;
}


/*op can only be an op created by one of the "add" functions below.*/
-(void)retry:(MFNetOperation*)op
{
  insist (op);
  insist (op.numTries > 1);
  totalSent++;
  [operationQueue addOperation:op];
}

/*
 these 2 methods are only for internal use, because they assume timeout has been set in the request.
 */

-(void)addDataRequest:(NSURLRequest*)request block:(MFNetOperationCompletionBlock)block
{
  MFNetDataOperation*op = [[MFNetDataOperation alloc] initWithRequest:request net:self completionBlock:block];
  insist (op);
  totalSent++;
  [operationQueue addOperation:op];
  
  //AppLog (@"%@", [MFNetOperation stringOfRequest:request]);
}
-(void)addFileRequest:(NSURLRequest*)request path:(NSString*)path block:(MFNetOperationCompletionBlock)block
{
  MFNetFileOperation*op = [[MFNetFileOperation alloc] initWithRequest:request net:self path:path completionBlock:block];
  insist (op);
  totalSent++;
  [operationQueue addOperation:op];
}

/*these 4 are the only way to actually send any requests in all of the MFNet stuff*/
-(void)addDataURL:(NSURL*)url body:(id)body block:(MFNetOperationCompletionBlock)block
{
  [self addDataRequest:[self requestWithUrl:url body:body] block:block];
}

-(void)addFileURL:(NSURL*)url path:(NSString*)path body:(id)body block:(MFNetOperationCompletionBlock)block
{
  [self addFileRequest:[self requestWithUrl:url body:body] path:path block:block];
}

-(void)addUploadURL:(NSURL*)url data:(NSData*)data block:(MFNetOperationCompletionBlock)block
{
  NSURLRequest*request = [self requestWithUrl:url data:data];
  insist (request);
  
  [self addDataRequest:request block:block];
}

-(id)valueforKey:(NSString*)key dictionary:(NSDictionary*)dict error:(MFError*__autoreleasing*)error
{
  insist (self && key && dict && error);
  
  id v;
  v = [dict valueForKey:key];
  if (!v)
  {
    *error = [MFError errorWithCode:MFErrorJson description:[NSString stringWithFormat:@"Missing key %@, json is:%@", key, dict]];
    return nil;
  }
  return v;
}

-(NSString*)urlEncode:(NSString*)s
{
  
  CFStringRef encoded = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                      (CFStringRef)s,
                                                                      NULL,
                                                                      CFSTR(":/?#[]@!$&'()*+,;="),
                                                                      kCFStringEncodingUTF8);
  
  return (NSString*)CFBridgingRelease (encoded);
}


@end
