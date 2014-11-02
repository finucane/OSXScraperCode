//
//  MFDoctorList.m
//  CourtCrawler
//
//  Created by finucane on 4/3/14.
//  Copyright (c) 2014  All rights reserved.
//

#import "MFDoctorList.h"
#import <MFLib/insist.h>

@implementation MFDoctor

/*
 write the source_index_key into the database for this doctor license. the database should already be opened
 and on return it is left opened.
 
 db - the database
 error - set if there was an error
 
 returns: false if there was an error
 */

-(BOOL)updateSourceIndexKey:(MFDB*)db error:(MFError*__autoreleasing*)error
{
  insist (db && error);
  insist ([db isOpened]);
  
  /*prepare query*/
  if (![db execError:error format:@"UPDATE doctor SET source_index_key='%@' WHERE mf_doctor_id='%@'", [MFDB escape:source_index_key], mf_doctor_id])
    return FALSE;
  
  return YES;
}


/*
 clear all source_index_keys
 
 db - the database
 error - set if there was an error
 
 returns: false if there was an error
 */

+(BOOL)clearSourceIndexKeys:(MFDB*)db error:(MFError*__autoreleasing*)error
{
  insist (db && error);
  insist ([db isOpened]);
  
  /*prepare query*/
  if (![db execError:error format:@"UPDATE doctor SET source_index_key=null"])
    return FALSE;
  
  return YES;
}


@end

@implementation MFDoctorList

-(BOOL)selectAllDoctorsBegin:(MFError*__autoreleasing*)error;
{
  insist (tempDB && error);
  
  /*open tempDB*/
  if (![tempDB open:error])
    return NO;
  
  /*prepare query*/
  if (![tempDB prepareError:error format:@"SELECT mf_doctor_id, last_name, first_name, middle_name, source_index_key FROM 'doctor'"])
  {
    [tempDB close];
    return NO;
  }
  return YES;
}


-(BOOL)selectDoctorsWithoutSourceIndexKeyBegin:(MFError*__autoreleasing*)error
{
  insist (tempDB && error);
  
  /*open tempDB*/
  if (![tempDB open:error])
    return NO;
  
  /*prepare query*/
  if (![tempDB prepareError:error format:
        @"SELECT mf_doctor_id, last_name, first_name, middle_name, source_index_key FROM 'doctor' WHERE source_index_key ISNULL"])
  {
    [tempDB close];
    return NO;
  }
  return YES;
}
-(MFDoctor*)parseRow
{
  MFDoctor*doctor = [[MFDoctor alloc] init];
  insist (doctor);
  
  doctor->mf_doctor_id = [tempDB textAtColumn:0];
  doctor->last_name = [tempDB textAtColumn:1];
  doctor->first_name = [tempDB textOrNilAtColumn:2];
  doctor->middle_name = [tempDB textOrNilAtColumn:3];
  doctor->source_index_key = [tempDB textOrNilAtColumn:4];

  return doctor;
}

@end
