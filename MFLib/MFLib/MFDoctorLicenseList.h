//
//  MFDoctorLicenseList.h
//  Scraper
//
//  Created by Finucane on 3/20/14.
//  Copyright (c) 2014 mf. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MFLib/MFDBList.h>


@interface MFDoctorLicenseList : MFDBList

-(BOOL)selectAllDoctorLicensesBegin:(MFError*__autoreleasing*)error;
-(BOOL)selectDoctorLicensesWithoutSourceIndexKeyBegin:(MFError*__autoreleasing*)error;
-(id)parseRow;
@end
