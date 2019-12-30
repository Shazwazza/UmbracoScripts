# Load testing utils

## Listing, creating & restarting

loadtest.jmx is an Apache JMeter file which is used to trigger the local load testing. 
It requires that the LoadTest.cs file exist in ~/App_Code or is compiled as part of the application.

These tests will test how Umbraco behaves when there are a lot of threads that are both listing data, creating new data and shutting down the app domain. 
Very usefuly for testing how cache, lucene, etc... behaves with restarts and publishing.

The controller is: LoadTestController and is routed /LoadTest and will display a menu.
