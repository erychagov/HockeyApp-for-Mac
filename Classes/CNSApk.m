// Copyright 2011 Codenauts UG. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "CNSApk.h"
#import "CNSLogHelper.h"
#import "NSFileHandle+CNSAvailableData.h"
#import "CNSPreferencesViewController.h"

@implementation CNSApk

#pragma mark - NSDocument Methods

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
  return YES;
}

- (NSString *)windowNibName {
  return @"CNSApk";
}

#pragma mark - Private Helper Methods

- (NSDictionary *)getInfosFromAPKAtPath:(NSString *)path {
  NSDictionary *results = nil;
  NSString *aaptPath = [[NSUserDefaults standardUserDefaults] stringForKey:CNSUserDefaultsAAPTPath];
  if ([aaptPath length] > 0) {
    NSTask *aapt = [[NSTask alloc] init];
    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *grepPipe = [NSPipe pipe];
    [aapt setStandardOutput:grepPipe];
    [aapt setLaunchPath:aaptPath];
    [aapt setArguments:[NSArray arrayWithObjects:@"dump", @"badging", path, nil]];
    [aapt launch];

    NSTask *grep = [[NSTask alloc] init];
    [grep setStandardInput:grepPipe];
    [grep setStandardOutput:outPipe];
    [grep setLaunchPath:@"/usr/bin/egrep"];
    [grep setArguments:[NSArray arrayWithObjects:@"package:", nil]];
    [grep launch];

    NSMutableData *result = [NSMutableData data];
    NSData *dataIn = nil;
    NSException *error = nil;

    while ((dataIn = [[outPipe fileHandleForReading] availableDataOrError:&error]) && [dataIn length] && error == nil) {
      [result appendData:dataIn];
    }
    NSString *line = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];

    NSRegularExpression* regex = [[NSRegularExpression alloc]
                                  initWithPattern:@"package: name='(.*)' versionCode='(.*)' versionName='(.*)'"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:nil];
    NSArray* chunks = [regex matchesInString:line options:0
                                       range:NSMakeRange(0, [line length])];

    if ([chunks count] > 0) {
      for (NSTextCheckingResult* b in chunks) {
        results = @{
          @"name" : [line substringWithRange:[b rangeAtIndex:1]],
          @"versionCode" : [line substringWithRange:[b rangeAtIndex:2]],
          @"versionName" : [line substringWithRange:[b rangeAtIndex:3]]
        };
      }
    }
  }
  return results;
}

- (NSString *)bundleIdentifier {
  if (bundleIdentifier) {
    return bundleIdentifier;
  }

  NSDictionary *info = [self getInfosFromAPKAtPath:[self.fileURL path]];

  self.bundleIdentifier = [info valueForKey:@"name"];
  self.bundleVersion = [info valueForKey:@"versionCode"];
  self.bundleShortVersion = [info valueForKey:@"versionName"];

  return bundleIdentifier;
}
@end
