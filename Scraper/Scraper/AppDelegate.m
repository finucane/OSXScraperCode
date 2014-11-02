//
//  AppDelegate.m
//  Scraper
//
//  Created by Finucane on 3/20/14.
//  Copyright (c) 2014 All rights reserved.
//

#import "AppDelegate.h"
#import <MFLib/MFDoctorLicense.h>
#import <MFLib/insist.h>
#import <MFLib/MFIgnore.h>

#define DEFAULTS_NUM_FETCHERS_KEY @"NumFetchers"
#define DEFAULTS_DELAY_KEY @"Delay"
#define DEFAULTS_INPUT_PATH_KEY @"InputPath"
#define DEFAULTS_OUTPUT_PATH_KEY @"OutputPath"
#define DEFAULTS_SCRAPE_TYPE_INDEX_KEY @"ScrapeIndex"
#define DEFAULTS_APPEND_KEY @"Append"
#define DEFAULTS_REMEMBER_KEY @"Append"
#define NOT_FOUND_SOURCE_INDEX_KEY @"Not Found"
#define FOUND_SOURCE_INDEX_KEY @"Found"

void AppLog(NSString*format,...)
{
  insist (format);
  va_list args;
  va_start(args, format);
  NSString*text = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);
  
  NSLog (@"%@", text);
  
#if 0
  /*for now omit low level errors*/
  NSRange r = [text rangeOfString:@"NSLocalizedDescription"];
  if (r.location != NSNotFound)
    return;
#endif
  
  AppDelegate*app = (AppDelegate*)[[NSApplication sharedApplication] delegate];
  insist (app);
  
  [app appendLog:text];
}

@implementation AppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  /*make backing string for log view*/
  logString = [[NSMutableString alloc] init];
  insist (logString);
  
  /*set up defaults*/
  NSUserDefaults*defaults = [NSUserDefaults standardUserDefaults];
  [defaults registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]]];
  
  /*set up controls etc from defaults*/
  inputTextField.stringValue = [defaults stringForKey:DEFAULTS_INPUT_PATH_KEY];
  outputTextField.stringValue = [defaults stringForKey:DEFAULTS_OUTPUT_PATH_KEY];
  [stepSlider setIntegerValue: [defaults integerForKey:DEFAULTS_NUM_FETCHERS_KEY]];
  [appendCheckButton setState: [defaults integerForKey:DEFAULTS_APPEND_KEY] ? NSOnState : NSOffState];
  [rememberDoNotScrapesCheckButton setState: [defaults integerForKey:DEFAULTS_REMEMBER_KEY] ? NSOnState : NSOffState];
  
  [self refreshStepLabel];
  
  [delayStepper setIntegerValue: [defaults integerForKey:DEFAULTS_DELAY_KEY]];
  [self refreshDelayLabel];
  
  /*setup popup button*/
  [scrapePopupButton removeAllItems];
  [scrapePopupButton addItemsWithTitles:@[@"Massachusetts Malpractice", @"West Virginia Malpractice", @"Maine Specialty", @"Georgia Malpractice", @"Connecticut", @"Virginia Specialty"]];
  [scrapePopupButton selectItemAtIndex: [defaults integerForKey:DEFAULTS_SCRAPE_TYPE_INDEX_KEY]];
  
  /*make ignore db*/
  ignore = [[MFIgnore alloc] init];
  insist (ignore);
  
  /*array of fetchers*/
  fetchers = [[NSMutableArray alloc] init];
  insist (fetchers);
}


-(void)refreshStepLabel
{
  int v = stepSlider.intValue;
  stepLabel.stringValue = [NSString stringWithFormat:@"%d", v];
  stepSize = stepSlider.intValue;
}
-(void)refreshDelayLabel
{
  delayLabel.stringValue = delayStepper.stringValue;
  delay = delayStepper.intValue;
}

/*
 fetch some more MA malpractice info or stop fetching if we are done.
 */
