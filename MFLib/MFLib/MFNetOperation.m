//
//  MFNetOperation.m
//  Geocoder
//
//  Created by finucane on 3/13/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//


/*
 MFNetOperation calls the completion block when the network transfer finishes or fails or is cancelled.
 in the cancel or error case, error is set like described in MFNet.h, otherwise it is nil, which
 means success.
 
 so the completion block should check [netOperation error].
 
 subclasses should implement resetData and appendData, and on any error these should call
 dieWithError:description and return NO.
 */
#import "insist.h"
#import "MFNet.h"
#import "MFNetOperation.h"
#import <stdlib.h>

static unsigned errorRate = 0;

@implementation MFNetOperation

-(id)initWithRequest:(NSURLRequest*)aRequest net:(MFNet*)aNet completionBlock:(MFNetOperationCompletionBlock)aBlock
{
  insist (aRequest);
  insist (aBlock);
  
  if (self = [super init])
  {
    /*save the request and block for retry*/
    request = aRequest;
    block = aBlock;
    numTries = 1;
    
    __unsafe_unretained MFNetOperation*myself = self;
    
    self.completionBlock = ^{
      
      /*implement "friend" functionality without the "friend" keyword.*/
      myself->net->_totalCompleted++;
      
      aBlock (myself);
      
      /*this is actually safe*/
      myself->net = nil;
    };
    
    /*initialize the variables we are using to implement the NSOperation state properties.*/
    isExecuting = isFinished = NO;
    
    /*keep a link to the net to prevent it from being deallocated*/
    net = aNet;
  }
  return self;
  
}
-(id)initWithUrl:(NSString*)url net:(MFNet*)aNet completionBlock:(MFNetOperationCompletionBlock)aBlock
{
  return [self initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]] net:aNet completionBlock:aBlock];
}

-(NSString*)url
{
  return [[request URL] absoluteString];
}
-(MFError*)error
{
  return error;
}

-(NSString*)dataAsString
{
  NSString*s = [[NSString alloc] initWithData:[self data] encoding:NSUTF8StringEncoding];
  if (s)
    return s;
  NSStringEncoding encoding = NSASCIIStringEncoding;
  
  if (textEncodingName)
    encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef)textEncodingName));
  s =  [[NSString alloc] initWithData:[self data] encoding:encoding];
  return s;
  
}


+(void)setErrorRate:(unsigned)rate
{
  errorRate = rate;
}

/*get the count of how many times this operation, in any of its incarnations, has been run*/
-(int)numTries
{
  return numTries;
}

/*should be overridden*/
-(MFNetOperation*)retryWithNet:(MFNet*)aNet
{
  insist (0);
  return NO;
}
-(BOOL)appendData:(NSData*)data
{
  insist (0);
  return NO;
}
-(BOOL)resetData
{
  insist (0);
  return NO;
}
-(NSData*)data
{
  insist (0);
  return nil;
}

-(id)jsonOfClass:(Class)class options:(NSJSONReadingOptions)options error:(MFError*__autoreleasing*)anError
{
  insist (self && anError);
  NSData*data = [self data];
  insist (data);
  
  //AppLog (@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
  
  __autoreleasing NSError*jsonError;
  id json = [NSJSONSerialization JSONObjectWithData:data options:options error:&jsonError];
  if (!json)
  {
    *anError = [MFError errorWithCode:MFErrorJson error:jsonError];
    return nil;
  }
  if (![json isKindOfClass:class])
  {
    /*on empty arrays, NSJSONSerialization will not return a mutable array even though we asked for one. work around that here.
     we don't ever ask for mutable dictionaries so we don't need to worry about that case.
     */
    if (class == [NSMutableArray class] && [json isKindOfClass:[NSArray class]] && [json count] == 0)
    {
      return [[NSMutableArray alloc] initWithArray:json];
    }
    
    *anError = [MFError errorWithCode:MFErrorJson description:[NSString stringWithFormat:@"Bad JSON root container class, json is %@:", json]];
    return nil;
  }
  return json;
}

-(NSMutableArray*)jsonArrayWithError:(MFError*__autoreleasing*)anError
{
  return [self jsonOfClass:[NSMutableArray class] options:NSJSONReadingMutableContainers error:anError];
}

-(NSDictionary*)jsonDictionaryWithError:(MFError*__autoreleasing*)anError
{
  return [self jsonOfClass:[NSDictionary class] options:0 error:anError];
}

-(BOOL)die:(int)errorCode description:(NSString*)description
{
  /*remember the error*/
  error = [MFError errorWithCode:errorCode description:description];
  
  /*cancel the operation*/
  [self cancel];
  
  /*in case callers want to use this method to return from a method*/
  return NO;
}

#pragma - mark all this stuff is necessary in subclassing NSOperation

/*helper functions to deal w/ keeping the NSOperation KVO stuff sane*/
-(void)setIsExecuting:(BOOL)v
{
  [self willChangeValueForKey:@"isExecuting"];
  isExecuting = v;
  [self didChangeValueForKey:@"isExecuting"];
}
-(void)setIsFinished:(BOOL)v
{
  [self willChangeValueForKey:@"isFinished"];
  isFinished = v;
  [self didChangeValueForKey:@"isFinished"];
}

