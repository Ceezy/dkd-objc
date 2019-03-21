//
//  NSDate+Timestamp.m
//  MingKeMing
//
//  Created by Albert Moky on 2018/11/15.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import "NSDate+DKD_Timestamp.h"

NSNumber * DKD_NSNumberFromDate(const NSDate *date) {
    assert(date);
    NSTimeInterval ti = [date timeIntervalSince1970];
    return [[NSNumber alloc] initWithLong:ti];
}

NSDate * DKD_NSDateFromNumber(const NSNumber *timestamp) {
    NSTimeInterval ti = [timestamp doubleValue];
    //assert(ti > 1);
    return [[NSDate alloc] initWithTimeIntervalSince1970:ti];
}
