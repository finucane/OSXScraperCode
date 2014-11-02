//  Created by finucane on 3/14/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

#import "insist.h"
#import "MFNetDataOperation.h"

@implementation MFNetDataOperation

/*NSOperations cannot be re-used, so we make a new operation based on our own details. net has to be set afresh*/
-(MFNetOperation*)retryWithNet:(MFNet*)aNet
{
  insist (aNet && block);
  
  MFNetDataOperation*op = [[MFNetDataOperation alloc] initWithRequest:request net:aNet completionBlock:block];
  insist (op);
  op->numTries = numTries + 1;
  return op;
}
-(BOOL)appendData:(NSData*)someData
{
  insist (self && data && someData);
  [data appendData:someData];
  return YES;
}
-(BOOL)resetData
{
  insist (self);
  
  if (!data)
    data = [[NSMutableData alloc] init];
  insist (data);
  [data setLength:0];
  return YES;
}
-(NSData*)data
{
  return data;
}

@end
