//
//  MFStringCategory.h
//  MFLib
//
//  Created by finucane on 3/20/14.
//  Copyright (c) 2014 mf. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (StringCategory)
-(BOOL) grep:(NSString*)s;
-(NSString*)htmlSafe;
-(BOOL) igrep:(NSString*)s;
-(BOOL) startsWith:(NSString*)s;
-(NSString*) stringByTrimmingString:(NSString*)s;
-(NSString*) stringByRemovingCharactersInString:(NSString*)s;
-(NSString*) flattenHTML;
-(NSString*)detag;
-(NSString*) stringByReplacing:(unichar)original withChar:(unichar)replacement;
-(NSString*) substringAfterString:(NSString*)s;
-(NSArray*) componentsSeparatedByCharactersInString:(NSString*)s;
-(NSString*) stringWithoutRepeatedString:(NSString*)s;
-(NSArray*) nonEmptyComponentsSeparatedByCharactersInSet:(NSCharacterSet*)set;
-(NSArray*) nonEmptyComponentsSeparatedByString:(NSString*)s;
-(NSString*)substringToString:(NSString*)s;
@end
