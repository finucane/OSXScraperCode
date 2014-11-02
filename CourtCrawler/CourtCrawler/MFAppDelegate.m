//
//  MFAppDelegate.m
//  CourtCrawler
//
//  Created by Finucane on 4/2/14.
//  Copyright (c) 2014  All rights reserved.
//

#import "MFAppDelegate.h"
#import <MFLib/insist.h>

@implementation MFAppDelegate

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  /*make backing string for log view*/
  logString = [[NSMutableString alloc] init];
  insist (logString);
  
  /*set up defaults*/
  NSUserDefaults*defaults = [NSUserDefaults standardUserDefaults];
  [defaults registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]]];
}

-(void)appendLog:(NSString*)text
{
  insist (text && logString);
  [logString appendString:text];
  [logString appendString:@"\n"];
  [[self logTextView] setString:logString];
}

-(void)clearLog
{
  insist (logString);
  [logString setString:@""];
  [[self logTextView] setString:logString];
}

-(void)inputButton:(id)sender textField:(NSString*)defaultsPathKey textField:(NSTextField*)textField
{
  insist (sender);
  insist (defaultsPathKey && textField);

  NSOpenPanel*panel = [NSOpenPanel openPanel];
  insist (panel);
  
  panel.canChooseDirectories = NO;
  panel.canChooseFiles = YES;
  [sender setEnabled:NO];

  [panel beginWithCompletionHandler:^(NSInteger result) {
    
    [sender setEnabled:YES];

    if (result == NSFileHandlingPanelOKButton)
    {
      insist ([[panel URLs] count]);
      NSURL*url = [panel URLs][0];
      insist ([url isFileURL]);
      
      [[NSUserDefaults standardUserDefaults] setObject:url.path forKey:defaultsPathKey];
      textField.stringValue = url.path;
    }
  }];
}

-(void)outputButton:(id)sender textField:(NSString*)defaultsPathKey textField:(NSTextField*)textField
{
  insist (sender);
  insist (defaultsPathKey && textField);
  
  NSSavePanel*panel = [NSSavePanel savePanel];
  insist (panel);
  
  [sender setEnabled:NO];
  [panel beginWithCompletionHandler:^(NSInteger result) {
    [sender setEnabled:YES];

    if (result == NSFileHandlingPanelOKButton)
    {
      NSURL*url = [panel URL];
      insist ([url isFileURL]);
      
      [[NSUserDefaults standardUserDefaults] setObject:url.path forKey:defaultsPathKey];
      textField.stringValue = url.path;
    }
  }];
}


-(void)progressFormat:(BOOL)log format:(NSString*)format, ...
{
  NSTextField*label = [self progressLabel];
  if (!label)
    return;
  
  /*make string from args*/
  va_list args;
  va_start(args, format);
  NSString*s = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);
  
  dispatch_async(dispatch_get_main_queue(),^{
    [label setStringValue:s];
    if (log)
      [self appendLog:s];
  });
}

/* 
 subclasses should override this if they have a textview to log to,
 or a progress label.
*/

-(NSTextView*)logTextView
{
  return nil;
}
-(NSTextField*)progressLabel
{
  return nil;
}

@end
