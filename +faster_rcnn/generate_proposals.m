function [boxes, scores] = generate_proposals( im )
%GENERATE_PROPOSALS Outputs a cell array of box proposals in XYWHS format.

    persistent opts proposal_detection_model rpn_net
    
    if ~exist('opts', 'var') || isa(opts, 'double')
        addpath /home/rsoiffer/Desktop/faster_rcnn-master
        run startup
        
        opts.caffe_version     = 'caffe_faster_rcnn';
        opts.gpu_id            = auto_select_gpu;
        opts.per_nms_topN      = 6000;
        opts.nms_overlap_thres = 0.7;
        opts.after_nms_topN    = 300;
        opts.use_gpu           = true;
        opts.test_scales       = 600;
        opts.model_dir         = '/home/rsoiffer/Desktop/faster_rcnn-master/output/faster_rcnn_final/faster_rcnn_VOC0712_ZF';
        
        active_caffe_mex(opts.gpu_id, opts.caffe_version);

        proposal_detection_model = faster_rcnn.load_proposal_detection_model(opts);

        rpn_net = caffe.Net(proposal_detection_model.proposal_net_def, 'test');
        rpn_net.copy_from(proposal_detection_model.proposal_net);
        
        % set gpu/cpu
        if opts.use_gpu
            caffe.set_mode_gpu();
        else
            caffe.set_mode_cpu();
        end
    end
    
    if opts.use_gpu,  im = gpuArray(im);  end

    % test proposal
    [boxes, scores] = proposal_im_detect(proposal_detection_model.conf_proposal, rpn_net, im);
    boxes = faster_rcnn.boxes_filter([boxes, scores], opts.per_nms_topN, opts.nms_overlap_thres, opts.after_nms_topN, opts.use_gpu);
    
    boxes = num2cell([boxes, scores], 2);
    boxes = map(boxes, @(x) faster_rcnn.format_box(x, im));
    
    scores = boxes(:,5);
    boxes_xywh = boxes(:,1:4);
    
end

