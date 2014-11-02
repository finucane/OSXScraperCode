//  Created by finucane on 3/14/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

#import "MFNetOperation.h"

@interface MFNetFileOperation : MFNetOperation
{
    @private
    NSFileHandle*fileHandle;
    NSString*path;
}
-(id)initWithRequest:(NSURLRequest*)request net:(MFNet*)aNet path:(NSString*)aPath completionBlock:(MFNetOperationCompletionBlock)block;
-(BOOL)appendData:(NSData*)data;
-(BOOL)resetData;
-(MFNetOperation*)retryWithNet:(MFNet*)aNet;

@end
