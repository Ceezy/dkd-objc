//
//  DKDTransceiver.m
//  DaoKeDaoe
//
//  Created by Albert Moky on 2018/10/7.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import "NSObject+Singleton.h"
#import "NSObject+JsON.h"

#import "DKDEnvelope.h"
#import "DKDMessageContent.h"
#import "DKDMessageContent+Forward.h"

#import "DKDMessage.h"
#import "DKDInstantMessage.h"
#import "DKDSecureMessage.h"
#import "DKDReliableMessage.h"

#import "DKDSecureMessage+Packing.h"
#import "DKDInstantMessage+Transform.h"
#import "DKDSecureMessage+Transform.h"
#import "DKDReliableMessage+Transform.h"
#import "DKDReliableMessage+Meta.h"

#import "DKDTransceiver.h"

@implementation DKDTransceiver

SingletonImplementations(DKDTransceiver, sharedInstance)

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

- (BOOL)sendMessageContent:(const DKDMessageContent *)content
                      from:(const MKMID *)sender
                        to:(const MKMID *)receiver
                      time:(nullable const NSDate *)time
                  callback:(nullable DKDTransceiverCallback)callback {
    // make instant message
    DKDInstantMessage *iMsg;
    iMsg = [[DKDInstantMessage alloc] initWithContent:content
                                               sender:sender
                                             receiver:receiver
                                                 time:time];
    
    return [self sendInstantMessage:iMsg
                           callback:callback
                        dispersedly:YES];
}

- (BOOL)sendInstantMessage:(const DKDInstantMessage *)iMsg
                  callback:(nullable DKDTransceiverCallback)callback
               dispersedly:(BOOL)split {
    const MKMID *receiver = iMsg.envelope.receiver;
    DKDReliableMessage *rMsg = [self encryptAndSignMessage:iMsg];
    if (split && MKMNetwork_IsGroup(receiver.type)) {
        NSArray *messages = [rMsg split];
        if (messages.count == 0) {
            NSLog(@"failed to split msg, send it to group: %@", receiver);
            return [self sendReliableMessage:rMsg callback:callback];
        }
        BOOL OK = YES;
        for (rMsg in messages) {
            if ([rMsg.envelope.receiver isEqual:rMsg.envelope.sender]) {
                // ignore message to the sender itself
                continue;
            }
            if ([self sendReliableMessage:rMsg callback:callback]) {
                //NSLog(@"group message sent to %@", rMsg.envelope.receiver);
            } else {
                OK = NO;
            }
        }
        return OK;
    } else {
        return [self sendReliableMessage:rMsg callback:callback];
    }
}

- (BOOL)sendReliableMessage:(const DKDReliableMessage *)rMsg
                   callback:(DKDTransceiverCallback)callback {
    NSData *data = [rMsg jsonData];
    if (data) {
        NSAssert(_delegate, @"transceiver delegate not set");
        return [_delegate sendPackage:data
                    completionHandler:^(const NSError * _Nullable error) {
                        assert(!error);
                        !callback ?: callback(rMsg, error);
                    }];
    } else {
        NSAssert(false, @"message data error: %@", rMsg);
        return NO;
    }
}

#pragma mark -

- (DKDReliableMessage *)encryptAndSignContent:(const DKDMessageContent *)content
                                       sender:(const MKMID *)sender
                                     receiver:(const MKMID *)receiver
                                         time:(nullable const NSDate *)time {
    NSAssert(MKMNetwork_IsPerson(sender.type), @"sender error: %@", sender);
    NSAssert(receiver.isValid, @"receiver error: %@", receiver);
    
    // make instant message
    DKDInstantMessage *iMsg;
    iMsg = [[DKDInstantMessage alloc] initWithContent:content
                                               sender:sender
                                             receiver:receiver
                                                 time:time];
    
    // let another selector to do the continue jobs
    return [self encryptAndSignMessage:iMsg];
}

- (DKDReliableMessage *)encryptAndSignMessage:(const DKDInstantMessage *)iMsg {
    NSAssert(iMsg.content, @"content cannot be empty");
    
    // 1. encrypt 'content' to 'data'
    DKDSecureMessage *sMsg = [iMsg encrypt];
    NSAssert(sMsg.data, @"data cannot be empty");
    
    // 2. sign 'data'
    DKDReliableMessage *rMsg = [sMsg sign];
    NSAssert(rMsg.signature, @"signature cannot be empty");
    
    // OK
    return rMsg;
}

- (DKDInstantMessage *)verifyAndDecryptMessage:(const DKDReliableMessage *)rMsg
                                       forUser:(const MKMUser *)user {
    NSAssert(rMsg.signature, @"signature cannot be empty");
    
    // 0. check with the current user
    if (user) {
        const MKMID *receiver = rMsg.envelope.receiver;
        if (MKMNetwork_IsPerson(receiver.type)) {
            if (![receiver isEqual:user.ID]) {
                // TODO: You can forward it to the true receiver,
                //       or just ignore it.
                NSAssert(false, @"This message is for %@, not for you!", receiver);
                return nil;
            }
        } else if (MKMNetwork_IsGroup(receiver.type)) {
            MKMGroup *group = MKMGroupWithID(receiver);
            if (![group existsMember:user.ID]) {
                // TODO: You can forward it to the true receiver,
                //       or just ignore it.
                NSAssert(false, @"This message is not for you!");
                return nil;
            }
        }
    }
    
    // [Meta Protocol] check meta in first contact message
    const MKMID *sender = rMsg.envelope.sender;
    const MKMMeta *meta = MKMMetaForID(sender);
    if (!meta) {
        // first contact, try meta in message package
        meta = rMsg.meta;
        if ([meta matchID:sender]) {
            MKMBarrack *barrack = [MKMBarrack sharedInstance];
            [barrack saveMeta:meta forEntityID:sender];
        } else {
            NSAssert(false, @"meta not found for sender: %@", sender);
            return nil;
        }
    }
    
    // 1. verify 'data' witn 'signature'
    DKDSecureMessage *sMsg = [rMsg verify];
    NSAssert(sMsg.data, @"data cannot be empty");
    
    // 1.1. trim for user
    sMsg = [sMsg trimForMember:user.ID];
    NSAssert(MKMNetwork_IsPerson(sMsg.envelope.receiver.type), @"receiver error: %@", sMsg.envelope.receiver);
    
    // 2. decrypt 'data' to 'content'
    DKDInstantMessage *iMsg = [sMsg decrypt];
    NSAssert(iMsg.content, @"content cannot be empty");
    
    // 3. check: top-secret message
    if (iMsg.content.type == DKDMessageType_Forward) {
        // do it again to drop the wrapper,
        // the secret inside the content is the real message
        rMsg = iMsg.content.forwardMessage;
        return [self verifyAndDecryptMessage:rMsg forUser:user];
    }
    
    // OK
    return iMsg;
}

@end
