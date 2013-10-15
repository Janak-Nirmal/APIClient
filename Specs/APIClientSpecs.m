//
//  APIClientSpecs.m
//  APIClient
//
//  Created by Klaas Pieter Annema on 30-08-13.
//  Copyright 2013 Klaas Pieter Annema. All rights reserved.
//

#import "SpecHelper.h"

#import "APIClient.h"

#import "APITestHTTPClient.h"
#import "Product.h"

SpecBegin(APIClient)

describe(@"APIClient", ^{
    before(^{
        setAsyncSpecTimeout(1.0);
    });

    __block APIClient *_client;
    __block NSURL *_baseURL;
    __block APITestHTTPClient *_httpClient;
    __block id _router;
    __block id _serializer;
    __block id _mapper;

    beforeEach(^{
        _baseURL = [NSURL URLWithString:@"https://api.example.org"];
        _httpClient = [[APITestHTTPClient alloc] initWithBaseURL:_baseURL];
        _router = [[APIRouter alloc] init];
        _serializer = [[APIJSONSerializer alloc] init];
        _mapper = [[APIMapper alloc] init];
        _client = [[APIClient alloc] initWithHTTPClient:_httpClient router:_router serializer:_serializer mapper:_mapper];
    });

    describe(@"initialization", ^{
        it(@"can be configured with a configuration block", ^{
            _client = [APIClient clientWithConfigurationBlock:^(APIClientConfiguration *configuration) {
                configuration.httpClient = _httpClient;
                configuration.router = _router;
                configuration.serializer = _serializer;
            }];

            expect(_client.httpClient).to.equal(_httpClient);
            expect(_client.router).to.equal(_router);
            expect(_client.serializer).to.equal(_serializer);
        });

        it(@"creates a configuration with the given httpClient", ^{
            _client = [[APIClient alloc] initWithHTTPClient:_httpClient router:_router serializer:_serializer mapper:_mapper];
            expect(_client.configuration.httpClient).to.equal(_httpClient);
        });

        it(@"creates a configuration with the given router", ^{
            _client = [[APIClient alloc] initWithHTTPClient:_httpClient router:_router serializer:_serializer mapper:_mapper];
            expect(_client.configuration.router).to.equal(_router);
        });
    });

    describe(@"routing", ^{
        it(@"uses the router to build paths for a resource", ^{
            _router = [OCMockObject mockForProtocol:@protocol(APIRouter)];
            [[[_router expect] andReturn:@"/objects"] pathForAction:@"index" onResource:[Product class]];
            _client = [[APIClient alloc] initWithHTTPClient:_httpClient router:_router serializer:_serializer mapper:_mapper];
            [_client findAll:[Product class]];
            expect(_httpClient.requests[0]).to.equal(@"/objects");
            [_router verify];
        });
    });

    describe(@"serialization", ^{
        it(@"uses the serializer to deserialize the response body", ^{
            _serializer = [OCMockObject mockForProtocol:@protocol(APIJSONSerializer)];
            [[[_serializer expect] andReturn:@{}] deserializeJSON:[@"{}" dataUsingEncoding:NSUTF8StringEncoding]];
            _client = [[APIClient alloc] initWithHTTPClient:_httpClient router:_router serializer:_serializer mapper:_mapper];
            [_client findAll:[Product class]];
            [_httpClient succeedRequests];
            [_serializer verify];
        });
    });

    describe(@"mapping", ^{
        it(@"uses the mapper to map the response to resource objects", ^{
            _mapper = [OCMockObject mockForProtocol:@protocol(APIMapper)];
            [[_mapper expect] mapValuesFrom:@{} toInstance:[OCMArg isNotNil] usingMapping:@{}];
            _client  = [[APIClient alloc] initWithHTTPClient:_httpClient router:_router serializer:_serializer mapper:_mapper];
            [_client findAll:[Product class]];
            [_httpClient succeedRequests];
            [_mapper verify];
        });
    });

    describe(@"findAll:", ^{
        it(@"returns a response promise", ^{
            id response = [_client findAll:[Product class]];
            expect(response).to.beKindOf([APIResponse class]);
        });

        it(@"makes a request for the resource", ^{
            [_client findAll:[Product class]];
            expect(_httpClient.requests[0]).to.equal(@"products");
        });

        context(@"with a successful request", ^{
            it(@"resolves the response with the mapping result", ^AsyncBlock {
                APIResponse *response = [_client findAll:[Product class]];
                response.success = ^(id object) {
                    expect(object).to.beInstanceOf([Product class]);
                    done();
                };
                [_httpClient succeedRequests];
            });
        });

        context(@"with a failed request", ^{
            it(@"rejects the response with the error", ^AsyncBlock {
                APIResponse *response = [_client findAll:[Product class]];
                response.failure = ^(NSError *error) {
                    expect(error).notTo.beNil();
                    done();
                };
                [_httpClient failRequests];
            });
        });
    });
});

SpecEnd