
function [boxes_r0rfc0cf, raw_samples] = situation_model_normal_rc_sample( model, arg1, arg2 )
    
    % [boxes_r0rfc0cf, raw_samples] = situation_model_normal_sample( model, object_type, n); 
        % if a joint distribution
    
    % [boxes_r0rfc0cf, raw_samples] = situation_model_normal_sample( model, n ); 
        % if a conditioned distribution for a single object

    if nargin == 3
        object_type = arg1;
        n = arg2;
    end
        
    if nargin < 3 && isnumeric(arg1)
        object_type = [];
        n = arg1;
    end
    
    if nargin < 3 && ischar(arg1)
        object_type = arg1;
    end
    
    if ~exist('n','var') || isempty(n)
        n = 1;
    end
    
    
    % see if we're sampling from a big joint distribution or a conditioned
    % distribution for a particular object
    
    if model.is_conditional
    
        % if it's conditioned, it's conditioned for only one object, so
        % just return the only box spec in there
        
        raw_samples = mvnrnd( model.mu, model.Sigma, n);
        r0_col = find(strcmp( 'r0', model.parameters_description ));
        rf_col = find(strcmp( 'rf', model.parameters_description ));
        c0_col = find(strcmp( 'c0', model.parameters_description ));
        cf_col = find(strcmp( 'cf', model.parameters_description ));
        
        boxes_r0rfc0cf = raw_samples( :, [r0_col rf_col c0_col cf_col] );
        
    elseif isempty(object_type) 
        
        % return a sample for all objects
        raw_samples = mvnrnd( model.mu, model.Sigma, n );
        num_vars_per_obj = length(model.mu)/length(model.situation_objects);
        r0_col = find(strcmp( 'r0', model.parameters_description ));
        rf_col = find(strcmp( 'rf', model.parameters_description ));
        c0_col = find(strcmp( 'c0', model.parameters_description ));
        cf_col = find(strcmp( 'cf', model.parameters_description ));
        box_inds = [];
        for oi = 1:length(model.situation_objects)
            offset = (oi-1)*num_vars_per_obj;
            new_inds = offset + [r0_col rf_col c0_col cf_col];
            box_inds(end+1:end+4) = new_inds;
        end
        boxes_r0rfc0cf = raw_samples(box_inds);
        
    else
        
        % is from the joint with a specified object,
        % so we want to figure out where in the big vector our object of interest is
        
        raw_samples = mvnrnd( model.mu, model.Sigma, n );

        num_vars_per_obj = length(model.mu)/length(model.situation_objects);
        row_ish = find( strcmp( object_type, model.situation_objects ), 1, 'first' );
        sub_ind_0 = (row_ish-1) * num_vars_per_obj + 1;
        sub_ind_f = sub_ind_0 + num_vars_per_obj - 1;

        obj_samples = raw_samples(:, sub_ind_0:sub_ind_f );
        r0_col = find(strcmp( 'r0', model.parameters_description ));
        rf_col = find(strcmp( 'rf', model.parameters_description ));
        c0_col = find(strcmp( 'c0', model.parameters_description ));
        cf_col = find(strcmp( 'cf', model.parameters_description ));

        boxes_r0rfc0cf = obj_samples( :, [r0_col rf_col c0_col cf_col] );
        
    end

end







