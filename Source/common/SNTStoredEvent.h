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

@import Foundation;

#import "SNTCommonEnums.h"

@class MOLCertificate;

// List of string constants used as keys for JSON encoding SNTStoredEvent.
extern NSString *const kFileSHA256;
extern NSString *const kFilePath;
extern NSString *const kFileName;
extern NSString *const kExecutingUser;
extern NSString *const kExecutionTime;
extern NSString *const kDecision;
extern NSString *const kLoggedInUsers;
extern NSString *const kCurrentSessions;
extern NSString *const kFileBundleID;
extern NSString *const kFileBundlePath;
extern NSString *const kFileBundleExecutableRelPath;
extern NSString *const kFileBundleName;
extern NSString *const kFileBundleVersion;
extern NSString *const kFileBundleShortVersionString;
extern NSString *const kFileBundleHash;
extern NSString *const kFileBundleHashMilliseconds;
extern NSString *const kFileBundleBinaryCount;
extern NSString *const kPID;
extern NSString *const kPPID;
extern NSString *const kParentName;
extern NSString *const kSigningChain;
extern NSString *const kCertSHA256;
extern NSString *const kCertCN;
extern NSString *const kCertOrg;
extern NSString *const kCertOU;
extern NSString *const kCertValidFrom;
extern NSString *const kCertValidUntil;
extern NSString *const kQuarantineDataURL;
extern NSString *const kQuarantineRefererURL;
extern NSString *const kQuarantineTimestamp;
extern NSString *const kQuarantineAgentBundleID;

///
///  Given a SNTEventState, returns a human-readable string description.
///
extern NSString *NSStringFromSNTEventState(SNTEventState state);

///
///  Represents an event stored in the database.
///
@interface SNTStoredEvent : NSObject<NSSecureCoding>

///
///  An index for this event, randomly generated during initialization.
///
@property NSNumber *idx;

///
///  The SHA-256 of the executed file.
///
@property NSString *fileSHA256;

///
///  The full path of the executed file.
///
@property NSString *filePath;

///
///  Set to YES if the event is a part of a bundle. When an event is passed to SantaGUI this propery
///  will be used as an indicator to to kick off bundle hashing as necessary. Default value is NO.
///
@property BOOL needsBundleHash;

///
///  If the executed file was part of a bundle, this is the calculated hash of all the nested
///  executables within the bundle.
///
@property NSString *fileBundleHash;

///
///  If the executed file was part of a bundle, this is the time in ms it took to hash the bundle.
///
@property NSNumber *fileBundleHashMilliseconds;

///
///  If the executed file was part of a bundle, this is the total count of related mach-o binaries.
///
@property NSNumber *fileBundleBinaryCount;

///
///  If the executed file was part of the bundle, this is the CFBundleDisplayName, if it exists
///  or the CFBundleName if not.
///
@property NSString *fileBundleName;

///
///  If the executed file was part of the bundle, this is the path to the bundle.
///
@property NSString *fileBundlePath;

///
///  The relative path to the bundle's main executable.
///
@property NSString *fileBundleExecutableRelPath;

///
///  If the executed file was part of the bundle, this is the CFBundleID.
///
@property NSString *fileBundleID;

///
///  If the executed file was part of the bundle, this is the CFBundleVersion.
///
@property NSString *fileBundleVersion;

///
///  If the executed file was part of the bundle, this is the CFBundleShortVersionString.
///
@property NSString *fileBundleVersionString;

///
///  If the executed file was signed, this is an NSArray of MOLCertificate's
///  representing the signing chain.
///
@property NSArray<MOLCertificate *> *signingChain;

///
///  The user who executed the binary.
///
@property NSString *executingUser;

///
///  The date and time the execution request was received by santad.
///
@property NSDate *occurrenceDate;

///
///  The decision santad returned.
///
@property SNTEventState decision;

///
///  NSArray of logged in users when the decision was made.
///
@property NSArray<NSString *> *loggedInUsers;

///
///  NSArray of sessions when the decision was made (e.g. nobody@console, nobody@ttys000).
///
@property NSArray<NSString *> *currentSessions;

///
///  The process ID of the binary being executed.
///
@property NSNumber *pid;

///
///  The parent process ID of the binary being executed.
///
@property NSNumber *ppid;

///
///  The name of the parent process.
///
@property NSString *parentName;

///
///  Quarantine data about the executed file, if any.
///
@property NSString *quarantineDataURL;
@property NSString *quarantineRefererURL;
@property NSDate *quarantineTimestamp;
@property NSString *quarantineAgentBundleID;

///
///  Return an NSData object containing a JSON digest representation of the stored event.
///
- (NSData *)jsonData;

@end

///
///  This temporary object is used only to return JSON event data paired with a identifying index
///  from SNTEventTable's pendingEvents method.
///
@interface SNTStoredEventJSON : NSObject<NSSecureCoding>

///
///  The index for the event, stored separately from the JSON data.  This index is used to later
///  delete the stored event from the event table after it has been processed.
///
@property(nonatomic, readonly) NSNumber *index;

///
///  A digested JSON-encoded representation of a SNTStoredEvent.
///
@property(nonatomic, readonly) NSData *jsonData;

///
///  This is the designated initializer.
///
- (instancetype)initWithIndex:(NSNumber *)index data:(NSData *)data;

///
///  Create a SNTStoredEventJSON object from a SNTStoredEvent.
///
- (instancetype)initWithStoredEvent:(SNTStoredEvent *)event;

@end
