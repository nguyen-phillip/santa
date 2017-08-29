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

#import "SNTStoredEvent.h"

#import "MOLCertificate.h"

NSString *const kFileSHA256 = @"file_sha256";
NSString *const kFilePath = @"file_path";
NSString *const kFileName = @"file_name";
NSString *const kExecutingUser = @"executing_user";
NSString *const kExecutionTime = @"execution_time";
NSString *const kDecision = @"decision";
NSString *const kLoggedInUsers = @"logged_in_users";
NSString *const kCurrentSessions = @"current_sessions";
NSString *const kFileBundleID = @"file_bundle_id";
NSString *const kFileBundlePath = @"file_bundle_path";
NSString *const kFileBundleExecutableRelPath = @"file_bundle_executable_rel_path";
NSString *const kFileBundleName = @"file_bundle_name";
NSString *const kFileBundleVersion = @"file_bundle_version";
NSString *const kFileBundleShortVersionString = @"file_bundle_version_string";
NSString *const kFileBundleHash = @"file_bundle_hash";
NSString *const kFileBundleHashMilliseconds = @"file_bundle_hash_millis";
NSString *const kFileBundleBinaryCount = @"file_bundle_binary_count";
NSString *const kPID = @"pid";
NSString *const kPPID = @"ppid";
NSString *const kParentName = @"parent_name";
NSString *const kSigningChain = @"signing_chain";
NSString *const kCertSHA256 = @"sha256";
NSString *const kCertCN = @"cn";
NSString *const kCertOrg = @"org";
NSString *const kCertOU = @"ou";
NSString *const kCertValidFrom = @"valid_from";
NSString *const kCertValidUntil = @"valid_until";
NSString *const kQuarantineDataURL = @"quarantine_data_url";
NSString *const kQuarantineRefererURL = @"quarantine_referer_url";
NSString *const kQuarantineTimestamp = @"quarantine_timestamp";
NSString *const kQuarantineAgentBundleID = @"quarantine_agent_bundle_id";

NSString *NSStringFromSNTEventState(SNTEventState state) {
  switch (state) {
    case SNTEventStateUnknown: return @"UNKNOWN";
    case SNTEventStateBundleBinary: return @"BUNDLE_BINARY";
    case SNTEventStateBlockUnknown: return @"BLOCK_UNKNOWN";
    case SNTEventStateBlockBinary: return @"BLOCK_BINARY";
    case SNTEventStateBlockCertificate: return @"BLOCK_CERTIFICATE";
    case SNTEventStateBlockScope: return @"BLOCK_SCOPE";
    case SNTEventStateAllowUnknown: return @"ALLOW_UNKNOWN";
    case SNTEventStateAllowBinary: return @"ALLOW_BINARY";
    case SNTEventStateAllowCertificate: return @"ALLOW_CERTIFICATE";
    case SNTEventStateAllowScope: return @"ALLOW_SCOPE";
    default: return @"UNKNOWN";  // TODO: should this return INVALID?
  }
}

@implementation SNTStoredEvent

