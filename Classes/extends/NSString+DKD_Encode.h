//
//  MKMString+Crypto.h
//  MingKeMing
//
//  Created by Albert Moky on 2018/9/26.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (DKD_Decode)

- (NSData *)dkd_base64Decode;

@end

NS_ASSUME_NONNULL_END
