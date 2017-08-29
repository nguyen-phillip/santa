/// Copyright 2015 Google Inc. All rights reserved.
///
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
///
///    http://www.apache.org/licenses/LICENSE-2.0
///
///    Unless required by applicable law or agreed to in writing, software
///    distributed under the License is distributed on an "AS IS" BASIS,
///    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
///    See the License for the specific language governing permissions and
///    limitations under the License.

#import "SNTCommandSyncEventUpload.h"

#include "SNTLogging.h"

#import "MOLCertificate.h"
#import "MOLCodesignChecker.h"
#import "NSData+Zlib.h"
#import "SNTCommandSyncConstants.h"
#import "SNTCommandSyncState.h"
#import "SNTFileInfo.h"
#import "SNTStoredEvent.h"
#import "SNTXPCConnection.h"
#import "SNTXPCControlInterface.h"

@implementation SNTCommandSyncEventUpload

- (NSURL *)stageURL {
  NSString *stageName = [@"eventupload" stringByAppendingFormat:@"/%@", self.syncState.machineID];
  return [NSURL URLWithString:stageName relativeToURL:self.syncState.syncBaseURL];
}

- (BOOL)sync {
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  [[self.daemonConn remoteObjectProxy]
      databaseEventsPending:^(NSArray<SNTStoredEventJSON *> *events) {
        if (events.count) {
          [self uploadJSONEvents:events];
        }
        dispatch_semaphore_signal(sema);
      }];
  return (dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER) == 0);
}

// Manually create and return a JSON dictionary of the form "{ kEvents : [ event1, event2, ... ] }"
// where event1, event2, ... are items in the jsonEvents array.
- (NSData *)jsonDictionaryForEvents:(NSArray<NSData *> *)jsonEvents {
  NSMutableString *result = [NSMutableString string];
  [result appendFormat:@"{\"%@\":[", kEvents];
  BOOL prevItem = NO;
  for (NSData *jsonEvent in jsonEvents) {
    if (prevItem) [result appendString:@","];
    [result appendString:[[NSString alloc] initWithData:jsonEvent encoding:NSUTF8StringEncoding]];
    prevItem = YES;
  }
  [result appendString:@"]}"];
  return [result dataUsingEncoding:NSUTF8StringEncoding];
}

// Uploads an array of SNTStoredEventJSON to the server
- (BOOL)uploadJSONEvents:(NSArray<SNTStoredEventJSON *> *)events {
  NSMutableArray<NSData *> *uploadEvents = [[NSMutableArray alloc] init];

  NSMutableSet<NSNumber *> *eventIds = [NSMutableSet setWithCapacity:events.count];
  for (SNTStoredEventJSON *event in events) {
    [uploadEvents addObject:event.jsonData];
    if (event.index) [eventIds addObject:event.index];
    if (uploadEvents.count >= self.syncState.eventBatchSize) break;
  }

  NSData *requestBody = [self jsonDictionaryForEvents:uploadEvents];
  NSDictionary *r = [self performRequest:[self requestWithJSONData:requestBody]];
  if (!r) return NO;

  // A list of bundle hashes that require their related binary events to be uploaded.		
  self.syncState.bundleBinaryRequests = r[kEventUploadBundleBinaries];

  LOGI(@"Uploaded %lu events", uploadEvents.count);

  // Remove event IDs. For Bundle Events the ID is 0 so nothing happens.
  [[self.daemonConn remoteObjectProxy] databaseRemoveEventsWithIDs:[eventIds allObjects]];

  // See if there are any events remaining to upload
  if (uploadEvents.count < events.count) {
    NSRange nextEventsRange = NSMakeRange(uploadEvents.count, events.count - uploadEvents.count);
    NSArray *nextEvents = [events subarrayWithRange:nextEventsRange];
    return [self uploadJSONEvents:nextEvents];
  }

  return YES;
}

// Uploads an array of SNTStoredEvent to the server, by first converting each stored event to
// an instance of SNTStoredEventJSON, then calling uploadJSONEvents:
- (BOOL)uploadEvents:(NSArray<SNTStoredEvent *> *)events {
  NSMutableArray<SNTStoredEventJSON *> *jsonEvents = [NSMutableArray array];
  for (SNTStoredEvent *event in events) {
    [jsonEvents addObject:[[SNTStoredEventJSON alloc] initWithStoredEvent:event]];
  }
  return [self uploadJSONEvents:jsonEvents];
}

@end