#define ENCODE(obj, key) if (obj) [coder encodeObject:obj forKey:key]
#define DECODE(cls, key) [decoder decodeObjectOfClass:[cls class] forKey:key]
#define DECODEARRAY(cls, key) \
    [decoder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [cls class], nil] \
                            forKey:key]

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  ENCODE(self.idx, @"idx");
  ENCODE(self.fileSHA256, @"fileSHA256");
  ENCODE(self.filePath, @"filePath");

  ENCODE(@(self.needsBundleHash), @"needsBundleHash");
  ENCODE(self.fileBundleHash, @"fileBundleHash");
  ENCODE(self.fileBundleHashMilliseconds, @"fileBundleHashMilliseconds");
  ENCODE(self.fileBundleBinaryCount, @"fileBundleBinaryCount");
  ENCODE(self.fileBundleName, @"fileBundleName");
  ENCODE(self.fileBundlePath, @"fileBundlePath");
  ENCODE(self.fileBundleExecutableRelPath, @"fileBundleExecutableRelPath");
  ENCODE(self.fileBundleID, @"fileBundleID");
  ENCODE(self.fileBundleVersion, @"fileBundleVersion");
  ENCODE(self.fileBundleVersionString, @"fileBundleVersionString");

  ENCODE(self.signingChain, @"signingChain");

  ENCODE(self.executingUser, @"executingUser");
  ENCODE(self.occurrenceDate, @"occurrenceDate");
  ENCODE(@(self.decision), @"decision");
  ENCODE(self.pid, @"pid");
  ENCODE(self.ppid, @"ppid");
  ENCODE(self.parentName, @"parentName");

  ENCODE(self.loggedInUsers, @"loggedInUsers");
  ENCODE(self.currentSessions, @"currentSessions");

  ENCODE(self.quarantineDataURL, @"quarantineDataURL");
  ENCODE(self.quarantineRefererURL, @"quarantineRefererURL");
  ENCODE(self.quarantineTimestamp, @"quarantineTimestamp");
  ENCODE(self.quarantineAgentBundleID, @"quarantineAgentBundleID");
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _idx = @(arc4random());
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
  self = [super init];
  if (self) {
    _idx = DECODE(NSNumber, @"idx");
    _fileSHA256 = DECODE(NSString, @"fileSHA256");
    _filePath = DECODE(NSString, @"filePath");

    _needsBundleHash = [DECODE(NSNumber, @"needsBundleHash") boolValue];
    _fileBundleHash = DECODE(NSString, @"fileBundleHash");
    _fileBundleHashMilliseconds = DECODE(NSNumber, @"fileBundleHashMilliseconds");
    _fileBundleBinaryCount = DECODE(NSNumber, @"fileBundleBinaryCount");
    _fileBundleName = DECODE(NSString, @"fileBundleName");
    _fileBundlePath = DECODE(NSString, @"fileBundlePath");
    _fileBundleExecutableRelPath = DECODE(NSString, @"fileBundleExecutableRelPath");
    _fileBundleID = DECODE(NSString, @"fileBundleID");
    _fileBundleVersion = DECODE(NSString, @"fileBundleVersion");
    _fileBundleVersionString = DECODE(NSString, @"fileBundleVersionString");

    _signingChain = DECODEARRAY(MOLCertificate, @"signingChain");

    _executingUser = DECODE(NSString, @"executingUser");
    _occurrenceDate = DECODE(NSDate, @"occurrenceDate");
    _decision = (SNTEventState)[DECODE(NSNumber, @"decision") intValue];
    _pid = DECODE(NSNumber, @"pid");
    _ppid = DECODE(NSNumber, @"ppid");
    _parentName = DECODE(NSString, @"parentName");

    _loggedInUsers = DECODEARRAY(NSString, @"loggedInUsers");
    _currentSessions = DECODEARRAY(NSString, @"currentSessions");

    _quarantineDataURL = DECODE(NSString, @"quarantineDataURL");
    _quarantineRefererURL = DECODE(NSString, @"quarantineRefererURL");
    _quarantineTimestamp = DECODE(NSDate, @"quarantineTimestamp");
    _quarantineAgentBundleID = DECODE(NSString, @"quarantineAgentBundleID");
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) return YES;
  if (![other isKindOfClass:[SNTStoredEvent class]]) return NO;
  SNTStoredEvent *o = other;
  return ([self.fileSHA256 isEqual:o.fileSHA256] && [self.idx isEqual:o.idx]);
}

- (NSUInteger)hash {
  NSUInteger prime = 31;
  NSUInteger result = 1;
  result = prime * result + [self.idx hash];
  result = prime * result + [self.fileSHA256 hash];
  result = prime * result + [self.occurrenceDate hash];
  return result;
}

