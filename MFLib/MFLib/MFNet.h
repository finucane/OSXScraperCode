//
//  MFNet.h
//  Geocoder
//
//  Created by finucane on 3/13/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

/*
 if the MFNet level cancellation block is ever called with the cancel error, it means the download was cancelled by the user doing cancel.
 
 the error reporting is, in the MFNet completion block, [error code] will an MFError value and [error localizedDescription]
 will contain any extra information that might have been collected.
 
 this code avoids the use of synchronous NSURLConnection calls. one benefit is we can cancel all pending requests as part of
 error handling, or to implement a cancel from the user. another benefit is we can download large files directly to disk.
 
 */

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "MFNetOperation.h"
#import "MFError.h"

typedef void (^MFNetCompletionBlock)(MFError*error);


@interface MFNet : NSObject
{
@public
  unsigned _totalCompleted; //for MFNetOperation to use as a friend
  
@private
  NSOperationQueue*operationQueue;
  unsigned totalSent;
  MFError*originalError;
  MFNetCompletionBlock completionBlock;
  
@protected
  NSTimeInterval timeout;
}


-(id)initWithTimeout:(NSTimeInterval)timeout maxConnections:(int)maxConnections completionBlock:(MFNetCompletionBlock)block;
-(void)cancel;
-(void)addDataURL:(NSURL*)url body:(id)body block:(MFNetOperationCompletionBlock)block;

/*methods for subclasses to use*/
-(int)pending;
-(void)die:(MFErrorCode)code description:(NSString*)description;
-(void)dieWithError:(MFError*)error;
-(void)retry:(MFNetOperation*)op;
-(void)addFileURL:(NSURL*)url path:(NSString*)path body:(id)body block:(MFNetOperationCompletionBlock)block;
-(void)addUploadURL:(NSURL*)url data:(NSData*)data block:(MFNetOperationCompletionBlock)block;
-(id)valueforKey:(NSString*)key dictionary:(NSDictionary*)dict error:(MFError*__autoreleasing*)error;
-(void)callCompletionBlock:(MFError*)error;
-(NSString*)urlEncode:(NSString*)s;


@property (nonatomic) unsigned maxPending;

@end
