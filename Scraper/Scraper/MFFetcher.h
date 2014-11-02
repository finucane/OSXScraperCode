//
//  MFFetcher.h
//  Scraper
//
//  Created by Finucane on 4/9/14.
//  Copyright (c) 2014 All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MFFetcher : NSObject
{
  @protected
  BOOL busy;
}

-(BOOL)busy;

@end
