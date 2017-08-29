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

#import "SNTCommandSyncConstants.h"

NSString *const kXSRFToken = @"X-XSRF-TOKEN";

NSString *const kSerialNumber = @"serial_num";
NSString *const kHostname = @"hostname";
NSString *const kSantaVer = @"santa_version";
NSString *const kOSVer = @"os_version";
NSString *const kOSBuild = @"os_build";
NSString *const kPrimaryUser = @"primary_user";
NSString *const kRequestCleanSync = @"request_clean_sync";
NSString *const kBatchSize = @"batch_size";
NSString *const kUploadLogsURL = @"upload_logs_url";
NSString *const kClientMode = @"client_mode";
NSString *const kClientModeMonitor = @"MONITOR";
NSString *const kClientModeLockdown = @"LOCKDOWN";
NSString *const kCleanSync = @"clean_sync";
NSString *const kWhitelistRegex = @"whitelist_regex";
NSString *const kBlacklistRegex = @"blacklist_regex";
NSString *const kBinaryRuleCount = @"binary_rule_count";
NSString *const kCertificateRuleCount = @"certificate_rule_count";
NSString *const kFCMToken = @"fcm_token";
NSString *const kFCMFullSyncInterval = @"fcm_full_sync_interval";
NSString *const kFCMGlobalRuleSyncDeadline = @"fcm_global_rule_sync_deadline";
NSString *const kBundlesEnabled = @"bundles_enabled";

NSString *const kEvents = @"events";
NSString *const kEventUploadBundleBinaries = @"event_upload_bundle_binaries";

NSString *const kLogUploadField = @"files";

NSString *const kRules = @"rules";
NSString *const kRuleSHA256 = @"sha256";
NSString *const kRulePolicy = @"policy";
NSString *const kRulePolicyWhitelist = @"WHITELIST";
NSString *const kRulePolicyBlacklist = @"BLACKLIST";
NSString *const kRulePolicySilentBlacklist = @"SILENT_BLACKLIST";
NSString *const kRulePolicyRemove = @"REMOVE";
NSString *const kRuleType = @"rule_type";
NSString *const kRuleTypeBinary = @"BINARY";
NSString *const kRuleTypeCertificate = @"CERTIFICATE";
NSString *const kRuleCustomMsg = @"custom_msg";
NSString *const kCursor = @"cursor";

NSString *const kBackoffInterval = @"backoff";

NSString *const kFullSync = @"full_sync";
NSString *const kRuleSync = @"rule_sync";
NSString *const kConfigSync = @"config_sync";
NSString *const kLogSync = @"log_sync";

const NSUInteger kDefaultEventBatchSize = 50;
const NSUInteger kDefaultFullSyncInterval = 600;
const NSUInteger kDefaultFCMFullSyncInterval = 14400;
const NSUInteger kDefaultFCMGlobalRuleSyncDeadline = 600;
