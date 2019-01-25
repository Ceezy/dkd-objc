//
//  DKDSecureMessage+Packing.m
//  DaoKeDao
//
//  Created by Albert Moky on 2018/12/28.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import "DKDEnvelope.h"

#import "DKDSecureMessage+Packing.h"

static inline BOOL check_group(const MKMID *grp, const MKMID *receiver) {
    assert(MKMNetwork_IsGroup(grp.type));
    return [grp isEqual:receiver] || [MKMGroupWithID(grp) isMember:receiver];
}

@implementation DKDSecureMessage (Packing)

- (MKMID *)group {
    MKMID *ID = [_storeDictionary objectForKey:@"group"];
    ID = [MKMID IDWithID:ID];
    if (MKMNetwork_IsGroup(ID.type)) {
        NSAssert(check_group(ID, self.envelope.receiver), @"group error");
        return ID;
    } else {
        NSAssert(!ID, @"group ID error");
        return nil;
    }
}

- (void)setGroup:(MKMID *)group {
    if (group) {
        NSAssert(check_group(group, self.envelope.receiver), @"group error");
        [_storeDictionary setObject:group forKey:@"group"];
    } else {
        [_storeDictionary removeObjectForKey:@"group"];
    }
}

#pragma mark -

- (NSArray<DKDSecureMessage *> *)split {
    NSMutableArray<DKDSecureMessage *> *mArray = nil;
    
    DKDEnvelope *env = self.envelope;
    MKMID *sender = env.sender;
    MKMID *receiver = env.receiver;
    NSDate *time = env.time;
    NSData *data = self.data;
    
    if (MKMNetwork_IsGroup(receiver.type)) {
        DKDEncryptedKeyMap *keyMap = self.encryptedKeys;
        MKMGroup *group = MKMGroupWithID(receiver);
        mArray = [[NSMutableArray alloc] initWithCapacity:group.members.count];
        
        DKDSecureMessage *sMsg;
        NSData *key;
        for (MKMID *member in group.members) {
            // 1. rebuild envelope
            env = [[DKDEnvelope alloc] initWithSender:sender
                                             receiver:member
                                                 time:time];
            // 2. get encrypted key
            key = [keyMap encryptedKeyForID:member];
            // 3. repack message
            sMsg = [[DKDSecureMessage alloc] initWithData:data
                                             encryptedKey:key
                                                 envelope:env];
            if (sMsg) {
                // 3.1. save receiver as group in the message package
                sMsg.group = receiver;
            }
            
            [mArray addObject:sMsg];
        }
    } else {
        NSAssert(false, @"only group message can be splitted");
    }
    
    return mArray;
}

- (DKDSecureMessage *)trimForMember:(const MKMID *)member {
    DKDSecureMessage *sMsg = nil;
    
    DKDEnvelope *env = self.envelope;
    MKMID *sender = env.sender;
    MKMID *receiver = env.receiver;
    NSDate *time = env.time;
    NSData *data = self.data;
    
    if (MKMNetwork_IsCommunicator(receiver.type)) {
        if (!member || [member isEqual:receiver]) {
            sMsg = self;
        } else {
            NSAssert(false, @"receiver not match");
        }
    } else if (MKMNetwork_IsGroup(receiver.type)) {
        // 0. check member
        MKMGroup *group = MKMGroupWithID(receiver);
        if (member) {
            if (![group isMember:member]) {
                NSAssert(false, @"not the group's member");
                return nil;
            }
        } else if (self.encryptedKeys.allKeys.count == 1) {
            // the only key is for you, maybe
            member = self.encryptedKeys.allKeys.firstObject;
        } else if (group.members.count == 1) {
            // you are the only member of this group
            member = group.members.firstObject;
        } else {
            NSAssert(false, @"who are you?");
            return nil;
        }
        
        // 1. rebuild envelope
        env = [[DKDEnvelope alloc] initWithSender:sender
                                         receiver:member
                                             time:time];
        // 2. get encrypted key
        NSData *key = [self.encryptedKeys encryptedKeyForID:member];
        // 3. repack message
        sMsg = [[DKDSecureMessage alloc] initWithData:data
                                         encryptedKey:key
                                             envelope:env];
        if (sMsg) {
            // 3.1. save receiver as group in the message package
            sMsg.group = receiver;
        }
    } else {
        NSAssert(false, @"receiver type not supported");
    }
    
    return sMsg;
}

@end
