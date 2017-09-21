addpath /home/rsoiffer/Desktop/faster_rcnn-master
run startup

%% Setup options

opts.caffe_version     = 'caffe_faster_rcnn';
opts.gpu_id            = auto_select_gpu;
opts.per_nms_topN      = 6000;
opts.nms_overlap_thres = 0.7;
opts.after_nms_topN    = 300;
opts.use_gpu           = true;
opts.test_scales       = 600;
opts.model_dir         = '/home/rsoiffer/Desktop/faster_rcnn-master/output/faster_rcnn_final/faster_rcnn_VOC0712_ZF';
%opts.model_dir         = '/home/rsoiffer/Desktop/faster_rcnn-master/output/faster_rcnn_final/faster_rcnn_VOC0712_vgg_16layers';


%% Load initial stuff

reset(gpuDevice(opts.gpu_id));
clear mex;

im_names = image_files('/home/rsoiffer/Desktop/Matlab/DogWalkingData/PortlandSimpleDogWalking/');

active_caffe_mex(opts.gpu_id, opts.caffe_version);

proposal_detection_model = faster_rcnn.load_proposal_detection_model(opts);

% caffe.init_log(fullfile(pwd, 'caffe_log'));
% proposal net
rpn_net = caffe.Net(proposal_detection_model.proposal_net_def, 'test');
rpn_net.copy_from(proposal_detection_model.proposal_net);
% fast rcnn net
fast_rcnn_net = caffe.Net(proposal_detection_model.detection_net_def, 'test');
fast_rcnn_net.copy_from(proposal_detection_model.detection_net);

% set gpu/cpu
if opts.use_gpu
    caffe.set_mode_gpu();
else
    caffe.set_mode_cpu();
end


%% Run through each of the images

results = cell(3, size(im_names,1));
for j = 1:size(im_names)
    
    if mod(j,10) == 0
        disp(j);
    end

    % load and process the image
    im = imread(im_names{j});
    if size(im, 3) == 1
        rgb = zeros(size(im,1), size(im,2), 3);
        rgb(:,:,1) = im;
        rgb(:,:,2) = im;
        rgb(:,:,3) = im;
        im = rgb;
    end
    if opts.use_gpu,  im = gpuArray(im);  end

    % test proposal
    [boxes, scores] = proposal_im_detect(proposal_detection_model.conf_proposal, rpn_net, im);
    aboxes = faster_rcnn.boxes_filter([boxes, scores], opts.per_nms_topN, opts.nms_overlap_thres, opts.after_nms_topN, opts.use_gpu);
        
    % test detection
    if proposal_detection_model.is_share_feature
        [boxes, scores] = fast_rcnn_conv_feat_detect(proposal_detection_model.conf_detection, fast_rcnn_net, im, ...
            rpn_net.blobs(proposal_detection_model.last_shared_output_blob_name), ...
            aboxes(:, 1:4), opts.after_nms_topN);
    else
        [boxes, scores] = fast_rcnn_im_detect(proposal_detection_model.conf_detection, fast_rcnn_net, im, ...
            aboxes(:, 1:4), opts.after_nms_topN);
    end

    results{1,j} = aboxes;
    results{2,j} = boxes;
    results{3,j} = scores;
end
