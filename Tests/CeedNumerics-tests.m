//
//  CeedNumerics-tests.m
//  CeedNumerics-tests.mac
//
//  Created by Raphael Sebbe on 05/12/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface CeedNumerics_tests : XCTestCase

@end

@implementation CeedNumerics_tests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
		// Put the code you want to measure the time of here.
		int sum = 0;
		for(int i=0; i<1000; i++) {
			for(int j=0; j<1000; j++) {
				sum += j+i;
			}
		}
		NSLog(@"sum: %d", sum);
    }];
}

@end
