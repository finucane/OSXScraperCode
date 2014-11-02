//
//  insist.h
//  Geocoder
//
//  Created by finucane on 3/13/14.
//  Copyright (c) 2014 Truth MD, Inc. All rights reserved.
//

#ifndef Geocoder_insist_h
#define Geocoder_insist_h

#ifdef DEBUG

#define insist(e) if(!(e)) [NSException raise: @"assertion failed." format: @"%@:%d (%s)", [[NSString stringWithCString:__FILE__ encoding:NSUTF8StringEncoding] lastPathComponent], __LINE__, #e]

#else

#define insist(e)

#endif

extern void MF_test ();
#endif
