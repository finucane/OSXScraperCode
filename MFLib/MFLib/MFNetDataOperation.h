//  Created by finucane on 3/14/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

#import "MFNetOperation.h"

@interface MFNetDataOperation : MFNetOperation
{
    @private
    NSMutableData*data;
}

-(MFNetOperation*)retryWithNet:(MFNet*)aNet;
-(BOOL)appendData:(NSData*)data;
-(BOOL)resetData;
-(NSData*)data;

@end
