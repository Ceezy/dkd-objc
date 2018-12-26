//
//  DKDReliableMessage+Transform.m
//  DaoKeDao
//
//  Created by Albert Moky on 2018/12/27.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import "DKDEnvelope.h"

#import "DKDReliableMessage+Transform.h"

@implementation DKDReliableMessage (Transform)

- (DKDSecureMessage *)verify {
    MKMID *sender = self.envelope.sender;
    MKMID *receiver = self.envelope.receiver;
    NSAssert(MKMNetwork_IsPerson(sender.type), @"sender error");
    
    // 1. verify the signature with public key
    MKMContact *contact = MKMContactWithID(sender);
    MKMPublicKey *PK = contact.publicKey;
    if (![PK verify:self.data withSignature:self.signature]) {
        // signature error
        return nil;
    }
    
    // 2. create secure message
    DKDSecureMessage *sMsg;
    if (MKMNetwork_IsPerson(receiver.type)) {
        sMsg = [[DKDSecureMessage alloc] initWithData:self.data
                                         encryptedKey:self.encryptedKey
                                             envelope:self.envelope];
    } else if (MKMNetwork_IsGroup(receiver.type)) {
        sMsg = [[DKDSecureMessage alloc] initWithData:self.data
                                        encryptedKeys:self.encryptedKeys
                                             envelope:self.envelope];
    } else {
        NSAssert(false, @"receiver error: %@", receiver);
    }
    
    NSAssert(sMsg, @"verify message error: %@", self);
    return sMsg;
}

@end
