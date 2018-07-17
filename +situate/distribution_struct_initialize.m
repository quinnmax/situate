function [d,d_joint] = distribution_struct_initialize(p,im,learned_models,workspace)

    d = [];
    for dist_index = length(p.situation_objects):-1:1
        d(dist_index).interest          = p.situation_objects{dist_index};
        if isstruct(p.situation_objects_urgency_pre)
            d(dist_index).interest_priority = p.situation_objects_urgency_pre.(p.situation_objects{dist_index});
        elseif numel(p.situation_objects_urgency_pre) == 1
            d(dist_index).interest_priority = p.situation_objects_urgency_pre;
        elseif numel(p.situation_objects_urgency_pre) == numel(p.situation_objects)
            d(dist_index).interest_priority = p.situation_objects_urgency_pre(dist_index);
        else
            error('multiple values but don''t know to which objects to assign them');
        end
        d(dist_index).distribution      = learned_models.situation_model;
        if nargin(p.situation_model.update) < 4 % see if it wants the image for updating
            d(dist_index).distribution      = p.situation_model.update( d(dist_index).distribution, p.situation_objects{dist_index}, workspace );
        else
            d(dist_index).distribution      = p.situation_model.update( d(dist_index).distribution, p.situation_objects{dist_index}, workspace, im );
        end
        d(dist_index).image_size        = [size(im,1)   size(im,2)];
        d(dist_index).image_size_px     =  size(im,1) * size(im,2);
    end
    
    % include the joint distribution at the end
    % this is useful for re-conditioning the distributions, as well as for having it as an option if
    % we only want to sample from the conditioned sitributions some of the time
    d_joint = [];
    d_joint.interest          = 'joint distribution';
    d_joint.interest_priority = 0;
    d_joint.distribution      = learned_models.situation_model;
    d_joint.distribution      = p.situation_model.update( d(dist_index).distribution, p.situation_objects{dist_index}, workspace, im );
    d_joint.image_size        = [size(im,1)   size(im,2)];
    d_joint.image_size_px     =  size(im,1) * size(im,2);
    
end