//
//  MFDoctorList.h
//  CourtCrawler
//
//  Created by finucane on 4/3/14.
//  Copyright (c) 2014  All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MFLib/MFDBList.h>

@interface MFDoctor : NSObject 
{
  @public
  NSString*mf_doctor_id;
  NSString*last_name;
  NSString*first_name;
  NSString*middle_name;
  NSString*source_index_key;
}
-(BOOL)updateSourceIndexKey:(MFDB*)db error:(MFError*__autoreleasing*)error;
+(BOOL)clearSourceIndexKeys:(MFDB*)db error:(MFError*__autoreleasing*)error;
@end

@interface MFDoctorList : MFDBList

-(BOOL)selectAllDoctorsBegin:(MFError*__autoreleasing*)error;
-(BOOL)selectDoctorsWithoutSourceIndexKeyBegin:(MFError*__autoreleasing*)error;
@end
