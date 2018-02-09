function workspace = workspace_score( workspace, label, p )
% workspace = workspace_score( workspace, label_struct, p );
% workspace = workspace_score( workspace, label_fname,  p );
%
% if the p structure is given, and there are labels that can be swapped, will look for the best
% assignment of labels to objects such that it matches the gt and returns the updated workspace.
%
% (labels that can be swapped: raw labels are identical, but working labels are not, ie, player1 and
% player2, where the raw labels that feed into each are exactly the same)

    if ischar(label)
        lb = situate.labl_load( label, p );
    else
        lb = label;
    end

    workspace.GT_IOU = workspace_score_helper( workspace, lb );

    if exist('p','var') && isstruct(p) && isfield(p,'situation_objects_possible_labels')
        [unique_label_sets,counts,IA] = unique_cell( p.situation_objects_possible_labels );
        if any( counts > 1 )
        % we'll go ahead and try to reconcile labels with objects in the workspace
            best_workspace = workspace;
            for li = 1:length(unique_label_sets)
                best_workspace_quality = sum( workspace.GT_IOU );
                if counts(li) > 1
                    exchangeable_labels = p.situation_objects( eq(IA,li) );
                    exchangeable_labels_in_workspace = find(ismember( workspace.labels, exchangeable_labels ));
                    assginment_orders = all_sequences( exchangeable_labels );
                    for ai = 1:size(assginment_orders,1)
                        workspace_temp = workspace;
                        for wi = 1:length(exchangeable_labels_in_workspace)
                            workspace_temp.labels(exchangeable_labels_in_workspace(wi)) = assginment_orders(ai,wi);
                        end
                        workspace_temp.GT_IOU = workspace_score_helper( workspace_temp, lb );
                        new_workspace_quality = sum( workspace_temp.GT_IOU );
                        if new_workspace_quality > best_workspace_quality
                            best_workspace = workspace_temp;
                            best_workspace_quality = new_workspace_quality;
                        end
                    end
                end
                workspace = best_workspace;
            end
        end
    end
    
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





