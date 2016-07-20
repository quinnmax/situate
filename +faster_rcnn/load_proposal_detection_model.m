function proposal_detection_model = load_proposal_detection_model(opts)

    ld = load(fullfile(opts.model_dir, 'model'));
    proposal_detection_model = ld.proposal_detection_model;
    clear ld;
    
    proposal_detection_model.proposal_net_def = fullfile(opts.model_dir, proposal_detection_model.proposal_net_def);
    proposal_detection_model.proposal_net = fullfile(opts.model_dir, proposal_detection_model.proposal_net);
    proposal_detection_model.detection_net_def = fullfile(opts.model_dir, proposal_detection_model.detection_net_def);
    proposal_detection_model.detection_net = fullfile(opts.model_dir, proposal_detection_model.detection_net);
    
    proposal_detection_model.conf_proposal.test_scales = opts.test_scales;
    proposal_detection_model.conf_detection.test_scales = opts.test_scales;
    if opts.use_gpu
        proposal_detection_model.conf_proposal.image_means = gpuArray(proposal_detection_model.conf_proposal.image_means);
        proposal_detection_model.conf_detection.image_means = gpuArray(proposal_detection_model.conf_detection.image_means);
    end
    
end
