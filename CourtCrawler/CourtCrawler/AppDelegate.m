//
//  AppDelegate.m
//  CourtCrawler
//
//  Created by finucance on 4/2/14.
//  Copyright (c) 2014  All rights reserved.
//

#import "AppDelegate.h"
#import <MFLib/insist.h>
#import <MFLib/MFError.h>

#define DEFAULTS_INPUT_PATH_KEY @"InputPath"
#define DEFAULTS_OUTPUT_PATH_KEY @"OutputPath"
#define DEFAULTS_APPEND_KEY @"Append"
#define DEFAULTS_IGNORE_KEY @"Ignore"
#define NOT_FOUND_SOURCE_INDEX_KEY @"Not Found"
#define FOUND_SOURCE_INDEX_KEY @"Found"

@implementation AppDelegate

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  [super applicationDidFinishLaunching:aNotification];
  
  NSUserDefaults*defaults = [NSUserDefaults standardUserDefaults];

  /*set up controls etc from defaults. MFApplication superclass has already registered defaults from Defaults.plist*/
  inputTextField.stringValue = [defaults stringForKey:DEFAULTS_INPUT_PATH_KEY];
  outputTextField.stringValue = [defaults stringForKey:DEFAULTS_OUTPUT_PATH_KEY];
  [appendCheckButton setState: [defaults integerForKey:DEFAULTS_APPEND_KEY] ? NSOnState : NSOffState];
  [ignoreCheckButton setState: [defaults integerForKey:DEFAULTS_IGNORE_KEY] ? NSOnState : NSOffState];

  /*make ignore db*/
  ignore = [[MFIgnore alloc] init];
  insist (ignore);
}

-(void)setEnabled:(BOOL)enabled
{
  insist (inputButton && outputButton);
  
  dispatch_async(dispatch_get_main_queue(),^{
    
    [inputButton setEnabled:enabled];
    [outputButton setEnabled:enabled];
    [startButton setEnabled:enabled];
  });
}

-(void)setProgress:(BOOL)on
{
  dispatch_async(dispatch_get_main_queue(),^{
    
    if (on)
      [progressIndicator startAnimation:self];
    else
      [progressIndicator stopAnimation:self];
  });
}
-(NSTextView*)logTextView
{
  return textView;
}

-(NSTextField*)progressLabel
{
  return progressLabel;
}


-(IBAction)appendCheckButton:(id)sender
{
  insist (sender == appendCheckButton);
  [[NSUserDefaults standardUserDefaults] setInteger:appendCheckButton.state == NSOnState ? 1 : 0 forKey:DEFAULTS_APPEND_KEY];
}

-(IBAction)ignoreCheckButton:(id)sender
{
  insist (sender == ignoreCheckButton);
  [[NSUserDefaults standardUserDefaults] setInteger:ignoreCheckButton.state == NSOnState ? 1 : 0 forKey:DEFAULTS_IGNORE_KEY];
}

-(IBAction)inputButton:(id)sender
{
  [self inputButton:sender textField:DEFAULTS_INPUT_PATH_KEY textField:inputTextField];
}

-(IBAction)outputButton:(id)sender
{
  [self outputButton:sender textField:DEFAULTS_OUTPUT_PATH_KEY textField:outputTextField];
}

-(IBAction)clearButton:(id)sender
{
  insist (sender == clearButton);
  [self clearLog];
}

-(IBAction)startButton:(id)sender
{
  MFError*error;
  
  BOOL appending = appendCheckButton.state == NSOnState;

  /*open output file, appending if the append checkbox is set, otherwise overwriting.*/
  outputStream = [NSOutputStream outputStreamToFileAtPath:outputTextField.stringValue append:appending];
  [outputStream open];
  
  if ([outputStream streamStatus] != NSStreamStatusOpen)
  {
    [self progressFormat:YES format:@"couldn't open %@ (%@)", outputTextField.stringValue, [outputStream streamError]];
  }
  
  /*make dr list from input file*/
  doctorList = [[MFDoctorList alloc] initWithPath:inputTextField.stringValue];
  insist (doctorList);
  
  /*create a db to do the writing to -- we're going to write source_index_key*/
  db = [[MFDB alloc] initWithPath:inputTextField.stringValue];
  if (![db open:&error])
  {
    [self progressFormat:YES format:@"Couldn't open db. error : %@", error];
    db = nil;
  }

  if (appending)
  {
    if (![doctorList selectDoctorsWithoutSourceIndexKeyBegin:&error])
    {
      [self progressFormat:YES format:@"selectDoctorLicensesWithoutSourceIndexKeyBegin failed with %@", error];
      return;
    }
  }
  else
  {
    /*first clear any license_index_keys from previous runs, since we aren't appending*/
    if (![MFDoctor clearSourceIndexKeys:db error:&error])
    {
      [self progressFormat:YES format:@"clearSourceIndexKeys failed with %@", error];
      return;
    }
    if (![doctorList selectAllDoctorsBegin:&error])
    {
      [self progressFormat:YES format:@"selectAllDoctorLicensesBegin failed with %@", error];
      return;
    }
    
    if (![doctorList selectAllDoctorsBegin:&error])
    {
      [self progressFormat:YES format:@"selectAllDoctorLicensesBegin failed with %@", error];
      return;
    }
  }
  numDoctors = [doctorList countError:&error];
  doctorIndex = 0;
  numNotFound = 0;

   /*start fetching court info from the doctor list*/
  [self setProgress:YES];
  [self setEnabled:NO];
  
  BOOL remember = ignoreCheckButton.state == NSOnState;

  if (![ignore reset:0 remember:remember error:&error])
  {
    [self progressFormat:YES format:@"Couldn't setup ignore db: %@", error];
  }
  
  if (!appending)
    [self outputFormat:[MDCourt csvColumns]];
  
  if (!mdCourtFetcher)
    mdCourtFetcher = [[MDCourtFetcher alloc]init];
  
  [self nextMDDoctor];
}


