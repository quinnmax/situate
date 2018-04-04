% setup matconvnet

matconvnetdir = 'matconvnet';
version       = 'matconvnet-1.0-beta25';
model_url     = 'http://www.vlfeat.org/matconvnet/models/imagenet-vgg-f.mat';

if ~exist(matconvnetdir,'dir') || ~exist(fullfile(matconvnetdir,version),'dir')
    
    % http://www.vlfeat.org/matconvnet/install/
    display('setting-up matconvnet');
    
    % download matconvnet
    mkdir(matconvnetdir);
    recent_version_url = ['http://www.vlfeat.org/matconvnet/download/' version '.tar.gz'];
    untar(recent_version_url, matconvnetdir);
    
    % compile and setup
    addpath(fullfile(matconvnetdir, version, 'matlab'))
    vl_compilenn();
    vl_setupnn();
    
end

% download the pre-trained model
if ~exist(fullfile(matconvnetdir,fileparts_mq(model_url,'name.ext')),'file')
    display(['downloading ' model_url]);
    websave(fullfile(matconvnetdir,fileparts_mq(model_url,'name.ext')),model_url);
end
    
addpath(fullfile(matconvnetdir, version, 'matlab/simplenn'))
    