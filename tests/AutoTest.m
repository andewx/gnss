suite = matlab.unittest.TestSuite.fromFile('TestGPSSignalProcessor.m');
runner = matlab.unittest.TestRunner.withTextOutput;
results = runner.run(suite);
