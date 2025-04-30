suite = matlab.unittest.TestSuite.fromFile('TestDLL.m');
runner = matlab.unittest.TestRunner.withTextOutput;
results = runner.run(suite);