-(void) outputFormat:(NSString*)format, ...
{
  insist (outputStream);
  
  /*make string from args*/
  va_list args;
  va_start(args, format);
  NSString*s = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);
  
  NSData*data = [s dataUsingEncoding:NSUTF8StringEncoding];
  insist (data);
  long r = [outputStream write:data.bytes maxLength:data.length];
  if (r != data.length)
  {
    [self progressFormat:YES format:@"couldn't write to output file. wrote %d, expected %d", (int)r, (int)data.length];
  }
}

-(NSString*)ignoreTagFirstName:(NSString*)first_name lastName:(NSString*)last_name
{
  return [NSString stringWithFormat:@"%@,%@", first_name, last_name];
}

-(void)nextMDDoctor
{
  MFError*error;
  
  MFDoctor*doctor = [doctorList getOneMore];
  if (!doctor)
  {
    [self setProgress:NO];
    [self setEnabled:YES];
    [outputStream close];
    [doctorList end];
    [db close];
    return;
  }
  insist (mdCourtFetcher);
  __unsafe_unretained AppDelegate*myself = self;
  
  insist (ignore);
  BOOL shouldIgnore;
  if (![ignore ignore:[self ignoreTagFirstName:doctor->first_name lastName:doctor->last_name] result:&shouldIgnore error:&error])
  {
    [myself progressFormat:YES format:@"couldn't read ignore db. %@", error.description];
    [myself setProgress:NO];
    [myself setEnabled:YES];
    [outputStream close];
    [doctorList end];
    [db close];
    return;
  }
  
  if (shouldIgnore)
  {
    /*can't use recursion here, the stack gets too large, even though it's tail recursive*/
    doctorIndex++;
    dispatch_async(dispatch_get_main_queue(),^{

      [myself nextMDDoctor];
    });
    return;
  }
  
  [mdCourtFetcher fetchFirstName:doctor->first_name lastName:doctor->last_name block:^(MFError*error, MDCourt*court) {
    
    dispatch_async(dispatch_get_main_queue(),^{
      MFError*other;

      if (error)
      {
        /*if a lookup failed, mark the doctor license as not found so we make progress*/
        if (error.code == MFErrorNotFound)
        {
          numNotFound++;
          doctor->source_index_key = NOT_FOUND_SOURCE_INDEX_KEY;
          if (![doctor updateSourceIndexKey:db error:&other])
          {
            [myself progressFormat:YES format:@"couldn't write db. %@", other.description];
            [myself setProgress:NO];
            [myself setEnabled:YES];
            [outputStream close];
            [doctorList end];
            [db close];
            return;
          }
        }
        else
        {
          [myself progressFormat:YES format:@"specialty fetch failed. %@", error.description];
        }
      }
      doctorIndex++;
      [myself progressFormat:NO format:@"%d(%d)/%d", doctorIndex, numNotFound, numDoctors];
      
      /*if there was court info, write to output*/
      if (court)
      {
        /*add the data that we get from our own mf db*/
        court->mf_doctor_id = doctor->mf_doctor_id;
        court->last_name = doctor->last_name;
        court->first_name = doctor->first_name;
        court->middle_name = doctor->middle_name;
        
        if ([court->items count])
          [self outputFormat:@"%@", [court csv]];

        insist (db);
        doctor->source_index_key = FOUND_SOURCE_INDEX_KEY;
        if (![doctor updateSourceIndexKey:db error:&other])
        {
          [myself progressFormat:YES format:@"couldn't write db. %@", other.description];
          [myself setProgress:NO];
          [myself setEnabled:YES];
          [outputStream close];
          [doctorList end];
          [db close];
          return;
        }
      }
      else
      {
        /*a dr that exists resulted in no information, mark him as to be ignored*/
        if (![ignore update:[self ignoreTagFirstName:doctor->first_name lastName:doctor->last_name] error:&other])
        {
          [myself progressFormat:YES format:@"couldn't write ignore db. %@", other.description];
          [myself setProgress:NO];
          [myself setEnabled:YES];
          [outputStream close];
          [doctorList end];
          [db close];
          return;
        }
      }
      [self nextMDDoctor];
    });
  }];
  
}

@end
