//
//  MakesYouUP.m
//  MakesYouUP
//
//  Created by Mohammad Abdurraafay on 31/01/13.
//  Copyright (c) 2013 Mohammad Abdurraafay. All rights reserved.
//

#import "MakesYouUP.h"

#import "MUPSocialFeed.h"
#import "MUPDailySummary.h"

static NSTimeZone *TheCurrentTimeZone;
static NSDateFormatter *TimeZoneFormatter;

@implementation MakesYouUP

- (id)init
{
    self = [super init];
    if (!self) {
        return nil;
    }
    return self;
}


+ (MakesYouUP *)sharedInstance {
    static MakesYouUP *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[MakesYouUP alloc] init];
    });
    return _sharedInstance;
}


/*
 email=user@domain.com
 pwd=YourPassword
 service=nudge
 */

+ (void)signWithUsername:(NSString *)userName
             andPassword:(NSString *)password
                response:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                 failure:(void(^)(AFHTTPRequestOperation *operation, NSError *error))failure {

    
    [[MUPAPIClient sharedClient]
     postPath:@"user/signin/login"
     parameters:@{@"email": userName, @"pwd": password, @"service": @"nudge"}
     success:^(AFHTTPRequestOperation *operation, id responseObject) {
         
         NSDictionary *responseError = [responseObject objectForKey:@"error"];
         
         if (responseError.count != 0) {
             
             NSError *error = [NSError errorWithDomain:@"com.mup.signinerror"
                                                  code:[[responseError valueForKey:@"code"] intValue]
                                              userInfo:responseObject];
             
             failure(operation, error);
         } else {
             
             NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
             [userDefaults setObject:[responseObject valueForKey:@"token"] forKey:@"token"];
             [userDefaults synchronize];
             
             
             success(operation, responseObject);
         }
         
         
     }
     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
         failure(operation, error);
                                  }];
    
}

+ (void)feedForTheUser:(NSString *)user
     withNumberOfFeeds:(NSString *)limit
              response:(void (^)(NSArray *socialFeeds))success
               failure:(void (^)(NSError *error))failure {
    
    NSString *token = [[MakesYouUP sharedInstance] userToken];
    NSString *path = [NSString stringWithFormat:@"nudge/api/users/%@/social", user];
    NSDictionary *parameters = @{@"after": @"null", @"limit": limit, @"_token": token};
    
    [[MUPAPIClient sharedClient]
     getPath:path
     parameters:parameters
     success:^(AFHTTPRequestOperation *operation, id responseObject) {
         
         NSArray *feeds = [[responseObject valueForKey:@"data"] valueForKey:@"feed"];
         NSMutableArray *socialFeeds = [[NSMutableArray alloc] initWithCapacity:feeds.count];
         
         NSLog(@"ResponseObject:%@", feeds);
         
         dispatch_queue_t feedsCreationQueue = dispatch_queue_create("com.mup.feedcreation", NULL);
         dispatch_async(feedsCreationQueue, ^{
             
             for (NSDictionary *feed in feeds) {
                 MUPSocialFeed *socialFeed = [[MUPSocialFeed alloc] initWithFeedAttributes:feed];
                 [socialFeeds addObject:socialFeed];
             }
             success(socialFeeds);
             
         });
         
     }
     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
         
         failure(error);
         
     }];
    
}

/*
 date=2011-11-27
timezone=-28800
move_goal=0
sleep_goal=0
eat_goal=0
check_levels=1
_token=<your auth token>
 */

- (NSString *)timeZoneInString {
    
    TheCurrentTimeZone = [NSTimeZone systemTimeZone];
    /*
     NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
     [dateFormatter setDateFormat:@"yyyy-M-d"];
     [dateFormatter setTimeZone:theCurrentTimeZone];
     NSString *date = [dateFormatter stringFromDate:[NSDate date]];
     */
    
    TimeZoneFormatter = [[NSDateFormatter alloc] init];
    [TimeZoneFormatter setDateFormat:@"Z"];
    [TimeZoneFormatter setTimeZone:TheCurrentTimeZone];
    NSString *timeZone = [TimeZoneFormatter stringFromDate:[NSDate date]];
    
    return timeZone;
}

+ (void)dailySummaryForDate:(NSString *)date
                    forUser:(NSString *)user
                   response:(void (^)(MUPDailySummary *dailySummary))success
                    failure:(void (^)(NSError *error))failure {
    
    NSString *path = [NSString stringWithFormat:@"nudge/api/users/%@/healthCredits", user];
    NSString *token = [[MakesYouUP sharedInstance] userToken];
    NSDictionary *param = @{@"date": date,
                            @"timezone":[[self sharedInstance] timeZoneInString],
                            @"move_goal": @"0",
                            @"sleep_goal":@"0",
                            @"eat_goal":@"0",
                            @"check_levels":@"100",
                            @"_token":token};
    
    [[MUPAPIClient sharedClient]
     getPath:path
     parameters:param
     success:^(AFHTTPRequestOperation *operation, id responseObject) {
         
         MUPDailySummary *dailySummary = [[MUPDailySummary alloc] initWithDailySummaryAttributes:[responseObject valueForKey:@"data"]];
         
         success(dailySummary);
     }
     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
         
         failure(error);
     }];
    
}

