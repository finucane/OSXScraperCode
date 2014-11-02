//
//  MFWebPage.h
//  MFLib
//
//  Created by finucane on 3/21/14.
//  Copyright (c) 2014 mf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <MFLib/MFError.h>

/*
 Wrapper around WebView to load a web page, execute js on it, and get html source from it.
 
 the methods with block params are asynchronous and only one can be in progress at a time,
 or it is a programmer error.
 
 currently it is a programmer error to ever use this on a web page that has more than 1 frame.
*/

@class MFWebPage;

typedef void (^WebPageBlock)(MFWebPage*webPage, MFError*error);

/*
 MFWebPageJSBlock is for runJS:tries:delay:block, which is a way to call some js and
 poll, in the background, for a result. this is for web pages that involve AJAX, where
 we never get page reloads to indicate completion of some javascript that triggers
 some aysnch operation (network use).
 
 The block determines if the js result has happened or not.
 
 aWebPage - the webPage.
 timedOut - true if runJS:tries:delay:block timed out. this tells the block code
 of the failure.
 
 returns: true if runJS:tries:delay:block should keep retrying 
 */

typedef BOOL (^MFWebPageJSBlock)(MFWebPage*webPage, BOOL timedOut);

@interface MFWebPage : NSObject
{
  @private
  NSString*url;
  WebView*webView;
  WebPageBlock block;
  MFWebPageJSBlock jsBlock;
  double delay;
  int numTries;
  int maxTries;
}

-(id)initWithURL:(NSString*)url;
-(void)load:(WebPageBlock)block;
-(BOOL)runReloadingJS:(NSString*)jsString block:(WebPageBlock)aBlock;
-(void)runJS:(NSString*)jsString;
-(void)runJSTries:(int)tries delay:(double)delay jsString:(NSString*)jsString block:(MFWebPageJSBlock)block;
-(NSString*)html;
-(DOMDocument*)document;
-(void)dumpDom;
-(DOMNode*)findName:(NSString*)name;
-(BOOL)setName:(NSString*)name value:(NSString*)value;
-(void)setWebView:(WebView*)webView;
@end
