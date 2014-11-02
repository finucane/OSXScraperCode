//
//  MFZipCodeDB.m
//  Geocoder
//
//  Created by finucane on 3/17/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

#import "MFZipCodeDB.h"
#import "insist.h"

#define TABLE_NAME @"zip_code"
/*
 wrapper around a sqlite3 database file created by importing zip_code_database.csv from
 
 http://www.unitedstateszipcodes.org/zip-code-database/
 
 head -n 1 zip_code_database.csv
 
 created by sqlite tool w/ these commands:
 
 create table zip_code(zip text, type text, primary_city text, acceptable_cities text, unacceptable_cities text, state text, county text, timezone text, area_codes text, latitude text, longitude text, world_region text, country text, decommissioned text, estimated_population text, notes);
 .separator ,
 .import zip_code_database.csv
 .quit
 
 
*/


@implementation MFZipCodeDB

-(id)initWithPath:(NSString*)aPath;
{
  if ((self = [super initWithPath:aPath]))
  {
    /*set up table of state abbreviations*/
    states =
      @{@"ALASKA" : @"AK",
        @"ARIZONA" : @"AZ",
        @"ARKANSAS" : @"AR",
        @"CALIFORNIA" : @"CA",
        @"COLORADO" : @"CO",
        @"CONNECTICUT" : @"CT",
        @"DELAWARE" : @"DE",
        @"DISTRICT OF COLUMBIA" : @"DC",
        @"WASHINGTON DC" : @"DC",
        @"FLORIDA" : @"FL",
        @"GEORGIA"	: @"GA",
        @"HAWAII" : @"HI",
        @"IDAHO" : @"ID",
        @"ILLINOIS" : @"IL",
        @"INDIANA" : @"IN",
        @"IOWA" : @"IA",
        @"KANSAS" : @"KS",
        @"KENTUCKY" : @"KY",
        @"LOUISIANA" : @"LA",
        @"MAINE" : @"ME",
        @"MARYLAND" : @"MD",
        @"MASSACHUSETTS" : @"MA",
        @"MICHIGAN" : @"MI",
        @"MINNESOTA" : @"MN",
        @"MISSISSIPPI" : @"MS",
        @"MISSOURI" : @"MO",
        @"MONTANA" : @"MT",
        @"NEBRASKA" : @"NE",
        @"NEVADA" : @"NV",
        @"NEW HAMPSHIRE" : @"NH",
        @"NEW JERSEY" : @"NJ",
        @"NEW MEXICO" : @"NM",
        @"NEW YORK" : @"NY",
        @"NORTH CAROLINA" : @"NC",
        @"NORTH DAKOTA" : @"ND",
        @"OHIO" : @"OH",
        @"OKLAHOMA" : @"OK",
        @"OREGON" : @"OR",
        @"PENNSYLVANIA" : @"PA",
        @"RHODE ISLAND" : @"RI",
        @"SOUTH CAROLINA" : @"SC",
        @"SOUTH DAKOTA" : @"SD",
        @"TENNESSEE" : @"TN",
        @"TEXAS" : @"TX",
        @"UTAH" : @"UT",
        @"VERMONT" : @"VT",
        @"VIRGINIA" : @"VA",
        @"WASHINGTON"	: @"WA",
        @"WEST VIRGINIA" : @"WV",
        @"WISCONSIN" : @"WI",
        @"WYOMING" : @"WY",
        @"GUAM" : @"GU",
        @"PUERTO RICO" : @"PR",
        @"VIRGIN ISLANDS" : @"VI"};
    
    stateNames = [states allKeys];
    stateAbbreviations = [states allValues];
  }
  return self;
}


/*
 return zip w/out any +4 component
*/
-(NSString*)chop:(NSString*)zip
{
  insist (zip);
  NSRange r = [zip rangeOfString:@"-"];
  if (r.location != NSNotFound)
    zip = [zip substringToIndex:r.location];
  
  /*some zips are 9 digits w/out hypens*/
  if (zip.length > 5)
    return [zip substringToIndex:5];
  
  return zip;
}


/*
 return the value of a column for a zip code. it is a programmer error if the db is not already opened.
 
 column - a column name like state, county, etc.
 zip - zip code
 error - set if there was an error
 
 return: the value at column, row of zip code. nil if error.
*/
-(NSString*)column:(NSString*)column forZip:(NSString*)zip error:(MFError* __autoreleasing*)error
{
  insist (column && column.length);
  insist (zip && zip.length && error);
  insist ([self isOpened]);
  
  /*our db doesn't have zip+4 so make sure we don't look for any*/
  zip = [self chop:zip];
  
  if (![self prepareError:error format:@"SELECT %@ FROM '%@' WHERE zip='%@'", column, TABLE_NAME, zip])
    return nil;
  
  if (![self step])
  {
    //*error = [MFError errorWithCode:MFErrorSql format:@"Couldn't find zip code %@ in \"%@\"", zip, path];
    //return nil;
    return @"";
  }
  
  NSString*value = [self textAtColumn:0];
  
  [self finalize];
  return value;
}

-(NSString*)countyForZip:(NSString*)zip error:(MFError* __autoreleasing*)error
{
  return [self column:@"county" forZip:zip error:error];
}
-(NSString*)stateForZip:(NSString*)zip error:(MFError* __autoreleasing*)error
{
  return [self column:@"state" forZip:zip error:error];
}


/*
 compare to strings that stand for states, including abbreviations
 
 s1 - a state spelled out or abbreviated
 s2 - a state spelled out or abbreviated

 returns : true if the states match.
*/
-(BOOL)equalState:(NSString*)s1 state:(NSString*)s2
{
  insist (s1 && s2 && states);
  
  /*normalize the strings, uppercase because the list we got off the internet was uppercase*/
  s1 = [[s1 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
  s1 = [s1 stringByReplacingOccurrencesOfString:@"." withString:@""];
  s1 = [s1 stringByReplacingOccurrencesOfString:@"," withString:@""];
  
  s2 = [[s2 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
  s2 = [s2 stringByReplacingOccurrencesOfString:@"." withString:@""];
  s2 = [s2 stringByReplacingOccurrencesOfString:@"," withString:@""];

  /*handle the easy case*/
  if ([s1 isEqualToString:s2])
    return YES;
  
  /*if the strings are the same length then one is not the abbreviation the other so they can't match*/
  if (s1.length == s2.length)
    return NO;
  
  /*convert any non abbreviations to abbreviations so we can compare*/
  NSString*abbreviation;
  if ((abbreviation = [states objectForKey:s1]))
    s1 = abbreviation;
  if ((abbreviation = [states objectForKey:s2]))
    s2 = abbreviation;
  
  /*compare*/
  return [s1 isEqualToString:s2];
}

-(NSString*)normalizeState:(NSString*)s
{
  insist (s);
  
  /*normalize the strings, uppercase because the list we got off the internet was uppercase*/
  s = [[s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
  s = [s stringByReplacingOccurrencesOfString:@"." withString:@""];
  s = [s stringByReplacingOccurrencesOfString:@"," withString:@""];
  return s;
}

/*
 return YES if s is a state name or abbreviation
*/
-(BOOL)isState:(NSString*)s
{
  insist (s && stateAbbreviations && stateNames);

  return [stateAbbreviations indexOfObject:s] != NSNotFound || [stateNames indexOfObject:s] != NSNotFound;
}


@end
