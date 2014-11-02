//
//  AppDelegate.h
//  Scraper
//
//  Created by Finucane on 3/20/14.
//  Copyright (c) 2014 All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MFLib/MFDoctorLicenseList.h>
#import <MFLib/MFIgnore.h>
#import "MAMalpracticeFetcher.h"
#import "WVMalpracticeFetcher.h"
#import "MESpecialtyFetcher.h"
#import "GAMalpracticeFetcher.h"
#import "CTMalpracticeFetcher.h"
#import "VASpecialtyFetcher.h"
#import <WebKit/WebKit.h>

void AppLog(NSString*format,...);

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
  @private
  MFDB*db; //for updating
  MFIgnore*ignore;
  MAMalpracticeFetcher*maMalpracticeFetcher;
  WVMalpracticeFetcher*wvMalpracticeFetcher;
  MESpecialtyFetcher*meSpecialtyFetcher;
  CTMalpracticeFetcher*ctMalpracticeFetcher;
  VASpecialtyFetcher*vaSpecialtyFetcher;
  
  NSMutableArray*fetchers;
  
  MFDoctorLicenseList*licenseList;
  NSMutableString*logString;
  NSOutputStream*outputStream;
  int stepSize;
  int delay;
  int numLicenses;
  int licenseIndex;
  int numNotFound;
  
  IBOutlet NSWindow *window;
  IBOutlet NSTextField*inputTextField;
  IBOutlet NSTextField*outputTextField;
  IBOutlet NSButton*inputButton;
  IBOutlet NSButton*outputButton;
  IBOutlet NSButton*scrapeButton;
  IBOutlet NSPopUpButton*scrapePopupButton;
  IBOutlet NSProgressIndicator*progressIndicator;
  IBOutlet NSSlider*stepSlider;
  IBOutlet NSTextField*stepLabel;
  IBOutlet NSStepper*delayStepper;
  IBOutlet NSTextField*delayLabel;
  IBOutlet NSTextView*logTextView;
  IBOutlet NSButton*clearButton;
  IBOutlet NSTextField*statusLabel;
  IBOutlet NSButton*appendCheckButton;
  IBOutlet NSButton*rememberDoNotScrapesCheckButton;
}

-(IBAction)inputButtonAction:(id)sender;
-(IBAction)outputButtonAction:(id)sender;
-(IBAction)scrapeButtonAction:(id)sender;
-(IBAction)stepSliderAction:(id)sender;
-(IBAction)delayStepperAction:(id)sender;
-(IBAction)clearButtonAction:(id)sender;
-(IBAction)scrapePopupButtonAction:(id)sender;
-(IBAction)appendCheckButtonAction:(id)sender;
-(IBAction)rememberDoNotScrapesCheckButtonAction:(id)sender;

-(void)appendLog:(NSString*)text;
-(void)clearLog;

@end
