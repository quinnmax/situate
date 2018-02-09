function [relevant_model,description] = distribution_struct_conditional_model_selector( conditional_models, target_object, conditioning_objects )
    
    % relevant_model = conditional_model_selector( conditional_models, target_object, conditioning_objects );
    %
    % target_object
    % conditioning_objects
    
    target_object_index = find(strcmpi(target_object, conditional_models.labels_in_indexing_order ),1,'first');
    [ ~, ~, conditioning_object_indices ] = intersect( conditioning_objects, conditional_models.labels_in_indexing_order );
    none_index = find(strcmpi('none', conditional_models.labels_in_indexing_order ));
    
    switch length(conditioning_object_indices)
        case 0
            relevant_model = conditional_models.models{ target_object_index, none_index, none_index };
            description    = [ target_object ' given no other boxes' ];
        case 1
            relevant_model = conditional_models.models{ target_object_index, conditioning_object_indices(1), none_index };
            description    = [ target_object ' given '  conditioning_objects{1} ];
        case 2
            relevant_model = conditional_models.models{ target_object_index, conditioning_object_indices(1), conditioning_object_indices(2) };
            description    = [ target_object ' given '  conditioning_objects{1} ' and ' conditioning_objects{2}];
        case 3
            relevant_model = conditional_models.models{ target_object_index, conditioning_object_indices(1), conditioning_object_indices(2), conditioning_object_indices(3) };
            description    = [ target_object ' given '  conditioning_objects{1} ', ' conditioning_objects{2}, ', and ' conditioning_objects{3}];
        otherwise
            error('conditional_model_selector: too many relevant objects in the workspace');
    end
    
end
    
    