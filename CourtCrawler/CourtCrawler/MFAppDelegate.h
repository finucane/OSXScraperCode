//
//  MFAppDelegate.h
//  CourtCrawler
//
//  Created by Finucane on 4/2/14.
//  Copyright (c) 2014  All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MFAppDelegate : NSObject <NSApplicationDelegate>
{
  @private
  IBOutlet NSWindow*window;
  NSMutableString*logString;

  @protected
}

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification;
-(void)appendLog:(NSString*)text;
-(void)clearLog;
-(void)progressFormat:(BOOL)log format:(NSString*)format, ...;
-(void)inputButton:(id)sender textField:(NSString*)defaultsPathKey textField:(NSTextField*)textField;
-(void)outputButton:(id)sender textField:(NSString*)defaultsPathKey textField:(NSTextField*)textField;

/*for subclasses to override*/
-(NSTextView*)logTextView;
-(NSTextField*)progressLabel;

@end