+ (void)detailedUserActivityDataForUser:(NSString *)user
                          fromStartDate:(NSDate *)startDate
                            tillEndDate:(NSDate *)endDate
                               response:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                                failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure {
    
    NSString *path = [NSString stringWithFormat:@"nudge/api/users/%@/band", user];
    NSString *token = [[MakesYouUP sharedInstance] userToken];
    long epochStartDate = (long)[startDate timeIntervalSince1970];
    long epochEndDate = (long)[endDate timeIntervalSince1970];
    NSString *sinceDate = [NSString stringWithFormat:@"%ld", epochStartDate];
    NSString *untilDate = [NSString stringWithFormat:@"%ld", epochEndDate];
    
    NSDictionary *param = @{@"start_time": sinceDate,
                            @"end_time": untilDate,
                            @"_token":token};
    
    [[MUPAPIClient sharedClient]
     getPath:path
     parameters:param
     success:^(AFHTTPRequestOperation *operation, id responseObject) {
         success(operation, responseObject);
     }
     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
         failure(operation, error);
     }];
  
}



+ (void)sleepSummaryForUserName:(NSString *)userName
                  fromStartDate:(NSDate *)startDate
                    tillEndDate:(NSDate *)endDate
                       response:(void (^)(NSArray *sleeps))success
                        failure:(void (^)(NSError *error))failure {
    
    NSString *path = [NSString stringWithFormat:@"nudge/api/users/%@/sleeps", userName];
    NSString *token = [[MakesYouUP sharedInstance] userToken];
    long epochStartDate = (long)[startDate timeIntervalSince1970];
    long epochEndDate = (long)[endDate timeIntervalSince1970];
    
    NSDictionary *param = @{@"start_time": [NSString stringWithFormat:@"%ld", epochStartDate],
                            @"end_time": [NSString stringWithFormat:@"%ld", epochEndDate],
                            @"_token":token};
    
    
    [[MUPAPIClient sharedClient]
     getPath:path
     parameters:param
     success:^(AFHTTPRequestOperation *operation, id responseObject) {
         
         NSArray *sleeps = [[responseObject valueForKey:@"data"] valueForKey:@"items"];
         NSMutableArray *sleepsObjects = [[NSMutableArray alloc] initWithCapacity:[sleeps count]];
         for (NSDictionary *sleep in sleeps) {
             
             [sleepsObjects addObject:[[MUPSleep alloc] initWithSleepAttributes:sleep]];
             
         }
         success(sleepsObjects);
     }
     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
         failure(error);
     }];
    
    
}

+ (void)sleepDetailedDataForUser:(NSString *)user
                   fromStartDate:(NSDate *)startDate
                     tillEndDate:(NSDate *)endDate
                        response:(void (^)(AFHTTPRequestOperation *, id responseObject))success
                         failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure {
    
    //TODO:Detailed Sleep Data with xid.
    
    
}

+ (void)workOutSummaryDataForUser:(NSString *)user
                    fromStartDate:(NSDate *)startDate
                      tillEndDate:(NSDate *)endDate
                        withLimit:(NSString *)limit
                         response:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                          failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure {
    
    NSString *path = [NSString stringWithFormat:@"nudge/api/users/%@/workouts", user];
    NSString *token = [[MakesYouUP sharedInstance] userToken];
    long epochStartDate = (long)[startDate timeIntervalSince1970];
    long epochEndDate = (long)[endDate timeIntervalSince1970];
    
    [[MUPAPIClient sharedClient]
     getPath:path
     parameters:@{@"start_time": [NSString stringWithFormat:@"%ld", epochStartDate], @"end_time": [NSString stringWithFormat:@"%ld", epochEndDate], @"limit":limit, @"_token":token}
     success:^(AFHTTPRequestOperation *operation, id responseObject) {
         
         success(operation, responseObject);
         
     }
     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
         
         
         failure(operation, error);
         
         
     }];
}

+ (void)workoutDetailedDataForUser:(NSString *)user
                   fromStartDate:(NSDate *)startDate
                     tillEndDate:(NSDate *)endDate
                        response:(void (^)(AFHTTPRequestOperation *, id responseObject))success
                         failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure {
    
    //TODO:Detailed Workout Data with xid.
    
    
}

#pragma mark - Private Methods

- (NSString *)userToken {
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *token = [userDefaults valueForKey:@"token"];
    
    return token;
}



@end
