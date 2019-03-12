//
//  DKDSecureMessage+Packing.m
//  DaoKeDao
//
//  Created by Albert Moky on 2018/12/28.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import "NSData+Crypto.h"

#import "DKDEnvelope.h"

#import "DKDSecureMessage+Packing.h"

@implementation DKDSecureMessage (Packing)

- (nullable const MKMID *)group {
    NSString *str = [_storeDictionary objectForKey:@"group"];
    if (str) {
        MKMID *ID = [MKMID IDWithID:str];
        if (ID != str) {
            if (ID) {
                // replace group ID object
                [_storeDictionary setObject:ID forKey:@"group"];
            } else {
                NSAssert(false, @"group ID error: %@", str);
                //[_storeDictionary removeObjectForKey:@"group"];
            }
        }
        NSAssert(MKMNetwork_IsGroup(ID.type), @"group error: %@", str);
        return ID;
    } else {
        return nil;
    }
}

- (void)setGroup:(const MKMID *)group {
    if (group) {
        NSAssert(MKMNetwork_IsGroup(group.type), @"group error: %@", group);
        [_storeDictionary setObject:group forKey:@"group"];
    } else {
        [_storeDictionary removeObjectForKey:@"group"];
    }
}

#pragma mark -

- (NSArray *)split {
    NSMutableArray *mArray = nil;
    
    DKDEnvelope *env = self.envelope;
    const MKMID *receiver = env.receiver;
    
    if (MKMNetwork_IsGroup(receiver.type)) {
        NSMutableDictionary *msg;
        msg = [[NSMutableDictionary alloc] initWithDictionary:self];
        [msg setObject:receiver forKey:@"group"];
        
        DKDEncryptedKeyMap *keyMap = self.encryptedKeys;
        MKMGroup *group = MKMGroupWithID(receiver);
        NSArray *members = group.members;
        mArray = [[NSMutableArray alloc] initWithCapacity:members.count];
        
        NSData *key;
        for (MKMID *member in members) {
            // 1. change receiver to the group member
            [msg setObject:member forKey:@"receiver"];
            // 2. get encrypted key
            key = [keyMap encryptedKeyForID:member];
            if (key) {
                [msg setObject:[key base64Encode] forKey:@"key"];
            } else {
                [msg removeObjectForKey:@"key"];
            }
            // 3. repack message
            [mArray addObject:[[[self class] alloc] initWithDictionary:msg]];
        }
    } else {
        NSAssert(false, @"only group message can be splitted");
    }
    
    return mArray;
}

- (DKDSecureMessage *)trimForMember:(const MKMID *)member {
    DKDSecureMessage *sMsg = nil;
    
    DKDEnvelope *env = self.envelope;
    const MKMID *receiver = env.receiver;
    
    if (MKMNetwork_IsCommunicator(receiver.type)) {
        if (!member || [member isEqual:receiver]) {
            sMsg = self;
        } else {
            NSAssert(false, @"receiver not match: %@, %@", member, receiver);
        }
    } else if (MKMNetwork_IsGroup(receiver.type)) {
        // 0. check member
        MKMGroup *group = MKMGroupWithID(receiver);
        if (member) {
            if (![group existsMember:member]) {
                NSAssert(false, @"not the group's member");
                return nil;
            }
        } else if (self.encryptedKeys.allKeys.count == 1) {
            // the only key is for you, maybe
            member = self.encryptedKeys.allKeys.firstObject;
        } else {
            NSArray *members = group.members;
            if (members.count == 1) {
                // you are the only member of this group
                member = members.firstObject;
            } else {
                NSAssert(false, @"who are you?");
                return nil;
            }
        }
        
        NSMutableDictionary *mDict = [[NSMutableDictionary alloc] initWithDictionary:self];
        // 1. change receiver to the group member
        [mDict setObject:receiver forKey:@"group"];
        [mDict setObject:member forKey:@"receiver"];
        
        // 2. get encrypted key
        NSData *key = [self.encryptedKeys encryptedKeyForID:member];
        if (key) {
            [mDict setObject:[key base64Encode] forKey:@"key"];
        }
        // 3. repack message
        sMsg = [[DKDSecureMessage alloc] initWithDictionary:mDict];
    } else {
        NSAssert(false, @"receiver type not supported: %@", receiver);
    }
    
    return sMsg;
}

@end
