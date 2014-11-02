//  Created by finucane on 3/14/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

/*subclass of MFNetOperation that writes data to a file. WHen the operation completes the caller should call "close" in
 the completion block to not have to rely on dealloc closing the actual file eventually.
 */

#import "insist.h"
#import "MFNetFileOperation.h"
#import "MFNet.h"

@implementation MFNetFileOperation

-(id)initWithRequest:(NSURLRequest*)aRequest net:(MFNet*)aNet path:(NSString*)aPath completionBlock:(MFNetOperationCompletionBlock)aBlock
{
  insist (aPath && [aPath length]);
  insist (aBlock);
  
  if ((self = [super initWithRequest:aRequest net:aNet completionBlock:aBlock]))
  {
    insist (net);
    
    /*keep the path around for when we try to create a file outside of the initializer, where it's ok to fail*/
    path = aPath;
    
  }
  return self;
}

/*NSOperations cannot be re-used, so we make a new operation based on our own details. net has to be set afresh.*/
-(MFNetOperation*)retryWithNet:(MFNet*)aNet
{
  insist (aNet && block);
  
  MFNetFileOperation*op = [[MFNetFileOperation alloc] initWithRequest:request net:aNet path:path completionBlock:block];
  insist (op);
  op->numTries = numTries + 1;
  return op;
}

-(BOOL)appendData:(NSData*)data
{
  insist (self && data);
  insist (fileHandle);
  
  @try
  {
    
    [fileHandle writeData:data];
  }
  @catch (NSException *exception)
  {
    return [self die:MFErrorFile
         description:[NSString stringWithFormat:@"Couldn't write %lul bytes to %@, reason is %@", (unsigned long)data.length, path, exception.reason]];
  }
  
  return YES;
}

/*get a path to a tmp file for our download*/
-(NSString*)tmpPath
{
  insist (self && path);
  
  NSString*tmpPath = [NSString pathWithComponents:[NSArray arrayWithObjects:NSTemporaryDirectory(), [path lastPathComponent], nil]];
  return tmpPath;
}

-(BOOL)resetData
{
  insist (self && path);
  
  /*create a filehandle to write to, overwriting any existing file*/
  NSString*tmpPath = [self tmpPath];
  insist (tmpPath);
  
  if (![[NSFileManager defaultManager] createFileAtPath:tmpPath contents:nil attributes:nil])
    return [self die:MFErrorFile description:[NSString stringWithFormat:@"Couldn't create %@",path]];
  
  /*get the filehandle*/
  fileHandle = [NSFileHandle fileHandleForWritingAtPath:tmpPath];
  if (!fileHandle)
    return [self die:MFErrorFile description:[NSString stringWithFormat:@"Couldn't open %@",path]];
  
  return YES;
}

-(BOOL)atomicWrite
{
  insist (path && fileHandle);
  
  NSFileManager*fileManger = [NSFileManager defaultManager];
  insist (fileManger);
  
  __autoreleasing NSError*anError;
  __autoreleasing NSURL*dc;
  NSURL*dst = [NSURL fileURLWithPath:path];
  NSURL*src = [NSURL fileURLWithPath:[self tmpPath]];
  insist (dst && src);
  
  /*flush the tmp file*/
  [fileHandle closeFile];
  
  /*try a simple replace. this will fail if the existing file doesn't exist*/
  if ([fileManger replaceItemAtURL:dst withItemAtURL:src backupItemName:nil options:0 resultingItemURL:&dc error:&anError])
  {
    /*ignore this error because we don't care*/
    [fileManger removeItemAtURL:src error:&anError];
    return YES;
  }
  
  /*we don't actually care about the error. the expected error is NSFileNoSuchFileError, when dst doesn't exist, but so what, try another way*/
  [fileManger removeItemAtURL:dst error:&anError];
  
  /*we don't care about that failing either. this is the error we care about:*/
  if (![fileManger moveItemAtURL:dst toURL:src error:&anError])
  {
    error = [MFError errorWithCode:MFErrorFile error:anError];
    return FALSE;
  }
  return YES;
}

/*override the 2 ways NSURL connection should be ending to do some file stuff*/
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  insist (fileHandle);
  
  /*mv the tmp file to the new path. if this fails we will be in the error state and the superclass knows how to handle this.*/
  [self atomicWrite];
  
  /*call this afterwards, it will trigger all the isFinished based completion*/
  [super connectionDidFinishLoading:connection];
}

/*delete the tmp file to be nice, it will be deleted anyway, but possibly not any time soon.*/
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)anError
{
  [[NSFileManager defaultManager] removeItemAtPath:[self tmpPath] error:nil];
  
  /*need to do this to end the NSOperation with all the isFinished stuff*/
  [super connection:connection didFailWithError:anError];
}

@end
