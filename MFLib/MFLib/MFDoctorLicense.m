//
//  MFDoctorLicense.m
//  Scraper
//
//  Created by Finucane on 3/20/14.
//  Copyright (c) 2014 mf. All rights reserved.
//

#import "MFDoctorLicense.h"
#import <MFLib/insist.h>

@implementation MFDoctorLicense

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
  if (![db execError:error format:@"UPDATE doctor_license SET source_index_key='%@' WHERE mf_doctor_id='%@'", [MFDB escape:source_index_key], mf_doctor_id])
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
  if (![db execError:error format:@"UPDATE doctor_license SET source_index_key=null"])
    return FALSE;
  
  return YES;
}

@end
