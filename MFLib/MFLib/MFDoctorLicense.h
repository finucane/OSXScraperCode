//
//  MFDoctorLicense.h
//  Scraper
//
//  Created by Finucane on 3/20/14.
//  Copyright (c) 2014 mf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MFLib/MFDB.h>

@interface MFDoctorLicense : NSObject
{
  @public
  NSString*mf_doctor_id;
  NSString*license_number;
  NSString*source_index_key;
}
-(BOOL)updateSourceIndexKey:(MFDB*)db error:(MFError*__autoreleasing*)error;
+(BOOL)clearSourceIndexKeys:(MFDB*)db error:(MFError*__autoreleasing*)error;
@end
