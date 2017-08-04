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

#import "SNTCommandSyncRuleDownload.h"

#import "SNTCommandSyncConstants.h"
#import "SNTCommandSyncState.h"
#import "SNTRule.h"
#import "SNTXPCConnection.h"
#import "SNTXPCControlInterface.h"
#import "SNTStoredEvent.h"


#include "SNTLogging.h"

@implementation SNTCommandSyncRuleDownload

- (NSURL *)stageURL {
  NSString *stageName = [@"ruledownload" stringByAppendingFormat:@"/%@", self.syncState.machineID];
  return [NSURL URLWithString:stageName relativeToURL:self.syncState.syncBaseURL];
}

// This is called only from SNTCommandSyncManager.
// Either from a block created within initWithDaemonConnection:isDaemon: or
// from ruleDownloadWithSyncState:
- (BOOL)sync {
  self.syncState.downloadedRules = [NSMutableArray array];
  return [self ruleDownloadWithCursor:nil];
}

- (void)logDictionary:(NSDictionary *)dict withName:(NSString *)name {
  LOGI(@"#### --------%@--------", name);
  for (id key in dict) {
    LOGI(@"#### %@ : %@", key, dict[key]);
  }
  LOGI(@"#### ---------------------");
}

// This is called from sync only.
// What does the return value mean?? A: nothing b/c never used.
- (BOOL)ruleDownloadWithCursor:(NSString *)cursor {
  NSDictionary *requestDict = (cursor ? @{kCursor : cursor} : @{});

  NSDictionary *resp = [self performRequest:[self requestWithDictionary:requestDict]];
  if (!resp) return NO;

  LOGI(@"#### ruleDownloadWithCursor:");
  [self logDictionary:resp withName:@"resp"];

  for (NSDictionary *rule in resp[kRules]) {
    SNTRule *r = [self ruleFromDictionary:rule];  // This is where we lose the PACKAGE rule.
    [self logDictionary:rule withName:@"rule in resp[kRules]"];
    if (r) [self.syncState.downloadedRules addObject:r];
  }

  // keep downloading more rules from server if there are more
  // There is definitely a better way to write this...
  if (resp[kCursor]) {
    return [self ruleDownloadWithCursor:resp[kCursor]];
  }

  if (!self.syncState.downloadedRules.count) return YES;

  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  __block NSError *error;
  [[self.daemonConn remoteObjectProxy] databaseRuleAddRules:self.syncState.downloadedRules
                                                 cleanSlate:self.syncState.cleanSync
                                                      reply:^(NSError *e) {
    error = e;
    dispatch_semaphore_signal(sema);
  }];
  dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_SEC));

  if (error) {
    LOGE(@"Failed to add rule(s) to database: %@", error.localizedDescription);
    LOGD(@"Failure reason: %@", error.localizedFailureReason);
    return NO;
  }

  sema = dispatch_semaphore_create(0);
  [[self.daemonConn remoteObjectProxy] setRuleSyncLastSuccess:[NSDate date] reply:^{
    dispatch_semaphore_signal(sema);
  }];
  dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));

  LOGI(@"#### Added %lu rules", self.syncState.downloadedRules.count);

  for (SNTRule *rule in self.syncState.downloadedRules) {
    NSString *filename = [[self.syncState.ruleSyncCache objectForKey:rule.shasum] copy];
    LOGI(@"#### downloaded rule: %@, filename=%@", rule, filename);
  }

  for (SNTRule *r in self.syncState.downloadedRules) {
    // Ignore rules that aren't related to whitelisting a binary.
    if (!(r.type == SNTRuleTypeBinary && r.state == SNTRuleStateWhitelist)) continue;
    // Check to see if new rule corresponds to a recently blocked binary.
    [[self.daemonConn remoteObjectProxy] recentlyBlockedEventWithSHA256:r.shasum
                                                                  reply:^(SNTStoredEvent *se) {
      if (!se) {
        LOGI(@"#### recentlyBlockedEvent for %@ returned nil", r.shasum);
        return;
      }
      LOGI(@"#### matching event: %@, %@, %@", se, se.fileBundleName, se.filePath);
      NSString *name = (se.fileBundleName) ? se.fileBundleName : se.filePath;
      NSString *message = [NSString stringWithFormat:@"%@ can now be run", name];
      LOGI(@"#### %@", message);
      [[self.daemonConn remoteObjectProxy]
        postRuleSyncNotificationWithCustomMessage:message reply:^{}];
    }];
  }

  /*
  for (SNTRule *r in self.syncState.downloadedRules) {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [[self.daemonConn remoteObjectProxy] databaseEventsWithSHA256:r.shasum
                                                            reply:^(NSArray *events) {
      LOGI(@"#### found %d matching events", [events count]);
      for (SNTStoredEvent *se in events) {
        LOGI(@"#### matching event: %@, %@, %@", se, se.fileBundleName, se.filePath);
        NSString *name = (se.fileBundleName) ? se.fileBundleName : se.filePath;
        NSString *message = [NSString stringWithFormat:@"%@ can now be run", name];
        [[self.daemonConn remoteObjectProxy]
         postRuleSyncNotificationWithCustomMessage:message reply:^{}];
      }
      dispatch_semaphore_signal(sema);
    }];
  }
   */

  /*
  if (self.syncState.targetedRuleSync) {
    for (SNTRule *r in self.syncState.downloadedRules) {
      NSString *fileName = [[self.syncState.ruleSyncCache objectForKey:r.shasum] copy];
      [self.syncState.ruleSyncCache removeObjectForKey:r.shasum];
      if (fileName.length) {
        NSString *message = [NSString stringWithFormat:@"%@ can now be run", fileName];
        [[self.daemonConn remoteObjectProxy]
            postRuleSyncNotificationWithCustomMessage:message reply:^{}];
      }
    }
  }
   */

  return YES;
}

- (SNTRule *)ruleFromDictionary:(NSDictionary *)dict {
  if (![dict isKindOfClass:[NSDictionary class]]) return nil;

  SNTRule *newRule = [[SNTRule alloc] init];
  newRule.shasum = dict[kRuleSHA256];
  if (newRule.shasum.length != 64) return nil;

  NSString *policyString = dict[kRulePolicy];
  if ([policyString isEqual:kRulePolicyWhitelist]) {
    newRule.state = SNTRuleStateWhitelist;
  } else if ([policyString isEqual:kRulePolicyBlacklist]) {
    newRule.state = SNTRuleStateBlacklist;
  } else if ([policyString isEqual:kRulePolicySilentBlacklist]) {
    newRule.state = SNTRuleStateSilentBlacklist;
  } else if ([policyString isEqual:kRulePolicyRemove]) {
    newRule.state = SNTRuleStateRemove;
  } else {
    return nil;
  }

  NSString *ruleTypeString = dict[kRuleType];
  if ([ruleTypeString isEqual:kRuleTypeBinary]) {
    newRule.type = SNTRuleTypeBinary;
  } else if ([ruleTypeString isEqual:kRuleTypeCertificate]) {
    newRule.type = SNTRuleTypeCertificate;
  } else {
    return nil;
  }

  NSString *customMsg = dict[kRuleCustomMsg];
  if (customMsg.length) {
    newRule.customMsg = customMsg;
  }

  return newRule;
}

@end