-(void)nextMADoctorLicenses
{
  MFDoctorLicense*license = [licenseList getOneMore];
  if (!license)
  {
    [self setProgress:NO];
    [self setEnabled:YES];
    [outputStream close];
    [licenseList end];
    [db close];
    return;
  }
  
  insist (maMalpracticeFetcher);
  __unsafe_unretained AppDelegate*myself = self;
  [maMalpracticeFetcher fetch:license->license_number block:^(MFError*error, MAMalpractice*malpractice, NSString*physicianID) {
    dispatch_async(dispatch_get_main_queue(),^{
      
      MFError*other;
      
      if (error)
      {
        /*if a lookup faied, mark the doctor license as not lookup-able so we make progress*/
        if (error.code == MFErrorNotFound)
        {
          numNotFound++;
          license->source_index_key = NOT_FOUND_SOURCE_INDEX_KEY;
          if (![license updateSourceIndexKey:db error:&other])
          {
            [myself progressLog:YES format:@"couldn't write db. %@", other.description];
            [myself setProgress:NO];
            [myself setEnabled:YES];
            [outputStream close];
            [licenseList end];
            [db close];
            return;
          }
        }
        else
          [myself progressLog:YES format:@"malpractice fetch failed. %@", error.description];
        /*
         [myself setProgress:NO];
         [myself setEnabled:YES];
         [outputStream close];
         [licenseList end];
         [db close];
         return;
         */
      }
      licenseIndex++;
      [myself progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
      
      /*if there was malpractice info, write to output*/
      if (malpractice)
      {
        [self outputFormat:@"%@", [malpractice csv]];
      }
      
      /*if the dr was found, update db w/ source_index_key*/
      if (physicianID)
      {
        insist (!malpractice || [malpractice->physician_id isEqualToString:physicianID]);
        
        insist (db);
        license->source_index_key = physicianID;
        if (![license updateSourceIndexKey:db error:&other])
        {
          [myself progressLog:YES format:@"couldn't write db. %@", other.description];
          [myself setProgress:NO];
          [myself setEnabled:YES];
          [outputStream close];
          [licenseList end];
          [db close];
          return;
        }
      }
      [self nextMADoctorLicenses];
    });
  }];
}


/*
 fetch some more WV malpractice info or stop fetching if we are done.
 */
-(void)nextWVDoctorLicenses
{
  MFDoctorLicense*license = [licenseList getOneMore];
  if (!license)
  {
    [self setProgress:NO];
    [self setEnabled:YES];
    [outputStream close];
    [licenseList end];
    [db close];
    return;
  }
  
  MFError*error;
  BOOL dont_scrape;
  if (![ignore ignore:license->license_number result:&dont_scrape error:&error])
  {
    [self progressLog:YES format:@"doNotScrape failed. %@", error.description];
    [self setProgress:NO];
    [self setEnabled:YES];
    [outputStream close];
    [licenseList end];
    [db close];
    return;
  }
  
  if (dont_scrape)
  {
    licenseIndex++;
    [self progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
    [self nextWVDoctorLicenses];
    return;
  }
  
  insist (wvMalpracticeFetcher);
  __unsafe_unretained AppDelegate*myself = self;
  [wvMalpracticeFetcher fetch:license->license_number block:^(MFError*error, NSArray*malpractices) {
    dispatch_async(dispatch_get_main_queue(),^{
      
      if (error)
      {
        [myself progressLog:YES format:@"malpractice fetch failed. %@", error.description];
        /*
         [myself setProgress:NO];
         [myself setEnabled:YES];
         [outputStream close];
         [licenseList end];
         [db close];
         return;
         */
      }
      licenseIndex++;
      [myself progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
      
      if (malpractices)
      {
        int numWritten = 0;
        
        for (WVMalpractice*malpractice in malpractices)
        {
          /*if there was malpractice info, write to output*/
          if (malpractice && [malpractice->incidents count])
          {
            numWritten++;
            [self outputFormat:@"%@", [malpractice csv]];
          }
          
          /*if we at least found a dr, update database so we make progress across runs*/
          if (malpractice)
          {
            license->source_index_key = malpractice->individual_id;
            
            MFError*other;
            
            if (![license updateSourceIndexKey:db error:&other])
            {
              [myself progressLog:YES format:@"couldn't write db. %@", error.description];
              [myself setProgress:NO];
              [myself setEnabled:YES];
              [outputStream close];
              [licenseList end];
              [db close];
              return;
            }
          }
        }
        
        if (numWritten == 0)
        {
          MFError*other;
          /*if we didn't write anything it means there was nothing to scrape. so remember to skip this license next time*/
          if (![ignore update:license->license_number error:&other])
          {
            [myself progressLog:YES format:@"ignore update failed. %@", other.description];
            [myself setProgress:NO];
            [myself setEnabled:YES];
            [outputStream close];
            [licenseList end];
            [db close];
            return;
          }
          numNotFound++;
          [myself progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
        }
      }
      [self nextWVDoctorLicenses];
    });
  }];
}

/*
 fetch some more ME specialty info or stop fetching if we are done.
 */
-(void)nextMESpecialtyDoctorLicenses
{
  MFDoctorLicense*license = [licenseList getOneMore];
  if (!license)
  {
    [self setProgress:NO];
    [self setEnabled:YES];
    [outputStream close];
    [licenseList end];
    [db close];
    return;
  }
  
  
  MFError*error;
  BOOL dont_scrape;
  if (![ignore ignore:license->license_number result:&dont_scrape error:&error])
  {
    [self progressLog:YES format:@"doNotScrape failed. %@", error.description];
    [self setProgress:NO];
    [self setEnabled:YES];
    [outputStream close];
    [licenseList end];
    [db close];
    return;
  }
  
  if (dont_scrape)
  {
    licenseIndex++;
    [self progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
    [self nextMESpecialtyDoctorLicenses];
    return;
  }
  
  insist (meSpecialtyFetcher);
  __unsafe_unretained AppDelegate*myself = self;
  [meSpecialtyFetcher fetch:license->license_number block:^(MFError*error, MESpecialty*specialty) {
    dispatch_async(dispatch_get_main_queue(),^{
      MFError*other;
      
      if (error)
      {
        /*if a lookup faied, mark the doctor license as not lookup-able so we make progress*/
        if (error.code == MFErrorNotFound)
        {
          numNotFound++;
          license->source_index_key = NOT_FOUND_SOURCE_INDEX_KEY;
          if (![license updateSourceIndexKey:db error:&other])
          {
            [myself progressLog:YES format:@"couldn't write db. %@", other.description];
            [myself setProgress:NO];
            [myself setEnabled:YES];
            [outputStream close];
            [licenseList end];
            [db close];
            return;
          }
        }
        else
        {
          [myself progressLog:YES format:@"specialty fetch failed. %@", error.description];
        }
      }
      licenseIndex++;
      [myself progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
      
      /*if there was specialty info, write to output*/
      if (specialty)
      {
        if ([specialty->items count])
          [self outputFormat:@"%@", [specialty csv]];
        
        insist (db);
        license->source_index_key = FOUND_SOURCE_INDEX_KEY;
        if (![license updateSourceIndexKey:db error:&other])
        {
          [myself progressLog:YES format:@"couldn't write db. %@", error.description];
          [myself setProgress:NO];
          [myself setEnabled:YES];
          [outputStream close];
          [licenseList end];
          [db close];
          return;
        }
      }
      [self nextMESpecialtyDoctorLicenses];
    });
  }];
}

/*
 fetch some more GA malpractice info or stop fetching if we are done.
 return YES if we can start more fetches
 */
-(BOOL)nextGAMalpracticeDoctorLicenses
{
  /*first see if we have an idle fetcher*/
  GAMalpracticeFetcher*fetcher = nil;
  for (int i = 0; i < fetchers.count; i++)
  {
    if (![fetchers [i] busy])
    {
      fetcher = fetchers [i];
      break;
    }
  }
  
  /*if we have no spare capacity, do nothing*/
  if (!fetcher)
    return NO;
  
  
  MFDoctorLicense*license = [licenseList getOneMore];
  if (!license)
  {
    /*if we have no working fetchers and no more licenses, we are done!*/
    if (!fetcher)
    {
      [self setProgress:NO];
      [self setEnabled:YES];
      [outputStream close];
      [licenseList end];
      [db close];
    }
    return NO; //wait for working fetchers to finish
  }
  MFError*error;
  BOOL dont_scrape;
  if (![ignore ignore:license->license_number result:&dont_scrape error:&error])
  {
    [self progressLog:YES format:@"ignore ignore failed. %@", error.description];
    [self setProgress:NO];
    [self setEnabled:YES];
    [outputStream close];
    [licenseList end];
    [db close];
    return YES;
  }
  
  if (dont_scrape)
  {
    licenseIndex++;
    [self progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
    [self nextGAMalpracticeDoctorLicenses];
    return YES;
  }
  
  __unsafe_unretained AppDelegate*myself = self;
  [fetcher fetch:license->license_number block:^(MFError*error, GAMalpractice*malpractice) {
    dispatch_async(dispatch_get_main_queue(),^{
      MFError*other;
      
      if (error)
      {
        /*if a lookup faied, mark the doctor license as not lookup-able so we make progress*/
        if (error.code == MFErrorNotFound)
        {
          numNotFound++;
          license->source_index_key = NOT_FOUND_SOURCE_INDEX_KEY;
          if (![license updateSourceIndexKey:db error:&other])
          {
            [myself progressLog:YES format:@"couldn't write db. %@", other.description];
            [myself setProgress:NO];
            [myself setEnabled:YES];
            [outputStream close];
            [licenseList end];
            [db close];
            return;
          }
        }
        else
        {
          [myself progressLog:YES format:@"specialty fetch failed. %@", error.description];
        }
      }
      licenseIndex++;
      [myself progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
      
      if (malpractice)
      {
        /*if there was malpractice or specialty info, write to output*/
        
        if ([malpractice->items count])
          [self outputFormat:@"%@", [malpractice csv]];
        else
        {
          /*now we are printing out data even if there were no items, this is because we care about the top level specialty now*/
          [self outputFormat:@"%@", [malpractice csv]];
          
          MFError*other;
          /*if we didn't write anything it means there was nothing to scrape. so remember to skip this license next time*/
          if (![ignore update:license->license_number error:&other])
          {
            [myself progressLog:YES format:@"ignore update failed. %@", other.description];
            [myself setProgress:NO];
            [myself setEnabled:YES];
            [outputStream close];
            [licenseList end];
            [db close];
            return;
          }
          numNotFound++;
          [myself progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
        }
        insist (db);
        license->source_index_key = FOUND_SOURCE_INDEX_KEY; //no source index key for this stuff, use any string so we make progress
        if (![license updateSourceIndexKey:db error:&other])
        {
          [myself progressLog:YES format:@"couldn't write db. %@", other.description];
          [myself setProgress:NO];
          [myself setEnabled:YES];
          [outputStream close];
          [licenseList end];
          [db close];
          return;
        }
      }
      while ([self nextGAMalpracticeDoctorLicenses]);
    });
  }];
  return YES;
}


/*
 fetch some more CT malpractice info or stop fetching if we are done.
 */
-(void)nextCTMalpracticeDoctorLicenses
{
  MFDoctorLicense*license = [licenseList getOneMore];
  if (!license)
  {
    [self setProgress:NO];
    [self setEnabled:YES];
    [outputStream close];
    [licenseList end];
    [db close];
    return;
  }
  MFError*error;
  BOOL dont_scrape;
  if (![ignore ignore:license->license_number result:&dont_scrape error:&error])
  {
    [self progressLog:YES format:@"ignore ignore failed. %@", error.description];
    [self setProgress:NO];
    [self setEnabled:YES];
    [outputStream close];
    [licenseList end];
    [db close];
    return;
  }
  
  if (dont_scrape)
  {
    licenseIndex++;
    [self progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
    [self nextCTMalpracticeDoctorLicenses];
    return;
  }
  
  insist (ctMalpracticeFetcher);
  __unsafe_unretained AppDelegate*myself = self;
  [ctMalpracticeFetcher fetch:license->license_number block:^(MFError*error, CTMalpractice*malpractice) {
    dispatch_async(dispatch_get_main_queue(),^{
      MFError*other;
      
      if (error)
      {
        /*if a lookup faied, mark the doctor license as not lookup-able so we make progress*/
        if (error.code == MFErrorNotFound)
        {
          numNotFound++;
          license->source_index_key = NOT_FOUND_SOURCE_INDEX_KEY;
          if (![license updateSourceIndexKey:db error:&other])
          {
            [myself progressLog:YES format:@"couldn't write db. %@", other.description];
            [myself setProgress:NO];
            [myself setEnabled:YES];
            [outputStream close];
            [licenseList end];
            [db close];
            return;
          }
        }
        else
        {
          [myself progressLog:YES format:@"specialty fetch failed. %@", error.description];
        }
      }
      licenseIndex++;
      [myself progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
      
      if (malpractice)
      {
        /*if there was malpractice or specialty info, write to output*/
        
        if ([malpractice->items count])
          [self outputFormat:@"%@", [malpractice csv]];
        else
        {
          MFError*other;
          /*if we didn't write anything it means there was nothing to scrape. so remember to skip this license next time*/
          if (![ignore update:license->license_number error:&other])
          {
            [myself progressLog:YES format:@"ignore update failed. %@", other.description];
            [myself setProgress:NO];
            [myself setEnabled:YES];
            [outputStream close];
            [licenseList end];
            [db close];
            return;
          }
          numNotFound++;
          [myself progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
        }
        insist (db);
        license->source_index_key = FOUND_SOURCE_INDEX_KEY; //no source index key for this stuff, use any string so we make progress
        if (![license updateSourceIndexKey:db error:&other])
        {
          [myself progressLog:YES format:@"couldn't write db. %@", error.description];
          [myself setProgress:NO];
          [myself setEnabled:YES];
          [outputStream close];
          [licenseList end];
          [db close];
          return;
        }
      }
      [self nextCTMalpracticeDoctorLicenses];
    });
  }];
}


/*
 fetch some more CT malpractice info or stop fetching if we are done.
 */
-(void)nextVASpecialtyDoctorLicenses
{
  MFDoctorLicense*license = [licenseList getOneMore];
  if (!license)
  {
    [self setProgress:NO];
    [self setEnabled:YES];
    [outputStream close];
    [licenseList end];
    [db close];
    return;
  }
  MFError*error;
  BOOL dont_scrape;
  if (![ignore ignore:license->license_number result:&dont_scrape error:&error])
  {
    [self progressLog:YES format:@"ignore ignore failed. %@", error.description];
    [self setProgress:NO];
    [self setEnabled:YES];
    [outputStream close];
    [licenseList end];
    [db close];
    return;
  }
  
  if (dont_scrape)
  {
    licenseIndex++;
    [self progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
    [self nextVASpecialtyDoctorLicenses];
    return;
  }
  
  insist (vaSpecialtyFetcher);
  __unsafe_unretained AppDelegate*myself = self;
  [vaSpecialtyFetcher fetch:license->license_number block:^(MFError*error, VASpecialty*specialty) {
    dispatch_async(dispatch_get_main_queue(),^{
      MFError*other;
      
      if (error)
      {
        /*if a lookup failed, mark the doctor license as not lookup-able so we make progress*/
        if (error.code == MFErrorNotFound)
        {
          numNotFound++;
          license->source_index_key = NOT_FOUND_SOURCE_INDEX_KEY;
          if (![license updateSourceIndexKey:db error:&other])
          {
            [myself progressLog:YES format:@"couldn't write db. %@", other.description];
            [myself setProgress:NO];
            [myself setEnabled:YES];
            [outputStream close];
            [licenseList end];
            [db close];
            return;
          }
        }
        else
        {
          [myself progressLog:YES format:@"specialty fetch failed. %@", error.description];
        }
      }
      licenseIndex++;
      [myself progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
      
      if (specialty)
      {
        /*set the mf id, which we get from the db, not the scrape*/
        specialty->mf_doctor_id = license->mf_doctor_id;
        /*if there was specialty info, write to output*/
        
        if ([specialty->items count])
          [self outputFormat:@"%@", [specialty csv]];
        else
        {
          MFError*other;
          /*if we didn't write anything it means there was nothing to scrape. so remember to skip this license next time*/
          if (![ignore update:license->license_number error:&other])
          {
            [myself progressLog:YES format:@"ignore update failed. %@", other.description];
            [myself setProgress:NO];
            [myself setEnabled:YES];
            [outputStream close];
            [licenseList end];
            [db close];
            return;
          }
          numNotFound++;
          [myself progressLog:NO format:@"%d(%d)/%d", licenseIndex, numNotFound, numLicenses];
        }
        insist (db);
        license->source_index_key = FOUND_SOURCE_INDEX_KEY; //no source index key for this stuff, use any string so we make progress
        if (![license updateSourceIndexKey:db error:&other])
        {
          [myself progressLog:YES format:@"couldn't write db. %@", other.description];
          [myself setProgress:NO];
          [myself setEnabled:YES];
          [outputStream close];
          [licenseList end];
          [db close];
          return;
        }
      }
      [self nextVASpecialtyDoctorLicenses];
    });
  }];
}


# pragma - Actions

/*
 action for input button. brings up file selection box to select existing file.
 if user clicks OK then the inputPath is changed in the defaults.
 */
-(IBAction)inputButtonAction:(id)sender
{
  insist (sender == inputButton);
  NSOpenPanel*panel = [NSOpenPanel openPanel];
  insist (panel);
  
  panel.canChooseDirectories = NO;
  panel.canChooseFiles = YES;
  
  [panel beginWithCompletionHandler:^(NSInteger result) {
    
    if (result == NSFileHandlingPanelOKButton)
    {
      insist ([[panel URLs] count]);
      NSURL*url = [panel URLs][0];
      insist ([url isFileURL]);
      
      [[NSUserDefaults standardUserDefaults] setObject:url.path forKey:DEFAULTS_INPUT_PATH_KEY];
      inputTextField.stringValue = url.path;
    }
  }];
}
-(IBAction)outputButtonAction:(id)sender
{
  insist (sender == outputButton);
  NSSavePanel*panel = [NSSavePanel savePanel];
  insist (panel);
  
  [panel beginWithCompletionHandler:^(NSInteger result) {
    
    if (result == NSFileHandlingPanelOKButton)
    {
      NSURL*url = [panel URL];
      insist ([url isFileURL]);
      
      [[NSUserDefaults standardUserDefaults] setObject:url.path forKey:DEFAULTS_OUTPUT_PATH_KEY];
      outputTextField.stringValue = url.path;
    }
  }];
}



-(IBAction)scrapeButtonAction:(id)sender
{
  insist (sender == scrapeButton);
  MFError*error;
  
  BOOL appending = appendCheckButton.state == NSOnState;
  
  /*open output file, appending if the append checkbox is set, otherwise overwriting.*/
  outputStream = [NSOutputStream outputStreamToFileAtPath:outputTextField.stringValue append:appending];
  [outputStream open];
  
  if ([outputStream streamStatus] != NSStreamStatusOpen)
  {
    [self progressLog:YES format:@"couldn't open %@ (%@)", outputTextField.stringValue, [outputStream streamError]];
  }
  
  /*create a db to do the writing to*/
  db = [[MFDB alloc] initWithPath:inputTextField.stringValue];
  if (![db open:&error])
  {
    [self progressLog:YES format:@"Couldn't open db. error : %@", error];
    db = nil;
  }
  /*make a doctorList from the db path*/
  
  licenseList = [[MFDoctorLicenseList alloc] initWithPath:inputTextField.stringValue];
  insist (licenseList);
  
  /*get list of doctors, either just doctors w/out source_index_key set, or all doctors, depending of if we aren't appending or if we are.*/
  
  if (appending)
  {
    if (![licenseList selectDoctorLicensesWithoutSourceIndexKeyBegin:&error])
    {
      [self progressLog:YES format:@"selectDoctorLicensesWithoutSourceIndexKeyBegin failed with %@", error];
      return;
    }
  }
  else
  {
    /*first clear any license_index_keys from previous runs, since we aren't appending*/
    if (![MFDoctorLicense clearSourceIndexKeys:db error:&error])
    {
      [self progressLog:YES format:@"clearSourceIndexKeys failed with %@", error];
      return;
    }
    if (![licenseList selectAllDoctorLicensesBegin:&error])
    {
      [self progressLog:YES format:@"selectAllDoctorLicensesBegin failed with %@", error];
      return;
    }
    
    if (![licenseList selectAllDoctorLicensesBegin:&error])
    {
      [self progressLog:YES format:@"selectAllDoctorLicensesBegin failed with %@", error];
      return;
    }
  }
  licenseIndex = numNotFound = 0;
  numLicenses = [licenseList countError:&error];
  
  int numFetchers = stepSlider.intValue;
  
  /*start fetching malpractice info from the dr licenses*/
  [self setProgress:YES];
  [self setEnabled:NO];
  
  int which = (int)scrapePopupButton.indexOfSelectedItem;
  BOOL remember = rememberDoNotScrapesCheckButton.state == NSOnState;
  
  if (![ignore reset:which remember:remember error:&error])
  {
    [self progressLog:YES format:@"ignore reset failed with %@", error];
    return;
  }
  
  switch (which)
  {
    case 0:
      /*write columns to csv*/
      if (!appending)
        [self outputFormat:[MAMalpractice csvColumns]];
      
      if (!maMalpracticeFetcher)
        maMalpracticeFetcher = [[MAMalpracticeFetcher alloc] init];
      insist (maMalpracticeFetcher);
      
      [self nextMADoctorLicenses];
      break;
    case 1:
      /*write columns to csv*/
      if (!appending)
        [self outputFormat:[WVMalpractice csvColumns]];
      
      if (!wvMalpracticeFetcher)
        wvMalpracticeFetcher = [[WVMalpracticeFetcher alloc] init];
      insist (wvMalpracticeFetcher);
      
      [self nextWVDoctorLicenses];
      break;
    case 2:
      /*write columns to csv*/
      if (!appending)
        [self outputFormat:[MESpecialty csvColumns]];
      
      if (!meSpecialtyFetcher)
        meSpecialtyFetcher = [[MESpecialtyFetcher alloc] init];
      insist (meSpecialtyFetcher);
      
      [self nextMESpecialtyDoctorLicenses];
      break;
    case 3:
      /*write columns to csv*/
      if (!appending)
        [self outputFormat:[GAMalpractice csvColumns]];
      
      insist (fetchers);
      [fetchers removeAllObjects];
      
      for (int i = 0; i < numFetchers; i++)
      {
        GAMalpracticeFetcher*fetcher = [[GAMalpracticeFetcher alloc] init];
        insist (fetcher);
        [fetchers addObject:fetcher];
      }
      while ([self nextGAMalpracticeDoctorLicenses]);
      break;
    case 4:
      /*write columns to csv*/
      if (!appending)
        [self outputFormat:[CTMalpractice csvColumns]];
      
      if (!ctMalpracticeFetcher)
        ctMalpracticeFetcher = [[CTMalpracticeFetcher alloc] init];
      insist (ctMalpracticeFetcher);
      
      [self nextCTMalpracticeDoctorLicenses];
      break;
      
    case 5:
      /*write columns to csv*/
      if (!appending)
        [self outputFormat:[VASpecialty csvColumns]];
      
      if (!vaSpecialtyFetcher)
        vaSpecialtyFetcher = [[VASpecialtyFetcher alloc] init];
      insist (vaSpecialtyFetcher);
      
      [self nextVASpecialtyDoctorLicenses];
      break;
      
    default:
      insist (0);
      break;
  }
}

/*
 when step slider changes, save new value to user defaults and update label+stepSize ivar
 */
-(IBAction)stepSliderAction:(id)sender
{
  insist (sender == stepSlider);
  [[NSUserDefaults standardUserDefaults] setInteger:[sender integerValue ] forKey:DEFAULTS_NUM_FETCHERS_KEY];
  [self refreshStepLabel];
}

-(IBAction)delayStepperAction:(id)sender
{
  insist (sender == delayStepper);
  [[NSUserDefaults standardUserDefaults] setInteger:[sender integerValue ] forKey:DEFAULTS_DELAY_KEY];
  [self refreshDelayLabel];
  
}
-(IBAction)clearButtonAction:(id)sender
{
  insist (sender == clearButton);
  [self clearLog];
}
-(IBAction)scrapePopupButtonAction:(id)sender
{
  insist (sender == scrapePopupButton);
  [[NSUserDefaults standardUserDefaults] setInteger:[scrapePopupButton indexOfSelectedItem] forKey:DEFAULTS_SCRAPE_TYPE_INDEX_KEY];
}

-(IBAction)appendCheckButtonAction:(id)sender
{
  insist (sender == appendCheckButton);
  [[NSUserDefaults standardUserDefaults] setInteger:appendCheckButton.state == NSOnState ? 1 : 0 forKey:DEFAULTS_APPEND_KEY];
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

-(IBAction)rememberDoNotScrapesCheckButtonAction:(id)sender
{
  insist (sender == rememberDoNotScrapesCheckButton);
  [[NSUserDefaults standardUserDefaults] setInteger:rememberDoNotScrapesCheckButton.state == NSOnState ? 1 : 0 forKey:DEFAULTS_REMEMBER_KEY];
}
-(void)setEnabled:(BOOL)enabled
{
  insist (inputButton && outputButton && scrapeButton && scrapePopupButton);
  
  dispatch_async(dispatch_get_main_queue(),^{
    
    [inputButton setEnabled:enabled];
    [outputButton setEnabled:enabled];
    [scrapeButton  setEnabled:enabled];
    [scrapePopupButton  setEnabled:enabled];
    
    
  });
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
    [self progressLog:YES format:@"couldn't write to output file. wrote %d, expected %d", (int)r, (int)data.length];
  }
}



-(void)progressLog:(BOOL)log format:(NSString*)format, ...
{
  insist (statusLabel);
  
  /*make string from args*/
  va_list args;
  va_start(args, format);
  NSString*s = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);
  
  if (log)
    AppLog (@"%@", s);
  
  dispatch_async(dispatch_get_main_queue(),^{
    [statusLabel setStringValue:s];
  });
}

-(void)appendLog:(NSString*)text
{
  insist (text && logString);
  [logString appendString:text];
  [logString appendString:@"\n"];
  [logTextView setString:logString];
}

-(void)clearLog
{
  insist (logString && logTextView);
  [logString setString:@""];
  [logTextView setString:logString];
}

@end
