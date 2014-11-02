//
//  AppDelegate.h
//  CourtCrawler
//
//  Created by finucane on 4/2/14.
//  Copyright (c) 2014  All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MFLib/MFIgnore.h>
#import "MFAppDelegate.h"
#import "MFDoctorList.h"
#import "MDCourtFetcher.h"

@interface AppDelegate : MFAppDelegate
{
  @private
  MFDB*db;
  MDCourtFetcher*mdCourtFetcher;
  MFIgnore*ignore;
  NSOutputStream*outputStream;
  MFDoctorList*doctorList;
  int doctorIndex;
  int numDoctors;
  int numNotFound;
  
  IBOutlet NSButton*inputButton;
  IBOutlet NSButton*outputButton;
  IBOutlet NSTextView*textView;
  IBOutlet NSButton*clearButton;
  IBOutlet NSButton*startButton;
  IBOutlet NSProgressIndicator*progressIndicator;
  IBOutlet NSTextField*inputTextField;
  IBOutlet NSTextField*outputTextField;
  IBOutlet NSTextField*progressLabel;
  IBOutlet NSButton*ignoreCheckButton;
  IBOutlet NSButton*appendCheckButton;
}

-(IBAction)inputButton:(id)sender;
-(IBAction)outputButton:(id)sender;
-(IBAction)clearButton:(id)sender;
-(IBAction)startButton:(id)sender;
-(IBAction)appendCheckButton:(id)sender;
-(IBAction)ignoreCheckButton:(id)sender;
@end
