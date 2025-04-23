% Setup.m sets up the matlab environment for running tests
% This script creates the necessary folders for tests and reference files
parentFolder = pwd;  % Or specify explicitly
testFolder = fullfile(parentFolder, 'tests');
refFolder = fullfile(parentFolder, 'reference_files');
utilFolder = fullfile(parentFolder, 'utils');

if ~exist(testFolder, 'dir')
    mkdir(testFolder);
end

if ~exist(refFolder, 'dir')
    mkdir(refFolder);
end


addpath(genpath(testFolder));
addpath(genpath(refFolder));
