function [workspace, label_used] = workspace_score( workspace, lb_input, situation_struct )
% [workspace,label_used] = workspace_score( workspace, label_struct,  situation_struct );
% [workspace,label_used] = workspace_score( workspace, label_fname,   situation_struct );
%
% if the situation_struct is given, and there are labels that can be swapped, will look for the best
% assignment of labels to objects such that it matches the gt and returns the updated workspace.
%
% (labels that can be swapped: raw labels are identical, but working labels are not, ie, player1 and
% player2, where the raw labels that feed into each are exactly the same)
%
% label_used is the assignment of objects in the ground truth that led to the best interpretation of the workspace. 

    if ischar(lb_input)
        lb_fname = lb_input;
        [~,lbs] = situate.labl_load( lb_fname, situation_struct );
    elseif isstruct(lb_input)
        lb_fname = lb_input.fname_lb;
        [~,lbs] = situate.labl_load( lb_fname, situation_struct );
    elseif isempty(lb_input)
        warning('called with an empty label file');
        return;
    end
    
    best_GT_IOU = zeros(1,length(workspace.labels));
    best_lb_ind = [];
    for li = 1:length(lbs)
        GT_IOU = workspace_score_helper( workspace, lbs(li) );
        if sum(GT_IOU) > sum(best_GT_IOU)
            best_GT_IOU = GT_IOU;
            best_lb_ind = li;
        end
    end
    
    workspace.GT_IOU = best_GT_IOU;
    label_used = lbs(best_lb_ind);
    
end

function GT_IOU = workspace_score_helper( workspace, lb )

    GT_IOU = zeros(1,length(workspace.labels));
    for wi = 1:length(workspace.labels)
        lb_ind = strcmp( workspace.labels{wi}, lb.labels_adjusted );
        if isfield(workspace,'boxes_r0rfc0cf')
            GT_IOU(wi) = intersection_over_union( workspace.boxes_r0rfc0cf(wi,:), lb.boxes_r0rfc0cf(lb_ind,:), 'r0rfc0cf', 'r0rfc0cf' );
        elseif isfield(workspace,'boxes_xywh')
            GT_IOU(wi) = intersection_over_union( workspace.boxes_xywh(wi,:), lb.boxes_xywh(lb_ind,:), 'xywh', 'xywh' ); 
        end
    end

end





