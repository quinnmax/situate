 
function [workspaces_dummy, detected_object_matrix] = make_dummy_workspaces( lb_fname, situation_struct )

% [workspaces_dummy, object_matrix] = make_dummy_workspaces( lb_fname,  situation_struct );
% [workspaces_dummy, object_matrix] = make_dummy_workspaces( lb_struct, situation_struct );
%
% workspace array, with all combinations of n,n-1,n-2 objects found

    if ~isstruct(lb_fname)
        cur_lb_struct = situate.labl_load( lb_fname, situation_struct );
    else
        cur_lb_struct = lb_fname;
    end
    
    num_objs = numel(situation_struct.situation_objects);

    full_workspace = [];
    full_workspace.labels = cur_lb_struct.labels_adjusted;
    full_workspace.boxes_r0rfc0cf = cur_lb_struct.boxes_r0rfc0cf;
    full_workspace.im_size(1) = cur_lb_struct.im_h;
    full_workspace.im_size(2) = cur_lb_struct.im_w;
    
    [~,ordering1] = sort(situation_struct.situation_objects);
    [~,ordering2] = sort(full_workspace.labels);
    full_workspace.labels = full_workspace.labels(ordering2(ordering1));
    full_workspace.boxes_r0rfc0cf = full_workspace.boxes_r0rfc0cf(ordering2(ordering1),:);
    
    detected_object_matrix = all_combinations(num_objs);
    workspaces_dummy = cell(size(detected_object_matrix,1),1);
    
    for omi = 1:size(detected_object_matrix,1)
        
        cur_workspace = full_workspace;
        cur_workspace.boxes_r0rfc0cf( detected_object_matrix(omi,:), : ) = [];
        cur_workspace.labels( detected_object_matrix(omi,:) ) = [];
        
        workspaces_dummy{omi} = cur_workspace;
        
    end
    
    detected_object_matrix = ~detected_object_matrix;
    
end
    