//
//  MFWebPage.m
//  MFLib
//
//  Created by finucane on 3/21/14.
//  Copyright (c) 2014 mf. All rights reserved.
//

#import "MFWebPage.h"
#import <MFLib/MFError.h>
#import <MFLib/insist.h>


@implementation MFWebPage

-(id)initWithURL:(NSString*)aUrl
{
  insist (aUrl && aUrl.length);
  
  if ((self = [super init]))
  {
    /*keep the URL so we can call load more than once*/
    url = aUrl;
    
    /*make an invisible WebView and set ourself as its delegate*/
    webView = [[WebView alloc] initWithFrame:NSMakeRect (0,0,0,0) frameName:nil groupName:nil];
    insist (webView);
    
    [webView setFrameLoadDelegate:self];
  }
  return self;
}

/*
 asynchronously load the web page for the url.
 
 block - block to be called when load is done (or when load failed)
 
 returns : nothing.
 */
-(void)load:(WebPageBlock)aBlock
{
  insist (aBlock && !block);
  block = aBlock;
  
  [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
}

/*
 run js code that triggers a new page load, it is a programmer error if
 this js doesn't cause more loading, and the result will be "block"
 never being called.
 
 block - block to be called when load is done (or when load failed)
 
 returns : true if the JS ran ok.
 */

-(BOOL)runReloadingJS:(NSString*)jsString block:(WebPageBlock)aBlock
{
  insist (jsString && jsString.length && aBlock && !block);
  block = aBlock;
  
  /*result is always "" apparently so we can't use it to see if there was an error*/
  [webView stringByEvaluatingJavaScriptFromString:jsString];
  
  return YES;
}


-(void)runJS:(NSString*)jsString
{
  [webView stringByEvaluatingJavaScriptFromString:jsString];
}



/*
  run some javascript and poll web page on the main thread for an expected side effect.
 
  tries - how many times to wait
  delay - delay before each wait, in seconds
  jsString - javascript to run
  block - block to determine if the side effect happened.
*/

-(void)runJSTries:(int)aTries delay:(double)aDelay jsString:(NSString*)jsString block:(MFWebPageJSBlock)aBlock
{
  insist (aTries > 0 && aDelay > 0);
  insist (jsString && jsString.length);
  insist (aBlock);
  
  delay = aDelay;
  maxTries = aTries;
  jsBlock = aBlock;
  numTries = 0;
  
  [self runJS:jsString];
  [self asyncWait];
  
}

-(void)asyncWait
{
  /*if we are out of tries, tell the block to give up*/
  if (numTries > maxTries)
  {
    jsBlock (self, YES);
    return;
  }
  
  numTries++;
  
  /*call the block after a delay*/
  
  dispatch_after (dispatch_time (DISPATCH_TIME_NOW, (uint64)(delay * (double)NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    
    /*if we are not done, retry*/
    if (jsBlock (self, NO))
      [self asyncWait];
  });
}



-(NSString*)html
{
  insist (webView);
  return [webView stringByEvaluatingJavaScriptFromString:@"document.documentElement.outerHTML"];
}

-(DOMDocument*)document
{
  return [[webView mainFrame] DOMDocument];
}

/* 
 dump dom tree to nslog, for debugging.
*/
-(void)dumpDom
{
  DOMDocument*d = [self document];
  
  DOMNodeIterator*iter = [d createNodeIterator:d whatToShow:DOM_SHOW_ALL filter:nil expandEntityReferences:YES];
  DOMNode*n;
  int numNodes = 0;
  while ((n = [iter nextNode]))
  {
    numNodes++;
    NSLog (@"node name: %@ value: %@", n.nodeName, n.nodeValue);
    DOMNamedNodeMap*attributes = n.attributes;
    
    for (unsigned i = 0; i < attributes.length;i++)
    {
      DOMNode*a = [attributes item:i];
      NSLog (@"attribute name: %@ value: %@", a.nodeName, a.nodeValue);
      
    }
  }
  NSLog (@"numNodes was %d", numNodes);
}

/*
 return DOMNode for first element named "name". This is for web pages
 that dont use id's but at least use unique names.
 
  name - name of element
  returns: element or nil of not found.
*/
-(DOMNode*)findName:(NSString*)name
{
  DOMDocument*d = [self document];
  
  DOMNodeIterator*iter = [d createNodeIterator:d whatToShow:DOM_SHOW_ALL filter:nil expandEntityReferences:YES];
  DOMNode*n;
  while ((n = [iter nextNode]))
  {
    //NSLog (@"node name: %@ value: %@", n.nodeName, n.nodeValue);
    DOMNamedNodeMap*attributes = n.attributes;
    DOMNode*found = nil;
    
    for (unsigned i = 0; i < attributes.length;i++)
    {
      DOMNode*a = [attributes item:i];
      if ([a.nodeName isEqualToString:@"name"] && [a.nodeValue isEqualToString:name])
        found = n;
      //NSLog (@"attribute name: %@ value: %@", a.nodeName, a.nodeValue);
      
    }
    if (found)
      return found;
  }
  return nil;
}

/*
 set the value of an element.
 
 name - name of element
 value - new value
 
 returns: no if the element couldn't be found.
*/

-(BOOL)setName:(NSString*)name value:(NSString*)value
{
  DOMNode*n = [self findName:name];

  if (!n)
    return NO;
  
  DOMNamedNodeMap*attributes = n.attributes;
  for (unsigned i = 0; i < attributes.length;i++)
  {
    DOMNode*a = [attributes item:i];
    //NSLog (@"attribute name: %@ value: %@", a.nodeName, a.nodeValue);

    if ([a.nodeName isEqualToString:@"value"])
    {
      a.nodeValue = value;
      return YES;
    }
  }
  return NO;
}
-(void)setWebView:(WebView*)aWebView
{
  insist (aWebView);
  webView = aWebView;
  [webView setFrameLoadDelegate:self];

}
#pragma - WebFrameLoadDelegate methods

/*
 in these methods we nil the block ivar before calling the block. we do this so our assertions for non-concurrency work
*/

- (void)webView:(WebView*)sender didFailLoadWithError:(NSError*)error forFrame:(WebFrame*)frame
{
  insist (frame == [webView mainFrame]);
  
  WebPageBlock tmpBlock = block;
  block = nil;
  
  tmpBlock (self, [MFError errorWithCode:MFErrorConnection error:error]);
}

- (void)webView:(WebView*)sender didFinishLoadForFrame:(WebFrame*)frame
{
  insist (frame == [webView mainFrame]);
  
  WebPageBlock tmpBlock = block;
  block = nil;
  
  tmpBlock (self, nil);
}
- (void)webView:(WebView*)sender didFailProvisionalLoadWithError:(NSError*)error forFrame:(WebFrame*)frame
{
  insist (frame == [webView mainFrame]);
  
  WebPageBlock tmpBlock = block;
  block = nil;
  
  tmpBlock (self, [MFError errorWithCode:MFErrorConnection error:error]);
}
@end
