//
//  MFStringCategory.m
//  MFLib
//
//  Created by finucane on 3/20/14.
//  Copyright (c) 2014 mf. All rights reserved.
//

#import "MFStringCategory.h"
#import <MFLib/insist.h>

@implementation  NSString (StringCategory)


- (NSString*) flattenHTML
{
  NSMutableString*s = [NSMutableString stringWithCapacity:[self length]];
  insist (s);
  
  
  unsigned long numChars = [self length];
  BOOL inTag = NO;
  BOOL inEscape = NO;
  
  for (int i = 0; i < numChars; i++)
  {
    unichar c = [self characterAtIndex:i];
    
    if (c == '<')
      inTag = YES;
    else if(c == '>')
      inTag = NO;
    else if (!inTag && c == '&')
      inEscape = YES;
    else if (!inTag && inEscape && c == ';')
      inEscape = NO;
    else if (!inTag && !inEscape)
      [s appendFormat:@"%C", c];
  }
  
	return s;
}

- (NSString*)detag
{
  NSMutableString*s = [NSMutableString stringWithCapacity:[self length]];
  insist (s);
  
  
  unsigned long numChars = [self length];
  BOOL inTag = NO;
  
  for (int i = 0; i < numChars; i++)
  {
    unichar c = [self characterAtIndex:i];
    
    if (c == '<')
      inTag = YES;
    else if(c == '>')
      inTag = NO;
    else if (!inTag )
      [s appendFormat:@"%C", c];
  }
  
	return s;
}


- (NSString*)htmlSafe
{
  NSMutableString*s = [NSMutableString stringWithString:self];
  insist (s);
  
  /*order matters here because of the &*/
  [s replaceOccurrencesOfString:@"&" withString:@"&amp;" options:NSLiteralSearch range:NSMakeRange(0,[s length])];
  [s replaceOccurrencesOfString:@"<" withString:@"&lt;" options:NSLiteralSearch range:NSMakeRange(0,[s length])];
  [s replaceOccurrencesOfString:@">" withString:@"&gt;" options:NSLiteralSearch range:NSMakeRange(0,[s length])];
  return s;
}


- (BOOL) grep:(NSString*)s
{
  NSRange r = [self rangeOfString:s];
  return r.location != NSNotFound;
}

- (BOOL) igrep:(NSString*)s
{
  NSRange r = [self rangeOfString:s options:NSCaseInsensitiveSearch];
  return r.location != NSNotFound;
}

- (BOOL) startsWith:(NSString*)s
{
  NSRange r = [self rangeOfString:s];
  return r.location == 0;
}

- (NSString*) stringByTrimmingString:(NSString*)s;
{
  NSMutableString*ms = [NSMutableString stringWithString:self];
  NSCharacterSet*whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  
  int changes;
  do
  {
    changes = 0;
    for (NSRange r = [ms rangeOfCharacterFromSet:whitespace]; !r.location; r = [ms rangeOfCharacterFromSet:whitespace], changes++)
      [ms deleteCharactersInRange:r];
    
    for (NSRange r = [ms rangeOfString:s options:NSCaseInsensitiveSearch]; !r.location; r = [ms rangeOfString:s options:NSCaseInsensitiveSearch], changes++)
      [ms deleteCharactersInRange:r];
    
  } while (changes);
  return ms;
}


- (NSString*) stringByRemovingCharactersInString:(NSString*)s
{
  NSMutableString*ms = [NSMutableString stringWithString:self];
  NSCharacterSet*set = [NSCharacterSet characterSetWithCharactersInString:s];
  
  for (NSRange r = [ms rangeOfCharacterFromSet:set]; r.length; r = [ms rangeOfCharacterFromSet:set])
    [ms deleteCharactersInRange:r];

  return ms;
}

- (NSString*) stringByReplacing:(unichar)original withChar:(unichar)replacement
{
  NSMutableString*s = [NSMutableString stringWithCapacity:[self length]];
  insist (s);
  
  for (int i = 0; i < [self length]; i++)
  {
    unichar c = [self characterAtIndex:i];
    [s appendFormat:@"%C", (unichar)(c == original ? replacement : c)];
  }
	return s;
}

- (NSString*) substringAfterString:(NSString*)s
{
  NSRange r = [self rangeOfString:s];
  if (r.location == NSNotFound || r.location == [self length] - 1)
    return nil;
  return [self substringFromIndex:r.location + 1];
}

- (NSString*)substringToString:(NSString*)s
{
  NSRange r = [self rangeOfString:s];
  if (r.location == NSNotFound)
    return @"";
  return [self substringToIndex:r.location];
}

- (NSArray*) componentsSeparatedByCharactersInString:(NSString*)s
{
  return [self componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:s]];
}

- (NSString*) stringWithoutRepeatedString:(NSString*)s
{
  insist (s);
  NSMutableString*ms = [NSMutableString stringWithString:self];
  NSString*pair = [NSString stringWithFormat:@"%@%@", s, s];
  insist (pair);
  
  for (;;)
  {
    NSRange r = [ms rangeOfString:pair];
    if (r.location == NSNotFound)
      break;
    r.length--;
    [ms deleteCharactersInRange:r];
  } 
  return ms;
}


- (NSArray*) nonEmptyComponentsSeparatedByString:(NSString*)s
{
  NSMutableArray*words = [NSMutableArray arrayWithArray:[self componentsSeparatedByString:s]];
  insist (words);
  
  /*remove empty strings*/
  for (int i = 0; i < [words count]; i++)
  {
    NSString*t = [[words objectAtIndex:i] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([t isEqualToString:@""])
    {
      [words removeObjectAtIndex: i];
      i--;
    }
  }
  return words;
}


- (NSArray*) nonEmptyComponentsSeparatedByCharactersInSet:(NSCharacterSet*)set
{
  NSMutableArray*words = [NSMutableArray arrayWithArray:[self componentsSeparatedByCharactersInSet:set]];
  insist (words);
  
  /*remove empty strings*/
  for (int i = 0; i < [words count]; i++)
  {
    NSString*t = [[words objectAtIndex:i] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([t isEqualToString:@""])
    {
      [words removeObjectAtIndex: i];
      i--;
    }
  }
  return words;
}




@end
