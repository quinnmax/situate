


% check for expected directories
expected_dirs = {...
    'results', ...
    'pre_extracted_feature_data', ...
    'external box data', ...
    'saved_models', ...
    'local only' };
for edi = 1:numel(expected_dirs)
    if ~exist(expected_dirs{edi},'dir')
        mkdir(expected_dirs{edi});
    end
end



% check for matconvnet
matconvnetdir = 'matconvnet';
version       = 'matconvnet-1.0-beta25';
model_url     = 'http://www.vlfeat.org/matconvnet/models/imagenet-vgg-f.mat';

if ~exist(fullfile(matconvnetdir,version,'matlab','vl_nnconv.m'),'file')
    
    % http://www.vlfeat.org/matconvnet/install/
    display('setting-up matconvnet');
    
    % download matconvnet
    mkdir(matconvnetdir);
    recent_version_url = ['http://www.vlfeat.org/matconvnet/download/' version '.tar.gz'];
    untar(recent_version_url, matconvnetdir);
    
    % compile and setup
    addpath(fullfile(matconvnetdir, version, 'matlab'))
    try
        vl_compilenn();
    catch
        error('Matconvnet failed to compile. It''s proabably worth looking at their compilation instructions at http://www.vlfeat.org/matconvnet/install/#compiling');
    end
    vl_setupnn();
    
end



% check for the pre-trained model
if ~exist(fullfile(matconvnetdir,fileparts_mq(model_url,'name.ext')),'file')
    display(['downloading ' model_url]);
    websave(fullfile(matconvnetdir,fileparts_mq(model_url,'name.ext')),model_url);
end
  


% add tools to path
addpath(fullfile(pwd,'tools'));
addpath(fullfile(pwd,matconvnetdir, version, 'matlab'))
addpath(fullfile(pwd,matconvnetdir, version, 'matlab/simplenn'))
addpath(fullfile(pwd,matconvnetdir, version, 'matlab/mex'))

    