- (NSData *)jsonData {
#define ADDKEY(dict, key, value) if (value) dict[key] = value
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  ADDKEY(dict, kFileSHA256, self.fileSHA256);
  ADDKEY(dict, kFilePath, [self.filePath stringByDeletingLastPathComponent]);
  ADDKEY(dict, kFileName, [self.filePath lastPathComponent]);

  ADDKEY(dict, kFileBundleHash, self.fileBundleHash);
  ADDKEY(dict, kFileBundleHashMilliseconds, self.fileBundleHashMilliseconds);
  ADDKEY(dict, kFileBundleBinaryCount, self.fileBundleBinaryCount);
  ADDKEY(dict, kFileBundleName, self.fileBundleName);
  ADDKEY(dict, kFileBundlePath, self.fileBundlePath);
  ADDKEY(dict, kFileBundleExecutableRelPath, self.fileBundleExecutableRelPath);
  ADDKEY(dict, kFileBundleID, self.fileBundleID);
  ADDKEY(dict, kFileBundleVersion, self.fileBundleVersion);
  ADDKEY(dict, kFileBundleShortVersionString, self.fileBundleVersionString);

  if (self.signingChain && self.signingChain.count) {
    NSMutableArray *certList = [NSMutableArray array];
    for (MOLCertificate *cert in self.signingChain) {
      NSMutableDictionary *certDict = [NSMutableDictionary dictionary];
      ADDKEY(certDict, kCertSHA256, cert.SHA256);
      ADDKEY(certDict, kCertCN, cert.commonName);
      ADDKEY(certDict, kCertOrg, cert.orgName);
      ADDKEY(certDict, kCertOU, cert.orgUnit);
      if (cert.validFrom) {
        certDict[kCertValidFrom] = @([cert.validFrom timeIntervalSince1970]);
      }
      if (cert.validUntil) {
        certDict[kCertValidUntil] = @([cert.validUntil timeIntervalSince1970]);
      }
      [certList addObject:certDict];
    }
    dict[kSigningChain] = certList;
  }

  ADDKEY(dict, kExecutingUser, self.executingUser);
  if (self.occurrenceDate) {
    dict[kExecutionTime] = @([self.occurrenceDate timeIntervalSince1970]);
  }
  ADDKEY(dict, kDecision, NSStringFromSNTEventState(self.decision));
  ADDKEY(dict, kLoggedInUsers, self.loggedInUsers);
  ADDKEY(dict, kCurrentSessions, self.currentSessions);
  ADDKEY(dict, kPID, self.pid);
  ADDKEY(dict, kPPID, self.ppid);
  ADDKEY(dict, kParentName, self.parentName);

  ADDKEY(dict, kQuarantineDataURL, self.quarantineDataURL);
  ADDKEY(dict, kQuarantineRefererURL, self.quarantineRefererURL);
  if (self.quarantineTimestamp) {
    dict[kQuarantineTimestamp] = @([self.quarantineTimestamp timeIntervalSince1970]);
  }
  ADDKEY(dict, kQuarantineAgentBundleID, self.quarantineAgentBundleID);

  return [NSJSONSerialization dataWithJSONObject:dict options:0 error:NULL];
#undef ADDKEY
}

- (NSString *)description {
  return
      [NSString stringWithFormat:@"SNTStoredEvent[%@] with SHA-256: %@", self.idx, self.fileSHA256];
}

@end

@implementation SNTStoredEventJSON

- (instancetype)initWithIndex:(NSNumber *)index data:(NSData *)data {
  self = [super init];
  if (self) {
    _index = index;
    _jsonData = data;
  }
  return self;
}

- (instancetype)initWithStoredEvent:(SNTStoredEvent *)event {
  return [self initWithIndex:event.idx data:[event jsonData]];
}

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:self.index forKey:@"index"];
  [coder encodeObject:self.jsonData forKey:@"jsonData"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
  NSNumber *index = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"index"];
  NSData *data = [decoder decodeObjectOfClass:[NSData class] forKey:@"jsonData"];
  return [self initWithIndex:index data:data];
}

@end