/*
 we have to periodically check and see if the NSOperation was cancelled. here's where we do it.
 update all the KVO state and actually cancel the connection too if we have to. return YES
 if we were cancelled.
 */
-(BOOL)checkCancelled
{
  if (self.isCancelled)
  {
    /*cancel the connection, no matter what state it was in. connection might be nil. we will never
     get any NSURLConnection delegate call after this, however we are being called from inside one
     and that means we'll call the completion block here and also break out of our runloop. since the
     network activity is an input source.
     */
    
    [connection cancel];
    
    /*throw away any data*/
    [self resetData];
    
    error = [MFError errorWithCode:MFErrorCancelled description:@"Cancelled"];
    
    /*update all the KVO stuff*/
    
    [self setIsExecuting:NO];
    [self setIsFinished:YES];
    
    return YES;
  }
  return NO;
}

#pragma mark - NSOperation methods. subclasses of this thing have to be careful to maintain all the KVO stuff

/*
 since we are using a synchronous request, we do the "concurrent" flavor of NSOperation, that means overriding 4 state functions
 instead of just overriding main.
 */

- (BOOL)isConcurrent
{
  return YES;
}
- (BOOL)isExecuting
{
  return isExecuting;
}
- (BOOL)isFinished
{
  return isFinished;
}

- (void)start
{
  /*check to see if we were cancelled, we might have no work to do at all*/
  if ([self checkCancelled])
    return;
  
  /*make sure we have storage*/
  if (![self resetData])
    return;
  
  [self setIsExecuting:YES];
  [self setIsFinished:NO];
  
  /*get a connection and start it up on the current thread's run loop. probably just using the main thread is ok here too, it's all just a select call.*/
  connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
  
  [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
  [connection start];
  
  while(!self.isFinished)
  {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
  }
}


#pragma mark - required NSURLConnectionDelegate methods.

/*every time we get a peep out of the connection, make sure to check to see if the NSOperation part of us was cancelled*/

- (NSCachedURLResponse *)connection:(NSURLConnection *)aConnection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
  insist (self && connection && connection == aConnection);
  
  /*check to see if the NSOperation was cancelled*/
  if ([self checkCancelled])
    return nil;
  
  return nil;
}
- (NSURLRequest *)connection:(NSURLConnection *)aConnection willSendRequest:(NSURLRequest *)aRequest redirectResponse:(NSURLResponse *)redirectResponse
{
  insist (self && connection && connection == aConnection);
  
  /*check to see if the NSOperation was cancelled*/
  if ([self checkCancelled])
    return nil;
  
  return redirectResponse ? nil : aRequest;
}


+(NSString*)stringOfRequest:(NSURLRequest*)req
{
  NSMutableString*s = [[NSMutableString alloc] init];
  [s appendFormat:@"url: %@\n\n", [req.URL absoluteString]];
  [s appendFormat:@"http method: %@\n\n", req.HTTPMethod];
  [s appendFormat:@"header dictionary: %@\n\n", req.allHTTPHeaderFields];
  [s appendFormat:@"body: %@", [[NSString alloc] initWithData:req.HTTPBody encoding:NSUTF8StringEncoding]];
  
  return s;
}

- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)aResponse
{
  insist (self && connection && connection == aConnection && aResponse);
  
  NSHTTPURLResponse*response = (NSHTTPURLResponse*)aResponse;
  
  /*check to see if the NSOperation was cancelled*/
  if ([self checkCancelled])
    return;
  
  /*forget any data we might have got before, we might be here on a redirect*/
  if (![self resetData])
    return;
  
  /*check for http response error. if there's an error, end the operation*/
  
  if (response.statusCode >= 400)
  {
    error = [MFError errorWithCode:MFErrorHttp
                       description:[NSString stringWithFormat:@"status code %ld, URL:%@", (long)response.statusCode, response.URL.absoluteString]];
    
    [connection cancel];
    [self setIsExecuting:NO];
    [self setIsFinished:YES];
  }
  
  /*remember textEncodingName*/
  NSString*s = [response textEncodingName];
  if (s)
    textEncodingName = s;
}

- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)data
{
  insist (self && connection && connection == aConnection && data);
  
  /*check to see if the NSOperation was cancelled*/
  if ([self checkCancelled])
    return;
  
  /*accumulate the new chunk of data*/
  if (![self appendData:data])
    return;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  if (errorRate && arc4random_uniform (errorRate) == 0)
  {
    error = [MFError randomError];
  }
  /*all done.*/
  [self setIsExecuting:NO];
  [self setIsFinished:YES];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)anError
{
  insist (self && anError);
  
  /*translate timeouts and network down errors here, the rest pass up.*/
  
  MFErrorCode code = MFErrorConnection;
  
  if (anError.domain == NSURLErrorDomain && anError.code == NSURLErrorTimedOut)
    code = MFErrorTimeout;
  else if (anError.domain == NSURLErrorDomain && anError.code == NSURLErrorNotConnectedToInternet)
    code = MFErrorDisconnected;
  
  error = [MFError errorWithCode:code error:anError];
  
  [self resetData];
  
  [self setIsExecuting:NO];
  [self setIsFinished:YES];
}


@end
