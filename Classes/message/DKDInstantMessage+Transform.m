//
//  DKDInstantMessage+Transform.m
//  DaoKeDao
//
//  Created by Albert Moky on 2018/12/27.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import "NSObject+JsON.h"
#import "NSData+Crypto.h"

#import "DKDEnvelope.h"
#import "DKDMessageContent.h"
#import "DKDSecureMessage.h"
#import "DKDKeyStore.h"

#import "DKDInstantMessage+Transform.h"

static inline MKMSymmetricKey *encrypt_key(const MKMID *receiver,
                                           const MKMID * _Nullable group) {
    DKDKeyStore *store = [DKDKeyStore sharedInstance];
    MKMSymmetricKey *scKey = nil;
    
    if (group) {
        assert([group isEqual:receiver] || [MKMGroupWithID(group) hasMember:receiver]);
        receiver = group;
    }
    
    if (MKMNetwork_IsCommunicator(receiver.type)) {
        scKey = [store cipherKeyForAccount:receiver];
        if (!scKey) {
            // create a new key & save it into the Key Store
            scKey = [[MKMSymmetricKey alloc] init];
            [store setCipherKey:scKey forAccount:receiver];
        }
    } else if (MKMNetwork_IsGroup(receiver.type)) {
        scKey = [store cipherKeyForGroup:receiver];
        if (!scKey) {
            // create a new key & save it into the Key Store
            scKey = [[MKMSymmetricKey alloc] init];
            [store setCipherKey:scKey forGroup:receiver];
        }
    } else {
        // receiver type not supported
        assert(false);
    }
    return scKey;
}

static inline DKDEncryptedKeyMap *pack_keys(const MKMGroup *group,
                                            const NSData *json) {
    DKDEncryptedKeyMap *map;
    map = [[DKDEncryptedKeyMap alloc] initWithCapacity:[group.members count]];
    
    MKMMember *member;
    NSData *data;
    for (MKMID *ID in group.members) {
        member = MKMMemberWithID(ID, group.ID);
        assert(member.publicKey);
        data = [member.publicKey encrypt:json];
        assert(data);
        [map setEncryptedKey:data forID:ID];
    }
    return map;
}

@implementation DKDInstantMessage (Transform)

- (DKDSecureMessage *)encrypt {
    MKMID *receiver = self.envelope.receiver;
    MKMID *group = self.content.group;
    
    // 1. symmetric key
    MKMSymmetricKey *scKey = encrypt_key(receiver, group);
    
    // 2. encrypt 'content' to 'data'
    NSData *json = [self.content jsonData];
    NSData *CT = [scKey encrypt:json];
    if (!CT) {
        NSAssert(false, @"failed to encrypt data: %@", self);
        return nil;
    }
    
    // 3. rebuild message info
    NSMutableDictionary *mDict = [[NSMutableDictionary alloc] initWithDictionary:self];
    // 3.1. replace content with data
    [mDict removeObjectForKey:@"content"];
    [mDict setObject:[CT base64Encode] forKey:@"data"];
    
    // 3.2. encrypt 'key'
    NSData *key = [scKey jsonData];
    if (MKMNetwork_IsCommunicator(receiver.type)) {
        MKMAccount *contact = MKMAccountWithID(receiver);
        key = [contact.publicKey encrypt:key]; // pack_key()
        if (!key) {
            NSAssert(false, @"failed to encrypt key: %@", self);
            return nil;
        }
        [mDict setObject:[key base64Encode] forKey:@"key"];
    } else if (MKMNetwork_IsGroup(receiver.type)) {
        NSAssert([group isEqual:receiver], @"error");
        DKDEncryptedKeyMap *keys;
        keys = pack_keys(MKMGroupWithID(receiver), key); // pack_keys()
        if (!keys) {
            NSAssert(false, @"failed to pack keys: %@", self);
            return nil;
        }
        [mDict setObject:keys forKey:@"keys"];
    } else {
        NSAssert(false, @"receiver error: %@", receiver);
    }
    
    // 4. create secure message
    return [[DKDSecureMessage alloc] initWithDictionary:mDict];
}

@end
