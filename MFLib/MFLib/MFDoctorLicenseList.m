//
//  MFDoctorLicenseList.m
//  Scraper
//
//  Created by Finucane on 3/20/14.
//  Copyright (c) 2014 mf. All rights reserved.
//

#import "MFDoctorLicenseList.h"
#import "MFDoctorLicense.h"
#import <MFLib/insist.h>

@implementation MFDoctorLicenseList

-(BOOL)selectAllDoctorLicensesBegin:(MFError*__autoreleasing*)error
{
  insist (tempDB && error);
  
  /*open tempDB*/
  if (![tempDB open:error])
    return NO;
  
  /*prepare query*/
  if (![tempDB prepareError:error format:
        @"SELECT mf_doctor_id, license_number, source_index_key FROM 'doctor_license'"])
  {
    [tempDB close];
    return NO;
  }
  return YES;
}

-(BOOL)selectDoctorLicensesWithoutSourceIndexKeyBegin:(MFError*__autoreleasing*)error
{
  insist (tempDB && error);
  
  /*open tempDB*/
  if (![tempDB open:error])
    return NO;
  
  /*prepare query*/
  if (![tempDB prepareError:error format:
        @"SELECT mf_doctor_id, license_number, source_index_key FROM 'doctor_license' WHERE source_index_key ISNULL"])
  {
    [tempDB close];
    return NO;
  }
  return YES;
}

/*
 create a DoctorLicense object from the current row in tempDB.
 
 returns - a DoctorLicense
 */

-(id)parseRow
{
  MFDoctorLicense*license = [[MFDoctorLicense alloc] init];
  insist (license);
  
  license->mf_doctor_id = [tempDB textAtColumn:0];
  license->license_number = [tempDB textOrNilAtColumn:1];
  license->source_index_key = [tempDB textAtColumn:2];
  
  return license;
}


@end
