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

#import "SNTEventTable.h"

#import "MOLCertificate.h"
#import "SNTStoredEvent.h"

@implementation SNTEventTable

- (uint32_t)initializeDatabase:(FMDatabase *)db fromVersion:(uint32_t)version {
  int newVersion = 0;

  if (version < 1) {
    [db executeUpdate:@"CREATE TABLE 'events' ("
                      @"'idx' INTEGER PRIMARY KEY AUTOINCREMENT,"
                      @"'filesha256' TEXT NOT NULL,"
                      @"'eventdata' BLOB);"];
    [db executeUpdate:@"CREATE INDEX filesha256 ON events (filesha256);"];
    newVersion = 1;
  }

  if (version < 2) {
    // Clean-up: Find events where the bundle details might not be strings and update them.
    FMResultSet *rs = [db executeQuery:@"SELECT * FROM events"];
    while ([rs next]) {
      SNTStoredEvent *se = [self legacyEventFromResultSet:rs];
      if (!se) continue;

      Class NSStringClass = [NSString class];
      if ([se.fileBundleID class] != NSStringClass) {
        se.fileBundleID = [se.fileBundleID description];
      }
      if ([se.fileBundleName class] != NSStringClass) {
        se.fileBundleName = [se.fileBundleName description];
      }
      if ([se.fileBundleVersion class] != NSStringClass) {
        se.fileBundleVersion = [se.fileBundleVersion description];
      }
      if ([se.fileBundleVersionString class] != NSStringClass) {
        se.fileBundleVersionString = [se.fileBundleVersionString description];
      }

      NSData *eventData;
      NSNumber *idx = [rs objectForColumnName:@"idx"];
      @try {
        eventData = [NSKeyedArchiver archivedDataWithRootObject:se];
        [db executeUpdate:@"UPDATE events SET eventdata=? WHERE idx=?", eventData, idx];
      } @catch (NSException *exception) {
        [db executeUpdate:@"DELETE FROM events WHERE idx=?", idx];
      }
    }
    [rs close];
    newVersion = 2;
  }

  if (version < 3) {
    // Clean-up: Disable AUTOINCREMENT on idx column
    [db executeUpdate:@"CREATE TABLE 'events_tmp' ("
                      @"'idx' INTEGER PRIMARY KEY,"
                      @"'filesha256' TEXT NOT NULL,"
                      @"'eventdata' BLOB);"];
    [db executeUpdate:@"INSERT INTO events_tmp SELECT * FROM events"];
    [db executeUpdate:@"DROP TABLE events"];
    [db executeUpdate:@"ALTER TABLE events_tmp RENAME TO events"];
    newVersion = 3;
  }

  if (version < 4) {
    // Clean-up: Update all events so that eventdata is JSON blob instead of NSKeyedArchiver blob.
    FMResultSet *rs = [db executeQuery:@"SELECT * FROM events"];
    while ([rs next]) {
      SNTStoredEvent *se = [self legacyEventFromResultSet:rs];
      if (!se) continue;
      NSData *jsonData = [se jsonData];
      if (!jsonData) continue;
      NSNumber *idx = [rs objectForColumnName:@"idx"];
      [db executeUpdate:@"UPDATE events SET eventdata=? WHERE idx=?", jsonData, idx];
    }
    [rs close];
    newVersion = 4;
  }

  return newVersion;
}

#pragma mark Loading / Storing

- (BOOL)addStoredEvent:(SNTStoredEvent *)event {
  return [self addStoredEvents:@[event]];
}

- (BOOL)addStoredEvents:(NSArray<SNTStoredEvent *> *)events {
  NSMutableDictionary *eventsData = [NSMutableDictionary dictionaryWithCapacity:events.count];
  for (SNTStoredEvent *event in events) {
    if (!event.idx ||
        !event.fileSHA256 ||
        !event.filePath ||
        !event.occurrenceDate ||
        !event.decision) continue;

    NSData *jsonData = [event jsonData];
    eventsData[jsonData] = event;
  }

  __block BOOL success = NO;
  [self inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [eventsData enumerateKeysAndObjectsUsingBlock:^(NSData *jsonData,
                                                    SNTStoredEvent *event,
                                                    BOOL *stop) {
      success = [db executeUpdate:@"INSERT INTO 'events' (idx, filesha256, eventdata)"
                    @"VALUES (?, ?, ?)",
                    event.idx, event.fileSHA256, jsonData];
      if (!success) *stop = YES;
    }];
  }];

  return success;
}

#pragma mark Querying/Retreiving

- (NSUInteger)pendingEventsCount {
  __block NSUInteger count = 0;
  [self inDatabase:^(FMDatabase *db) {
    count = [db intForQuery:@"SELECT COUNT(*) FROM events"];
  }];
  return count;
}

- (NSArray<SNTStoredEventJSON *> *)pendingEvents {
  NSMutableArray<SNTStoredEventJSON *> *result = [NSMutableArray array];

  [self inDatabase:^(FMDatabase *db) {
    FMResultSet *rs = [db executeQuery:@"SELECT * FROM events"];

    while ([rs next]) {
      SNTStoredEventJSON *event = [self eventFromResultSet:rs];
      if (event) {
        [result addObject:event];
      } else {
        [db executeUpdate:@"DELETE FROM events WHERE idx=?", [rs objectForColumnName:@"idx"]];
      }
    }

    [rs close];
  }];

  return result.copy;
}

// For event tables with schema version <= 3, extract the SNTStoredEvent from the the result set.
- (SNTStoredEvent *)legacyEventFromResultSet:(FMResultSet *)rs {
  NSData *eventData = [rs dataForColumn:@"eventdata"];
  if (!eventData) return nil;

  SNTStoredEvent *event;

  @try {
    event = [NSKeyedUnarchiver unarchiveObjectWithData:eventData];
    event.idx = event.idx ?: @((uint32_t)[rs intForColumn:@"idx"]);
  } @catch (NSException *exception) {
  }

  return event;
}

// For event tables with schema version >= 4, extract the JSON event data from the result set.
- (SNTStoredEventJSON *)eventFromResultSet:(FMResultSet *)rs {
  NSData *jsonData = [rs dataForColumn:@"eventdata"];
  if (!jsonData) return nil;
  NSNumber *index = @((uint32_t)[rs intForColumn:@"idx"]);
  return [[SNTStoredEventJSON alloc] initWithIndex:index data:jsonData];
}

#pragma mark Deleting

- (void)deleteEventWithId:(NSNumber *)index {
  [self inDatabase:^(FMDatabase *db) {
    [db executeUpdate:@"DELETE FROM events WHERE idx=?", index];
  }];
}

- (void)deleteEventsWithIds:(NSArray<NSNumber *> *)indexes {
  for (NSNumber *index in indexes) {
    [self deleteEventWithId:index];
  }
  [self inDatabase:^(FMDatabase *db) {
    [db executeUpdate:@"VACUUM"];
  }];
}

@end
