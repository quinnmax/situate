function workspace = workspace_initialize(p,im_size)

    workspace.boxes_r0rfc0cf   = [];
    workspace.labels           = {};
    workspace.labels_raw       = {};
    workspace.internal_support = [];
    workspace.external_support = [];
    workspace.total_support    = [];
    workspace.GT_IOU           = [];
    
    workspace.im_size = im_size;
    workspace.im_fname = '';
    
    workspace.situation_support = 0;
    workspace.total_iterations = 0;
    
    if isfield(p,'temperature')
        workspace.temperature = p.temperature.initial;
    else
        workspace.temperature = -1;
    end
    
end